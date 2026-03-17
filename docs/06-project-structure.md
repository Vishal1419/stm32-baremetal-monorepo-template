# Project Structure

Understanding how the workspace is organised helps you know where to look when something
is not working and where to put things when you are adding something new.

---

## The full picture

```
stm32-baremetal-monorepo-template/
│
├── Makefile                        ← the only file you run commands from
├── README.md
├── stm32-baremetal-monorepo-template.code-workspace  ← open this in VSCode
├── .gitignore
│
├── docs/                           ← documentation
│
├── boards/                         ← board definitions (single source of truth)
│   ├── nucleo_f767zi/
│   │   ├── board.mk                ← compiler flags, flash config, SVD path
│   │   ├── linker.ld               ← MEMORY block for this chip
│   │   └── STM32F767.svd           ← SVD file for live register debugging
│   └── nucleo_g474re/
│       ├── board.mk
│       ├── linker.ld
│       └── STM32G474.svd           ← SVD file for live register debugging
│
├── scripts/                        ← automation scripts (never run directly)
│   ├── new-app.sh
│   ├── add-board.sh
│   ├── remove-board.sh
│   ├── change-board.sh
│   ├── add-shared.sh
│   ├── flash.sh
│   ├── gen-vscode.sh
│   ├── prompt.sh
│   └── templates/
│       ├── app.Makefile            ← template copied into every new C app
│       └── libs.mk                 ← template copied into every new C app
│
├── .vscode/
│   └── extensions.json             ← committed; the rest is gitignored
│
├── <appname>/                      ← a C firmware app (created by make new-app)
│   ├── Makefile                    ← generated; never edit
│   ├── .board                      ← board pointer, do not change manually
│   ├── libs.mk                     ← library declarations
│   ├── src/
│   │   └── main.c                  ← your code lives here
│   ├── submodules/
│   │   └── libopencm3/             ← git submodule
│   └── build/                      ← gitignored; deleted by make clean
│
├── <sharedname>/                   ← a shared C library (created by make new-app)
│   ├── src/                        ← .c files and internal .h files
│   └── inc/                        ← headers with no corresponding .c file
│
└── <tsappname>/                    ← a TypeScript app (created by make new-app)
    ├── package.json
    ├── tsconfig.json
    └── src/
        └── index.ts
```

---

## The root Makefile

Everything runs from the root `Makefile`. You never `cd` into a folder to run make
(unless you specifically want to work within one app). The root Makefile discovers
what exists in the workspace automatically — it scans for `.board` files to find C
apps, `package.json` files to find TypeScript apps, and `src/` folders to find
shared libraries.

---

## How projects are identified

The root Makefile uses three simple rules:

| If a folder contains... | It is a... |
|------------------------|------------|
| A `.board` file | C firmware app |
| A `package.json` (and no `.board`) | TypeScript app |
| A `src/` directory (and no `.board`, no `package.json`) | Shared C library |

The `.board` file contains exactly one line — the board name, like `nucleo_f767zi`.
This is how the app points at its board configuration without copying it.
**Do not change this file manually** — use `make change-board` instead.

---

## The boards directory

`boards/` is the single source of truth for hardware configuration. Apps do not contain
board configuration — they reference it. If you need to update a compiler flag or flash
address, change it in `boards/<boardname>/board.mk` and every app targeting that board
picks it up automatically.

Each board directory contains:

**`board.mk`** — a Makefile fragment defining MCU family, compiler flags, flash config,
and SVD file path.

**`linker.ld`** — the linker script with the chip's Flash and RAM sizes, plus an
`INCLUDE cortex-m-generic.ld` that pulls in libopencm3's section layout.

**`*.svd`** — the register description file enabling live peripheral debugging
in VSCode. Stored beside `board.mk` and `linker.ld`. Included for both template
boards; add one when you create a new board (see [Managing Boards](04-boards.md)).

---

## The app's Makefile and libs.mk

Every C app has a `Makefile` that was generated once and should never be edited manually.
It contains the full build logic.

`libs.mk` is where library dependencies are declared. It uses a simple format:

```makefile
# A compiled library (libopencm3):
LIBS += submodules/libopencm3:opencm3_stm32f7:stm32/f7

# A shared source library:
SHARED += ../<sharedname>
```

You do not edit `libs.mk` directly — `make add-shared` manages it for you.

---

## What is and is not committed to git

| Path | Committed |
|------|-----------|
| `Makefile` | Yes |
| `boards/` | Yes |
| `scripts/` | Yes |
| `README.md`, `docs/` | Yes |
| `.gitignore` | Yes |
| `*.code-workspace` | Yes |
| `.vscode/extensions.json` | Yes |
| `.vscode/settings.json` | No — machine-specific |
| `.vscode/tasks.json` | No — generated |
| `.vscode/launch.json` | No — generated |
| `.vscode/c_cpp_properties.json` | No — generated |
| `*/build/` | No — compiled output |
| `*/submodules/*/lib/` | No — compiled library output |
| `*/node_modules/` | No |
| `*/dist/` | No |
