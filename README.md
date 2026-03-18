# stm32-baremetal-monorepo-template

A template for STM32 embedded firmware projects. You write C code. The workspace
handles the rest — compiling libopencm3, generating linker scripts, configuring
VSCode, and putting firmware on hardware.

Every board, every app, every library lives in one place. One command creates a project.
One command builds it. One command flashes it.

---

## How it works in two minutes

This is a monorepo template. Inside it live multiple sub-projects — firmware apps for
different boards, shared C libraries they can pull from, and TypeScript tools for your
development machine. The root `Makefile` is the single entry point for everything.

When you create a new firmware app, the workspace downloads libopencm3 as a git
submodule, generates a complete build setup, and produces a starter `main.c` ready to
compile. You never write a Makefile. You never configure a linker script. You just write
your firmware.

```bash
make new-app                        # guided prompts, creates everything
make build APP=<appname>            # compiles including libopencm3
make flash APP=<appname>            # detects your probe and flashes the chip
```

---

## New to this template?

Start with [Getting Started](docs/01-getting-started.md). It walks you through
installing tools, setting up your first app, and getting firmware running on
hardware — step by step.

---

## Documentation

| Guide                                                 | What it covers                                            |
| ----------------------------------------------------- | --------------------------------------------------------- |
| [Getting Started](docs/01-getting-started.md)         | Install tools, clone, create first app, build, flash      |
| [Creating Sub-projects](docs/02-creating-projects.md) | C firmware apps, shared libraries, TypeScript tools       |
| [Building and Flashing](docs/03-build-and-flash.md)   | Compiling, cleaning, verbose output, flashing hardware    |
| [Managing Boards](docs/04-boards.md)                  | Adding boards, linker scripts, SVD files, removing boards |
| [Debugging in VSCode](docs/05-vscode.md)              | Breakpoints, live watch, peripheral register view         |
| [Project Structure](docs/06-project-structure.md)     | Every file and folder explained                           |
| [Command Reference](docs/07-command-reference.md)     | Every `make` command in one place                         |

---

## Quick reference

```bash
# Setup (run once after cloning)
make init                                       # initialise submodules + activate pre-commit hook
make vscode                                     # generate VSCode configs

# Create
make new-app                                    # interactive
make new-app TYPE=c APP=<appname> BOARD=<board>
make new-app TYPE=shared NAME=<sharedname>
make new-app TYPE=ts APP=<appname>

# Build
make build                                      # all apps
make build APP=<appname>                        # one app
make build APP=<appname> V=1                    # verbose

# Flash
make flash APP=<appname>                        # default tool
make flash APP=<appname> TOOL=openocd
make flash APP=<appname> TOOL=jlink
make flash APP=<appname> SERIAL=066DFF...       # specific ST-Link

# Boards
make add-board                                  # interactive
make change-board APP=<appname> BOARD=<board>
make remove-board                               # interactive

# Shared libraries
make add-shared APP=<appname> SHARED=<sharedname>

# Utilities
make list-apps                                  # show everything
make clean APP=<appname>
```

---

## Staying up to date

This repository was created from the `stm32-baremetal-monorepo-template`. To pull
improvements from the template into your project:

```bash
# One-time setup: add the template as an upstream remote
make add-upstream

# Pull latest template changes (fetch + merge + run tests)
make upstream-sync
```

`make upstream-sync` will flag any merge conflicts clearly. Resolve them, run
`git commit`, then `bash scripts/test.sh` to verify everything still works.

---

## Testing

```bash
bash scripts/test.sh    # run full test suite manually (100 tests, ~10 seconds)
```

The pre-commit hook runs tests automatically before every `git commit` — activated
by `make init`. See [Command Reference](docs/07-command-reference.md#testing) for details.

---

## Boards included

| Board           | MCU         | Core      | Flash | RAM   |
| --------------- | ----------- | --------- | ----- | ----- |
| `nucleo_f767zi` | STM32F767ZI | Cortex-M7 | 2MB   | 512KB |
| `nucleo_g474re` | STM32G474RE | Cortex-M4 | 512KB | 128KB |

SVD files for live register debugging are included beside each board's `linker.ld`. See [Managing Boards](docs/04-boards.md#svd-files-for-live-debugging) to add one for a new board.
Adding a new board takes two minutes. See [Managing Boards](docs/04-boards.md).
