# How this project is built

Three seats, handing off through files in this repo. Nothing is coordinated live between models;
the repo is the shared memory.

| Seat | Model | Runs in | Paid by |
|---|---|---|---|
| Architect: scope, specs, decisions | Fable | A claude.ai chat with the owner | Max plan |
| Lead: executes one spec, one session | Opus | Claude Code cloud session on this repo | Cloud session credit |
| Coders, reviewer, test runner, researcher | Sonnet, Sonnet, Haiku, Sonnet | Subagents inside the lead's session (`.claude/agents/`) | Cloud session credit |
| Mac tests: build, controller, game | Sonnet | Claude Code on the owner's Mac, local session | Max plan |

## The loop, once per milestone

1. The architect writes `specs/M<n>.md`: goal, deliverables, tasks, acceptance tests, questions that
   must stop the work. The spec is committed to `main` before the session starts.
2. The owner starts a cloud session (see "Starting a cloud session") and gives it one line:
   `Read CLAUDE.md and docs/pipeline.md, then execute specs/M<n>.md as the lead.`
3. The lead works through the tasks: coder implements, reviewer checks, test-runner runs, lead commits.
   It ends with a pull request and `docs/sessions/<date>-M<n>-cloud.md`.
4. The owner reads the report and the PR, runs `/usage` in the session, records the row in
   `docs/usage-log.md`, and merges if CI is green.
5. If the milestone has Mac tests (`docs/mac-tests/M<n>.md`), the owner runs a local session on the
   Mac on a branch `m<n>/mac` created from the merged `main`. It builds, walks through the tests
   with the controller, commits results and fixtures, writes `docs/sessions/<date>-M<n>-mac.md`,
   and opens its own pull request.
6. The owner brings both reports to the architect chat. The architect writes the next spec.

## Delegation rules (enforced by prompts, checked by the reports)

- The lead writes code itself only after a coder has failed twice on the same task. Every such
  escalation is listed in the session report; they are the main signal that a spec was too loose.
- A design question that is not answered by the spec or CLAUDE.md stops that task. The lead continues
  with other tasks, then lists the question under "Questions for the architect".
- Nothing but the architect changes `specs/`. The lead may append to a spec's "Session notes" section.
- Subagents do not spawn subagents (their `tools` lists omit `Agent`). Depth stays at two.

## Measurement

Every session adds one row to `docs/usage-log.md`:
- credit balance before and after (usage menu at claude.ai/code, shown while the credit lasts),
- the per-model split from `/usage` (the owner runs it at the end of the session),
- subagent token counts per task, which the lead copies from each Agent tool result into the
  session report.

Targets: about 60% of tokens on Sonnet and Haiku, under 40% on Opus. If Opus passes half, the
specs are too loose or the tasks too large; that is the architect's problem to fix, not the lead's.

Caps are not enforced by anything. The owner checks the balance at the end of each session; an
overrun means re-planning with the architect before the next session starts.

## Schedule and caps

The cloud session credit expires Wed Nov 4, 2026 at 11:59 PM PT. Finish dates fall on days without
classes, because each milestone ends with the owner holding the controller.

| | Milestone | Cloud deliverable | Mac deliverable | Finish by | Cap |
|---|---|---|---|---|---|
| M0 | Scaffold and feasibility | Package, CI, minimal core, `ds4probe`, XInput stub DLL | Fixtures captured; seize, injection, bridge and XInput tests run in Fallout 4 | Tue Oct 20 | $20 |
| M1 | Controller core | Full USB and Bluetooth parsing with CRC, output reports with triggers, touchpad gesture engine, protocol doc | Spot-check on the controller | Thu Oct 22 | $30 |
| M2 | Mac layer | Device manager with hot-plug and seize, keyboard/mouse output, permissions flow, headless runner | Play test with a hard-coded profile | Sun Oct 25 | $30 |
| M3 | Profile engine | Profile file format, mappings, trigger and haptic presets, input-reactive haptics, per-app auto-switch | Fallout 4 profile v1 | Thu Oct 29 | $35 |
| M3b | XInput bridge (only if the M0 test passes) | Proxy DLL with UDP state and rumble capture, Mac side | Rumble from the game drives the controller | with M3 | $35 |
| M4 | Menu bar app | SwiftUI profile editor, live input view, launch at login | Daily-use check | Sun Nov 1 | $40 |
| M5 | Tune and ship | Fixes from play, install docs, release build | Fallout 4 profile tuned in play | Tue Nov 3 | $20 |
| | Reserve for overruns | | | | $40 |

Caps are estimates (roughly $5 to $8 per Opus lead session, $1 to $3 per Sonnet task) and get
rescaled after M0 using the usage log.

## Starting a cloud session

One-time setup:
1. At claude.ai/code, connect GitHub and install the Claude GitHub App on `Solaras-Noir/DS4MacOS`.
2. Create the cloud environment described in `docs/cloud-environment.md`.

Per session:
1. Make sure the milestone's spec is on `main` (merge the architect's pull request first). Then:
   new session, repository `Solaras-Noir/DS4MacOS`, branch `main`, environment `DS4MacOS`.
2. Model: Opus. Permission mode: auto if offered, otherwise accept edits (the repo's
   `.claude/settings.json` pre-approves the build, test and git commands the lead needs).
3. First message: `Read CLAUDE.md and docs/pipeline.md, then execute specs/M<n>.md as the lead.`
4. Check in from the phone or the desktop app; answer questions when the session stops for one.
5. When the lead reports done: review the PR, run `/usage` in the session, check the credit balance,
   add the usage-log row, merge.

If a session dies or the context fills: start a new session on the same branch with
`Continue specs/M<n>.md as the lead. Read the running report in docs/sessions/ for what was
already done.` (The lead commits that report after every task for exactly this reason.)

## Starting a Mac session

1. On the Mac: Xcode Command Line Tools (`xcode-select --install`), Claude Code, and a clone of the
   repo with `main` up to date and a new branch `m<n>/mac` checked out.
2. Open Claude Code in the clone (desktop app, local session, or `claude` in Terminal). Model: Sonnet.
3. First message: `Run docs/mac-tests/M<n>.md with me, one step at a time. I am holding the
   controller. Record results in the results table and commit fixtures as the protocol says.`
4. Run `ds4probe` from Terminal.app when the protocol says so; macOS grants Accessibility and Input
   Monitoring to the terminal app, not to the binary.
5. End with `docs/sessions/<date>-M<n>-mac.md`, commit, push the branch, open a pull request.

## When to ask the architect

The owner brings the session reports back to the architect chat after each milestone. Between
milestones, a stopped session with a "Questions for the architect" section is the trigger. Everything
else (which file, which name, which test) is the lead's call.
