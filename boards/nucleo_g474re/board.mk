###############################################################################
# Board: nucleo_g474re

MCU_FAMILY     := stm32/g4

FLASH_BASE     := 0x08000000

ARCH           := cortex-m4
FPU            := fpv4-sp-d16
FLOAT_ABI      := hard

ARCH_FLAGS     := -mcpu=$(ARCH) -mthumb -mfpu=$(FPU) -mfloat-abi=$(FLOAT_ABI)

OPENOCD_TARGET := stm32g4x
OPENOCD_BOARD  := st_nucleo_g4.cfg
JLINK_DEVICE   := STM32G474RE

# Default flash tool when TOOL= not specified at make flash time
# Options: openocd | jlink
DEFAULT_TOOL   := openocd

# SVD file for Cortex-Debug live watch (register view while debugging).
# File lives beside this board.mk. Download instructions in docs/04-boards.md.
SVD_FILE       := $(dir $(lastword $(MAKEFILE_LIST)))STM32G474.svd