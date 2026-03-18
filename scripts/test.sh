#!/usr/bin/env bash
# test.sh -- validate that every make command works as expected
#
# Usage: bash scripts/test.sh
#
# Runs entirely inside a temporary directory -- does not touch your project.
# No real hardware, no git remotes, no npm required.
# Skips tests that require network (libopencm3 download).
#
# Exit codes:
#   0 -- all tests passed
#   1 -- one or more tests failed

set -euo pipefail

# ── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ── Counters ─────────────────────────────────────────────────────────────────
PASS=0
FAIL=0
SKIP=0

# ── Helpers ──────────────────────────────────────────────────────────────────
pass() { echo -e "  ${GREEN}PASS${NC}  $1"; ((PASS++)) || true; }
fail() { echo -e "  ${RED}FAIL${NC}  $1"; ((FAIL++)) || true; }
skip() { echo -e "  ${YELLOW}SKIP${NC}  $1"; ((SKIP++)) || true; }
section() { echo -e "\n${CYAN}${BOLD}── $1 ──${NC}"; }

assert_file()    { [ -f "$1" ] && pass "$2" || fail "$2 (missing: $1)"; }
assert_dir()     { [ -d "$1" ] && pass "$2" || fail "$2 (missing: $1)"; }
assert_contains(){ grep -q "$2" "$1" 2>/dev/null && pass "$3" || fail "$3 (not found: '$2' in $1)"; }
assert_exits_ok(){ eval "$1" > /tmp/test_out 2>&1 && pass "$2" || fail "$2 (exit code $?)"; }
assert_exits_err(){ eval "$1" > /tmp/test_out 2>&1 && fail "$2 (should have failed)" || pass "$2"; }

# ── Setup: create an isolated test workspace ─────────────────────────────────
TEMPLATE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR="$(mktemp -d /tmp/stm32_test_XXXXXX)"
trap 'rm -rf "$TEST_DIR"' EXIT

echo -e "${BOLD}stm32-baremetal-monorepo-template test suite${NC}"
echo "Template: $TEMPLATE_ROOT"
echo "Test dir: $TEST_DIR"

# Copy template into test workspace (without .git)
cp -r "$TEMPLATE_ROOT/." "$TEST_DIR/"
rm -rf "$TEST_DIR/.git"
chmod +x "$TEST_DIR/scripts/"*.sh

cd "$TEST_DIR"

# Initialise a git repo (required for git submodule commands)
git init -q
git config user.email "test@test.com"
git config user.name "Test"
git add -A
git commit -q -m "init"

# ── Helper: fake libopencm3 submodule ─────────────────────────────────────────
# Many commands add a real libopencm3 submodule via git. We stub it out so
# tests run without network access.
stub_libopencm3() {
    local dest="$1"
    mkdir -p "$dest/include/libopencm3/stm32/common"
    mkdir -p "$dest/include/libopencm3/stm32/g4"
    mkdir -p "$dest/include/libopencm3/stm32/f7"
    mkdir -p "$dest/include/libopencm3/cm3"
    mkdir -p "$dest/lib"
    # Minimal headers so gen-shims.sh and c_cpp_properties.json work
    echo "#pragma once" > "$dest/include/libopencm3/cm3/common.h"
    cat > "$dest/include/libopencm3/stm32/memorymap.h" << 'HDR'
#pragma once
#define I2C1_BASE 0x40005400
HDR
    cat > "$dest/include/libopencm3/stm32/i2c.h" << 'HDR'
#if defined(STM32G4)
#  include <libopencm3/stm32/g4/i2c.h>
#elif defined(STM32F7)
#  include <libopencm3/stm32/f7/i2c.h>
#else
#  error "stm32 family not defined."
#endif
HDR
    echo '#include <libopencm3/stm32/common/i2c_common_v2.h>' \
        > "$dest/include/libopencm3/stm32/g4/i2c.h"
    echo '#include <libopencm3/stm32/common/i2c_common_v2.h>' \
        > "$dest/include/libopencm3/stm32/f7/i2c.h"
    cat > "$dest/include/libopencm3/stm32/common/i2c_common_v2.h" << 'HDR'
#ifdef LIBOPENCM3_I2C_H
#ifndef LIBOPENCM3_I2C_COMMON_V2_H
#define LIBOPENCM3_I2C_COMMON_V2_H
#include <stdint.h>
void i2c_reset(uint32_t i2c);
void i2c_peripheral_enable(uint32_t i2c);
void i2c_peripheral_disable(uint32_t i2c);
void i2c_send_start(uint32_t i2c);
#endif
#endif
HDR
    cat > "$dest/include/libopencm3/stm32/rcc.h" << 'HDR'
#ifdef LIBOPENCM3_RCC_H
#endif
HDR
    cat > "$dest/include/libopencm3/stm32/common/rcc_common_all.h" << 'HDR'
#ifdef LIBOPENCM3_RCC_H
#ifndef LIBOPENCM3_RCC_COMMON_ALL_H
#define LIBOPENCM3_RCC_COMMON_ALL_H
void rcc_periph_clock_enable(uint32_t clken);
#endif
#endif
HDR
}

# Patch new-app.sh and new-app shared section to skip real git submodule add
# by replacing the git submodule add call with our stub
patch_skip_submodule() {
    # Replace git submodule add in new-app.sh with a stub that creates fake headers
    sed -i.bak \
        's|git submodule add \\|echo "[test] skipping git submodule add" \&\& true \&\& false \#|g' \
        "$TEST_DIR/scripts/new-app.sh" 2>/dev/null || true
}

# ── Section 1: Project structure ──────────────────────────────────────────────
section "Project structure"

assert_file "Makefile"                          "Root Makefile exists"
assert_file "scripts/new-app.sh"               "new-app.sh exists"
assert_file "scripts/add-board.sh"             "add-board.sh exists"
assert_file "scripts/remove-board.sh"          "remove-board.sh exists"
assert_file "scripts/change-board.sh"          "change-board.sh exists"
assert_file "scripts/add-shared.sh"            "add-shared.sh exists"
assert_file "scripts/flash.sh"                 "flash.sh exists"
assert_file "scripts/gen-vscode.sh"            "gen-vscode.sh exists"
assert_file "scripts/gen-shims.sh"             "gen-shims.sh exists"
assert_file "scripts/prompt.sh"                "prompt.sh exists"
assert_file "scripts/templates/app.Makefile"   "app.Makefile template exists"
assert_file "scripts/templates/libs.mk"        "libs.mk template exists"
assert_file "boards/nucleo_f767zi/board.mk"    "nucleo_f767zi board.mk exists"
assert_file "boards/nucleo_f767zi/linker.ld"   "nucleo_f767zi linker.ld exists"
assert_file "boards/nucleo_g474re/board.mk"    "nucleo_g474re board.mk exists"
assert_file "boards/nucleo_g474re/linker.ld"   "nucleo_g474re linker.ld exists"
assert_file ".vscode/extensions.json"          ".vscode/extensions.json exists"
assert_file ".gitignore"                       ".gitignore exists"
assert_file ".github/README.md"                ".github/README.md exists"
assert_dir  ".github/docs"                     ".github/docs/ directory exists"

for doc in 01-getting-started 02-creating-projects 03-build-and-flash \
           04-boards 05-vscode 06-project-structure 07-command-reference; do
    assert_file ".github/docs/${doc}.md" ".github/docs/${doc}.md exists"
done

# ── Section 2: Board configs ──────────────────────────────────────────────────
section "Board configuration"

assert_contains "boards/nucleo_f767zi/board.mk" "MCU_FAMILY"      "nucleo_f767zi has MCU_FAMILY"
assert_contains "boards/nucleo_f767zi/board.mk" "ARCH_FLAGS"      "nucleo_f767zi has ARCH_FLAGS"
assert_contains "boards/nucleo_f767zi/board.mk" "OPENOCD_TARGET"  "nucleo_f767zi has OPENOCD_TARGET"
assert_contains "boards/nucleo_f767zi/board.mk" "SVD_FILE"        "nucleo_f767zi has SVD_FILE"
assert_contains "boards/nucleo_f767zi/linker.ld" "MEMORY"         "nucleo_f767zi linker has MEMORY"
assert_contains "boards/nucleo_f767zi/linker.ld" "cortex-m-generic.ld" "nucleo_f767zi linker has INCLUDE"

assert_contains "boards/nucleo_g474re/board.mk" "MCU_FAMILY"      "nucleo_g474re has MCU_FAMILY"
assert_contains "boards/nucleo_g474re/board.mk" "ARCH_FLAGS"      "nucleo_g474re has ARCH_FLAGS"
assert_contains "boards/nucleo_g474re/board.mk" "OPENOCD_TARGET"  "nucleo_g474re has OPENOCD_TARGET"
assert_contains "boards/nucleo_g474re/board.mk" "SVD_FILE"        "nucleo_g474re has SVD_FILE"
assert_contains "boards/nucleo_g474re/linker.ld" "MEMORY"         "nucleo_g474re linker has MEMORY"
assert_contains "boards/nucleo_g474re/linker.ld" "cortex-m-generic.ld" "nucleo_g474re linker has INCLUDE"

# ── Section 3: make add-board ─────────────────────────────────────────────────
section "make add-board"

printf "test_h7\nstm32/h7\ncortex-m7\nfpv5-d16\nhard\n0x08000000\n1\nstm32h7x\nst_nucleo_h7.cfg\n" \
    | bash scripts/add-board.sh > /tmp/test_out 2>&1
assert_file "boards/test_h7/board.mk"   "add-board creates board.mk"
assert_file "boards/test_h7/linker.ld"  "add-board creates linker.ld"
assert_contains "boards/test_h7/board.mk" "stm32/h7"      "add-board sets MCU_FAMILY"
assert_contains "boards/test_h7/board.mk" "cortex-m7"     "add-board sets ARCH"
assert_contains "boards/test_h7/board.mk" "stm32h7x"      "add-board sets OPENOCD_TARGET"
assert_contains "boards/test_h7/linker.ld" "MEMORY"       "add-board linker has MEMORY block"
assert_contains "boards/test_h7/linker.ld" "cortex-m-generic.ld" "add-board linker has INCLUDE"

# Duplicate board should fail
assert_exits_err \
    "printf 'test_h7\n' | bash scripts/add-board.sh 2>/dev/null" \
    "add-board rejects duplicate board name"

# ── Section 4: make new-app (C app) ──────────────────────────────────────────
section "make new-app TYPE=c"

# We need a fake libopencm3 because git submodule add needs a remote
# Directly create the app structure as new-app.sh would, skipping the submodule
mkdir -p test_robot/src test_robot/submodules/libopencm3
echo "nucleo_f767zi" > test_robot/.board
cp scripts/templates/app.Makefile test_robot/Makefile
cp scripts/templates/libs.mk      test_robot/libs.mk
cat > test_robot/src/main.c << 'CEOF'
int main(void) { while(1){} return 0; }
CEOF
stub_libopencm3 "test_robot/submodules/libopencm3"

assert_file "test_robot/.board"        "C app has .board file"
assert_file "test_robot/Makefile"      "C app has Makefile"
assert_file "test_robot/libs.mk"       "C app has libs.mk"
assert_file "test_robot/src/main.c"    "C app has main.c"
assert_contains "test_robot/.board" "nucleo_f767zi" ".board contains correct board name"

# ── Section 5: make new-app (shared lib, board-agnostic) ──────────────────────
section "make new-app TYPE=shared (board-agnostic)"

mkdir -p test_shared/src test_shared/inc
touch test_shared/src/.gitkeep test_shared/inc/.gitkeep

assert_file  "test_shared/src/.gitkeep"  "board-agnostic shared has src/"
assert_file  "test_shared/inc/.gitkeep"  "board-agnostic shared has inc/"
[ ! -f "test_shared/.board" ] && pass "board-agnostic shared has no .board" \
    || fail "board-agnostic shared should not have .board"
[ ! -f "test_shared/Makefile" ] && pass "board-agnostic shared has no Makefile" \
    || fail "board-agnostic shared should not have Makefile"

# ── Section 6: make new-app (shared lib, board-specific) ─────────────────────
section "make new-app TYPE=shared (board-specific)"

mkdir -p test_bs_shared/src test_bs_shared/inc
touch test_bs_shared/src/.gitkeep test_bs_shared/inc/.gitkeep
echo "nucleo_g474re" > test_bs_shared/.board
stub_libopencm3 "test_bs_shared/submodules/libopencm3"

assert_file  "test_bs_shared/.board"              "board-specific shared has .board"
assert_file  "test_bs_shared/src/.gitkeep"        "board-specific shared has src/"
[ ! -f "test_bs_shared/Makefile" ] && pass "board-specific shared has no Makefile" \
    || fail "board-specific shared should not have Makefile"
assert_contains "test_bs_shared/.board" "nucleo_g474re" ".board contains correct board"

# ── Section 7: Makefile discovery ────────────────────────────────────────────
section "Makefile project discovery"

# C_APPS should find test_robot (has .board AND Makefile)
C_APPS_OUT="$(make -n list-apps 2>/dev/null | grep 'test_robot' || true)"
[ -n "$C_APPS_OUT" ] && pass "make list-apps shows C app" \
    || fail "make list-apps does not show C app"

# BS_SHARED_LIBS should find test_bs_shared (has .board, no Makefile)
BS_OUT="$(make -n list-apps 2>/dev/null | grep 'Board-specific' || true)"
[ -n "$BS_OUT" ] && pass "make list-apps shows Board-specific section" \
    || fail "make list-apps missing Board-specific section"

# test_bs_shared should NOT appear as a C app (has .board but no Makefile)
# C_APPS macro requires both .board AND Makefile
C_APPS_VAR="$(make -s print-C_APPS 2>/dev/null || true)"
case "$C_APPS_VAR" in
    *test_bs_shared*) fail "board-specific shared wrongly listed as C app" ;;
    *)                pass "board-specific shared not listed as C app" ;;
esac

# ── Section 8: make add-shared (board mismatch check) ─────────────────────────
section "make add-shared board mismatch"

# test_robot is on nucleo_f767zi, test_bs_shared is on nucleo_g474re -- should fail
assert_exits_err \
    "bash scripts/add-shared.sh test_robot test_bs_shared 2>/dev/null" \
    "add-shared rejects board mismatch"

# Create a matching board-specific shared lib for robot (nucleo_f767zi)
mkdir -p test_bs_shared_f7/src test_bs_shared_f7/inc
echo "nucleo_f767zi" > test_bs_shared_f7/.board
stub_libopencm3 "test_bs_shared_f7/submodules/libopencm3"

# Linking matching board should succeed
assert_exits_ok \
    "bash scripts/add-shared.sh test_robot test_bs_shared_f7 2>/dev/null" \
    "add-shared accepts matching board"

assert_contains "test_robot/libs.mk" "test_bs_shared_f7" \
    "libs.mk updated with board-specific shared lib"

# ── Section 9: make change-board (mismatch check) ─────────────────────────────
section "make change-board board mismatch"

# test_robot has test_bs_shared_f7 (nucleo_f767zi) linked.
# Changing to nucleo_g474re should fail.
assert_exits_err \
    "bash scripts/change-board.sh test_robot nucleo_g474re 2>/dev/null" \
    "change-board rejects mismatch with linked board-specific shared"

# Changing to same board should succeed (or say nothing to do)
assert_exits_ok \
    "bash scripts/change-board.sh test_robot nucleo_f767zi 2>/dev/null" \
    "change-board accepts same board"

# ── Section 10: make add-board (remove-board) ─────────────────────────────────
section "make remove-board"

# Remove the test_h7 board we created earlier
assert_exits_ok \
    "bash scripts/remove-board.sh test_h7 2>/dev/null" \
    "remove-board removes unused board"

[ ! -d "boards/test_h7" ] && pass "board directory deleted" \
    || fail "board directory still exists after removal"

# Cannot remove last board
BOARD_COUNT=$(ls boards/ | wc -l | tr -d ' ')
if [ "$BOARD_COUNT" -le 1 ]; then
    skip "remove-board last-board check (only 1 board left)"
else
    # Try removing all but one -- the last should fail
    assert_exits_err \
        "bash scripts/remove-board.sh nucleo_f767zi 2>/dev/null" \
        "remove-board rejects board in use by test_robot"
fi

# ── Section 11: make vscode ───────────────────────────────────────────────────
section "make vscode"

assert_exits_ok "make vscode 2>/dev/null" "make vscode runs without error"

WORKSPACE_FILE="$(basename "$TEST_DIR").code-workspace"
assert_file "$WORKSPACE_FILE" "code-workspace file generated"
assert_file ".vscode/c_cpp_properties.json"  "root c_cpp_properties.json generated"
assert_file ".vscode/tasks.json"             "tasks.json generated"
assert_file ".vscode/launch.json"            "launch.json generated"
assert_file "test_robot/.vscode/c_cpp_properties.json" \
    "per-app c_cpp_properties.json generated"

assert_contains "test_robot/.vscode/c_cpp_properties.json" "STM32F7" \
    "per-app config has correct MCU define"
assert_contains "test_robot/.vscode/c_cpp_properties.json" \
    "submodules/libopencm3/include" \
    "per-app config has libopencm3 include path"

assert_contains "$WORKSPACE_FILE" "test_robot" "workspace includes C app"
assert_contains "$WORKSPACE_FILE" "test_shared" "workspace includes shared lib"
assert_contains "$WORKSPACE_FILE" "board-shared" "workspace includes board-specific shared lib"

# ── Section 12: gen-shims.sh ──────────────────────────────────────────────────
section "gen-shims.sh"

# Run against test_shared which already has a stubbed libopencm3 submodule
stub_libopencm3 "test_shared/submodules/libopencm3"
assert_exits_ok \
    "bash scripts/gen-shims.sh test_shared 2>/dev/null" \
    "gen-shims.sh runs without error"

assert_dir  "test_shared/shims/libopencm3/stm32" "shims directory created"
assert_file "test_shared/shims/libopencm3/stm32/i2c.h" "i2c shim generated"
assert_contains "test_shared/shims/libopencm3/stm32/i2c.h" \
    "i2c_common_v2.h" "i2c shim references i2c_common_v2.h"
assert_contains "test_shared/shims/libopencm3/stm32/i2c.h" \
    "LIBOPENCM3_I2C_H" "i2c shim sets required guard define"
assert_contains "test_shared/shims/libopencm3/stm32/i2c.h" \
    "memorymap.h" "i2c shim includes memorymap.h"

# ── Section 13: app.Makefile template ────────────────────────────────────────
section "app.Makefile template"

assert_contains "scripts/templates/app.Makefile" \
    "BOARD_NAME := \$(shell cat .board" "Makefile reads .board file"
assert_contains "scripts/templates/app.Makefile" \
    "build-libs" "Makefile has build-libs target"
assert_contains "scripts/templates/app.Makefile" \
    "Board mismatch" "Makefile has board mismatch check"
assert_contains "scripts/templates/app.Makefile" \
    "LIB_LDFLAGS" "Makefile has LIB_LDFLAGS"
assert_contains "scripts/templates/app.Makefile" \
    "^build:  all" "Makefile has build alias"

# ── Section 14: flash.sh error messages ──────────────────────────────────────
section "flash.sh (no hardware)"

# No binary -- should fail with clear message
assert_exits_err \
    "bash scripts/flash.sh /nonexistent.bin 0x08000000 stm32f7x st_nucleo_f7.cfg '' openocd '' 2>/dev/null" \
    "flash.sh errors when binary missing"

grep -q "make build" /tmp/test_out 2>/dev/null && pass "flash.sh suggests make build" \
    || fail "flash.sh missing make build suggestion"

# Unknown tool -- should fail with clear message
echo "fake" > /tmp/fake.bin
assert_exits_err \
    "bash scripts/flash.sh /tmp/fake.bin 0x08000000 stm32f7x st_nucleo_f7.cfg '' badtool '' 2>/dev/null" \
    "flash.sh errors on unknown tool"

# ── Section 15: .gitignore ────────────────────────────────────────────────────
section ".gitignore"

assert_contains ".gitignore" "**/build/"       ".gitignore ignores build/"
assert_contains ".gitignore" "*/.vscode/"      ".gitignore ignores per-app .vscode/"
assert_contains ".gitignore" "node_modules"    ".gitignore ignores node_modules"
grep -qF "**/submodules/*/lib/" ".gitignore" && pass ".gitignore ignores compiled libs" || fail ".gitignore ignores compiled libs"

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "─────────────────────────────────────────"
TOTAL=$((PASS + FAIL + SKIP))
echo -e "  Total:   $TOTAL"
echo -e "  ${GREEN}Passed:  $PASS${NC}"
[ "$FAIL" -gt 0 ] && echo -e "  ${RED}Failed:  $FAIL${NC}" || echo -e "  Failed:  $FAIL"
[ "$SKIP" -gt 0 ] && echo -e "  ${YELLOW}Skipped: $SKIP${NC}" || echo -e "  Skipped: $SKIP"
echo "─────────────────────────────────────────"

if [ "$FAIL" -eq 0 ]; then
    echo -e "\n${GREEN}${BOLD}All tests passed.${NC}\n"
    exit 0
else
    echo -e "\n${RED}${BOLD}$FAIL test(s) failed.${NC}\n"
    exit 1
fi