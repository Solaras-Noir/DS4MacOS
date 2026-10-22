# DS4MacOS

A macOS app that makes a Sony DualSense controller fully programmable, in the spirit of DS4Windows:
every button, the touchpad (zones, taps, swipes), the lightbar, rumble and the adaptive triggers,
driven by per-game profiles. Target use: Windows games running under CrossOver that have no native
DualSense support (first target: Fallout 4), plus native Mac games.

Read `docs/pipeline.md` before doing any work. It explains who does what and how sessions run.

## Hard constraints (do not design around them, ask the architect)

- No virtual HID device. macOS requires an Apple-approved entitlement for that. The app maps controller
  input to keyboard and mouse events (CGEvent) and, if the M0 feasibility test passes, to a small
  XInput proxy DLL inside the CrossOver bottle. Never propose DriverKit, CoreHID virtual devices,
  kernel extensions, or disabling SIP.
- The app cannot see game state. Haptics and trigger effects for games without native support are
  driven by the player's own inputs (profiles), or by rumble calls captured through the XInput proxy.
- No third-party Swift packages without architect approval. Foundation, IOKit, CoreGraphics, AppKit
  and SwiftUI only.
- Swift 5 language mode (`swiftLanguageModes: [.v5]`) on a 6.0 tools version, XCTest for tests.
  This is a cost decision: strict concurrency errors burn tokens for no product value yet.

## Product shape: three modes, chosen per profile

The point of the app is to keep what a controller is good at (analogue sticks and triggers, the
game's own controller support) while adding what the DualSense can do on top (touchpad zones and
gestures as extra inputs, adaptive triggers, haptics). Replacing the controller with keyboard and
mouse is one option the user can choose, not the product.

| Mode | Controller access | Game sees | App adds | Use when |
|---|---|---|---|---|
| `augment` (default) | opened without seize, shared with the game | the real pad, analogue and all | keyboard/mouse events for touchpad gestures (and any button the user also binds), trigger effects, rumble, lightbar | the game supports controllers and accepts keyboard input alongside |
| `proxy` (M3b) | seized | a virtual XInput pad served by our DLL inside the CrossOver bottle, built from the app's state | full remapping including touchpad gestures to pad buttons, analogue preserved, the game's rumble calls captured and rendered | XInput games under CrossOver, especially ones that ignore the keyboard in gamepad mode |
| `keyboardMouse` | seized | nothing | every input as keyboard and mouse events | games with no controller support, or by choice |

Facts behind this (from `docs/mac-tests/M0-results.md`):
- Reading the pad without seize works while a CrossOver game uses it; CrossOver's own driver then
  also writes outputs (it set the lightbar when the game took focus), so in `augment` mode the app
  re-asserts its outputs periodically instead of assuming they stick.
- Seize works without root and hides the pad from the game, but a game that has seen the pad once
  stays in controller mode; seize must be active before the game launches.
- Fallout 4 ignores the keyboard while it is in controller mode, so in Fallout 4 `augment` can only
  add feedback (triggers, rumble, lightbar), not key bindings. `proxy` is the Fallout 4 answer for
  analogue plus touchpad bindings; `keyboardMouse` is the fallback and loses analogue.
- Keyboard and mouse injection through CGEvent works in CrossOver games, including relative mouse
  look. The IOKit input callback buffer includes the report ID in byte 0.
- The XInput proxy DLL is the only route to analogue sticks and game-driven rumble in CrossOver
  games; M3b depends on the rebuilt stub loading cleanly (M1-T6, tested in M2).

Never propose a virtual HID device, DriverKit, CoreHID virtual devices, or disabling SIP as a way
to get analogue into games.

## Repository layout

```
Package.swift            SwiftPM manifest. macOS-only targets are added under #if os(macOS)
Sources/DualSenseCore/   Cross-platform: report parsing, output report building, touchpad gestures,
                         profile model. No Apple frameworks beyond Foundation. Builds and tests on Linux.
Sources/DS4Mac/          macOS only: IOHIDManager device access, CGEvent injection, permissions.
Sources/ds4probe/        macOS only: command-line probe used for feasibility tests on the Mac.
Tests/DualSenseCoreTests Unit tests plus Fixtures/ (raw report captures from a real controller).
probes/xinput-stub/      Windows XInput proxy DLL (C, built with mingw-w64 on Linux).
specs/                   One spec per milestone, written by the architect. The lead executes them.
docs/pipeline.md         Roles, session loop, escalation rules, schedule, credit caps.
docs/sessions/           One report per session, written by the lead at the end of the session.
docs/mac-tests/          Step-by-step test protocols for the local Mac session, and their results.
docs/usage-log.md        Token and credit measurements, one row per session.
docs/protocol/           DualSense HID protocol notes with sources.
scripts/swift            Runs swift locally if installed, otherwise inside the official Swift Docker image.
scripts/cloud-setup.sh   Setup script for the Claude Code cloud environment.
```

## Build and test

- Cloud (Linux) sessions: `scripts/swift build` and `scripts/swift test`. Only `DualSenseCore` and its
  tests build on Linux; that is by design.
- Mac: `scripts/swift build`, `scripts/swift test`, `scripts/swift run ds4probe <command>`. The
  wrapper selects Xcode's toolchain when Xcode is installed; the Command Line Tools alone cannot run
  XCTest (`swift test` fails with "XCTest not found"). Plain `swift test` also works if
  `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` is set.
- CI (`.github/workflows/ci.yml`) runs a Linux job for the core and a macOS job for everything.
  A PR is not done until both jobs are green.

## Roles in a session

- The main conversation of a cloud session is the **lead** (Opus). The lead plans, dispatches tasks to
  subagents, reviews their results, commits, and writes the session report. The lead writes code itself
  only when a coder has failed twice on the same task (escalation).
- `coder` (Sonnet) implements one task at a time. `reviewer` (Sonnet) checks a diff against the spec
  with fresh context. `test-runner` (Haiku) runs commands and returns compact results.
  `researcher` (Sonnet) turns reference sources into a doc. Definitions live in `.claude/agents/`.
- The **architect** (Fable, in a separate chat) writes specs and decides scope. Questions listed under
  "Ask the architect" in a spec stop the work; everything else, the lead decides and records.

## Rules for every session

1. Work on the branch the spec names. Never commit to `main`, never force-push, never merge.
   One pull request per session (cloud sessions on `m<n>/<slug>`, Mac sessions on `m<n>/mac`),
   opened by the session, merged by the user.
2. Commit after each task that passes review, with the task id in the message (`M0-T3: ...`).
3. After each subagent returns, record its token count (from the tool result) in the session report.
4. Run the full test command before every commit. Do not commit red.
5. Keep secrets, bottle paths and personal data out of the repo.
6. Do not widen scope. If the spec is wrong or ambiguous in a way that changes the design, stop and
   write the question in the session report under "Questions for the architect".
7. Keep `docs/sessions/<date>-<milestone>-<cloud|mac>.md` (from `docs/sessions/_template.md`)
   as a running report: create it with the first commit, update it with every task commit, finish
   it before ending. A session that dies mid-way is resumed from that file.
8. Open a draft pull request after the first push (CI runs only on pull requests and `main`), and
   mark it ready for review at the end.

## Coding conventions

- Parsing of controller bytes must bounds-check everything; a short or malformed report returns `nil`,
  never traps. No force unwraps or `try!` outside tests.
- Public types in `DualSenseCore` get a doc comment and a unit test.
- Platform code is isolated: `#if os(macOS)` at file level in `DS4Mac` and `ds4probe`, nothing from
  IOKit, CoreGraphics or AppKit in `DualSenseCore`.
- Prefer small files named after the type they hold. No file over ~400 lines.
- Commit messages: `M<n>-T<k>: imperative summary` plus a short body when the why is not obvious.
