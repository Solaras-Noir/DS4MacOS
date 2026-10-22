# XInput export ordinals (Wine specs)

Status: sourced from Wine's `.spec` files, fetched 2026-10-22 (master). Wine's spec files list the
ordinals Wine exports; they are a Wine reimplementation, not Microsoft's binary. Where Wine is
silent the entry is marked UNVERIFIED. Any DLL we ship must export every name at exactly these
ordinals, because Fallout 4 appears to import by ordinal (M0 finding, `docs/mac-tests/M0-results.md`
Questions 4).

## xinput1_3.dll (source: dlls/xinput1_3/xinput1_3.spec)

| Ordinal | Export | Signature (spec) |
|---|---|---|
| 1 | DllMain (`-private`, not a real export) | `(long long ptr)` |
| 2 | XInputGetState | `(long ptr)` |
| 3 | XInputSetState | `(long ptr)` |
| 4 | XInputGetCapabilities | `(long long ptr)` |
| 5 | XInputEnable | `(long)` |
| 6 | XInputGetDSoundAudioDeviceGuids | `(long ptr ptr)` |
| 7 | XInputGetBatteryInformation | `(long long ptr)` |
| 8 | XInputGetKeystroke | `(long long ptr)` |
| 100 | XInputGetStateEx (undocumented, includes guide button) | `(long ptr)` |

## xinput1_4.dll (source: dlls/xinput1_4/xinput1_4.spec)

| Ordinal | Export | Differs from 1_3 |
|---|---|---|
| 1 | DllMain (`-private`) | same |
| 2 | XInputGetState | same |
| 3 | XInputSetState | same |
| 4 | XInputGetCapabilities | same |
| 5 | XInputEnable | same |
| 6 | (none) | 1_3 has XInputGetDSoundAudioDeviceGuids here; 1_4 does not list it |
| 7 | XInputGetBatteryInformation | same |
| 8 | XInputGetKeystroke | same |
| 10 | XInputGetAudioDeviceIds (`stub` in Wine) `(long ptr ptr ptr ptr)` | new in 1_4 |
| 100 | XInputGetStateEx | same |
| 108 | XInputGetCapabilitiesEx `(long long long ptr)` | new in 1_4 |

## Not in Wine's specs

| Ordinal | Item | Status |
|---|---|---|
| 101, 102, 103 | Guide-button wait / cancel / power-off style exports | Neither spec lists them. Names and ordinals UNVERIFIED. Do not export or invent them without a second source (Microsoft binary export table). |
| 9 | Not listed in either spec | Absent in Wine. Whether Microsoft's DLL has an export here is UNVERIFIED. |

## Implications for `probes/xinput-stub`

- M0 stub exported named functions at 93-99 and XInputGetStateEx at 100 (M0-results Q4). Per Wine,
  GetState=2, SetState=3, GetCapabilities=4, Enable=5, GetDSoundAudioDeviceGuids=6 (1_3 only),
  GetBatteryInformation=7, GetKeystroke=8. The ordinals 93-99 do not match; this supports the
  ordinal-mismatch hypothesis (still unconfirmed; F4SE plugins are another possible factor).
- On mingw, a `.def` file with explicit `@N` ordinals (e.g. `XInputGetState @2`) pins them.
  This is a toolchain statement from general knowledge, UNVERIFIED here.
- Ordinal 1 is DllMain in Wine's spec only because of `-private`; the PE entry point is not an export.

## Sources

- https://raw.githubusercontent.com/wine-mirror/wine/master/dlls/xinput1_3/xinput1_3.spec (fetched 2026-10-22)
- https://raw.githubusercontent.com/wine-mirror/wine/master/dlls/xinput1_4/xinput1_4.spec (fetched 2026-10-22)
- /Users/quixkster/Projects/DS4MacOS/docs/mac-tests/M0-results.md (stub ordinals, crash)
