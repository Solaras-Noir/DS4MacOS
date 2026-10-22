# XInput stub DLL (M0 feasibility test)

A tiny XInput replacement for Windows games under CrossOver. It reports a synthetic controller 0:
the A button is held for 1 s out of every 2 s, the left stick traces a circle (one turn per 4 s,
amplitude about 20000), and `dwPacketNumber` increments per call. Controllers 1 to 3 report
`ERROR_DEVICE_NOT_CONNECTED`. `XInputSetState` appends the two motor speeds to the log, and
`XInputGetState` appends one line per 500 calls. 
Exports carry the Wine/Microsoft ordinals from `docs/protocol/xinput-ordinals.md`, pinned by one `.def` per DLL:
`xinput1_3.def` (GetState 2, SetState 3, GetCapabilities 4, Enable 5, GetDSoundAudioDeviceGuids 6,
GetBatteryInformation 7, GetKeystroke 8, GetStateEx 100) and `xinput1_4.def` (no ordinal 6; adds
GetAudioDeviceIds 10 and GetCapabilitiesEx 108). Both DLLs are built from the same `xinput_stub.c`.
Ordinals 101 to 103 (guide-button wait/cancel, power-off) are deliberately NOT exported: neither Wine spec
lists them, and the ordinals doc says not to invent them without a second source. Ordinal 9 is also absent.
`DllMain` only returns TRUE (it is the PE entry point, not an export). The log file path is built and the
file opened lazily on the first logged call (rumble, or every 500th poll), so there is no load-time log line.
The stub uses no C runtime (`-nostdlib -nostartfiles`, hand-rolled formatting, sine approximation), so
the only import is `KERNEL32.dll`. The mingw toolchain on the Mac is UCRT-only; a normal build would import
`api-ms-win-crt-*`, which the spec's "KERNEL32 and msvcrt only" rule forbids. The DLLs are 64-bit only.

Export tables (`x86_64-w64-mingw32-objdump -p`), imports are identical for both DLLs:

```
xinput1_3.dll, Ordinal Base 2
	[   0] +base[   2] 00001980 Export RVA
	[   1] +base[   3] 00001a00 Export RVA
	[   2] +base[   4] 00001b40 Export RVA
	[   3] +base[   5] 00001b80 Export RVA
	[   4] +base[   6] 00001be0 Export RVA
	[   5] +base[   7] 00001b90 Export RVA
	[   6] +base[   8] 00001bc0 Export RVA
	[  98] +base[ 100] 000019c0 Export RVA
	[   3] +base[   5]  0000 XInputEnable
	[   5] +base[   7]  0001 XInputGetBatteryInformation
	[   2] +base[   4]  0002 XInputGetCapabilities
	[   4] +base[   6]  0003 XInputGetDSoundAudioDeviceGuids
	[   6] +base[   8]  0004 XInputGetKeystroke
	[   0] +base[   2]  0005 XInputGetState
	[  98] +base[ 100]  0006 XInputGetStateEx
	[   1] +base[   3]  0007 XInputSetState

xinput1_4.dll, Ordinal Base 2
	[   0] +base[   2] 00001980 Export RVA
	[   1] +base[   3] 00001a00 Export RVA
	[   2] +base[   4] 00001b40 Export RVA
	[   3] +base[   5] 00001b80 Export RVA
	[   5] +base[   7] 00001b90 Export RVA
	[   6] +base[   8] 00001bc0 Export RVA
	[   8] +base[  10] 00001bf0 Export RVA
	[  98] +base[ 100] 000019c0 Export RVA
	[ 106] +base[ 108] 00001c00 Export RVA
	[   3] +base[   5]  0000 XInputEnable
	[   8] +base[  10]  0001 XInputGetAudioDeviceIds
	[   5] +base[   7]  0002 XInputGetBatteryInformation
	[   2] +base[   4]  0003 XInputGetCapabilities
	[ 106] +base[ 108]  0004 XInputGetCapabilitiesEx
	[   6] +base[   8]  0005 XInputGetKeystroke
	[   0] +base[   2]  0006 XInputGetState
	[  98] +base[ 100]  0007 XInputGetStateEx
	[   1] +base[   3]  0008 XInputSetState

Import table (both DLLs)
	DLL Name: KERNEL32.dll
	CloseHandle, CreateFileA, GetLocalTime, GetTempPathA, GetTickCount64, Sleep, WriteFile
```

(The first number in each line is the zero-based table index; the ordinal is the `+base[N]` value.)

Note: `bin/xinput1_3.dll` and `bin/xinput1_4.dll` are committed. This is an exception to the normal
practice of not committing build output; they are small test artefacts so the Mac session needs no toolchain.

## Rebuild

On Linux with mingw-w64: `make` (from this folder), `make clean` to remove the objects and DLLs.
Check with `x86_64-w64-mingw32-objdump -p bin/xinput1_3.dll`.

## Install for Fallout 4 under CrossOver

Unplug the physical controller for this test, so the game sees only the stub's synthetic controller.

1. On the Mac, see which name the game imports first: `strings Fallout4.exe | grep -i xinput`.
2. Copy both `bin/xinput1_3.dll` and `bin/xinput1_4.dll` next to `Fallout4.exe` in the bottle.
3. Set the DLL override for `Fallout4.exe` to `native,builtin` for `xinput1_3` and `xinput1_4`, in the
   bottle's Wine configuration (Libraries tab, with `Fallout4.exe` as the application), or via the registry key
   `HKCU\Software\Wine\AppDefaults\Fallout4.exe\DllOverrides` (string values `xinput1_3` and `xinput1_4`
   set to `native,builtin`).
4. Start the game. The A button should toggle and the camera/character should drift in a circle if the stub is used.

## Log

`%TEMP%\xinput-stub.log` inside the bottle, typically
`<bottle>/drive_c/users/crossover/Temp/xinput-stub.log`.
The stub logs nothing at load; the first line appears on the first XInput call.

## Remove

Delete both DLLs from the game folder and remove the `Fallout4.exe` DLL overrides (or the registry key above).

## Pinned image base (probe only)

The DLLs have no `.reloc` section, so the Makefile pins the image base to `0x180000000` and clears the
DYNAMIC_BASE and HIGH_ENTROPY_VA flags (`--image-base`, `--disable-dynamicbase`,
`--disable-high-entropy-va`). That is acceptable for a feasibility probe loaded by one game under
CrossOver. A shipping proxy DLL (M3b) should be built with relocations instead. Not yet tested in a
bottle; the M2 Mac session does that.
