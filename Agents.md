# Kinesis Agent Memory

This file is the long-term working memory for AI agents contributing to Kinesis.
Update it frequently as the project architecture, direction, constraints, and
developer preferences become clearer.

## Project

- Name: Kinesis
- Public repository: https://github.com/AgarwalAarush/Kinesis
- Current state: new repository, project architecture not established yet.

## Agent Operating Rules

- Treat this file as durable project memory. Add useful context after each
  meaningful discovery, architecture decision, feature, refactor, or debugging
  lesson.
- Keep notes practical: record how the system is structured, why important
  choices were made, and anything future agents should remember to move faster.
- Prefer small, frequent edits over large retrospective updates.
- Do not let this file become a vague journal. Capture information that would
  help a future developer make better decisions.

## Version Control Preferences

- Version control is very important for this project.
- Commit after every meaningful change, feature, fix, or setup step.
- Keep commits focused and frequent so the project history stays easy to review.
- Before committing, check `git status` and avoid staging unrelated user changes.

## Architecture Notes

- Kinesis v0 is a native SwiftUI macOS app paired with a Python webcam helper.
- Swift app structure:
  - `Kinesis/App`: app entrypoint and macOS app delegate.
  - `Kinesis/Views`: control window, sidebar, menu bar controls, settings, and gesture log.
  - `Kinesis/Models`: JSON intent types, helper status, permissions, settings, and routing decisions.
  - `Kinesis/Stores`: app-level observable state and action orchestration.
  - `Kinesis/Services`: Python helper process supervisor, permission checks, Cmd+Esc hotkey monitor, gesture router, and guarded CGEvent output bridge.
  - `Kinesis/Support`: small project path helpers.
- Python helper structure:
  - `cv_helper/kinesis_cv.py` captures webcam frames, uses MediaPipe/OpenCV when installed, recognizes the v0 gesture grammar, and emits newline-delimited JSON intents.
  - Swift owns all macOS control. The helper never executes Mac actions directly.
- v0 gesture scope is intentionally narrow: index cursor movement, pinch click, pinch-hold drag, two-finger scroll, fist/open-palm clutch pause, menu bar pause, and Cmd+Esc emergency pause.
- Explicit v0 non-goals: Mission Control, Spaces/app switching, typing text, destructive actions, shell commands, window closing, messaging, or AI-triggered actions.

## Project Direction

- Product direction: "Air Mouse" first. Prove a reliable webcam-driven virtual trackpad before expanding to richer trackpad gestures or direct screen pointing.
- Success for v0 means the user can launch the app, start the helper, see live gesture status, move the cursor, click/drag, scroll, and instantly pause all output.

## Development Notes

- Repository started locally on branch `main`.
- Create Python CV dependencies with `script/setup_cv_env.sh`.
- Build and launch locally with `script/build_and_run.sh`.
- Verify launch with `script/build_and_run.sh --verify`.
- Run Swift and Python tests with `script/build_and_run.sh --test`.
- The local run script uses project-local DerivedData at `.build/DerivedData` and passes `CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO` for local Debug builds. This avoids requiring a Mac Development certificate on every agent machine.
- The deployment target is macOS 15.0 for local v0 development. Do not let the generated Info.plist drift back to a future-only minimum system version, or LaunchServices may refuse to open the app.
- Debug/local runs disable the app sandbox in the Xcode target so CGEvent cursor output, Accessibility checks, and Input Monitoring flows can be exercised realistically.
- Avoid SwiftUI `#Preview` macros in committed app source until CLI builds are known to handle the local sandbox reliably.
