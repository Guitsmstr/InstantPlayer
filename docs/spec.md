# InstantPlayer — Product Spec (source of truth)

An instant video player for macOS: pick a video, it plays — no friction, no waiting.

> Bootstrap note: this file is a skeleton created during harness bootstrap (D2). The product
> outline below is intentional placeholder — real requirements are authored through the SDD
> flow: stories in `docs/backlog.md`, per-story artifacts in `docs/specs/<story>/`. Fill this
> file story by story; it is overridden only by ADRs in `docs/decisions.md`.

## Product outline

- Target user and main job-to-be-done: `[NEEDS CLARIFICATION: who is this for, and in what situation does "instant" matter most?]`
- Sources of video: `[NEEDS CLARIFICATION: local files (Finder / open-with / drag & drop), network streams, camera imports — which are in scope?]`
- Minimum playback experience: `[NEEDS CLARIFICATION: formats, subtitles, picture-in-picture, background audio?]`
- Scope boundaries: `[NEEDS CLARIFICATION: editing? library management? casting? — presumably out of scope, confirm]`

## Functional requirements

None authored yet — the first story authors them in EARS notation (see `docs/specs/README.md`).

## Non-functional requirements

- **RNF-02 (performance — pillar):** "Instant" is the product promise. Playback must start with no perceptible wait on the happy path; the UI stays smooth (no main-thread stalls); launch is minimal. See the `swift-performance` skill. Per-story budgets are set in story designs.
- **RNF-04 (security — pillar):** user media and any credentials are handled as private data: Keychain for secrets, sandbox + security-scoped access for files, validated external input, ATS intact, no undocumented tracking. See the `swift-security` skill.
