# DualSense HID protocol: starting notes

Status: architect's notes from memory of the sources below. Offsets marked **verify** must be
checked against the sources and against captured fixtures before being relied on. The M1
researcher task replaces this file with a sourced version.

## Identification

| Field | Value |
|---|---|
| Vendor ID | `0x054C` (Sony) |
| Product ID | `0x0CE6` DualSense, `0x0DF2` DualSense Edge |
| USB input report | ID `0x01`, 64 bytes including the ID |
| USB output report | ID `0x02`, 48 bytes including the ID |
| Bluetooth input report (full) | ID `0x31`, 78 bytes including the ID, CRC32 in the last 4 bytes |
| Bluetooth input report (simple) | ID `0x01`, about 10 bytes, sent until the full mode is enabled (**verify**) |
| Bluetooth output report | ID `0x31`, 78 bytes including the ID, CRC32 in the last 4 bytes |
| Calibration feature report | ID `0x05`. Reading it over Bluetooth switches the controller to full `0x31` input reports (**verify**) |

## Input report payload (63 bytes)

The same 63-byte structure appears at offset 1 in the USB report (after the ID) and at offset 2 in
the Bluetooth `0x31` report (after the ID and one tag byte). Offsets below are within the payload.
Source: `struct dualsense_input_report` in the Linux driver `drivers/hid/hid-playstation.c`.

| Offset | Size | Name | Meaning |
|---|---|---|---|
| 0 | 1 | x | Left stick X, 0..255, 128 centre |
| 1 | 1 | y | Left stick Y, 0 up, 255 down |
| 2 | 1 | rx | Right stick X |
| 3 | 1 | ry | Right stick Y |
| 4 | 1 | z | L2 analog, 0..255 |
| 5 | 1 | rz | R2 analog, 0..255 |
| 6 | 1 | seq_number | Increments per report, wraps; use for drop detection |
| 7 | 1 | buttons[0] | Bits 0..3: hat (0 N, 1 NE, 2 E, 3 SE, 4 S, 5 SW, 6 W, 7 NW, 8 released). Bit 4 Square, 5 Cross, 6 Circle, 7 Triangle |
| 8 | 1 | buttons[1] | Bit 0 L1, 1 R1, 2 L2 click, 3 R2 click, 4 Create, 5 Options, 6 L3, 7 R3 |
| 9 | 1 | buttons[2] | Bit 0 PS, 1 touchpad click, 2 mute. Edge: bits 4..7 paddles and Fn (**verify**) |
| 10 | 1 | buttons[3] | Reserved |
| 11 | 4 | reserved | |
| 15 | 6 | gyro[3] | int16 little-endian x, y, z (pitch, yaw, roll). Raw, needs calibration from feature report `0x05` |
| 21 | 6 | accel[3] | int16 little-endian x, y, z |
| 27 | 4 | sensor_timestamp | uint32 little-endian, 0.33 microsecond units (**verify**) |
| 31 | 1 | reserved2 | |
| 32 | 4 | points[0] | Touch point 1, see below |
| 36 | 4 | points[1] | Touch point 2 |
| 40 | 12 | reserved3 | |
| 52 | 1 | status | Bits 0..3 battery level 0..10 (percent is level * 10 + 5, capped at 100). Bits 4..7: 0 discharging, 1 charging, 2 full, 0xA and 0xB temperature or voltage errors, 0xF unknown |
| 53 | 10 | reserved4 | Byte 53 bit 0 headphones, bit 3 USB connected (**verify**) |

Touch point (4 bytes):

| Byte | Meaning |
|---|---|
| 0 | Bit 7 set means no contact. Bits 0..6: contact id, increments per new touch |
| 1 | x low 8 bits |
| 2 | Bits 0..3: x high 4 bits. Bits 4..7: y low 4 bits |
| 3 | y high 8 bits |

Touchpad resolution is 1920 by 1080 (x 0..1919, y 0..1079).

## Output report common block (47 bytes)

At offset 1 in the USB report (after the ID `0x02`) and at offset 3 in the Bluetooth report (after
ID `0x31`, a sequence tag byte, and the tag byte `0x10`). Source: `struct
dualsense_output_report_common` in `hid-playstation.c`; trigger bytes from community sources.

| Offset | Size | Name | Meaning |
|---|---|---|---|
| 0 | 1 | valid_flag0 | Bit 0 compatible vibration (rumble bytes valid), bit 1 haptics select, bit 2 right trigger effect valid, bit 3 left trigger effect valid (**verify** bits 2 and 3; community sources, not the kernel) |
| 1 | 1 | valid_flag1 | Bit 0 mic mute LED, bit 1 power save control, bit 2 lightbar, bit 3 release LEDs, bit 4 player indicator |
| 2 | 1 | motor_right | Weak (high-frequency) rumble, 0..255 |
| 3 | 1 | motor_left | Strong (low-frequency) rumble, 0..255 |
| 4 | 4 | reserved | Audio controls |
| 8 | 1 | mute_button_led | 0 off, 1 on, 2 pulsing (**verify** pulsing) |
| 9 | 1 | power_save_control | Bit 4 mic mute |
| 10 | 1 | right trigger mode | See trigger effects |
| 11 | 10 | right trigger params | |
| 21 | 1 | left trigger mode | |
| 22 | 10 | left trigger params | |
| 32 | 6 | reserved | |
| 38 | 1 | valid_flag2 | Bit 1 lightbar setup valid, bit 2 compatible vibration 2 (newer firmware uses this instead of flag0 bit 0, **verify** the firmware threshold) |
| 39 | 2 | reserved3 | |
| 41 | 1 | lightbar_setup | Bit 1 fade out |
| 42 | 1 | led_brightness | 0 high, 1 medium, 2 low (**verify**) |
| 43 | 1 | player_leds | Bits 0..4, one per LED left to right. Player 1 is `0x04` (centre) |
| 44 | 1 | lightbar_red | |
| 45 | 1 | lightbar_green | |
| 46 | 1 | lightbar_blue | |

Trigger effect modes (mode byte plus up to 10 parameter bytes) come from community reverse
engineering, not Sony. Use Nielk1's `TriggerEffectGenerator` as the reference for the byte
encodings of: off, feedback (resistance from a position), weapon (resistance band with release),
vibration, multiple-position feedback, slope feedback and multiple-position vibration.

Known simple modes, enough for the M0 feel test (**verify** against pydualsense `TriggerModes`):

| Mode | Name | Params |
|---|---|---|
| `0x00` | Off | none |
| `0x01` | Continuous resistance | `[0]` start position 0..255, `[1]` force 0..255 |
| `0x02` | Section resistance | `[0]` start position, `[1]` end position, `[2]` force |
| `0x21` | Feedback (newer encoding of resistance) | position and strength bit fields, see TriggerEffectGenerator |
| `0x26` | Vibration | frequency and amplitude fields, see TriggerEffectGenerator |

## CRC32 over Bluetooth

Standard CRC-32 (reflected, polynomial `0xEDB88320`, initial `0xFFFFFFFF`, final xor
`0xFFFFFFFF`) computed over a one-byte seed followed by the report bytes including the report ID,
excluding the last four bytes. Stored little-endian in those four bytes. Seeds: `0xA1` input,
`0xA2` output, `0xA3` feature.

Bluetooth output report layout: byte 0 `0x31`, byte 1 sequence tag (sequence number 0..15 in the
upper nibble, increment per report), byte 2 `0x10`, bytes 3..49 the common block, bytes 50..73
zero, bytes 74..77 CRC32.

## macOS specifics to settle in M0 (not protocol, but the same people need it)

- Whether `IOHIDDeviceRegisterInputReportCallback` delivers the report with the ID in byte 0
  (hidapi's macOS backend includes the ID when writing with `IOHIDDeviceSetReport`; confirm on read
  with the `dump` probe, which prints the callback's report ID argument next to the bytes).
- Whether opening with `kIOHIDOptionsTypeSeizeDevice` works without root for a gamepad, and whether
  CrossOver then stops seeing the controller.
- The USB report rate (expected about 250 Hz) and the Bluetooth rate.

## Sources to verify against

- Linux kernel: `drivers/hid/hid-playstation.c` (structs, flags, CRC, battery decode)
- nondebug/dualsense-explorer on GitHub (byte-level maps of input and output reports)
- Nielk1's `TriggerEffectGenerator` on GitHub (trigger effect encodings)
- flok/pydualsense on GitHub (a readable Python implementation of the same)
