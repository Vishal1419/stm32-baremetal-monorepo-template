#!/usr/bin/env bash
# remove-app.sh -- remove a C app, TS app, or shared library
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/scripts/prompt.sh"

APP="${1:-}"

if [ -z "$APP" ]; then
    echo ""
    echo "==> Remove a sub-project"
    echo "-------------------------"

    APPS=()
    read_array APPS list_removable "$ROOT"
    if [ "${#APPS[@]}" -eq 0 ]; then
        echo "ERROR: No removable sub-projects found."
        exit 1
    fi
    ask_choice APP "Select sub-project to remove" "${APPS[@]}"
    echo ""
fi

APP_DIR="$ROOT/$APP"

for reserved in boards scripts .vscode; do
    [ "$APP" = "$reserved" ] && { echo "ERROR: '$APP' is a reserved name, cannot remove."; exit 1; }
done

[ -d "$APP_DIR" ] || { echo "ERROR: '$APP' not found."; exit 1; }

# -- Identify project type (for messaging only) -------------------------------
if [ -f "$APP_DIR/.board" ] && [ -f "$APP_DIR/Makefile" ]; then
    KIND="C app"
elif [ -f "$APP_DIR/package.json" ] && [ ! -f "$APP_DIR/.board" ]; then
    KIND="TypeScript app"
elif [ -d "$APP_DIR/src" ] && [ -f "$APP_DIR/.board" ] && [ ! -f "$APP_DIR/Makefile" ]; then
    KIND="board-specific shared library"
elif [ -d "$APP_DIR/src" ] && [ ! -f "$APP_DIR/.board" ] && [ ! -f "$APP_DIR/package.json" ]; then
    KIND="board-agnostic shared library"
else
    echo "ERROR: '$APP' does not look like a C app, TS app, or shared library."
    exit 1
fi

# -- Dependency check -- refuse if anything still depends on this project ----
# Only C apps and shared libs have libs.mk; TS apps can never be a SHARED
# dependency, so nothing can depend on one.
DEPENDENTS=()
for lm in "$ROOT"/*/libs.mk; do
    [ -f "$lm" ] || continue
    proj="$(basename "$(dirname "$lm")")"
    [ "$proj" = "$APP" ] && continue
    if grep -qF "SHARED += ../$APP" "$lm" 2>/dev/null; then
        DEPENDENTS+=("$proj")
    fi
done

if [ "${#DEPENDENTS[@]}" -gt 0 ]; then
    echo ""
    echo "ERROR: '$APP' is still depended on by: ${DEPENDENTS[*]}"
    echo "Remove those SHARED entries first (edit their libs.mk), or remove"
    echo "the dependent projects themselves before removing '$APP'."
    echo ""
    exit 1
fi

# -- Submodule cleanup ---------------------------------------------------------
# C apps always have submodules/libopencm3; board-specific shared libs always
# do too; board-agnostic shared libs have it only if the "yes" path was taken
# at creation. Registered submodules need proper deinit -- rm -rf alone would
# leave stale entries in .gitmodules and .git/modules/, the same class of
# issue that caused the motor-controller -> arm-controller rename headache.
SUBMOD_PATH="$APP/submodules/libopencm3"
if [ -f "$ROOT/.gitmodules" ] && grep -qF "path = $SUBMOD_PATH" "$ROOT/.gitmodules" 2>/dev/null; then
    echo "==> Deregistering libopencm3 git submodule..."
    ( cd "$ROOT" && git submodule deinit -f "$SUBMOD_PATH" > /dev/null 2>&1 ) || true
    ( cd "$ROOT" && git rm -f "$SUBMOD_PATH" > /dev/null 2>&1 ) || true
    rm -rf "$ROOT/.git/modules/$SUBMOD_PATH"
    echo "v  Submodule deregistered."
fi

rm -rf "$APP_DIR"
echo "v  $KIND '$APP' removed."

# Regenerate vscode configs so the removed project drops out of the
# workspace file and no longer appears in files.exclude / includePath.
echo "==> Regenerating VSCode configs..."
bash "$ROOT/scripts/gen-vscode.sh"
