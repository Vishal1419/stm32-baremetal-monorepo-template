#!/usr/bin/env bash
# remove-board.sh -- remove a board template
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/scripts/prompt.sh"

BOARD="${1:-}"

if [ -z "$BOARD" ]; then
    echo ""
    echo "==> Remove a board"
    echo "------------------"

    mapfile_compat() {
        local _arrname="$1"; shift
        local _i=0
        while IFS= read -r _line; do
            eval "${_arrname}[$_i]=\"\$_line\""
            ((_i++)) || true
        done < <("$@")
    }

    BOARDS=()
    mapfile_compat BOARDS list_boards "$ROOT"
    if [ "${#BOARDS[@]}" -eq 0 ]; then
        echo "ERROR: No boards found."
        exit 1
    fi

    echo "  Available boards:"
    for b in "${BOARDS[@]}"; do
        users=""
        for dot_board in "$ROOT"/*/.board; do
            [ -f "$dot_board" ] || continue
            [ "$(cat "$dot_board")" = "$b" ] && \
                users="$users $(basename "$(dirname "$dot_board")")"
        done
        if [ -n "$users" ]; then
            printf "    %s  (in use by:%s)\n" "$b" "$users"
        else
            printf "    %s\n" "$b"
        fi
    done
    echo ""
    # Use ask_choice so user picks by number
    ask_choice BOARD "Select board to remove" "${BOARDS[@]}"
    echo ""
fi

BOARD_DIR="$ROOT/boards/$BOARD"

[ -d "$BOARD_DIR" ] || { echo "ERROR: board '$BOARD' not found."; exit 1; }

BOARD_COUNT=$(find "$ROOT/boards" -mindepth 1 -maxdepth 1 -type d | wc -l)
if [ "$BOARD_COUNT" -le 1 ]; then
    echo "ERROR: Cannot remove the last board."
    exit 1
fi

USERS=()
for dot_board in "$ROOT"/*/.board; do
    [ -f "$dot_board" ] || continue
    if [ "$(cat "$dot_board")" = "$BOARD" ]; then
        USERS+=("$(basename "$(dirname "$dot_board")")")
    fi
done

if [ "${#USERS[@]}" -gt 0 ]; then
    echo "ERROR: board '$BOARD' is still in use by: ${USERS[*]}"
    echo "Use 'make change-board' to reassign those apps first."
    exit 1
fi

rm -rf "$BOARD_DIR"
echo "v  Board '$BOARD' removed."

# Issue 5: regenerate vscode configs after board removal
echo "==> Regenerating VSCode configs..."
bash "$ROOT/scripts/gen-vscode.sh"
