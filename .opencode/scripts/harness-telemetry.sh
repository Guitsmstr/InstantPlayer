#!/usr/bin/env bash
# Harness telemetry — reproducible session-store mining (D37).
#
# Replaces hand-written sqlite queries at converge (bottleneck C1 in
# docs/harness-perf-2026-09-24.md: ~69 min of E2-S4 converge went into
# ad-hoc mining, one cross-join query hung 60.7 min). Pre-baked queries +
# python parsing only — the json_each cross-join class is forbidden here.
#
# Method (same as the perf docs): steps = assistant messages; LLM = Σ
# (streamed−created); tool = Σ (completed−ran) over COMPLETED calls only;
# aborted/interrupted calls are reported separately, never summed into
# tool time (C5: idle-in-call pollutes durations).
#
# Usage:   harness-telemetry.sh <session-id> [<session-id>...]
#          A parent (coordinator) session automatically includes its children.
# Output:  markdown tables on stdout. Read-only; no args reach SQL unbound.
set -euo pipefail

if [ $# -eq 0 ]; then
  echo "usage: $0 <session-id> [<session-id>...]" >&2
  exit 1
fi

DB="${OPENCODE_DB:-$HOME/.local/share/opencode/opencode.db}"
[ -f "$DB" ] || { echo "error: session store not found: $DB" >&2; exit 1; }

exec python3 - "$DB" "$@" <<'PYEOF'
import json
import re
import sqlite3
import statistics
import sys
from collections import Counter
from datetime import datetime

DB, ids = sys.argv[1], sys.argv[2:]
for sid in ids:
    if not re.fullmatch(r"ses_[A-Za-z0-9]+", sid):
        sys.exit(f"error: bad session id: {sid!r}")

con = sqlite3.connect(f"file:{DB}?mode=ro", uri=True)
# Parents pull in their children (parent_id link), preserving caller order.
final, todo = [], list(ids)
while todo:
    sid = todo.pop(0)
    if sid in final:
        continue
    final.append(sid)
    for (child,) in con.execute(
        "SELECT id FROM session_v2 WHERE parent_id=? AND directory="
        "(SELECT directory FROM session_v2 WHERE id=?)", (sid, sid)):
        todo.append(child)


def fmt_min(ms):
    return f"{ms / 60000:.1f}" if ms is not None else "—"


rows_out, details = [], []
for sid in final:
    meta = con.execute(
        "SELECT COALESCE(title,'(none)'), COALESCE(agent,'?'), parent_id IS NOT NULL,"
        " tokens_input, tokens_output, tokens_cache_read, time_created, time_updated"
        " FROM session_v2 WHERE id=?", (sid,)).fetchone()
    if meta is None:
        sys.exit(f"error: session not found: {sid}")
    title, agent, is_child, t_in, t_out, t_cache, t_cre, t_upd = meta

    steps, tool_ok, tool_bad, denies, png, reads = [], Counter(), [], [], [], Counter()
    blocking = Counter()          # question/subagent wall, completed only
    for (raw,) in con.execute(
        "SELECT data FROM session_message WHERE session_id=? AND type='assistant'"
        " ORDER BY seq", (sid,)):
        try:
            d = json.loads(raw)
        except json.JSONDecodeError:
            continue
        t = d.get("time", {})
        if t.get("created") and t.get("streamed"):
            steps.append((t["created"], t["streamed"]))
        for p in d.get("content", []):
            if not (isinstance(p, dict) and p.get("type") == "tool"):
                continue
            pt, st = p.get("time", {}), p.get("state", {})
            name, status = p.get("name", "?"), st.get("status", "?")
            dur = (pt.get("completed") or 0) - (pt.get("ran") or 0)
            inp = st.get("input") or {}
            desc = (inp.get("command") or inp.get("path") or inp.get("pattern")
                    or str(inp.get("agent") or ""))[:60]
            if status == "completed":
                tool_ok[name] += dur
                if name in ("question", "subagent"):
                    blocking[name] += dur
            else:
                tool_bad.append({"tool": name, "status": status,
                                 "dur_ms": dur if dur > 0 else None,
                                 "desc": desc,
                                 "err": (st.get("error") or {}).get("message", "")[:70]})
                if "permission" in str(st.get("error", "")).lower():
                    denies.append(f"{name}: {desc}")
            if name in ("read", "glob", "grep"):
                tgt = inp.get("path") or inp.get("pattern") or "?"
                reads[tgt] += 1
                if str(tgt).lower().endswith((".png", ".jpg", ".webp")):
                    png.append(tgt)

    llm = [s - c for c, s in steps]
    tool_total = sum(tool_ok.values())

    # Idle candidates: gaps > 5 min between consecutive activity events.
    events = sorted([c for c, _ in steps] + [s for _, s in steps])
    gaps = [(b - a) / 60000 for a, b in zip(events, events[1:]) if b - a > 300_000]
    span = (events[-1] - events[0]) if events else (t_upd - t_cre)

    perm_denies = denies  # permission-denied only; provider/abort live in non_completed
    rows_out.append((sid, title, agent, "child" if is_child else "root",
                     len(steps), fmt_min(sum(llm)),
                     f"{statistics.median(llm)/1000:.0f}/{sorted(llm)[int(len(llm)*0.9)-1]/1000:.0f}"
                     if llm else "—",
                     fmt_min(tool_total), fmt_min(blocking.get("subagent", 0)),
                     fmt_min(blocking.get("question", 0)),
                     f"{t_in/1000:.0f}k/{t_out/1000:.0f}k ({t_cache/1e6:.1f}M)",
                     len(denies) if denies else 0, len(png)))
    details.append((sid, title, {
        "span_min": span / 60000, "llm_total": sum(llm) / 60000,        "tool_by_name_min": {k: round(v / 60000, 2) for k, v in tool_ok.items() if v > 1000},
        "non_completed_calls": tool_bad, "idle_gaps_over_5min": [round(g, 1) for g in gaps],
        "top_rereads": reads.most_common(5),
    }))
con.close()

print("## Harness telemetry (D37)\n")
print("| Session | Role | Kind | Steps | LLM min (med/p90 s) | Tool min | subagent min | question min | Tokens in/out (cache) | Denials | PNG reads |")
print("|---|---|---|---|---|---|---|---|---|---|---|")
for r in rows_out:
    sid, title, agent, kind, n, llm_t, llm_p, tool_t, sub_t, q_t, tok, dn, png = r
    print(f"| `{sid[:12]}…` {title[:34]} | {agent} | {kind} | {n} | {llm_t} ({llm_p}) | "
          f"{tool_t} | {sub_t} | {q_t} | {tok} | {dn} | {png} |")

print("\n### Detail\n")
for sid, title, dd in details:
    print(f"**{sid[:12]}… — {title[:50]}**")
    print(f"- span {dd['span_min']:.1f} min · LLM {dd['llm_total']:.1f} min · "
          f"idle gaps >5 min: {dd['idle_gaps_over_5min'] or 'none'}")
    if dd["tool_by_name_min"]:
        print(f"- tool (completed) min: {dd['tool_by_name_min']}")
    if dd["non_completed_calls"]:
        for b in dd["non_completed_calls"]:
            d = f" · {b['dur_ms']/60000:.1f} min" if b["dur_ms"] else ""
            print(f"- NON-COMPLETED {b['tool']} [{b['status']}]{d}: {b['desc']} — {b['err']}")
    if dd["top_rereads"]:
        tops = ", ".join(f"{p}×{n}" for p, n in dd["top_rereads"])
        print(f"- top reads: {tops}")
    print()
PYEOF
