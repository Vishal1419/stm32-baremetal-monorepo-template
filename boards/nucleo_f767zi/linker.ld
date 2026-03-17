/*
 * Linker script -- STM32F767ZI
 * Flash: 2MB  @ 0x08000000
 * RAM:   512KB @ 0x20000000
 */
MEMORY
{
    rom (rx)  : ORIGIN = 0x08000000, LENGTH = 2048K
    ram (rwx) : ORIGIN = 0x20000000, LENGTH = 512K
}

INCLUDE cortex-m-generic.ld
