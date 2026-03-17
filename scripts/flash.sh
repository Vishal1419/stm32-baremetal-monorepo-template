#!/usr/bin/env bash
# flash.sh -- flash firmware via OpenOCD or J-Link
# Usage: flash.sh <BIN> <FLASH_BASE> <OPENOCD_TARGET> <OPENOCD_BOARD>
#                 <JLINK_DEVICE> <TOOL> <SERIAL>
set -euo pipefail

BIN_FILE="$1"
FLASH_BASE="$2"
OPENOCD_TARGET="$3"
OPENOCD_BOARD="$4"
JLINK_DEVICE="$5"
TOOL="${6:-openocd}"
SERIAL="${7:-}"

# -- Validate binary ----------------------------------------------------------
if [ ! -f "$BIN_FILE" ]; then
    echo ""
    echo "ERROR: Firmware binary not found: $BIN_FILE"
    echo "       Run 'make build' first."
    echo ""
    exit 1
fi

# -- Device detection ---------------------------------------------------------
detect_openocd_device() {
    # Run openocd briefly to check if a probe is connected
    # Returns 0 if probe found, 1 if not
    local args=(-f "interface/stlink.cfg" -f "target/$OPENOCD_TARGET.cfg")
    [ -n "$SERIAL" ] && args+=(-c "hla_serial $SERIAL")
    args+=(-c "init" -c "exit")

    local output
    output=$(openocd "${args[@]}" 2>&1) || true

    # Check for known "no device" patterns
    if echo "$output" | grep -qiE "open failed|no device|usb error|unable to open|hla_swd.*failed|error.*init"; then
        return 1
    fi
    return 0
}

detect_jlink_device() {
    # Use JLinkExe with a quick connect check
    local tmpscript
    tmpscript="$(mktemp /tmp/jlink_detect_XXXXXX.jlink)"
    trap 'rm -f "$tmpscript"' RETURN
    printf 'connect\nexit\n' > "$tmpscript"

    local args=(-nogui 1 -device "$JLINK_DEVICE" -if SWD -speed 4000 -commandfile "$tmpscript")
    [ -n "$SERIAL" ] && args+=(-selectemubysn "$SERIAL")

    local output
    output=$(JLinkExe "${args[@]}" 2>&1) || true

    if echo "$output" | grep -qiE "failed to open dll|cannot connect|no j-link|failed to connect|error while|usb.*error"; then
        return 1
    fi
    return 0
}

# -- Flash --------------------------------------------------------------------
case "$TOOL" in
    openocd)
        if [ -z "$OPENOCD_TARGET" ] || [ -z "$OPENOCD_BOARD" ]; then
            echo ""
            echo "ERROR: This board is not configured for OpenOCD."
            echo "       Run 'make add-board' and select OpenOCD or Both."
            echo ""
            exit 1
        fi

        echo "==> Checking for connected ST-Link / debug probe..."
        if ! detect_openocd_device; then
            echo ""
            echo "ERROR: No debug probe detected."
            echo ""
            echo "  Possible causes:"
            echo "    - Board is not connected via USB"
            echo "    - ST-Link cable is loose or faulty"
            echo "    - ST-Link driver is not installed"
            if [ -n "$SERIAL" ]; then
                echo "    - ST-Link with serial '$SERIAL' is not connected"
            fi
            echo ""
            echo "  To check connected probes:"
            echo "    openocd -f interface/stlink.cfg -c \"init\" -c \"exit\" 2>&1"
            echo ""
            exit 1
        fi

        ARGS=(-f "interface/stlink.cfg" -f "target/$OPENOCD_TARGET.cfg")
        [ -n "$SERIAL" ] && ARGS+=(-c "hla_serial $SERIAL")
        ARGS+=(-c "program $BIN_FILE verify reset exit $FLASH_BASE")

        echo "==> Flashing: $(basename "$BIN_FILE")"
        echo "    Target  : $OPENOCD_TARGET"
        [ -n "$SERIAL" ] && echo "    ST-Link : $SERIAL"
        openocd "${ARGS[@]}"
        echo ""
        echo "v  Flash successful."
        ;;

    jlink)
        if [ -z "$JLINK_DEVICE" ]; then
            echo ""
            echo "ERROR: This board is not configured for J-Link."
            echo "       Run 'make add-board' and select J-Link or Both."
            echo ""
            exit 1
        fi

        echo "==> Checking for connected J-Link probe..."
        if ! detect_jlink_device; then
            echo ""
            echo "ERROR: No J-Link probe detected."
            echo ""
            echo "  Possible causes:"
            echo "    - J-Link is not connected via USB"
            echo "    - J-Link software is not installed (download from segger.com)"
            echo "    - J-Link USB driver is not installed"
            if [ -n "$SERIAL" ]; then
                echo "    - J-Link with serial '$SERIAL' is not connected"
            fi
            echo ""
            echo "  To check connected J-Link probes:"
            echo "    JLinkExe -nogui 1 -commandfile /dev/null 2>&1 | grep -i serial"
            echo ""
            exit 1
        fi

        JSCRIPT="$(mktemp /tmp/jlink_flash_XXXXXX.jlink)"
        trap 'rm -f "$JSCRIPT"' EXIT
        cat > "$JSCRIPT" << JEOF
si SWD
speed 4000
device $JLINK_DEVICE
connect
loadbin $BIN_FILE,$FLASH_BASE
r
g
exit
JEOF
        JLINK_ARGS=(-nogui 1 -commandfile "$JSCRIPT")
        [ -n "$SERIAL" ] && JLINK_ARGS+=(-selectemubysn "$SERIAL")

        echo "==> Flashing: $(basename "$BIN_FILE")"
        echo "    Device  : $JLINK_DEVICE"
        [ -n "$SERIAL" ] && echo "    J-Link  : $SERIAL"
        JLinkExe "${JLINK_ARGS[@]}"
        echo ""
        echo "v  Flash successful."
        ;;

    *)
        echo ""
        echo "ERROR: Unknown flash tool '$TOOL'."
        echo "       Use TOOL=openocd or TOOL=jlink"
        echo ""
        exit 1
        ;;
esac
