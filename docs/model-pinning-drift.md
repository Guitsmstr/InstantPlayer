# Harness note — model pinning drift (agent frontmatter vs `opencode.json`)

Status: **resolved — fix applied 2026-10-12**; decision recorded as **D29** in
`docs/decisions.md`. Observed on 2026-10-12 while replicating this harness into
the giv_manage project, and fixed here the same day.

## Problem (as observed)

OpenCode model pins can live in two places, and this repo used both:

1. `opencode.json` → `agents.<name>.model` (the "Harness model tiering" block)
2. Agent frontmatter → `model:` in `.opencode/agents/*.md`

When both pinned the same agent, **the frontmatter won**. The two sources had
drifted apart, so the models that actually ran were not the documented tiering:

| Agent | Pin in `opencode.json` | Pin in frontmatter | Actually ran |
|---|---|---|---|
| `spec-author` | `xiaomi-token-plan-sgp/mimo-v2.6-pro` | — | `mimo-v2.6-pro` ✅ |
| `implementer` | `xiaomi-token-plan-sgp/mimo-v2.6-flash` | `zai-coding-plan/glm-5.3-flash` | `glm-5.3-flash` ✅ (accidentally correct — the comment matched the frontmatter winner while `opencode.json` disagreed) |
| `implementer-flash` | `opencode-go/deepseek-v4.1-flash` | `zai-coding-plan/glm-5.3-flash` | **`glm-5.3-flash`** ❌ drift |
| `validator` | `xiaomi-token-plan-sgp/mimo-v2.6-flash` | `zai-coding-plan/glm-5.3-flash` | **`glm-5.3-flash`** ❌ drift |
| `explore` / `title` / `summary` | `opencode-go/deepseek-v4.1-flash` | — | `deepseek-v4.1-flash` ✅ |

Consequences observed:

- The cost/quality tiering was silently wrong for two of the four workflow
  agents (`implementer-flash` and `validator` ran glm instead of their tier).
- Any retier edit in `opencode.json` was a **no-op** for the
  frontmatter-pinned agents — the trap recurs on every retier.
- The `opencode.json` comment doubled as documentation and had gone stale.

## Resolution (applied 2026-10-12)

**One source of truth: models are pinned only in `opencode.json`; agent
frontmatter carries no `model` field** — the pattern adopted in giv_manage
while replicating this harness (decision "Model tiering per agent,
single-sourced in `opencode.json`", 2026-10-11) precisely to avoid this drift
class. Retiered per stakeholder request:

| Agent | Model (single source: `opencode.json`) |
|---|---|
| `spec-author` | `xiaomi-token-plan-sgp/mimo-v2.6-pro` |
| `implementer` | `zai-coding-plan/glm-5.3-flash` |
| `implementer-flash` | `opencode-go/deepseek-v4.1-flash` |
| `validator` | `opencode-go/deepseek-v4.1-flash` |
| `explore` / `title` / `summary` | `opencode-go/deepseek-v4.1-flash` |
| `sdd` | intentionally unpinned — inherits the session model |

Changes applied:

1. Deleted the `model:` line from `.opencode/agents/implementer.md`,
   `implementer-flash.md`, and `validator.md`.
2. Reconciled `opencode.json`: `implementer` → `zai-coding-plan/glm-5.3-flash`,
   `validator` → `opencode-go/deepseek-v4.1-flash`; `spec-author` and
   `implementer-flash` kept at their intended pins.
3. Updated the `opencode.json` comment so its tiering table matches the file.

**Rule going forward:** to retier any agent, edit `opencode.json` only. Never
add a `model:` field to agent frontmatter — it would silently win over the
config. New agents get their pin in the `agents` block.

Alternatives considered (rejected):

- **Frontmatter as the only pinning site** (delete the `agents` block from
  `opencode.json`): equally single-sourced, but hides the tiering in five
  files instead of one — worse for a deliberate cost policy.
- **Fixing only the stale comment**: cheapest, but leaves the two-source
  hazard in place; every future retier can silently re-drift.
