# Managing Boards

A board in this workspace is a named set of configuration — MCU family, CPU architecture,
flash address, FPU settings, and flash tool configuration. Board definitions live in
`boards/` and are the single source of truth for every app that targets that board.

Apps do not copy board configuration. They point to it. If you update a board definition,
every app using that board picks up the change on the next build.

---

## Boards included in this template

Two boards ship with the template:

| Board | MCU | Core | Flash | RAM | SVD |
|-------|-----|------|-------|-----|-----|
| `nucleo_f767zi` | STM32F767ZI | Cortex-M7 | 2MB | 512KB | needs download |
| `nucleo_g474re` | STM32G474RE | Cortex-M4 | 512KB | 128KB | needs download |

SVD files are included for both boards. See [SVD files](#svd-files-for-live-debugging)
for what they do.

**Note:** The `board.mk` for both boards is already configured to reference
`STM32F767.svd` and `STM32G474.svd` respectively. You just need to download
and place the files — no editing of `board.mk` is needed.

---

## Adding a new board

```bash
make add-board
```

The command walks you through every field interactively. Here is what each field means:

**Board name** — a short identifier you will use everywhere, like `nucleo_h743zi`.
Use lowercase with underscores. This becomes the folder name under `boards/`.

**MCU family** — the libopencm3 family string. Common values:

| MCU series | MCU family value |
|------------|-----------------|
| STM32F0 | `stm32/f0` |
| STM32F1 | `stm32/f1` |
| STM32F4 | `stm32/f4` |
| STM32F7 | `stm32/f7` |
| STM32G0 | `stm32/g0` |
| STM32G4 | `stm32/g4` |
| STM32H7 | `stm32/h7` |
| STM32L0 | `stm32/l0` |
| STM32L4 | `stm32/l4` |

**CPU architecture** — the `-mcpu` value:

| Core | Architecture value |
|------|--------------------|
| Cortex-M0 | `cortex-m0` |
| Cortex-M0+ | `cortex-m0plus` |
| Cortex-M3 | `cortex-m3` |
| Cortex-M4 | `cortex-m4` |
| Cortex-M7 | `cortex-m7` |

**FPU** — leave blank for M0, M0+, M3. For M4 and M7:

| Core | FPU value | Float ABI |
|------|-----------|-----------|
| Cortex-M4 | `fpv4-sp-d16` | `hard` |
| Cortex-M7 (single precision) | `fpv5-sp-d16` | `hard` |
| Cortex-M7 (double precision) | `fpv5-d16` | `hard` |

**Flash base address** — `0x08000000` for virtually all STM32 chips.

**Flash tool** — choose OpenOCD, J-Link, or both.

For OpenOCD, you need:
- **OpenOCD target** — e.g. `stm32h7x`
- **OpenOCD board config** — e.g. `st_nucleo_h7.cfg`

Find these in your OpenOCD scripts directory:
```bash
# macOS / Linux
ls $(dirname $(which openocd))/../share/openocd/scripts/target/stm32*
ls $(dirname $(which openocd))/../share/openocd/scripts/board/st_nucleo*
```

For J-Link, you need the device name as J-Link knows it, e.g. `STM32H743ZI`.

---

## After adding a board — required steps

### 1. Set the correct Flash and RAM sizes

Open `boards/<boardname>/linker.ld` and replace the placeholder values:

```
MEMORY
{
    rom (rx)  : ORIGIN = 0x08000000, LENGTH = 512K   <- change this
    ram (rwx) : ORIGIN = 0x20000000, LENGTH = 128K   <- and this
}
```

The correct values are on the MCU's datasheet or product page. For example, STM32H743ZI:

```
MEMORY
{
    rom (rx)  : ORIGIN = 0x08000000, LENGTH = 2048K
    ram (rwx) : ORIGIN = 0x20000000, LENGTH = 1024K
}
```

### 2. Download and configure an SVD file

See [SVD files](#svd-files-for-live-debugging) below.

---

## SVD files for live debugging

An SVD file is an XML description of every peripheral register in the MCU. With it,
the VSCode debugger shows you the actual value of every register — GPIO ODR, TIM CNT,
USART SR — in real time while your code is running.

### Getting the SVD file for a new board

SVD files for each board are stored directly beside the `linker.ld` in the board
folder. When you add a new board, you need to find and place its SVD file.

The recommended source is `modm-io/cmsis-svd-stm32` on GitHub — it has clean,
well-maintained SVD files for every STM32 family, organised by folder:

```
https://github.com/modm-io/cmsis-svd-stm32/tree/main/stm32h7/
```

Browse to the folder for your MCU family, find the matching `.svd` file, download
it raw, and place it beside your board's `linker.ld`:

```bash
# Example for a new STM32H743ZI board:
curl -L "https://raw.githubusercontent.com/modm-io/cmsis-svd-stm32/main/stm32h7/STM32H743.svd" \
     -o boards/nucleo_h743zi/STM32H743.svd
```
### Linking it in board.mk

Open `boards/<boardname>/board.mk` and update `SVD_FILE` with the filename:

```makefile
# Change from:
SVD_FILE       :=

# To:
SVD_FILE       := $(dir $(lastword $(MAKEFILE_LIST)))STM32H743.svd
```

The `$(dir $(lastword $(MAKEFILE_LIST)))` part resolves to the board's own directory
at build time — so you just fill in the filename. Then run `make vscode`.

---

## Removing a board

```bash
make remove-board
```

You will see a numbered list of boards with their usage status. Boards assigned to an
app cannot be removed until those apps are reassigned with `make change-board`.

The last board cannot be removed. After removal, VSCode configs regenerate automatically.

---

## Changing which board an app targets

```bash
make change-board
```

Or directly:
```bash
make change-board APP=<appname> BOARD=<boardname>
```

This handles the full sequence: clean, update board pointer, regenerate VSCode configs,
rebuild.

---

## How board configuration works internally

Each board directory contains exactly two files:

**`board.mk`** — included by the app's Makefile. Defines compiler flags, flash config,
and the SVD file path.

**`linker.ld`** — defines the `MEMORY` block with Flash and RAM sizes, then includes
`cortex-m-generic.ld` from libopencm3 for the section layout.

An app's `.board` file contains just the board name — one line. The app Makefile reads
it, looks up `boards/<boardname>/board.mk`, and includes it. No copying, no duplication.
