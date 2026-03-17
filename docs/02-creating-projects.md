# Creating Sub-projects

Every piece of code in this workspace lives in a sub-project. There are three kinds —
C firmware apps, shared C libraries, and TypeScript tools. Each has its own folder, and
the workspace treats them differently based on what's inside.

You never create a sub-project by hand. You always use:

```bash
make new-app
```

Run it without any arguments and it will ask you everything it needs to know.

---

## C firmware apps

A C firmware app is a complete STM32 firmware project. It compiles against a specific
board, links against libopencm3, and produces a `.elf` and `.bin` file ready to flash.

### Creating one interactively

```bash
make new-app
```

Choose `c` when asked for the type. You will then be asked for:
- A name (e.g. `motor-ctrl`, `sensor-node`, `gateway`)
- Which board to target (pick from the numbered list)
- Whether to link a shared library (optional — press Enter to skip)

### Creating one directly

```bash
make new-app TYPE=c APP=<appname> BOARD=<boardname>
```

Or with a shared library already linked:
```bash
make new-app TYPE=c APP=<appname> BOARD=<boardname> SHARED=<sharedname>
```

### What gets created

After running the command, your project gains a new folder:

```
<appname>/
├── Makefile          — never edit this manually
├── .board            — board pointer, do not change manually
├── libs.mk           — declares library dependencies
├── src/
│   └── main.c        — your starting point
└── submodules/
    └── libopencm3/   — git submodule, auto-populated
```

The `Makefile` inside the app is generated once and never touched again. All
board-specific configuration lives in `boards/` and is referenced by the `.board` file.

### Writing your firmware

Open `<appname>/src/main.c` and start writing. Headers from libopencm3 are available
right away. You can add as many `.c` files as you like anywhere under `src/`. The build
system finds them all automatically — no need to register them anywhere.

### Organising source files

This workspace does not impose a structure on how you organise files inside `src/`.
One pattern that works well is to keep each header file beside its corresponding `.c`
file:

```
<appname>/src/
├── main.c
├── drivers/
│   ├── uart.c
│   ├── uart.h          — lives beside uart.c
│   ├── i2c.c
│   └── i2c.h           — lives beside i2c.c
└── app/
    ├── control.c
    └── control.h
```

The `inc/` folder at the project root is only for headers that are truly shared across
multiple files and have no single corresponding `.c` file — things like type definitions,
enumerations, or configuration constants. Everything else lives beside its `.c` file.
This is a recommended pattern, not a requirement. You can organise your code however
works best for your project.

---

## Shared C libraries

A shared library is board-agnostic C code that multiple firmware apps can use. Unlike
a normal library, it is not compiled separately — its source files are compiled directly
into each app that uses it. This means you get full compiler optimisation across the
boundary and no separate build step.

### When to use one

If you have utility functions — a communication protocol implementation, a sensor driver
abstraction, a data structure — that multiple apps need, put it in a shared library
instead of duplicating code.

### Creating one

```bash
make new-app
```

Choose `shared` when asked for the type, then give it a name.

Or directly:
```bash
make new-app TYPE=shared NAME=<sharedname>
```

### What gets created

```
<sharedname>/
├── src/              — .c files and their companion .h files
└── inc/              — headers that are truly common with no corresponding .c file
```

There is no Makefile here. That is intentional. The sources compile inside the app's
build, not independently.

### Structuring shared code

Headers that are only used internally within the shared library live beside their `.c`
file in `src/`. The `inc/` folder is for headers that consuming apps need to include —
typically type definitions, enumerations, or interface declarations that span multiple
implementation files and have no single `.c` counterpart.

```
<sharedname>/
├── src/
│   ├── protocol.c
│   ├── protocol.h      — internal implementation details
│   ├── checksum.c
│   └── checksum.h      — internal
└── inc/
    └── comms_types.h   — shared types used by both protocol.c and consumers
```

### Linking it into an app

```bash
make add-shared
```

Pick the app and shared library from the numbered lists. Or directly:

```bash
make add-shared APP=<appname> SHARED=<sharedname>
```

This adds one line to `<appname>/libs.mk`. The next build automatically picks up the
shared sources.

---

## TypeScript / Node apps

TypeScript apps are for tooling that runs on your development machine — serial monitor
scripts, data loggers, test harnesses, or configuration generators.

### Creating one

```bash
make new-app
```

Choose `ts` when asked for the type, then give it a name.

Or directly:
```bash
make new-app TYPE=ts APP=<appname>
```

### Running and building

From inside the app's folder:

```bash
npm run dev      # run directly with ts-node (no compile step)
npm run build    # compile TypeScript to dist/
npm start        # run the compiled output
npm run clean    # remove dist/
```

---

## Linking a shared library after app creation

If you forgot to link a shared library when creating an app, add it any time:

```bash
make add-shared
```

---

## Switching an app to a different board

```bash
make change-board
```

Or directly:
```bash
make change-board APP=<appname> BOARD=<boardname>
```

This automatically cleans the stale build artefacts, updates the board pointer,
regenerates VSCode configs, and rebuilds.

---

## Seeing everything at a glance

```bash
make list-apps
```

Prints all C apps with their boards, all shared libraries, and all available boards.
