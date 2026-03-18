#!/usr/bin/env bash
# add-shared.sh -- link a shared library into an existing C app's libs.mk
# Usage: add-shared.sh <APP> <SHARED>
#   or:  add-shared.sh   (interactive)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/scripts/prompt.sh"

APP="${1:-}"
SHARED="${2:-}"

if [ -z "$APP" ] || [ -z "$SHARED" ]; then
    echo ""
    echo "==> Link shared library into C app"
    echo "----------------------------------"

    APPS=()
    read_array APPS list_apps "$ROOT"
    if [ "${#APPS[@]}" -eq 0 ]; then
        echo "ERROR: No C apps found. Create one with: make new-app"
        exit 1
    fi
    ask_choice APP "Select app" "${APPS[@]}"

    SHARED_LIBS=()
    read_array SHARED_LIBS list_shared "$ROOT"
    if [ "${#SHARED_LIBS[@]}" -eq 0 ]; then
        echo "ERROR: No shared libraries found. Create one with: make new-app"
        exit 1
    fi
    ask_choice SHARED "Select shared library" "${SHARED_LIBS[@]}"
    echo ""
fi

if [ ! -d "$ROOT/$APP" ] || [ ! -f "$ROOT/$APP/.board" ]; then
    echo "ERROR: '$APP' is not a C sub-project."
    exit 1
fi
if [ ! -d "$ROOT/$SHARED" ]; then
    echo "ERROR: shared lib '$SHARED' not found."
    exit 1
fi

# Board mismatch check -- board-specific shared libs can only link to matching apps
if [ -f "$ROOT/$SHARED/.board" ]; then
    SHARED_BOARD="$(cat "$ROOT/$SHARED/.board")"
    APP_BOARD="$(cat "$ROOT/$APP/.board")"
    if [ "$SHARED_BOARD" != "$APP_BOARD" ]; then
        echo ""
        echo "ERROR: Board mismatch."
        echo "  '$SHARED' is board-specific: $SHARED_BOARD"
        echo "  '$APP' targets:              $APP_BOARD"
        echo ""
        echo "  Board-specific shared libraries can only be linked to apps"
        echo "  targeting the same board."
        echo "  Use 'make change-board APP=$APP BOARD=$SHARED_BOARD' to retarget"
        echo "  the app, or choose a board-agnostic shared library instead."
        echo ""
        exit 1
    fi
fi

LIBS_MK="$ROOT/$APP/libs.mk"
MARKER="SHARED += ../$SHARED"

if grep -qF "$MARKER" "$LIBS_MK" 2>/dev/null; then
    echo "INFO: '$SHARED' is already registered in $APP/libs.mk -- nothing to do."
    exit 0
fi

printf '\nSHARED += ../%s\n' "$SHARED" >> "$LIBS_MK"
echo "v  Shared library '$SHARED' linked into '$APP'."
