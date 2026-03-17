#!/usr/bin/env bash
# add-board.sh -- register a new board template
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/scripts/prompt.sh"

BOARD="${1:-}"
MCU_FAMILY="${2:-}"
ARCH="${3:-}"
FPU="${4:-}"
FLOAT_ABI="${5:-}"
FLASH_BASE="${6:-}"
OPENOCD_TARGET="${7:-}"
OPENOCD_BOARD="${8:-}"
JLINK_DEVICE="${9:-}"

if [ -z "$BOARD" ] || [ -z "$MCU_FAMILY" ] || [ -z "$ARCH" ] || \
   [ -z "$FLASH_BASE" ]; then
    echo ""
    echo "==> Add new board"
    echo "-----------------"
    echo "  Common STM32 families: stm32/f0 f1 f2 f3 f4 f7 g0 g4 h7 l0 l1 l4"
    echo "  Common ARCHs: cortex-m0 cortex-m0plus cortex-m3 cortex-m4 cortex-m7"
    echo ""

    ask_required BOARD      "Board name (e.g. nucleo_h743zi)"
    ask_required MCU_FAMILY "MCU family (e.g. stm32/h7)"
    ask_required ARCH       "CPU architecture (e.g. cortex-m7)"
    ask_optional FPU        "FPU (e.g. fpv5-d16, leave blank if none)"
    if [ -n "$FPU" ]; then
        ask_required FLOAT_ABI "Float ABI (hard or soft)"
    else
        FLOAT_ABI=""
    fi
    ask_required FLASH_BASE "Flash base address (e.g. 0x08000000)"

    echo ""
    echo "  Flash tool selection:"
    FLASH_CHOICE=""
    ask_choice FLASH_CHOICE "Which flash tool(s) will you use?" \
        "openocd  - OpenOCD only (ST-Link / CMSIS-DAP)" \
        "jlink    - J-Link only" \
        "both     - Both OpenOCD and J-Link"
    FLASH_CHOICE="$(echo "$FLASH_CHOICE" | awk '{print $1}')"

    case "$FLASH_CHOICE" in
        openocd|both)
            ask_required OPENOCD_TARGET "OpenOCD target (e.g. stm32h7x)"
            ask_required OPENOCD_BOARD  "OpenOCD board config (e.g. st_nucleo_h7.cfg)"
            ;;
        *)
            OPENOCD_TARGET=""
            OPENOCD_BOARD=""
            ;;
    esac

    case "$FLASH_CHOICE" in
        jlink|both)
            ask_required JLINK_DEVICE "J-Link device name (e.g. STM32H743ZI)"
            ;;
        *)
            JLINK_DEVICE=""
            ;;
    esac
    echo ""
fi

# -- Validate ------------------------------------------------------------------
if [ -d "$ROOT/boards/$BOARD" ]; then
    echo "ERROR: board '$BOARD' already exists."
    exit 1
fi
if [ -n "$FPU" ] && [ -z "$FLOAT_ABI" ]; then
    echo "ERROR: FPU is set but FLOAT_ABI is missing."
    exit 1
fi
if [ -z "$OPENOCD_TARGET" ] && [ -z "$JLINK_DEVICE" ]; then
    echo "ERROR: At least one flash tool (OpenOCD or J-Link) must be configured."
    exit 1
fi

BOARD_DIR="$ROOT/boards/$BOARD"
mkdir -p "$BOARD_DIR"

# Derive family leaf name: stm32/h7 -> stm32h7
FAMILY_LEAF="$(echo "$MCU_FAMILY" | tr -d '/')"

# -- board.mk ------------------------------------------------------------------
{
cat << MKEOF
###############################################################################
# Board: $BOARD
#
# SVD file for Cortex-Debug live watch (enables register view in VSCode):
#   1. Browse to: https://github.com/cmsis-svd/cmsis-svd/tree/main/data/STMicro/
#   2. Download the .svd file matching your MCU
#   3. Place it at: boards/$BOARD/<filename>.svd
#   4. Update SVD_FILE below with the filename
###############################################################################

MCU_FAMILY     := $MCU_FAMILY

FLASH_BASE     := $FLASH_BASE

ARCH           := $ARCH
MKEOF

if [ -n "$FPU" ]; then
cat << MKEOF
FPU            := $FPU
FLOAT_ABI      := $FLOAT_ABI

ARCH_FLAGS     := -mcpu=\$(ARCH) -mthumb -mfpu=\$(FPU) -mfloat-abi=\$(FLOAT_ABI)
MKEOF
else
cat << MKEOF

ARCH_FLAGS     := -mcpu=\$(ARCH) -mthumb
MKEOF
fi

if [ -n "$OPENOCD_TARGET" ]; then
cat << MKEOF

OPENOCD_TARGET := $OPENOCD_TARGET
OPENOCD_BOARD  := $OPENOCD_BOARD
MKEOF
fi

if [ -n "$JLINK_DEVICE" ]; then
cat << MKEOF
JLINK_DEVICE   := $JLINK_DEVICE
MKEOF
fi

# Set default tool
if [ -n "$OPENOCD_TARGET" ]; then
    DEFAULT="openocd"
else
    DEFAULT="jlink"
fi

TOOL_OPTS="openocd"
[ -n "$OPENOCD_TARGET" ] && [ -n "$JLINK_DEVICE" ] && TOOL_OPTS="openocd | jlink"
[ -z "$OPENOCD_TARGET" ] && TOOL_OPTS="jlink"

cat << MKEOF

# Default flash tool when TOOL= not specified at make flash time
# Options: $TOOL_OPTS
DEFAULT_TOOL   := $DEFAULT

# SVD file for Cortex-Debug live watch (register view while debugging).
# Place the .svd file beside this board.mk, then update the filename below.
# Download from: https://www.st.com (CAD Resources tab) or ST SVD pack.
SVD_FILE       :=
MKEOF
} > "$BOARD_DIR/board.mk"

# -- linker.ld -----------------------------------------------------------------
cat > "$BOARD_DIR/linker.ld" << LDEOF
/*
 * Linker script -- $BOARD
 *
 * TODO: Set correct Flash and RAM sizes below.
 *       Current values are placeholder defaults.
 */
MEMORY
{
    rom (rx)  : ORIGIN = $FLASH_BASE, LENGTH = 512K
    ram (rwx) : ORIGIN = 0x20000000, LENGTH = 128K
}

INCLUDE cortex-m-generic.ld
LDEOF

echo ""
echo "v  Board '$BOARD' created at boards/$BOARD/"
echo ""
echo "ACTION REQUIRED:"
echo "  1. Edit boards/$BOARD/linker.ld -- set correct Flash and RAM sizes"
echo "  2. Download SVD file from:"
echo "     https://github.com/cmsis-svd/cmsis-svd/tree/main/data/STMicro/"
echo "     Place it at boards/$BOARD/<filename>.svd and update SVD_FILE in board.mk"
