#!/usr/bin/env bash
# Guardrailed worktree file removal — the sanctioned way to delete files (D30).
#
# Why this exists: shell permissions express verbs, not "only inside the
# worktree", so the guardrails live here (policy in code). Subagents delete
# planned-away files with `git rm` and scratch/probe leftovers with this script.
#
# Refused targets (nothing is removed if any target is refused):
#   - anything outside the worktree (absolute paths, `..` traversal, symlinks out)
#   - the worktree root itself
#   - `.git/**`
#   - secret env files (`.env`, `.env.*` — `.env.example` is exempt, it is tracked)
#
# Usage:
#   ./scripts/repo-fs.sh rm    <path...>   files (and empty dirs)
#   ./scripts/repo-fs.sh rm -r <path...>   directories (recursive)
#
# Exit codes: 0 removed as asked · 1 usage error · 2 refused (nothing removed).
set -uo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

usage() { printf 'usage: %s rm [-r] <path...>\n' "$0" >&2; exit 1; }

[ "${1:-}" = "rm" ] || usage
shift
recursive=0
if [ "${1:-}" = "-r" ]; then recursive=1; shift; fi
[ "$#" -gt 0 ] || usage

refused=0
validated=""

for p in "$@"; do
  case "$p" in
    "" | "." | ".." | "~"* | "/"* | "../"* | *"/../"* | *"/.." | ".."/*)
      printf 'refused: %s (outside the worktree or protected path)\n' "$p" >&2
      refused=2
      continue
      ;;
    ".git" | ".git"/* | *"/.git" | *"/.git"/*)
      printf 'refused: %s (.git is protected)\n' "$p" >&2
      refused=2
      continue
      ;;
  esac

  base="$(basename "$p")"
  if [ "$base" != ".env.example" ]; then
    case "$base" in
      .env | .env.*)
        printf 'refused: %s (env files hold secrets — see the swift-security skill)\n' "$p" >&2
        refused=2
        continue
        ;;
    esac
  fi

  parent="$(dirname "$p")"
  if [ ! -d "$parent" ]; then
    printf 'refused: %s (parent directory missing)\n' "$p" >&2
    refused=2
    continue
  fi
  abs="$(cd "$parent" && pwd -P)/$(basename "$p")"

  case "$abs" in
    "$root" | "$root"/*) : ;;
    *)
      printf 'refused: %s (resolves outside the worktree)\n' "$p" >&2
      refused=2
      continue
      ;;
  esac
  if [ "$abs" = "$root" ]; then
    printf 'refused: %s (worktree root)\n' "$p" >&2
    refused=2
    continue
  fi
  if [ -d "$abs" ] && [ ! -L "$abs" ] && [ "$recursive" -eq 0 ]; then
    printf 'refused: %s (directory — use: %s rm -r <path>)\n' "$p" "$0" >&2
    refused=2
    continue
  fi

  validated="$validated$abs
"
done

# Atomic: any refusal vetoes the whole call.
if [ "$refused" -ne 0 ]; then
  printf 'nothing removed\n' >&2
  exit 2
fi

printf '%s' "$validated" | while IFS= read -r abs; do
  [ -n "$abs" ] || continue
  if [ ! -e "$abs" ] && [ ! -L "$abs" ]; then
    printf 'absent:  %s\n' "${abs#"$root"/}"
    continue
  fi
  if [ "$recursive" -eq 1 ]; then
    rm -rf -- "$abs"
  else
    rm -f -- "$abs"
  fi
  printf 'removed: %s\n' "${abs#"$root"/}"
done
