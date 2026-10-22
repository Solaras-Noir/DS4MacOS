# XInput stub DLL (M0 feasibility test)

A tiny XInput replacement for Windows games under CrossOver. It reports a synthetic controller 0:
the A button is held for 1 s out of every 2 s, the left stick traces a circle (one turn per 4 s,
amplitude about 20000), and `dwPacketNumber` increments per call. Controllers 1 to 3 report
`ERROR_DEVICE_NOT_CONNECTED`. `XInputSetState` appends the two motor speeds to the log, and
`XInputGetState` appends one line per 500 calls. At load it logs which DLL file the game picked.
It exports the seven XInput functions plus `XInputGetStateEx` at ordinal 100 (`@100 NONAME`, ordinal only).
Imports are limited to `KERNEL32.dll` and `msvcrt.dll`. The DLLs are 64-bit only (Fallout 4 is a 64-bit game).

Known gaps: export ordinals other than 100 do not match Microsoft's DLLs (games import by name), and
the stub does not export `XInputGetAudioDeviceIds`, which the real `xinput1_4` has. If the game fails to
load with the override set, that missing export is the first suspect.

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
`<bottle>/drive_c/users/crossover/Temp/xinput-stub.log`. The first line (`DLL_PROCESS_ATTACH loaded as ...`)
names the DLL file the game loaded.

## Remove

Delete both DLLs from the game folder and remove the `Fallout4.exe` DLL overrides (or the registry key above).
