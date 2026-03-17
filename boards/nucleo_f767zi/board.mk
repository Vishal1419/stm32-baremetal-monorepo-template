###############################################################################
# Board: nucleo_f767zi -- STM32F767ZI
###############################################################################

MCU_FAMILY     := stm32/f7

FLASH_BASE     := 0x08000000
FLASH_SIZE     := 2048K
RAM_SIZE       := 512K

ARCH           := cortex-m7
FPU            := fpv5-d16
FLOAT_ABI      := hard

ARCH_FLAGS     := -mcpu=$(ARCH) -mthumb -mfpu=$(FPU) -mfloat-abi=$(FLOAT_ABI)

OPENOCD_TARGET := stm32f7x
OPENOCD_BOARD  := st_nucleo_f7.cfg
JLINK_DEVICE   := STM32F767ZI

# Default flash tool when TOOL= not specified at make flash time
# Options: openocd | jlink
DEFAULT_TOOL   := openocd

# SVD file for Cortex-Debug live watch (register view while debugging).
# File lives beside this board.mk. Download instructions in docs/04-boards.md.
SVD_FILE       := $(dir $(lastword $(MAKEFILE_LIST)))STM32F767.svd
