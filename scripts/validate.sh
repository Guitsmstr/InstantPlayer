#!/usr/bin/env bash
# Deterministic gate — must pass before every commit (wired via .githooks/pre-commit).
# Destination: macOS (D1) — this is a Mac app; no simulator involved.
# Usage: ./scripts/validate.sh [--staged] [--json <path>] [--verbose]
#   --uitests   also run the UI-test target (InstantPlayerUITests) — off by
#               default; implies the full run (docs-only shortcut not taken)
#   --staged    skip build-heavy steps when only docs/harness files are staged
#   --json      write a machine-readable evidence summary (per-step results) —
#               record evidence from it, never from memory
#   --verbose   print failing step output in full (default: tail + full log path)
# Every run keeps its full step logs in a temp dir, printed at start and end.
set -uo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

project="InstantPlayer.xcodeproj"
scheme="InstantPlayer"
unit_test_target="InstantPlayerTests"
ui_test_target="InstantPlayerUITests"
derived_data="$root/.deriveddata"

staged=0
verbose=0
json_out=""
uitests=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --staged) staged=1 ;;
    --uitests) uitests=1 ;;
    --verbose) verbose=1 ;;
    --json) json_out="${2:?--json needs a path}"; shift ;;
    *) printf 'unknown option: %s\n' "$1" >&2; exit 1 ;;
  esac
  shift
done

errors=0
cur=""
step_n=0
logdir="$(mktemp -d "${TMPDIR:-/tmp}/instantplayer-gate.XXXXXX")"
: > "$logdir/steps.tsv"
printf '# gate logs: %s\n' "$logdir"

step() { cur="$1"; printf '\n== %s ==\n' "$1"; }
record() { [ -n "$cur" ] && printf '%s\t%s\n' "$cur" "$1" >> "$logdir/steps.tsv"; return 0; }
ok()   { printf 'ok:   %s\n' "$1"; record ok; }
err()  { printf 'FAIL: %s\n' "$1"; errors=$((errors + 1)); record fail; }
show_log() {
  local log="$1"
  if [ "$verbose" -eq 1 ]; then
    cat "$log"
  else
    tail -n 60 "$log"
    printf 'full log: %s\n' "$log"
  fi
}
run_step() {
  local name="$1"; shift
  local slug out
  slug="$(printf '%s' "$name" | tr -cs 'A-Za-z0-9' '-' | sed 's/^-//;s/-$//')"
  out="$logdir/$(printf '%02d' "$step_n")-$slug.log"
  step_n=$((step_n + 1))
  if "$@" >"$out" 2>&1; then ok "$name"; else
    err "$name"
    show_log "$out"
  fi
}

# --- Docs checks (always) -----------------------------------------------------

step "ADR format (docs/decisions.md)"
adr_total=$(grep -c '^## D[0-9]' docs/decisions.md 2>/dev/null || true)
adr_bad=$(grep -n '^## D[0-9]' docs/decisions.md 2>/dev/null | grep -vE '^[0-9]+:## D[0-9]+ — .+ · [0-9]{4}-[0-9]{2}-[0-9]{2} · (accepted|pending|postponed|superseded|temporary)' || true)
if [ -n "$adr_bad" ]; then err "malformed ADR heading(s):
$adr_bad"; else ok "$adr_total ADRs well-formed"; fi

step "Internal links (docs + AGENTS.md)"
broken=0
for f in docs/*.md docs/specs/*.md docs/specs/*/*.md AGENTS.md; do
  [ -f "$f" ] || continue
  while IFS= read -r target; do
    target="${target%%#*}"
    [ -z "$target" ] && continue
    case "$target" in http*|mailto:*) continue ;; esac
    if [ ! -e "$(dirname "$f")/$target" ] && [ ! -e "$target" ]; then
      err "broken link in $f -> $target"; broken=1
    fi
  done < <(grep -oE '\]\([^)]+\)' "$f" | tr -d ']()')
done
[ "$broken" -eq 0 ] && ok "all internal links resolve"

step "Approved-spec hygiene (docs/specs/*/tasks.md)"
if compgen -G 'docs/specs/*/tasks.md' > /dev/null; then
  hits=$(grep -rn 'NEEDS CLARIFICATION' docs/specs/*/tasks.md || true)
  if [ -n "$hits" ]; then err "tasks.md must not contain NEEDS CLARIFICATION:
$hits"; else ok "no unresolved markers in tasks"; fi
else
  ok "no task specs yet"
fi

# --- Branch policy (staged mode only) ------------------------------------------

branch="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
if [ "$staged" -eq 1 ]; then
  step "Branch policy (staged changes vs. 'main' allowlist)"
  if [ "$branch" = "main" ]; then
    offenders="$(git diff --cached --name-only --diff-filter=ACMRD 2>/dev/null \
      | grep -vE '^(docs/|\.opencode/|\.pi/|\.githooks/|scripts/|AGENTS\.md$|opencode\.json$|\.gitignore$|\.swift-version$)' || true)"
    if [ -n "$offenders" ]; then
      printf '%s\n%s\n' "$branch" "$offenders" > "$logdir/branch-policy.txt"
      err "branch policy: code changes are not allowed on 'main' — create a story branch \`feat/<story-id>-<slug>\` (see AGENTS.md → Hard rule 7)
offending path(s):
$offenders"
    else
      printf '%s\n' "$branch" > "$logdir/branch-policy.txt"
      ok "staged paths within 'main' allowlist (docs/, .opencode/, .pi/, AGENTS.md, scripts/)"
    fi
  else
    printf '%s\n' "${branch:-detached HEAD}" > "$logdir/branch-policy.txt"
    ok "branch policy ok (branch: ${branch:-detached HEAD} — check active only on 'main')"
  fi
fi

# --- Docs-only mode (for --staged) ---------------------------------------------

docs_only=0
if [ "$staged" -eq 1 ] && [ "$uitests" -eq 0 ]; then
  files=$(git diff --cached --name-only 2>/dev/null || true)
  if [ -n "$files" ] && ! grep -qvE '^(\.opencode/|\.pi/|\.githooks/|scripts/|docs/|AGENTS\.md|opencode\.json|\.gitignore|\.swift-version|.*\.md$)' <<< "$files"; then
    docs_only=1
    step "Staged set is docs/harness only — skipping build steps"
  fi
fi
if [ "$staged" -eq 1 ] && [ "$uitests" -eq 1 ]; then
  printf '%s\n' "# --uitests set — full run required (UI tests need the built app); docs-only shortcut not applicable"
fi

# --- Project checks (auto-activate once the Xcode project exists) ---------------

if [ -d "$project" ] && [ "$docs_only" -eq 0 ]; then

  step "Lint (SwiftLint)"
  if command -v swiftlint > /dev/null 2>&1; then
    run_step "swiftlint lint --quiet" swiftlint lint --quiet
  else
    err "swiftlint not installed (brew install swiftlint) — gate is fail-closed"
  fi

  step "Format check (SwiftFormat --lint)"
  if command -v swiftformat > /dev/null 2>&1; then
    run_step "swiftformat --lint ." swiftformat --lint .
  else
    err "swiftformat not installed (brew install swiftformat) — gate is fail-closed"
  fi

  step "Build ($scheme)"
  run_step "xcodebuild build" \
    xcodebuild -project "$project" -scheme "$scheme" -configuration Debug \
      -destination 'platform=macOS' -derivedDataPath "$derived_data" build

  step "Unit tests ($unit_test_target)"
  run_step "xcodebuild test -only-testing:$unit_test_target" \
    xcodebuild -project "$project" -scheme "$scheme" -configuration Debug \
      -destination 'platform=macOS' -derivedDataPath "$derived_data" \
      -only-testing:"$unit_test_target" test

  if [ "$uitests" -eq 1 ]; then
    step "UI tests ($ui_test_target)"
    run_step "xcodebuild test -only-testing:$ui_test_target" \
      xcodebuild -project "$project" -scheme "$scheme" -configuration Debug \
        -destination 'platform=macOS' -derivedDataPath "$derived_data" \
        -only-testing:"$ui_test_target" test
  fi
fi

# --- Result ----------------------------------------------------------------------

step "Result"
exit_code=0
if [ "$errors" -gt 0 ]; then
  printf '%d check(s) FAILED\n' "$errors"
  exit_code=1
else
  printf 'all checks passed\n'
fi

if [ -n "$json_out" ]; then
  {
    printf '{\n'
    printf '  "branch": "%s",\n' "${branch:-}"
    printf '  "staged": %s,\n' "$([ "$staged" -eq 1 ] && printf true || printf false)"
    printf '  "result": "%s",\n' "$([ "$exit_code" -eq 0 ] && printf pass || printf fail)"
    printf '  "steps": ['
    first=1
    while IFS="$(printf '\t')" read -r name status; do
      [ -n "$name" ] || continue
      [ $first -eq 1 ] || printf ','
      printf '\n    { "name": "%s", "status": "%s" }' "$name" "$status"
      first=0
    done < "$logdir/steps.tsv"
    printf '\n  ]\n}\n'
  } > "$json_out"
fi
printf 'gate logs: %s\n' "$logdir"
exit "$exit_code"
