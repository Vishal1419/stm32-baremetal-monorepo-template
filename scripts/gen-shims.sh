#!/usr/bin/env bash
# gen-shims.sh -- generate libopencm3 shim headers for a shared library
#
# Usage: gen-shims.sh <shared-lib-root>
#
# Creates shims/libopencm3/stm32/<peripheral>.h files that allow shared code
# to write #include <libopencm3/stm32/i2c.h> without an MCU family define.
#
# App builds never see the shims folder -- they use their own libopencm3
# submodule with the correct MCU define.
#
# To add a new peripheral: add an entry to the SHIMS array below.
# To upgrade a version (e.g. i2c_common_v3): change the common_header value.

set -euo pipefail

SHARED_ROOT="${1:-}"
if [ -z "$SHARED_ROOT" ]; then
    echo "Usage: gen-shims.sh <shared-lib-root>"
    exit 1
fi

SHIMS_DIR="$SHARED_ROOT/shims"

# Each entry: "peripheral|guard_define|common_header"
# guard_define: the #ifdef guard inside the common header (empty if none needed)
# common_header: the versioned common file to include as fallback
SHIMS=(
    "i2c|LIBOPENCM3_I2C_H|libopencm3/stm32/common/i2c_common_v2.h"
    "spi|LIBOPENCM3_SPI_H|libopencm3/stm32/common/spi_common_v2.h"
    "rcc|LIBOPENCM3_RCC_H|libopencm3/stm32/common/rcc_common_all.h"
    "usart||libopencm3/stm32/common/usart_common_v2.h"
    "gpio||libopencm3/stm32/common/gpio_common_all.h"
    "timer||libopencm3/stm32/common/timer_common_all.h"
)

mkdir -p "$SHIMS_DIR/libopencm3/stm32"

for entry in "${SHIMS[@]}"; do
    peripheral="$(echo "$entry" | cut -d'|' -f1)"
    guard="$(echo "$entry"      | cut -d'|' -f2)"
    common="$(echo "$entry"     | cut -d'|' -f3)"

    out="$SHIMS_DIR/libopencm3/stm32/${peripheral}.h"

    {
        echo "#pragma once"
        echo ""
        echo "/*"
        echo " * Shim for libopencm3/stm32/${peripheral}.h"
        echo " *"
        echo " * Allows shared code to write:"
        echo " *   #include <libopencm3/stm32/${peripheral}.h>"
        echo " * without needing an MCU family define."
        echo " *"
        echo " * When compiled inside an app (MCU define present), this file is"
        echo " * never found -- the app's own libopencm3 dispatch header is used."
        echo " *"
        echo " * To upgrade version: change the common header include below."
        echo " */"
        echo ""
        echo "#include <libopencm3/stm32/memorymap.h>"
        echo "#include <libopencm3/cm3/common.h>"
        if [ -n "$guard" ]; then
            echo "#define ${guard}"
        fi
        echo "#include <${common}>"
    } > "$out"

    echo "  created: shims/libopencm3/stm32/${peripheral}.h -> ${common}"
done

echo ""
echo "v  Shims written to: $SHIMS_DIR"