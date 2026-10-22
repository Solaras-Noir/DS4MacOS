# DualSense HID protocol: sourced notes

Status: sourced, researched 2026-10-22. Short names: **K** = Linux `drivers/hid/hid-playstation.c`
(copy fetched from git.kernel.org, see Sources; line numbers are from that copy and drift), **E** =
nondebug/dualsense `dualsense-explorer.html` (and `report-descriptor-*.txt`), **N** = Nielk1
`TriggerEffectGenerator.cs` (a gist), **P** = flok/pydualsense `pydualsense.py` / `enums.py`,
**F** = our fixtures in `Tests/DualSenseCoreTests/Fixtures`, **M0** = `docs/mac-tests/M0-results.md`.
Anything not confirmed is marked UNVERIFIED. All offsets in the tables are **payload offsets** unless
stated "buffer".

## Identification

| Field | Value | Source |
|---|---|---|
| Vendor / product | `0x054C`; `0x0CE6` DualSense, `0x0DF2` Edge | dualsensehid.js FILTERS, E L113; K product ids at L1805-1809 |
| USB input report | ID `0x01`, 64 bytes incl. ID | K L81-82; F usb-*.hex (64-byte buffer) |
| USB output report | ID `0x02`. K: 63 bytes incl. ID. E: 47 data + ID = 48. USB descriptor Report Count 47 (0x2F) | K L85-86; E L909; rdusb.txt L56-59 |
| BT input report (full) | ID `0x31`, 78 bytes incl. ID, CRC32 last 4 | K L83-84; F bt-*.hex |
| BT input report (simple) | ID `0x01`, 10 bytes incl. ID (9 without ID) | E L121 (`BT_INPUT_REPORT_0x01_SIZE = 9`); layout below |
| BT output report | ID `0x31`, 78 bytes incl. ID, CRC32 last 4 | K L87-88, L301-309 |
| Feature `0x05` calibration | 41 bytes incl. ID (descriptor count 40 + ID); M0 read it OK over USB and BT | K L90-91; rdbt.txt L92-95; M0 step 2 |
| Feature `0x20` firmware info | 64 bytes; `update_version` = LE16 at buffer offset 44, hw_version LE32 at 24, fw_version LE32 at 28 | K L94-95, L1151-1176 |
| Feature `0x09` pairing info | 20 bytes (MAC address) | K L92-93 |

Measured on our hardware (M0): the IOKit callback buffer **includes the report ID in byte 0** (USB 64,
BT 78 bytes); USB about 250 Hz (250-262 reports/s), Bluetooth about 65 Hz (65-67); feature `0x05` read
OK, 41 bytes, on both transports.

## Bluetooth mode switch and the simple report

| Fact | Detail | Source |
|---|---|---|
| Default over BT | Controller sends only the simple report `0x01` (no motion, no touchpad, no battery) | E L339-341; K L1447-1449 comment |
| Switch to full `0x31` | **Get feature report `0x05`**, 41 bytes (ID + 40). Reading it makes the controller start sending `0x31`. (K reads it during probe for calibration, which has this effect.) The 41-byte reply carries a CRC (seed `0xA3`) in its last 4 bytes | E L338-346; K L1043, L799-832 |
| Confirmed on hardware | M0 read `0x05` over BT (41 bytes) and then captured `0x31` at ~65 Hz | M0 step 2, step 8 |

Simple `0x01` BT report, 10 bytes **with ID** (buffer offsets), derived from the HID descriptor
(4 axes X,Y,Z,Rz; 4-bit hat; 14 buttons; 6 const bits; Rx, Ry) and matching E's reader. No fixture
exists for it (F has only `0x31`), so field positions are source-derived only.

| Buffer offset | Meaning | Source |
|---|---|---|
| 0 | `0x01` | |
| 1, 2, 3, 4 | Left X, Left Y, Right X (usage Z), Right Y (usage Rz) | rdbt.txt L10-23; E L584-590 |
| 5 | bits 0-3 hat, bits 4-7 Square, Cross, Circle, Triangle | rdbt.txt L24-37; E L586 |
| 6 | L1, R1, L2, R2, Create, Options, L3, R3 (bits 0-7) | E L613-620 (same bit order as full report) |
| 7 | bit 0 PS, bit 1 touchpad click; bits 2-7 constant (no mute bit) | rdbt.txt L32-40; E L621 |
| 8, 9 | L2 analog, R2 analog (usages Rx, Ry) | rdbt.txt L41-48; E L588-589 |

## Input report payload (63 bytes)

Payload starts at buffer offset **1 on USB** and **2 on Bluetooth `0x31`** (byte 1 of a BT report is a
tag, see below). So buttons[0] is at buffer offset 8 on USB and **9 on BT**. Note: M0's statement
"BT buttons at the same column as USB" holds for the payload, not the buffer; verified below.
Source for all rows: K `struct dualsense_input_report` L245-266 (size asserted 63, L267); the verify
column says what else confirms it.

| Offset | Size | Name | Meaning | Verified by |
|---|---|---|---|---|
| 0-3 | 4 | x, y, rx, ry | Left X, Left Y, Right X, Right Y, 0..255, centre ~128, Y 0 = up | F usb-sticks (0..255 spans), M0 |
| 4, 5 | 2 | z, rz | L2, R2 analog 0..255 | K L1496+ |
| 6 | 1 | seq_number | USB: increments per report (F usb-idle 112, 115, ...). BT: constant `1` in every fixture row (the counter is in the BT tag byte, buffer 1, instead) | F |
| 7 | 1 | buttons[0] | bits 0-3 hat (0 N,1 NE,2 E,3 SE,4 S,5 SW,6 W,7 NW,8 neutral); bit 4 Square, 5 Cross, 6 Circle, 7 Triangle | K L98-102; F hat/face fixtures (idle `08`, Cross `28`) |
| 8 | 1 | buttons[1] | L1 b0, R1 b1, L2 click b2, R2 click b3, Create b4, Options b5, L3 b6, R3 b7 | K L103-110 |
| 9 | 1 | buttons[2] | PS b0, touchpad click b1, mic mute b2. Edge only: Fn1 b4, Fn2 b5, left paddle b6, right paddle b7 | K L111-119 |
| 10 | 1 | buttons[3] | Reserved (0 in all F) | K struct |
| 11-14 | 4 | reserved | | K |
| 15-20 | 6 | gyro[3] | int16 LE x,y,z (pitch, yaw, roll). Needs calibration from feature `0x05` | K L1556; F usb-idle decodes to plausible values |
| 21-26 | 6 | accel[3] | int16 LE x,y,z. 1 g = 8192 raw (K L173) | K |
| 27-30 | 4 | sensor_timestamp | uint32 LE, **0.33 microsecond units** (3 ticks = 1 us); wraps | K L1578-1594 |
| 31 | 1 | reserved2 | | K |
| 32-35, 36-39 | 4+4 | points[0], points[1] | touch points, below | K L236-241 |
| 40 | 1 | reserved3[0] | | K |
| 41, 42 | 1+1 | reserved3[1..2] | E reads these as R2 / L2 trigger-effect status (low nibble); F idle shows `09` on both. Meaning of 9 UNVERIFIED | E L708-709 |
| 43-51 | 9 | reserved3 rest | | K |
| 52 | 1 | status[0] | bits 0-3 battery level, bits 4-7 charge state; see Battery | K L122-123 |
| 53 | 1 | status[1] | bit 0 headphone jack, bit 1 mic jack, bit 2 mic mute; see below | K L124-127 |
| 54 | 1 | status[2] | not used by K | K struct |
| 55-62 | 8 | reserved4 | | K |

Battery and charge state (K L1610-1640; P enums agree):

| status[0] bits 4-7 | Meaning | Percent |
|---|---|---|
| `0x0` | discharging | `min(level*10 + 5, 100)` |
| `0x1` | charging | `min(level*10 + 5, 100)` |
| `0x2` | full | 100 |
| `0xA`, `0xB` | voltage/temperature out of range / temperature error (not charging) | 0 |
| `0xF` and other | charging error / unknown | 0 |

Level (bits 0-3) is 0..10. F: both USB captures have status[0] = `0x10` (charging, level 0, pad nearly
flat); BT captures have `0x00` (discharging, level 0). USB buffer offset of status[0] is 53, BT is 54.

status[1]: K defines only bit 0 (headphones), bit 1 (mic), bit 2 (mic mute); K uses bits 0-1 only on
USB (L1534). The old note "bit 3 = USB connected" is **not in K**. Observed in F: status[1] = `0x18`
(bits 3 and 4 set) on both USB captures and `0x00` on both BT captures. This suggests bits 3-4 relate
to the USB cable but is a 2-vs-2 observation only: meaning UNVERIFIED.

Touch point (4 bytes, K L236-241, L139-147):

| Byte | Meaning |
|---|---|
| 0 | bit 7 set = no contact; bits 0-6 contact id |
| 1 | x low 8 bits |
| 2 | bits 0-3 x high, bits 4-7 y low |
| 3 | y high 8 bits |

x = `(b2 & 0x0F) << 8 | b1`, y = `b3 << 4 | b2 >> 4`. Pad is 1920 x 1080 (K L177-178). Matches F
(top-left x 38-40,y 91-96; bottom-right x ~1807,y ~955) and E L33-39 / dualsensehid.js.

Gyro/accel order: confirmed. Row 0 of usb-idle.hex decodes (LE int16) gyro at payload 15-20 =
(-104, 27, 175) and accel at 21-26 = (1534, 7897, -230); bt-idle row 0 gyro (0, -1, 0), accel
(-56, 7999, 1052). Gyro near 0 and about 1 g (8192) on the Y accel axis at rest match K's layout
(gyro at 15, accel at 21). P's differing indices are not used.

## Bluetooth `0x31` framing

| Buffer offset | Input report | Output report | Source |
|---|---|---|---|
| 0 | `0x31` | `0x31` | K L83, L302 |
| 1 | tag byte: upper nibble counts up per report, low nibble `1` in all F captures (`41,51,61,...`) | **seq_tag**: upper nibble = sequence number 0..15, incremented every report (wraps at 16); lower nibble tag, 0 | F; K L1263-1270 |
| 2 | payload (63 bytes) starts | **tag `0x10`** ("must be set, meaning unclear") | K L1261, L1456 |
| 3-49 | payload continues | **common block** (47 bytes) | K L303-304 |
| 50-73 | | reserved, zero (24 bytes) | K L305 |
| 74-77 | CRC32 LE | CRC32 LE | K L306, L1458-1463 |

CRC32: standard CRC-32 (poly `0xEDB88320` reflected, init `0xFFFFFFFF`, final xor) over
`[seed byte] + report bytes 0..73` (report ID included, last 4 excluded). Stored little-endian in
bytes 74-77. Seeds: **`0xA1` input, `0xA2` output, `0xA3` feature** (K L77-79, L1308-1315). E agrees
(prefix `0xA2` then report ID, E L255). **Checked on fixtures:** 404 of 404 BT input reports in
`bt-idle.hex` and `bt-cross.hex` satisfy `crc32(A1 || buf[0..73]) == LE32(buf[74..77])`.

## Output report common block (47 bytes)

USB: common offset c is at report buffer offset **c + 1** (after ID `0x02`). BT: buffer offset **c + 3**.
Source: K `struct dualsense_output_report_common` L270-299 (size asserted 47, L300).

| Offset | Size | Name | Meaning | Source |
|---|---|---|---|---|
| 0 | 1 | valid_flag0 | b0 COMPATIBLE_VIBRATION, b1 HAPTICS_SELECT, b2 right trigger effect valid, b3 left trigger effect valid, b5 speaker volume, b6 mic volume, b7 audio control | K L154-158 for b0,b1,b5-7; **b2/b3 from P L522-523 comments, not in K**. Hardware-confirmed: M0 `trigger right` set b2 and R2 resistance worked (M0 3.3) |
| 1 | 1 | valid_flag1 | b0 mic mute LED, b1 power save control, b2 lightbar, b3 release LEDs, b4 player indicator, b7 audio control 2 | K L159-164 |
| 2 | 1 | motor_right | weak / high-frequency, 0..255 | K L275 |
| 3 | 1 | motor_left | strong / low-frequency, 0..255 | K L276 |
| 4 | 1 | headphone_volume | 0..0x7F | K L279 |
| 5 | 1 | speaker_volume | 0..0xFF (accepted ~0x3D..0x64) | K L1389 |
| 6 | 1 | mic_volume | 0..0x40 | K |
| 7 | 1 | audio_control | b4-5 output path select | K L167, L1384 |
| 8 | 1 | mute_button_led | 0 off, 1 on (K writes a bool). 2 = pulse: **UNVERIFIED** (no source) | K L1414 |
| 9 | 1 | power_save_control | b4 mic mute (needs flag1 b1) | K L169, L1417-1426 |
| 10-20 | 11 | **right trigger** | mode byte + 10 params | E L959 (r2Effect at common+10); N writes +0..+10; P |
| 21-31 | 11 | **left trigger** | mode byte + 10 params | E (l2Effect at common+21); P |
| 32-36 | 5 | reserved | (K lumps 10-36 as reserved2[27]; triggers live there) | K |
| 37 | 1 | audio_control2 | b0-2 speaker preamp gain | K L168, L1397 |
| 38 | 1 | valid_flag2 | b1 lightbar setup valid, b2 COMPATIBLE_VIBRATION2. P also uses b0 = led_brightness valid (not in K) | K L165-166; P enums LedOptions |
| 39-40 | 2 | reserved3 | | K |
| 41 | 1 | lightbar_setup | b1 = light out / fade out (K). P calls bit 0 "FadeBlue" (fade in blue), bit 1 "FadeOut" | K L170, L1695; P PulseOptions |
| 42 | 1 | led_brightness | 0 high, 1 medium, 2 low (P only; needs flag2 b0; UNVERIFIED on hardware) | P enums Brightness |
| 43 | 1 | player_leds | bits 0-4, LED mask | K L1722-1728 |
| 44-46 | 3 | lightbar R, G, B | needs flag1 b2 | K L1345-1349 |

Conflicts between sources (trust column is the decision):

| Item | Source A | Source B | Trust |
|---|---|---|---|
| valid_flag2 position | K: common 38 (USB buffer 39); P writes USB buffer 39 | E writes common index 39 (L1038) | K; K's struct sums to 47 and flag2 follows audio_control2 |
| BT common offset | K: report offset 3 (ID, seq_tag, 0x10, common) | P BT code puts flags one byte earlier (`outReport[1]=0x02`) | K (static_assert 78); E also uses offset 3 |
| USB output length | K 63 | E / descriptor 48 (47+ID); P 64 | Descriptor: 47 data bytes + ID = 48 works (M0 sent 48; lightbar, triggers, LEDs worked). K pads to 63 |
| lightbar_setup meaning | K: bit 1 = light out (fade) | E comment: 1 disable LEDs, 2 enable | K |
| Trigger "off" mode byte | P/old doc `0x00` | N `0x05` ("official") | Which byte M0's `trigger off` sent is UNVERIFIED (not checked); both are documented. Prefer `0x05` (N), test `0x00` on hardware |

## Rumble

Linux output worker (K L1331-1342), when `update_rumble` is set:

```
common->valid_flag0 |= HAPTICS_SELECT;                 /* 0x02, always */
if (ds->use_vibration_v2) common->valid_flag2 |= COMPATIBLE_VIBRATION2;  /* 0x04 */
else                      common->valid_flag0 |= COMPATIBLE_VIBRATION;   /* 0x01 */
common->motor_left  = ds->motor_left;   common->motor_right = ds->motor_right;
```

So the kernel sets valid_flag0 bit 1 **always**, plus exactly one of flag0 bit 0 (old firmware) or
flag2 bit 2 (new firmware). It never sets bit 0 and flag2 bit 2 together and never omits bit 1.
`use_vibration_v2` (K L1806, comment L1795-1804): DualSense `0x0CE6` : `update_version >= DS_FEATURE_VERSION(2,21)`;
DS_FEATURE_VERSION(major,minor) = `major << 8 | minor` (K L130-133), so **`>= 0x0215`** (not `0x0224`);
Edge `0x0DF2`: always v2. `update_version` = LE16 at offset 44 of feature report `0x20` (K L1176).
K's comment: v2 makes rumble behave like classic rumble; the original firmware emulated it through
haptics hardware. P comment: "0x01 set the main motors (also requires flag 0x02)" (P L520-521).

Why M0 rumble failed: M0 sent flag0 `0x01` and flag2 `0x04` with **no bit 1 (HAPTICS_SELECT)**. That
matches neither kernel path, so motors were not selected. (M0's "flags match the Linux driver" claim
is wrong.) Motor offsets were right: USB buffer 3 = motor_right (weak), 4 = motor_left (strong), both
consistent with K. Fix (owner decision, kernel-faithful): `VibrationMode.v1` sets `flag0 |= 0x03`; `.v2` sets `flag0 |= 0x02`
and `flag2 |= 0x04`; never flag0 b0 and flag2 b2 together. Default `.v2`; M2's DeviceManager reads
`update_version` and chooses (v2 iff >= `0x0215`). **Confirmed on hardware (M1, 2026-10-22, USB):** firmware
`update_version` = `0x0633` (feature `0x20` buffer starts `20 53 65 70`, ID included, so offset 44 is right);
`rumble 200 200 --ms 1000` felt with both `--vibration v2` and `--vibration v1`. Old-firmware (< 2.21)
behaviour is untested (no such controller).
Stop rumble by sending the same flags with motors 0. Mac retest should also print `update_version`.

## Lightbar, player LEDs, mic LED

- Lightbar colour: flag1 b2 + RGB at common 44-46 (works in M0 3.1). On BT the controller plays a
  startup animation and keeps a colour, so first send a setup report: flag2 = `0x02`, lightbar_setup =
  `0x02` (K L1685-1696: "On Bluetooth ... explicitly reconfigure the lightbar"; on USB harmless).
  Fade-out = lightbar_setup b1 (`0x02`).
- Player LEDs: flag1 b4 + common 43 (5 bits, centre-based). K L1722-1728 and P PlayerID agree:

| Player | Mask | Pattern |
|---|---|---|
| 1 | `0x04` | --x-- |
| 2 | `0x0A` | -x-x- |
| 3 | `0x15` | x-x-x |
| 4 | `0x1B` | xx-xx |
| 5 / all | `0x1F` | xxxxx |

  M0 3.5: `player 1` lit only the centre LED. Brightness: common 42 = 0 high / 1 medium / 2 low with
  flag2 b0 (P only, UNVERIFIED). M0 3.6: the game/CrossOver overrides LEDs while focused.
- Mic: mute LED = flag1 b0 + common 8 (0/1); microphone itself mutes with flag1 b1 + power_save_control
  b4 (K L1411-1427). Mute button toggling is the host's job (button = buttons[2] b2).

## Trigger effects

Each trigger block is 11 bytes: mode byte then 10 params (`p1..p10` = block bytes +1..+10).
Right block at common 10-20, left at 21-31 (USB buffer 11-21 / 22-32; BT 13-23 / 24-34). Enable with
valid_flag0 b2 (right) / b3 (left) (P; right confirmed by M0 3.3, left UNVERIFIED on hardware).
Zones are 0..9 along the travel; strength/amplitude 1..8 stored as `value-1` in 3 bits. Packing below
is from N unless stated (N L139-422).

| Effect | Mode | Params | Ranges |
|---|---|---|---|
| off | `0x05` (N); `0x00` also used by P/E | all 0 | |
| feedback(position, strength) | `0x21` | p1-p2 = u16 LE mask of active zones (`bit i` for i >= position); p3-p6 = u32 LE of 3-bit strengths, zone i at bits `3i..3i+2`, each `strength-1`; rest 0 | position 0..9, strength 0..8 (0 = off) |
| weapon(start, end, strength) | `0x25` | p1-p2 = u16 LE mask `(1<<start) \| (1<<end)`; p3 = `strength-1`; rest 0 | start 2..7, end start+1..8, strength 0..8 (0 = off) |
| vibration(position, amplitude, freq) | `0x26` | p1-p2 zone mask as feedback; p3-p6 u32 of 3-bit `amplitude-1` per zone; p9 = frequency Hz (byte); others 0 | position 0..9, amplitude 0..8, freq 1..255 (0 = off) |
| multiplePositionFeedback(s[10]) | `0x21` | mask has bit i only where `s[i]>0`; zone i gets 3 bits `s[i]-1` as above | each 0..8; all zero = off |
| slopeFeedback(start,end,s0,s1) | `0x21` | linear interpolation to `s[10]`, rounds, zones after end keep s1, then as multiplePositionFeedback | start 0..8, end start+1..9, strengths 1..8 |
| multiplePositionVibration(freq, a[10]) | `0x26` | as vibration but per-zone amplitudes; p9 = freq | each 0..8; freq > 0 required (N notes it may not behave as expected) |

N byte positions are `destinationIndex + n`, i.e. mode at +0 and p1 at +1; the "p9 = frequency" is
`+9`. Mask bytes: `+1` low, `+2` high; strengths: `+3` (bits 0-7), `+4`, `+5`, `+6` (bits 24-31); only
30 bits are used for 10 zones. Legacy "simple" modes (N says "should not be used"; M0 used `0x01`
successfully): `0x01` p1 start (0..255), p2 force; `0x02` p1 start, p2 end, p3 force; `0x06` p1 freq,
p2 amplitude, p3 position. P names: Rigid `0x01`, Pulse `0x02`, +`0x20` / `0x04` flag variants,
Calibration `0xFC` (do not use: N says it corrupts trigger state until reset). Other unofficial
modes in N (Bow `0x22`, Galloping `0x23`, Machine `0x27`) are out of scope.

## Sources

- https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/plain/drivers/hid/hid-playstation.c
  (fetched 2026-10-22; used because raw.githubusercontent.com/torvalds/linux/master/... returned HTTP 429)
- https://raw.githubusercontent.com/nondebug/dualsense/HEAD/dualsense-explorer.html
- https://raw.githubusercontent.com/nondebug/dualsense/HEAD/report-descriptor-bluetooth.txt
- https://raw.githubusercontent.com/nondebug/dualsense/HEAD/report-descriptor-usb.txt
- https://raw.githubusercontent.com/nondebug/dualsense/HEAD/gamepad-haptics-pcm-polyfill/dualsensehid.js
- https://gist.githubusercontent.com/Nielk1/6d54cc2c00d2201ccb8c2720ad7538db/raw/ExtendInput.DataTools.DualSense.TriggerEffectGenerator.cs
- https://raw.githubusercontent.com/flok/pydualsense/master/pydualsense/pydualsense.py and `enums.py`
- Local: docs/mac-tests/M0-results.md, Tests/DualSenseCoreTests/Fixtures/*.hex, Sources/DualSenseCore/OutputReport.swift
