#!/usr/bin/env bash
# change-board.sh -- switch the target board of a C app
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/scripts/prompt.sh"

APP="${1:-}"
BOARD="${2:-}"

if [ -z "$APP" ] || [ -z "$BOARD" ]; then
    echo ""
    echo "==> Change board for a C app"
    echo "----------------------------"

    APPS=()
    read_array APPS list_apps "$ROOT"
    if [ "${#APPS[@]}" -eq 0 ]; then
        echo "ERROR: No C apps found."
        exit 1
    fi
    ask_choice APP "Select app to change board for" "${APPS[@]}"

    CURRENT_BOARD="$(cat "$ROOT/$APP/.board" 2>/dev/null || echo "unknown")"
    echo "  Current board: $CURRENT_BOARD"

    BOARDS=()
    read_array BOARDS list_boards "$ROOT"
    ask_choice BOARD "Select new board" "${BOARDS[@]}"
    echo ""
fi

APP_DIR="$ROOT/$APP"
BOARD_DIR="$ROOT/boards/$BOARD"

[ ! -d "$APP_DIR" ] || [ ! -f "$APP_DIR/.board" ] && {
    echo "ERROR: '$APP' is not a C sub-project."
    exit 1
}
[ ! -d "$BOARD_DIR" ] && {
    echo "ERROR: board '$BOARD' not found."
    ls "$ROOT/boards/" 2>/dev/null
    exit 1
}

CURRENT_BOARD="$(cat "$APP_DIR/.board")"
if [ "$CURRENT_BOARD" = "$BOARD" ]; then
    echo "INFO: '$APP' is already using board '$BOARD' -- nothing to do."
    exit 0
fi

# Check if any board-specific shared libs linked to this app would mismatch
LIBS_MK="$ROOT/$APP/libs.mk"
if [ -f "$LIBS_MK" ]; then
    while IFS= read -r line; do
        case "$line" in
            SHARED*=*)
                shared_dir="$(echo "$line" | sed 's/.*=[[:space:]]*//' | tr -d ' \t')"
                shared_name="$(echo "$shared_dir" | sed 's|^\.\./||')"
                shared_board_file="$ROOT/$shared_name/.board"
                if [ -f "$shared_board_file" ]; then
                    shared_board="$(cat "$shared_board_file")"
                    if [ "$shared_board" != "$BOARD" ]; then
                        echo ""
                        echo "ERROR: Board mismatch with linked shared library."
                        echo "  '$shared_name' is board-specific: $shared_board"
                        echo "  Requested new board:             $BOARD"
                        echo ""
                        echo "  Unlink '$shared_name' first with:"
                        echo "    make remove-shared APP=$APP SHARED=$shared_name"
                        echo "  Or choose a board that matches: $shared_board"
                        echo ""
                        exit 1
                    fi
                fi
                ;;
        esac
    done < "$LIBS_MK"
fi

echo "==> Changing board for '$APP': $CURRENT_BOARD -> $BOARD"

echo "==> Cleaning stale build artefacts..."
make --no-print-directory -C "$APP_DIR" clean 2>/dev/null || true

echo "$BOARD" > "$APP_DIR/.board"
echo "v  Board updated: $APP -> $BOARD"

echo "==> Regenerating VSCode configs..."
bash "$ROOT/scripts/gen-vscode.sh"

echo "==> Building $APP for new board $BOARD..."
echo "    (run with V=1 to see all compiler commands)"
if make --no-print-directory -C "$APP_DIR" all; then
    echo ""
    echo "v  Build complete. Output files:"
    ls -lh "$APP_DIR/build/firmware.elf" "$APP_DIR/build/firmware.bin" 2>/dev/null || true
else
    echo "ERROR: Build failed for $APP on $BOARD"
    exit 1
fi
