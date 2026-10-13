#!/usr/bin/env bash
# App lifecycle for the stakeholder functional review (SDD converge step).
# The sanctioned way for agents to run/stop the app — raw xcodebuild/open/pkill
# stay out of the subagent allowlists (see .opencode/agents/implementer*.md).
#
# Usage:
#   ./scripts/app.sh run      build, install to ~/Applications, and launch the app
#   ./scripts/app.sh stop     quit the app gracefully (fallback: terminate)
#   ./scripts/app.sh status   print the app's process state
#
# `run` installs a copy at ~/Applications/InstantPlayer.app and registers it with
# Launch Services + Spotlight: the pinned derived-data path (.deriveddata/) is
# hidden and Spotlight does not index it, so Finder "Open With" and Spotlight
# would otherwise resolve to stale copies and the app would be undiscoverable.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

project="InstantPlayer.xcodeproj"
scheme="InstantPlayer"
bundle_id="com.guits.InstantPlayer"
derived_data="$root/.deriveddata"
config="Debug"

cmd="${1:-}"

app_path() {
  printf '%s/Build/Products/%s/InstantPlayer.app' "$derived_data" "$config"
}

case "$cmd" in
  run)
    xcodebuild -project "$project" -scheme "$scheme" -configuration "$config" \
      -destination 'platform=macOS' -derivedDataPath "$derived_data" build
    built="$(app_path)"
    [ -d "$built" ] || { echo "error: built app not found at $built" >&2; exit 2; }
    install_dir="$HOME/Applications"
    installed="$install_dir/InstantPlayer.app"
    lsregister=/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister
    mkdir -p "$install_dir"
    rm -rf "$installed"
    ditto "$built" "$installed"
    "$lsregister" -f -R -trusted "$installed"
    mdimport "$installed" >/dev/null 2>&1 || true
    open "$installed"
    echo "app launched: $bundle_id (installed: $installed)"
    ;;
  stop)
    osascript -e 'quit app id "'"$bundle_id"'"' 2>/dev/null || true
    sleep 1
    pgrep -xq InstantPlayer && pkill -x InstantPlayer 2>/dev/null || true
    echo "app stopped (if it was running)"
    ;;
  status)
    if pgrep -x InstantPlayer > /dev/null 2>&1; then
      printf 'running (pid %s)\n' "$(pgrep -x InstantPlayer | tr '\n' ' ' | sed 's/ *$//')"
    else
      echo "not running"
    fi
    ;;
  *)
    printf 'usage: %s run|stop|status\n' "$0" >&2
    exit 1
    ;;
esac
