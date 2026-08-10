#!/usr/bin/env bash
# add-shared.sh -- link a shared library into an existing C app's or shared
# library's libs.mk
# Usage: add-shared.sh <APP> <SHARED>
#   or:  add-shared.sh   (interactive)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/scripts/prompt.sh"

APP="${1:-}"
SHARED="${2:-}"

if [ -z "$APP" ] || [ -z "$SHARED" ]; then
    echo ""
    echo "==> Link shared library into a C app or another shared library"
    echo "----------------------------------------------------------------"

    APPS=()
    read_array APPS list_consumers "$ROOT"
    if [ "${#APPS[@]}" -eq 0 ]; then
        echo "ERROR: No C apps or shared libraries found. Create one with: make new-app"
        exit 1
    fi
    ask_choice APP "Select app or shared library" "${APPS[@]}"

    SHARED_LIBS_ALL=()
    read_array SHARED_LIBS_ALL list_shared_all "$ROOT"
    # Exclude APP itself -- a shared library can't depend on itself, so
    # don't even offer it as a choice (rather than let the picker allow it
    # and rely on the later validation check to reject it).
    SHARED_LIBS=()
    for lib in "${SHARED_LIBS_ALL[@]+"${SHARED_LIBS_ALL[@]}"}"; do
        [ "$lib" = "$APP" ] && continue
        SHARED_LIBS+=("$lib")
    done
    if [ "${#SHARED_LIBS[@]}" -eq 0 ]; then
        echo "ERROR: No other shared libraries found to depend on. Create one with: make new-app"
        exit 1
    fi
    ask_choice SHARED "Select shared library to depend on" "${SHARED_LIBS[@]}"
    echo ""
fi

# -- Validate the consumer (APP): a C app OR a shared library ---------------
# C app:            .board file AND Makefile
# Shared library:   src/ directory, no Makefile (agnostic or board-specific)
APP_IS_C=0
APP_IS_SHARED=0
if [ -f "$ROOT/$APP/.board" ] && [ -f "$ROOT/$APP/Makefile" ]; then
    APP_IS_C=1
elif [ -d "$ROOT/$APP/src" ] && [ ! -f "$ROOT/$APP/Makefile" ]; then
    APP_IS_SHARED=1
fi

if [ ! -d "$ROOT/$APP" ] || { [ "$APP_IS_C" -eq 0 ] && [ "$APP_IS_SHARED" -eq 0 ]; }; then
    echo "ERROR: '$APP' is not a C app or a shared library."
    exit 1
fi

if [ ! -d "$ROOT/$SHARED" ]; then
    echo "ERROR: shared lib '$SHARED' not found."
    exit 1
fi

if [ "$APP" = "$SHARED" ]; then
    echo "ERROR: '$APP' cannot depend on itself."
    exit 1
fi

# -- Board rules --------------------------------------------------------------
# SHARED is board-specific: consumer must target the same board, and a
# board-agnostic consumer can never depend on a board-specific library at
# all (that would silently make it not actually agnostic).
if [ -f "$ROOT/$SHARED/.board" ]; then
    SHARED_BOARD="$(cat "$ROOT/$SHARED/.board")"

    if [ ! -f "$ROOT/$APP/.board" ]; then
        echo ""
        echo "ERROR: board-agnostic library cannot depend on a board-specific one."
        echo "  '$SHARED' is board-specific: $SHARED_BOARD"
        echo "  '$APP' is board-agnostic and must remain usable on any board."
        echo ""
        echo "  Choose a board-agnostic shared library instead, or make '$APP'"
        echo "  board-specific if it genuinely needs to depend on '$SHARED'."
        echo ""
        exit 1
    fi

    APP_BOARD="$(cat "$ROOT/$APP/.board")"
    if [ "$SHARED_BOARD" != "$APP_BOARD" ]; then
        echo ""
        echo "ERROR: Board mismatch."
        echo "  '$SHARED' is board-specific: $SHARED_BOARD"
        echo "  '$APP' targets:              $APP_BOARD"
        echo ""
        echo "  Board-specific shared libraries can only be linked to apps or"
        echo "  other shared libraries targeting the same board."
        if [ "$APP_IS_C" -eq 1 ]; then
            echo "  Use 'make change-board APP=$APP BOARD=$SHARED_BOARD' to retarget"
            echo "  the app, or choose a board-agnostic shared library instead."
        else
            echo "  Choose a board-agnostic shared library instead, or a"
            echo "  board-specific one targeting: $APP_BOARD"
        fi
        echo ""
        exit 1
    fi
fi

LIBS_MK="$ROOT/$APP/libs.mk"
MARKER="SHARED += ../$SHARED"

if [ ! -f "$LIBS_MK" ]; then
    echo "ERROR: '$APP/libs.mk' not found."
    if [ "$APP_IS_SHARED" -eq 1 ]; then
        echo "  Shared libraries created before this feature was added need a"
        echo "  libs.mk copied in manually: cp scripts/templates/libs.mk $APP/libs.mk"
    fi
    exit 1
fi

if grep -qF "$MARKER" "$LIBS_MK" 2>/dev/null; then
    echo "INFO: '$SHARED' is already registered in $APP/libs.mk -- nothing to do."
    exit 0
fi

printf '\nSHARED += ../%s\n' "$SHARED" >> "$LIBS_MK"
echo "v  Shared library '$SHARED' linked into '$APP'."

echo "==> Regenerating VSCode configs..."
bash "$ROOT/scripts/gen-vscode.sh"
