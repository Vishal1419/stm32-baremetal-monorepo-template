# Command Reference

Every command in one place. All commands are run from the project root unless noted.

---

## make init

Initialises all git submodules recursively. Run this once after cloning.

```bash
make init
```

---

## make new-app

Creates a new sub-project. Interactive when run without arguments.

```bash
# Interactive (recommended)
make new-app

# C firmware app
make new-app TYPE=c APP=<appname> BOARD=<boardname>
make new-app TYPE=c APP=<appname> BOARD=<boardname> SHARED=<sharedname>

# Shared C library
make new-app TYPE=shared NAME=<sharedname>

# TypeScript app
make new-app TYPE=ts APP=<appname>
```

---

## make build

Compiles firmware. Automatically builds libopencm3 first if the `.a` is missing.

```bash
make build                       # build all C apps
make build APP=<appname>         # build one app
make build APP=<appname> V=1     # verbose

# From inside an app directory:
make
make build
```

---

## make clean

Removes compiled output. Does not touch libopencm3.

```bash
make clean                       # clean all C apps
make clean APP=<appname>         # clean one app
```

---

## make flash

Flashes firmware. Checks for a connected probe first.

```bash
make flash APP=<appname>                         # use default tool
make flash APP=<appname> TOOL=openocd            # OpenOCD / ST-Link
make flash APP=<appname> TOOL=jlink              # J-Link
make flash APP=<appname> TOOL=openocd SERIAL=xxx # specific ST-Link

# From inside an app directory:
make flash
make flash TOOL=jlink
make flash SERIAL=066DFF...
```

---

## make add-shared

Links a shared library into an existing C app.

```bash
make add-shared                                  # interactive
make add-shared APP=<appname> SHARED=<sharedname>
```

---

## make change-board

Changes which board a C app targets. Cleans, regenerates VSCode configs, and rebuilds.

```bash
make change-board                                # interactive
make change-board APP=<appname> BOARD=<boardname>
```

---

## make add-board

Registers a new board. Interactive when run without arguments.

```bash
make add-board    # interactive (recommended)
```

After running: edit `boards/<boardname>/linker.ld` with correct Flash/RAM sizes,
and optionally add an SVD file. See [Managing Boards](04-boards.md).

---

## make remove-board

Removes a board. Fails if any app uses it or if it is the last board.
Regenerates VSCode configs automatically.

```bash
make remove-board                # interactive — numbered list
make remove-board BOARD=<boardname>
```

---

## make vscode

Regenerates VSCode configuration. Preserves `settings.json`.

```bash
make vscode
```

Run after: `make new-app`, `make change-board`, `make add-board`, `make remove-board`.

---

## make list-apps

Shows all C apps, shared libraries, and available boards.

```bash
make list-apps
```

---

## TypeScript app commands

From inside a TypeScript app directory:

```bash
npm run dev      # run with ts-node (no compile step)
npm run build    # compile to dist/
npm start        # run compiled output
npm run clean    # remove dist/
```

---

## Inspecting Makefile variables

From inside any C app directory, you can print the value of any Makefile variable:

```bash
make print-TGT_CFLAGS
make print-LIB_LDFLAGS
make print-MCU_FAMILY
make print-LIB_ARCHIVES
```

Useful for debugging build issues.
