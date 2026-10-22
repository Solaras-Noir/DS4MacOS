# DS4MacOS
Dualsense Haptics and Adaptive Trigger Control on MacOS

A macOS app that makes the Sony DualSense fully programmable, in the spirit of DS4Windows: every
button, the touchpad (zones, taps, swipes), the lightbar, rumble and the adaptive triggers, driven by
per-game profiles. Built for Windows games running under CrossOver that have no DualSense support
(first target: Fallout 4) and for native Mac games. Input is delivered as keyboard and mouse events,
with an optional XInput proxy inside the CrossOver bottle; macOS does not allow a virtual controller
without an Apple-granted entitlement.

The project is built with Claude Code using a three-seat pipeline (architect, lead, coders) that is
documented in `docs/pipeline.md`. Milestone specs live in `specs/`, session reports in
`docs/sessions/`, and token measurements in `docs/usage-log.md`.

Status: M0 and M1 done (feasibility confirmed, controller core merged); M2 Mac layer and modes in progress.

## Build and test

- Linux or cloud (core only): `scripts/swift build` and `scripts/swift test`
- Mac (everything): `swift build`, `swift test`, `swift run ds4probe <command>`
