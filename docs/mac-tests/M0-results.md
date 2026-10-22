# M0 Mac test results

Branch `m0/mac`, run 2026-10-21/22 on a MacBook Air (macOS 27.0.1, Swift 6.4, Command Line Tools only),
DualSense over USB-C, Fallout 4 in CrossOver. All sections (1 to 8) are run.

Note on how it was run: the probe commands for sections 1 to 4 ran from the Claude desktop app's shell, not
Terminal.app. The injection and bridge steps (5, 6) ran from Terminal.app, because Accessibility is granted
per app and only Terminal had it. On macOS 27 the Accessibility pane is reached through
"Device Control and Data Access" in Privacy & Security.

| Step | Test | Result | Notes |
|---|---|---|---|
| 1 | Setup: build, test, `list`, permissions | PARTIAL | Swift 6.4. `swift build` passes. `swift test` fails: `XCTest` not found, only Command Line Tools installed (no Xcode). `list`: product 0x0CE6, USB, max input report size 64. |
| 2 | USB fixtures captured (2.1 to 2.11) | PASS | The buffer includes the report ID: each line is the ID column `01` plus a 64-byte buffer that starts `01`. About 250-262 reports/s. 2.6 hat-ne and 2.7 sticks and 2.8 touch-topleft were re-captured after a bad first take; all values checked (see below). |
| 2 | Bluetooth fixtures captured (2.12, 2.13) | PASS | Report ID column `31`, buffer starts `31`, 78 values per line. Feature report `0x05` read ok, 41 bytes. About 65 reports/s idle. |
| 2 | `swift test` with fixtures | FAIL | Could not run: XCTest missing (needs full Xcode). Not a code failure. Fixture parsing is unverified. |
| 3.1 | Lightbar | PASS | Turned blue. |
| 3.2 | Rumble | FAIL | No rumble at `rumble 200 0 --ms 500`, nor at `rumble 255 255 --ms 1500`. Writes succeeded. Report sent: `02 01 00 00 c8 00 ... 04 ...` (flag0 `0x01`, flag2 `0x04` at offset 39, strong motor `c8`). Flags match the spec and the Linux driver; cause unknown. See Questions. |
| 3.3 | Trigger resistance, mode `0x01` or `0x21` | PASS | Mode `0x01` (`trigger right 1 0 255 0 0 0 0 0 0 0 0`) made R2 hard to pull. `0x21` not needed. |
| 3.4 | Trigger off | PASS | R2 back to a normal pull. |
| 3.5 | Player LED | PASS | `player 1` lit only the centre LED. |
| 3.6 | Outputs with Fallout 4 running | PARTIAL | Lightbar and player LED held for 10 s while Terminal had focus. When the game was focused, the lightbar turned turquoise and the player LED went off: the game or CrossOver overrides outputs while it has focus. R2 resistance was hard with the game running but was not re-checked with the game focused. Rumble not repeated. |
| 4 | Seize hides the controller from the game | PASS | `read --seize` opened with `0x00000000`, no `sudo` needed, no errors, about 250 reports/s. The game stopped reacting while it ran, and saw the controller again on its own after Ctrl-C. Important condition: the seize must be active **before** the game boots. See Findings. |
| 5.1 | Injected key (W) | PASS | Character walked forward about 1 s (run from Terminal, seize active before boot). A first attempt failed for non-code reasons: `W` was bound to a mod hotkey, and Accessibility was not granted to the Claude app. |
| 5.2 | Injected mouse deltas | PASS | View turned right smoothly for about 0.8 s. |
| 5.3 | Injected click | PASS | The game registered the click. |
| 6 | Bridge playable | PASS | All ten mappings worked, no latency noticed, default sensitivity fine, nothing stuck after Ctrl-C (the game went back to keyboard). Limitation: keyboard and mouse lose analogue stick and trigger travel. See Findings. |
| 7 | XInput stub loaded, A press seen | FAIL | The game imports `XINPUT1_3.dll` (`strings Fallout4.exe`; no function names in the binary). The stub loaded as `...\Fallout 4\XINPUT1_3.dll` (stub log, and the module list in the Buffout 4 crash log), then the game crashed before the main menu, inside `BSPCGamepadDeviceHandler` (ntdll.dll+0068870, near the string "XINPUT1_3.dll"). No `XInputGetState` polling lines in the log. Leading hypothesis, not confirmed: the game looks the functions up by ordinal, and the stub's ordinals (named functions at 93-99, `XInputGetStateEx` at 100) do not match Microsoft's xinput1_3. See Questions. |
| 7 | Rumble calls observed | FAIL | None: no `XInputSetState` lines, the game crashed first. |
| 8 | USB report rate | PASS | 250 Hz, steady over 6 s (no seize). |
| 8 | Bluetooth report rate | PASS | 65-67 Hz. Reports undecoded as expected: last id=0x31, length 78. Feature report `0x05` read ok (41 bytes). |

## Fixture checks

All values below were verified by decoding the saved files.

- Buttons byte (buffer offset 8): idle `0x08`, Cross `0x28`, Circle `0x48`, Square `0x18`, Triangle `0x88`.
- Hat nibble: N 0, NE 1, E 2, SE 3, S 4, SW 5, W 6, NW 7, neutral 8.
- Sticks: all four axes span 0 to 255 in `usb-sticks.hex`.
- Touch: top-left x 38-40, y 91-96; bottom-right x 1806-1808, y 951-958 (pad 1920 x 1080). Two fingers: x about 171 and 1765, both near mid-height (finger 2 at buffer offsets 37-40).
- Charging: battery byte (offset 53) is `0x10` on both USB captures, status 1 (charging), level 0. The controller was nearly flat.
- Bluetooth: report ID `31`, buttons byte at the same column as USB (`28` with Cross held).

## Findings

1. **Fallout 4 ignores the keyboard when it sees a controller.** Seizing after the game has started is not enough: the game stays in controller mode. With the seize running **before** the game boots, the game never sees the controller and uses keyboard and mouse, and injection works. Any bridge must seize first and start the game second.
2. **The pad can connect over Bluetooth on its own** even with the USB cable in, and a seize on that connection showed no open line during one attempt. It later came up on USB. The app must handle either transport.
3. **The keyboard and mouse bridge loses analogue input.** Stick tilt becomes full-speed WASD, trigger travel becomes a button, and look speed can only be approximated. This is the case for the XInput proxy (section 7).
4. **The game or CrossOver overrides lightbar and player LEDs while it has focus** (3.6).

## Architecture answers

1. Seize works without root and hides the controller from CrossOver: **yes**, if it starts before the game boots.
2. Injected keys and mouse deltas drive Fallout 4: **yes** (W key, mouse deltas and click all worked), with the same seize-first condition.
3. The bridge loop is playable (latency notes): **yes**, no latency noticed, but analogue sticks and trigger travel are lost.
4. CrossOver loads the proxy DLL and the game accepts its state (rumble calls observed?): **partial**. CrossOver loads the proxy DLL (as `XINPUT1_3.dll`), but the game crashes before the main menu, so its state was not accepted and no rumble calls were observed. Likely cause: ordinal mismatch (see Questions).

## Questions

(for the architect)

1. Rumble does nothing over USB with the M0 builder (strong 200 and 255/255 both tried, writes succeed). Flags set: flag0 `0x01`, flag2 `0x04`. Is a further flag or field (for example haptics select, bit 1 of flag0, or a motor power setting) needed on this firmware? Lightbar, trigger and player LED all work with the same builder, so the output path itself is fine.
2. `swift test` could not run because the Mac has only the Command Line Tools. Install full Xcode, or is there a supported way to run XCTest with the Command Line Tools?
3. Should the bridge design assume seize-before-launch, given finding 1? That makes the app responsible for ordering.
4. The XInput stub crashes Fallout 4 at launch. The game imports `XINPUT1_3.dll` and seems to resolve functions by ordinal (the binary holds no XInput function names). The stub exports its named functions at ordinals 93-99, not at Microsoft's xinput1_3 ordinals. Please confirm Microsoft's ordinal table for xinput1_3 (and xinput1_4), have the stub use it, and have a cloud session rebuild the DLLs. Note the game was running F4SE and many F4SE plugins (Buffout 4 crash log), which could also play a part; a retest on a clean launch would rule that out.
