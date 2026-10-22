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
- Mac: `swift build`, `swift test`, `swift run ds4probe <command>`.
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
