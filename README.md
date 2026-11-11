# InstantPlayer

**An instant viewer for a folder of videos and images on macOS.** Open any file from
Finder (or drop a file or folder on the app) and flip through the whole folder in a
vertical feed. There is no import step, no library, and no wait before a clip plays.

> Native macOS app · Swift · SwiftUI + AppKit · AVFoundation · Swift Concurrency ·
> Clean Architecture + MVVM · 249 unit tests · built through a spec-driven multi-agent pipeline

<!-- TODO: add a screenshot or short GIF of the feed and the list view here -->

## What it does

- **Zero-setup entry.** Use "Open With" from Finder, or drag & drop a file or folder onto
  the app icon or window. The feed opens on that folder, positioned at the opened file.
  Unsupported files are ignored, and the folder still opens.
- **Vertical feed.** Videos and images share one feed. The current item fills the window.
  Page with scroll or the arrow keys.
- **Playback.** Auto-play on arrival, play/pause, scrub & seek, a five-step speed ladder
  (0.25×–2×) with `[` / `]` stepping, and loop in place (never auto-advance).
- **List view.** Toggle with `⌘L` or the floating control. Every item is listed by name,
  with keyboard navigation and ad-hoc multi-selection. Selecting an item jumps the feed
  to it.
- **Sandboxed and read-only.** Files are reached only through the access granted by the
  user's action (security-scoped), and media files are never rewritten.

## Architecture

Clean Architecture per feature, with MVVM presentation:

```
App/                 composition root (AppDependencies), key routing, window
Core/                shared protocols & models (Swift-pure)
Features/
  Feed/              Domain ← Data (AVFoundation, file access) · Presentation (SwiftUI)
  MediaList/         Domain (selection machine) · Presentation
```

- Dependencies point inward: Presentation → Domain ← Data. Domain is pure Swift.
  AVFoundation and file system access sit behind protocols in `Data/`, with stubs for
  tests.
- View models are `@MainActor` + `@Observable`. Async work uses `async/await` (no
  completion handlers). There is a hand-wired composition root and no DI framework.
- Details: [`docs/architecture.md`](docs/architecture.md). Every structural choice is
  recorded as an ADR in [`docs/decisions.md`](docs/decisions.md) (42 decisions).

## Testing & quality gate

- **249 unit tests** (Swift Testing, with XCTest in the performance suites) cover view models, the selection state machine, the
  keyboard command router, the security-scoped folder repository, and the AVFoundation
  playback layer (seek and speed behavior). They use generated media fixtures.
- **Performance tests with explicit budgets**, for example time-to-display, seek
  landing, and a 10,000-item list.
- **Deterministic gate**: [`scripts/validate.sh`](scripts/validate.sh) runs docs checks,
  SwiftLint, SwiftFormat, the build, and the unit tests (and the UI tests with
  `--uitests`). A pre-commit hook runs it on every commit, and `--json` writes a
  machine-readable evidence summary.

## How it was built

The project is run as a spec-driven process with AI coding agents. The repo includes its
own harness, for [OpenCode](https://opencode.ai) and [Pi](https://github.com/badlogic/pi-mono):

1. **Spec**: requirements are written in EARS form in [`docs/spec.md`](docs/spec.md).
   Each story gets its own `spec → design → tasks → evidence` folder under
   [`docs/specs/`](docs/specs/).
2. **Implement**: a coordinator agent (`sdd`) hands task batches to implementer agents,
   with different model tiers for complex and mechanical tasks.
3. **Validate**: an adversarial validator agent reviews each story against its acceptance
   criteria, and the deterministic gate must pass before any commit.
4. **Stakeholder gates**: a person approves the specs and does a functional review of the
   running app before a story is closed.

Agents, skills (`swift-security`, `swift-performance`) and model pinning live in
`.opencode/`, `.pi/` and `opencode.json`. The rules every agent follows are in
[`AGENTS.md`](AGENTS.md).

## Build & run

Requirements: **macOS 26** and **Xcode 26**. Install SwiftLint and SwiftFormat for the
gate (`brew install swiftlint swiftformat`).

```sh
git config core.hooksPath .githooks   # enable the pre-commit gate
./scripts/validate.sh                 # lint, format, build, unit tests
./scripts/app.sh run                  # build, install to ~/Applications and launch
```

Or open `InstantPlayer.xcodeproj` and run the `InstantPlayer` scheme. To sign with your
own team, set it under *Signing & Capabilities*.

More in [`docs/development.md`](docs/development.md).

## Status & roadmap

Started October 2026. Done: entry & media collection, vertical feed, basic playback,
scrub & seek, playback speed, list view & selection.
Next (see [`docs/backlog.md`](docs/backlog.md)): volume & mute, ordering modes,
live folder sync, and file operations from the list (zip, move, reveal, trash).
