#!/usr/bin/env bash
# new-app.sh -- create a new sub-project (C firmware, shared C lib, or TypeScript)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/scripts/prompt.sh"

TYPE="${1:-}"
shift 2>/dev/null || true

if [ -z "$TYPE" ]; then
    echo ""
    echo "==> Create new sub-project"
    echo "--------------------------"
    ask_choice TYPE "What type of sub-project?" \
        "c       - C firmware app (STM32 / libopencm3)" \
        "shared  - Shared C library (board-agnostic, used by C apps)" \
        "ts      - TypeScript / Node app"
    TYPE="$(echo "$TYPE" | awk '{print $1}')"
    echo ""
fi

case "$TYPE" in

# ── C firmware app ──────────────────────────────────────────────────────────
c)
    APP="${1:-}"
    BOARD="${2:-}"
    SHARED="${3:-}"

    if [ -z "$APP" ] || [ -z "$BOARD" ]; then
        ask_required APP "App name (e.g. robot)"

        BOARDS=()
        read_array BOARDS list_boards "$ROOT"
        if [ "${#BOARDS[@]}" -eq 0 ]; then
            echo "ERROR: No boards found. Run 'make add-board' first."
            exit 1
        fi
        ask_choice BOARD "Select board" "${BOARDS[@]}"

        # Issue 7: use ask_choice for shared library selection
        SHARED_LIBS=()
        read_array SHARED_LIBS list_shared "$ROOT"
        if [ "${#SHARED_LIBS[@]}" -gt 0 ]; then
            SHARED_CHOICES=("(none) - skip shared library")
            for lib in "${SHARED_LIBS[@]}"; do
                SHARED_CHOICES+=("$lib")
            done
            ask_choice SHARED_SEL "Link a shared library?" "${SHARED_CHOICES[@]}"
            SHARED="$(echo "$SHARED_SEL" | awk '{print $1}')"
            [ "$SHARED" = "(none)" ] && SHARED=""
        fi
        echo ""
    fi

    APP_DIR="$ROOT/$APP"
    BOARD_DIR="$ROOT/boards/$BOARD"

    [ -d "$APP_DIR" ]   && { echo "ERROR: '$APP' already exists."; exit 1; }
    [ -d "$BOARD_DIR" ] || { echo "ERROR: board '$BOARD' not found."; ls "$ROOT/boards/"; exit 1; }
    [ -n "$SHARED" ] && [ ! -d "$ROOT/$SHARED" ] && \
        { echo "ERROR: shared lib '$SHARED' not found."; exit 1; }

    echo "==> Creating C sub-project: $APP  (board: $BOARD)"
    mkdir -p "$APP_DIR/src" "$APP_DIR/submodules"
    echo "$BOARD" > "$APP_DIR/.board"
    cp "$ROOT/scripts/templates/app.Makefile" "$APP_DIR/Makefile"
    cp "$ROOT/scripts/templates/libs.mk"      "$APP_DIR/libs.mk"

    cat > "$APP_DIR/src/main.c" << 'CEOF'
#include <libopencm3/stm32/rcc.h>
#include <libopencm3/stm32/gpio.h>

int main(void)
{
    /* TODO: initialise clocks, peripherals, and application logic */
    while (1) {
    }
    return 0;
}
CEOF

    echo "==> Adding libopencm3 as git submodule..."
    cd "$ROOT"
    git submodule add \
        https://github.com/libopencm3/libopencm3.git \
        "$APP/submodules/libopencm3"
    git submodule update --init "$APP/submodules/libopencm3"

    if [ -n "$SHARED" ]; then
        echo "==> Linking shared library: $SHARED"
        bash "$ROOT/scripts/add-shared.sh" "$APP" "$SHARED"
    fi

    bash "$ROOT/scripts/gen-vscode.sh" --workspace-only

    echo ""
    echo "v  C app '$APP' created  (board: $BOARD)"
    echo "   Next: make vscode && make build APP=$APP"
    ;;

# ── Shared C library ────────────────────────────────────────────────────────
shared)
    NAME="${1:-}"

    if [ -z "$NAME" ]; then
        ask_required NAME "Library name (e.g. shared-comms)"
        echo ""
    fi

    for reserved in boards scripts .vscode; do
        [ "$NAME" = "$reserved" ] && { echo "ERROR: '$NAME' is a reserved name."; exit 1; }
    done
    [ -d "$ROOT/$NAME" ] && { echo "ERROR: '$NAME' already exists."; exit 1; }

    # Ask if board-specific
    BOARD_SPECIFIC=""
    ask_choice BOARD_SPECIFIC "Is this shared library board-specific?" \
        "no  - board-agnostic, works with any STM32 (recommended)" \
        "yes - tied to a specific board (for code shared between apps on the same board)"
    BOARD_SPECIFIC="$(echo "$BOARD_SPECIFIC" | awk '{print $1}')"

    echo "==> Creating shared library: $NAME"
    mkdir -p "$ROOT/$NAME/src" "$ROOT/$NAME/inc"
    touch "$ROOT/$NAME/src/.gitkeep"
    touch "$ROOT/$NAME/inc/.gitkeep"

    if [ "$BOARD_SPECIFIC" = "yes" ]; then
        # Board-specific shared lib -- has .board, own libopencm3 submodule, no shims
        BOARDS=()
        read_array BOARDS list_boards "$ROOT"
        if [ "${#BOARDS[@]}" -eq 0 ]; then
            echo "ERROR: No boards found. Run 'make add-board' first."
            exit 1
        fi
        ask_choice BOARD "Select board" "${BOARDS[@]}"

        echo "$BOARD" > "$ROOT/$NAME/.board"

        echo "==> Adding libopencm3 submodule..."
        cd "$ROOT"
        git submodule add \
            https://github.com/libopencm3/libopencm3.git \
            "$NAME/submodules/libopencm3"
        git submodule update --init "$NAME/submodules/libopencm3"
        echo "v  libopencm3 submodule added to $NAME/"

        bash "$ROOT/scripts/gen-vscode.sh" --workspace-only

        echo ""
        echo "v  Board-specific shared library '$NAME' created (board: $BOARD)."
        echo "   src/    -- .c and .h files"
        echo "   inc/    -- public headers"
        echo "   .board  -- board pointer, do not change manually"
        echo "   submodules/libopencm3/ -- for building and IntelliSense"
        echo "   Note: can only be linked to apps targeting board: $BOARD"
        echo "   Next: make add-shared  (to link into a C app on $BOARD)"
    else
        # Board-agnostic shared lib -- no .board, optional libopencm3 submodule + shims
        ADD_OCM3=""
        ask_choice ADD_OCM3 "Will this shared library use libopencm3 headers?" \
            "yes - add libopencm3 submodule for IntelliSense (headers only, never built)" \
            "no  - pure C, no libopencm3 dependency"
        ADD_OCM3="$(echo "$ADD_OCM3" | awk '{print $1}')"

        if [ "$ADD_OCM3" = "yes" ]; then
            echo "==> Adding libopencm3 submodule (headers only)..."
            cd "$ROOT"
            git submodule add \
                https://github.com/libopencm3/libopencm3.git \
                "$NAME/submodules/libopencm3"
            git submodule update --init "$NAME/submodules/libopencm3"
            echo "v  libopencm3 submodule added to $NAME/"

            echo "==> Generating libopencm3 shims..."
            bash "$ROOT/scripts/gen-shims.sh" "$ROOT/$NAME"
            echo "v  Shims generated at $NAME/shims/"
        fi

        bash "$ROOT/scripts/gen-vscode.sh" --workspace-only

        echo ""
        echo "v  Shared library '$NAME' created."
        echo "   src/ -- .c and .h files (headers beside their .c files)"
        echo "   inc/ -- public headers included by consuming apps"
        if [ "$ADD_OCM3" = "yes" ]; then
            echo "   submodules/libopencm3/ -- headers for IntelliSense (never built from here)"
            echo "   shims/ -- libopencm3 dispatch shims (committed to git)"
            echo "   Note: do not hardcode MCU family -- injected by app at build time."
        fi
        echo "   Next: make add-shared  (to link into a C app)"
    fi
    ;;

# ── TypeScript / Node app ───────────────────────────────────────────────────
ts)
    APP="${1:-}"

    if [ -z "$APP" ]; then
        ask_required APP "App name (e.g. mytools)"
        echo ""
    fi

    APP_DIR="$ROOT/$APP"

    for reserved in boards scripts .vscode; do
        [ "$APP" = "$reserved" ] && { echo "ERROR: '$APP' is a reserved name."; exit 1; }
    done
    [ -d "$APP_DIR" ] && { echo "ERROR: '$APP' already exists."; exit 1; }

    echo "==> Creating TypeScript sub-project: $APP"
    mkdir -p "$APP_DIR/src"

    cat > "$APP_DIR/package.json" << PKGEOF
{
  "name": "${APP}",
  "version": "1.0.0",
  "description": "",
  "main": "dist/index.js",
  "scripts": {
    "build": "tsc",
    "start": "node dist/index.js",
    "dev":   "ts-node src/index.ts",
    "clean": "rm -rf dist"
  },
  "devDependencies": {
    "typescript": "^5.0.0",
    "ts-node":    "^10.0.0",
    "@types/node": "^20.0.0"
  }
}
PKGEOF

    cat > "$APP_DIR/tsconfig.json" << 'TSCEOF'
{
  "compilerOptions": {
    "target":                          "ES2022",
    "module":                          "commonjs",
    "lib":                             ["ES2022"],
    "outDir":                          "./dist",
    "rootDir":                         "./src",
    "strict":                          true,
    "esModuleInterop":                 true,
    "skipLibCheck":                    true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule":               true
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist"]
}
TSCEOF

    cat > "$APP_DIR/src/index.ts" << 'TSEOF'
async function main(): Promise<void> {
    console.log("Hello from TypeScript!");
}

main().catch(console.error);
TSEOF

    echo "==> Running npm install..."
    cd "$APP_DIR" && npm install --silent
    cd "$ROOT"

    bash "$ROOT/scripts/gen-vscode.sh" --workspace-only

    echo ""
    echo "v  TypeScript app '$APP' created."
    echo "   cd $APP && npm run dev    -- run directly with ts-node"
    echo "   cd $APP && npm run build  -- compile to dist/"
    echo "   cd $APP && npm start      -- run compiled output"
    ;;

*)
    echo "ERROR: Unknown type '$TYPE'. Choose: c, shared, or ts"
    exit 1
    ;;
esac
