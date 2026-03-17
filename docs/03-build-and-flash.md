# Building and Flashing

This is where your code becomes firmware running on real hardware. The build system
handles everything — compiling libopencm3, compiling your code, linking, and producing
a binary ready for the chip.

---

## Building firmware

### Build one app

```bash
make build APP=<appname>
```

The first time you build, the terminal will show libopencm3 being compiled — dozens of
`.c` files flashing by. This takes a couple of minutes. It only happens once. After that,
only the files you changed get recompiled.

### Build from inside an app's directory

If you are already inside the app's folder, `make` and `make build` both work:

```bash
cd <appname>
make           # builds the app
make build     # same thing
```

No `APP=` argument needed. Everything works relative to the current directory.

### Build all apps

```bash
make build
```

Builds every C app in the workspace in sequence. Stops immediately if any app fails,
so you know exactly which one broke.

### Verbose build

```bash
make build APP=<appname> V=1
```

Shows every compiler and linker command in full. Useful when you are debugging a build
error and need to see the exact flags being passed.

---

## Cleaning

Cleaning removes the `build/` directory for an app — all compiled objects, the `.elf`,
the `.bin`, and the map file. It does not touch libopencm3 (that lives in `submodules/`
and takes a long time to rebuild).

```bash
make clean APP=<appname>    # clean one app
make clean                  # clean all apps
```

If you ever need to force a full rebuild including libopencm3:
```bash
make clean APP=<appname>
rm -rf <appname>/submodules/libopencm3/lib/
make build APP=<appname>
```

---

## Flashing firmware onto hardware

Once your board is connected via USB, flash the firmware:

```bash
make flash APP=<appname>
```

Before attempting to flash, the system checks whether a debug probe is actually
connected. If nothing is plugged in, you get a clear message explaining why it failed
and what to check — not a wall of raw OpenOCD output.

### Choosing the flash tool

By default, the flash tool configured in `board.mk` is used. You can override it:

```bash
make flash APP=<appname> TOOL=openocd    # ST-Link via OpenOCD
make flash APP=<appname> TOOL=jlink      # J-Link
```

### Multiple boards connected at once

If you have more than one ST-Link plugged in, specify which one by its serial number:

```bash
make flash APP=<appname> SERIAL=066DFF535148534257171535
```

To find the serial number of a connected ST-Link:
```bash
openocd -f interface/stlink.cfg -c "init" -c "exit" 2>&1 | grep -i serial
```

### Flashing from inside an app's directory

```bash
cd <appname>
make flash
make flash TOOL=jlink
make flash SERIAL=066DFF...
```

---

## Understanding the build output

### Normal build (quiet mode)

When the build runs without `V=1`, you only see:

```
==============================
 Building: <appname>
==============================
  Lib paths: -Lsubmodules/libopencm3/lib -Wl,-Lsubmodules/libopencm3/lib
```

The `Lib paths` line confirms that libopencm3 is found and already built (skipped).
Your source files compile silently. A successful build ends without errors.

### Verbose build (`V=1`)

```
arm-none-eabi-gcc -Os -ggdb3 -mcpu=cortex-m7 -mthumb ... -c src/main.c -o build/app/main.o
arm-none-eabi-gcc --static -nostartfiles -Tboards/.../linker.ld ... -o build/firmware.elf
arm-none-eabi-objcopy -Obinary build/firmware.elf build/firmware.bin
```

### libopencm3 first-time build

```
==> Building opencm3_stm32f7 from source (target: stm32/f7)
  GENHDR  stm32/f7
  BUILD   lib/stm32/f7
  CC      rcc.c
  CC      gpio_common_all.c
  ...
  AR      libopencm3_stm32f7.a
```

This only happens once per app. After the `.a` file exists, this section is skipped
entirely on subsequent builds.

---

## Build outputs

After a successful build, these files appear in `<appname>/build/`:

| File | Description |
|------|-------------|
| `firmware.elf` | Full debug binary with symbols — used by the debugger |
| `firmware.bin` | Raw binary flashed to the chip |
| `firmware.map` | Linker map — shows exactly where every function and variable landed in memory |

The `build/` directory is gitignored. It is safe to delete at any time.

---

## Common build errors

**`arm-none-eabi-gcc: No such file or directory`**
The ARM toolchain is not installed or not on your PATH. Install it and run
`which arm-none-eabi-gcc` to confirm it is found.

**`cannot find -lopencm3_stm32f7`**
The libopencm3 submodule was not initialised. Run `make init` from the project root,
or `cd <appname> && git submodule update --init`.

**`cannot open linker script file cortex-m-generic.ld`**
Same cause — libopencm3 is not initialised. Run `make init`.

**`undefined reference to rcc_periph_clock_enable`**
libopencm3 compiled but the function you are calling is not in the variant for your MCU
family. Check that your `#include` uses the correct header path.
