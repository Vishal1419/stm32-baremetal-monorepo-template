#!/usr/bin/env bash
# sync-makefiles.sh -- re-generate every C app's Makefile from the template.
#
# Usage:
#   bash scripts/sync-makefiles.sh            copy the template over every C app's Makefile
#   bash scripts/sync-makefiles.sh --check    only show which apps differ, change nothing
#                                             (exit code 1 if any app differs, 0 if all match)
#
# A "C app" is a folder that has both a .board file and a Makefile.
# (Board-specific shared libraries have .board but no Makefile, so they are skipped.)
#
# This replaces each app's whole Makefile with scripts/templates/app.Makefile.
# Anything written by hand in an app's Makefile is lost, so run --check first
# and look at the result with git diff afterwards.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMPLATE="$ROOT/scripts/templates/app.Makefile"

CHECK_ONLY=0
case "${1:-}" in
    "")       ;;
    --check)  CHECK_ONLY=1 ;;
    *)        echo "Usage: $0 [--check]"; exit 2 ;;
esac

if [ ! -f "$TEMPLATE" ]; then
    echo "ERROR: template not found: $TEMPLATE"
    exit 2
fi

found=0
differ=0

for dir in "$ROOT"/*/; do
    app="$(basename "$dir")"
    [ -f "$dir.board" ] && [ -f "$dir""Makefile" ] || continue
    found=$((found + 1))

    if cmp -s "$TEMPLATE" "$dir""Makefile"; then
        echo "  ok       $app"
        continue
    fi

    differ=$((differ + 1))

    if [ "$CHECK_ONLY" -eq 1 ]; then
        echo "  differs  $app"
    else
        cp "$TEMPLATE" "$dir""Makefile"
        echo "  updated  $app"
    fi
done

if [ "$found" -eq 0 ]; then
    echo "No C apps found."
    exit 0
fi

echo ""
if [ "$CHECK_ONLY" -eq 1 ]; then
    if [ "$differ" -gt 0 ]; then
        echo "$differ of $found app(s) differ from the template."
        echo "Run 'make sync-makefiles' to update them (see 'git diff' afterwards)."
        exit 1
    fi
    echo "All $found app(s) match the template."
else
    echo "$differ of $found app(s) updated."
fi
