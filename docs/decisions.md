# Decision Log (ADR)

Format: **D# — title** · date · status (`accepted` / `pending` / `postponed` / `superseded` / `temporary`). Each entry includes context, decision, alternatives, and consequences. This log is historical: decisions are never deleted; they are marked as superseded when they change.

---

## D1 — Stack: SwiftUI + Swift, Xcode 26, macOS · 2026-10-09 · accepted

- **Context:** existing Xcode 26 project (`InstantPlayer`, bundle `com.guits.InstantPlayer`, `SDKROOT = macosx`) with app, unit-test, and UI-test targets; product is an instant video player. The project is configured as a Mac app ("My Mac" is the only destination) — confirmed with the stakeholder at bootstrap.
- **Decision:** Swift + SwiftUI on **macOS**, standard `xcodebuild` toolchain with the `platform=macOS` destination, no simulator involved.
- **Alternatives:** retarget to iOS (discarded: the stakeholder wants a Mac app); UIKit-first (discarded: SwiftUI is the platform default for new apps and the UI surface here is small); UIKit via SwiftUI wrappers where playback needs it (possible later, per-story design decision).
- **Consequences:** macOS idioms apply — App Sandbox, security-scoped file access, Keychain, window-based SwiftUI; playback via `AVKit`/`AVPlayer` (`VideoPlayer` or `NSViewRepresentable` around `AVPlayerView`) when needed.

## D2 — SDD harness adoption (mirrors an earlier project) · 2026-10-09 · accepted

- **Context:** an earlier project runs a proven spec-driven flow: `sdd` coordinator + `spec-author`/`implementer`/`implementer-flash`/`validator` subagents, per-story artifacts in `docs/specs/<story>/`, stakeholder gates, ADR log, backlog states, and a deterministic pre-commit gate.
- **Decision:** adopt the same system for InstantPlayer, adapted to the Swift toolchain: pillars mapped to `swift-security`/`swift-performance` skills; deterministic gate rebuilt around `xcodebuild` + SwiftLint + SwiftFormat; stakeholder functional review happens in the running app (`scripts/app.sh`) instead of a preview URL.
- **Alternatives:** keep the default build agent only (discarded: loses gates, evidence discipline, and review); wait until the codebase grows (discarded: harness is cheapest to adopt at day zero).
- **Consequences:** all story work goes through the `sdd` coordinator; `AGENTS.md` is the constitution; the gate is law.

## D3 — No routing model; coordinator assigns batches · 2026-10-09 · accepted

- **Context:** an earlier project routes tasks to implementer tiers through a pnpm-managed routing plugin. InstantPlayer starts with no Node toolchain, and the routing machinery needs deps, pinning, and calibration.
- **Decision:** drop the routing plugins for now. The `sdd` coordinator assigns task batches itself: mechanical, well-scoped tasks → `implementer-flash`; everything else → `implementer`; when in doubt → `implementer`. Gaps follow the same rule.
- **Alternatives:** full routing-plugin copy (discarded for now: heavy machinery for a young codebase; revisit when task volume makes manual routing a bottleneck).
- **Consequences:** slightly more coordinator judgment per story; no `.opencode` Node deps; can be superseded later by re-introducing the routing plugin if routing quality or cost demands it.

## D4 — Gate scope: build + unit tests + lint on every commit · 2026-10-09 · accepted

- **Context:** the gate runs on every commit via the pre-commit hook. Full `xcodebuild test` including UI tests takes minutes; the gate must stay fast enough to never tempt a bypass.
- **Decision:** `scripts/validate.sh` runs, in order: docs checks (ADR format, internal links, approved-spec hygiene), branch policy (`--staged`), SwiftLint, SwiftFormat `--lint`, `xcodebuild build`, and `xcodebuild test -only-testing:InstantPlayerTests` (unit tests) with the `platform=macOS` destination and a pinned derived-data path (`.deriveddata/`). UI tests (`InstantPlayerUITests`) are out of the per-commit gate — the `validator`/converge step runs them when the story touches flows UI tests cover.
- **Alternatives:** include UI tests per commit (discarded: minutes per commit); lint/docs only (discarded: compile+unit regressions would land on main).
- **Consequences:** commits stay reasonably fast; slow UI tests are a validation-phase concern; the macOS destination is fixed, so there is no device/simulator variance to manage.

## D5 — Pillars: security (RNF-04) and performance (RNF-02) via macOS skills · 2026-10-09 · accepted

- **Context:** an earlier project enforces two pillars through `web-security`/`web-performance` skills loaded before any touching work. InstantPlayer's risk surface is different: local media, files from outside the sandbox, playback efficiency.
- **Decision:** keep two non-negotiable pillars with the same RNF numbering (RNF-02 performance, RNF-04 security) and adapt the skills: `swift-security` (data at rest, network/ATS, permissions & privacy manifest, untrusted input, secrets, dependencies) and `swift-performance` (main thread, SwiftUI view cost, playback lifecycle, memory, launch).
- **Alternatives:** no skills until the codebase grows (discarded: pillar checklists are cheapest applied from the first real feature).
- **Consequences:** every story brief touching pillar surfaces must name the skill; the validator applies both checklists.

## D6 — Language: English everywhere · 2026-10-09 · accepted

- **Context:** an earlier project mandates Spanish UI copy (Colombian market) with English for everything else. InstantPlayer has no defined localization market yet.
- **Decision:** everything in English — code, tests, docs, commit messages, and user-facing UI copy. Localization is a future story (String Catalogs) if a market is defined.
- **Alternatives:** Spanish UI like the earlier project (discarded: no market requirement yet; adds copy-review overhead).
- **Consequences:** one language to keep consistent; when localization comes, UI copy migrates into `Localizable.xcstrings` in a dedicated story.
