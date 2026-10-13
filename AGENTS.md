# InstantPlayer — Agent Constitution

Instant video player for **macOS** (SwiftUI). Stack: **Swift + SwiftUI, Xcode 26, xcodebuild (macOS destination), SwiftLint + SwiftFormat**. Targets: `InstantPlayer` (app), `InstantPlayerTests` (unit), `InstantPlayerUITests` (UI). Bundle id: `com.guits.InstantPlayer`.

**Language rule: everything in English — code, tests, docs, commit messages, and user-facing UI copy.**

## Hard rules

1. **Spec-driven.** `docs/spec.md` is the product source of truth. Story work happens through the `sdd` coordinator (opencode: switch agents with Tab · pi: run `/sdd <story-id>`); its artifacts live in `docs/specs/<story>/`. The default `build` agent is only for one-line fixes, typos, or mechanical renames.
2. **Two pillars, non-negotiable: security and performance** (RNF-04/RNF-02 in `docs/spec.md`). Before building or reviewing anything that touches persisted data, network, permissions, secrets, playback, lists, images, threading, or launch: load the matching skill (`swift-security` / `swift-performance`).
3. **Deterministic gate.** `./scripts/validate.sh` must pass before every commit; it is enforced by the pre-commit hook. Never bypass it (`--no-verify` is forbidden). If the gate fails, fix the code — not the gate.
4. **Stakeholder gates.** The user approves spec, design, and tasks before implementation. Agents never self-approve a phase.
5. **Delegation briefs are mandatory.** Every subagent task carries: objective, scope boundaries, expected output format, and file/spec pointers. Never a naked subtask.
6. **Decisions leave a trace.** Any product/technical decision → append an ADR in `docs/decisions.md` (format: `## D# — title · date · status`). Story state changes → update `docs/backlog.md`.
7. **One story = one branch.** Cut `feat/<id>-<slug>` from up-to-date `main` at story start; the whole story (spec/design/tasks artifacts + implementation + evidence + backlog state) lives on that branch; merge into `main` with `git merge --no-ff` at converge, then delete the branch. Docs/harness housekeeping (allowlist: `docs/`, `AGENTS.md`, `.opencode/`) may go to `main` directly — code commits on `main` are blocked by `./scripts/validate.sh --staged`.

## Commands

- Validate everything: `./scripts/validate.sh` (add `--staged` to skip build-heavy steps on docs-only commits).
- Run the app (stakeholder functional review): `./scripts/app.sh run` · `stop` · `status`.
- No Node toolchain: no package manager. Lint/format via Homebrew `swiftlint` / `swiftformat`; builds via `xcodebuild` (invoked through the gate, not ad hoc).

## Trigger table (read on demand, only when relevant)

| When | Read / use |
|---|---|
| Starting story work | pick a `ready` story from `docs/backlog.md`; run the `sdd` coordinator (opencode: switch agents with Tab · pi: `/sdd <story-id>`) |
| Starting or finishing story work | create/merge the story branch per hard rule 7 (`feat/<id>-<slug>`) |
| Spec/design/tasks conventions unknown | read `docs/specs/README.md` |
| Building or reviewing persisted data, network, permissions, secrets, file handling | load skill `swift-security` |
| Building or reviewing playback, lists, images, threading, launch, SwiftUI views | load skill `swift-performance` |
| A decision is made (product or technical) | append ADR to `docs/decisions.md` |
| Story state changes | update `docs/backlog.md` |
| Product question about scope or requirements | read `docs/spec.md` (source of truth) |
| Gate usage, flags, or CI runner questions | read `docs/development.md` |

## Repo map (paths only)

- `docs/spec.md` — product source of truth · `docs/decisions.md` — ADR log · `docs/backlog.md` — work queue
- `docs/specs/<story>/` — per-story SDD artifacts (`spec.md`, `design.md`, `tasks.md`)
- `.opencode/` — opencode harness (agents and skills) · `.pi/` — pi harness (agents, skills, prompts, sdd-guard) · `scripts/validate.sh` — deterministic gate · `scripts/app.sh` — app run/stop for functional review · `scripts/repo-fs.sh` — guarded deletion · `.githooks/` — pre-commit hook
