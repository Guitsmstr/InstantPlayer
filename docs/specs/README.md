# SDD spec conventions

Per-story artifacts live in `docs/specs/<story-id>/` (e.g. `docs/specs/e1-s1-product-spec/`). Created by the `spec-author` agent from coordinator briefs; approved by the stakeholder at each phase gate. Workflow and roles: see `AGENTS.md` and D2.

## spec.md — WHAT and WHY, never HOW

- User stories with context.
- Requirements in **EARS notation**, numbered:

  ```
  R1: WHEN the user picks a video file from the Files app
      THE SYSTEM SHALL start playback within one second on the happy path
  ```

- Ambiguities are marked, never guessed: `[NEEDS CLARIFICATION: specific question]`.
- A spec is not ready for approval while any `[NEEDS CLARIFICATION]` marker remains.
- No tech stack, no code structure, no implementation details.

## design.md — HOW

- Architecture and components; data model and contracts when applicable.
- **Pillar sections are mandatory**: how the design satisfies RNF-02 (performance) and RNF-04 (security). Reference the `swift-security` / `swift-performance` skills where relevant.
- Alternatives considered; links to ADRs in `docs/decisions.md` for decisions taken.

## tasks.md — executable plan

- Ordered checklist; every task is one commit (`task N → one conventional commit`).
- Tasks that can run in parallel carry the `[P]` marker (same level = same wave).
- Every task implicitly ends with: run `./scripts/validate.sh`; fix before moving on.
- `[NEEDS CLARIFICATION]` is forbidden here — tasks are generated only after the spec is approved (enforced by the gate).
- Status checkboxes (`[ ]`/`[x]`) are updated during implementation.
- **Evidence is recorded from tooling, never from memory:** gate evidence via `./scripts/validate.sh --json <tmp>/gate.json` (per-step pass/fail and result); functional evidence recorded as what was exercised and observed in the running app (`./scripts/app.sh run` — screenshot paths may be recorded, never read back into context). Quote tooling output verbatim; never paraphrase or re-derive it.

## Story states

`draft` → `refined` → `ready` → `in progress` → `done` (or `postponed`) — tracked in `docs/backlog.md`.

## Done gate (per story)

1. Deterministic gate green (`./scripts/validate.sh`).
2. `validator` review PASS (adversarial, spec + pillars).
3. **UI stories:** stakeholder functional review — the stakeholder exercises the story's visible behavior in the running app (`./scripts/app.sh run`) and explicitly approves before `done`. Agent-recorded evidence is supporting material, never the approval.
