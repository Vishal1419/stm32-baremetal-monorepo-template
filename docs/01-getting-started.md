# Getting Started

This is a template for STM32 embedded firmware projects. It gives you a complete,
working build system so you can focus entirely on writing firmware — not configuring
Makefiles, linker scripts, or VSCode.

This guide walks you through everything from a fresh clone to firmware running on
your board.

---

## What you need before you begin

### macOS

```bash
# ARM toolchain (compiler, linker, objcopy)
brew install --cask gcc-arm-embedded

# OpenOCD (flashing and debugging via ST-Link)
brew install openocd
```

### Linux (Ubuntu / Debian)

```bash
sudo apt update
sudo apt install gcc-arm-none-eabi openocd
```

### Windows

1. **ARM Toolchain** — download the installer from
   [developer.arm.com/downloads/-/arm-gnu-toolchain-downloads](https://developer.arm.com/downloads/-/arm-gnu-toolchain-downloads).
   Choose the `arm-none-eabi` Windows installer. During installation, tick
   "Add path to environment variable".

2. **OpenOCD** — download a pre-built Windows binary from
   [gnutoolchains.com/arm-eabi/openocd](https://gnutoolchains.com/arm-eabi/openocd/)
   or [xpack-dev-tools/openocd releases](https://github.com/xpack-dev-tools/openocd-xpack/releases).
   Extract the archive and add the `bin/` folder to your PATH.

3. **Make** — install via [Chocolatey](https://chocolatey.org/):

   ```
   choco install make
   ```

   Or install [Git for Windows](https://gitforwindows.org/) which includes
   `Git Bash` — run all `make` commands from Git Bash.

4. **Git** — [git-scm.com/download/win](https://git-scm.com/download/win)

Verify everything is working by opening a terminal (or Git Bash on Windows) and running:

```bash
arm-none-eabi-gcc --version
openocd --version
make --version
git --version
```

---

## Step 1 — Clone the template

```bash
git clone https://github.com/your-org/stm32-baremetal-monorepo-template.git
cd stm32-baremetal-monorepo-template
```

---

## Step 2 — Check if your board is already supported

```bash
make list-apps
```

Look at the **Available Boards** section. If your board is listed, move to next step.
If not, add it now:

```bash
make add-board
```

The command asks questions interactively — board name, MCU family, architecture,
flash address, and flash tool configuration. See [Managing Boards](04-boards.md)
for what to fill in for each field, and what to do after the board is created
(setting Flash/RAM sizes and downloading an SVD file).

---

## Step 3 — Create your first firmware app

```bash
make new-app
```

Choose `c` for a C firmware app. You will be asked for an app name and which board
to target. The command downloads libopencm3, generates all the build scaffolding,
and creates a starter `src/main.c`.

---

## Step 4 — Set up VSCode

```bash
make vscode
```

This detects your toolchain paths and generates all VSCode configuration —
IntelliSense, build tasks, and debug launch configurations. Run this command
again whenever you add a new app or change a board.

Open the workspace:

```
File → Open Workspace from File → stm32-baremetal-monorepo-template.code-workspace
```

Install the recommended extensions when prompted.

---

## Step 5 — Write your firmware

Open `<appname>/src/main.c` in VSCode. This is your entry point. IntelliSense
will offer completions for all libopencm3 functions. Start writing:

```c
#include <libopencm3/stm32/rcc.h>
#include <libopencm3/stm32/gpio.h>

int main(void)
{
    rcc_periph_clock_enable(RCC_GPIOA);
    gpio_mode_setup(GPIOA, GPIO_MODE_OUTPUT, GPIO_PUPD_NONE, GPIO5);

    while (1) {
        gpio_toggle(GPIOA, GPIO5);
        for (int i = 0; i < 1000000; i++) __asm__("nop");
    }
    return 0;
}
```

---

## Step 6 — Build

```bash
make build APP=<appname>
```

The first build takes a couple of minutes because it compiles libopencm3 from
source. Every build after that is fast — only changed files are recompiled.

---

## Step 7 — Flash or debug

Connect your board via USB, then either flash from the command line:

```bash
make flash APP=<appname>
```

Or launch the debugger in VSCode: press `F5`, select `Debug <appname>`,
and execution stops at `main()`. You can step through code, inspect variables,
and watch peripheral registers in real time.

---

## Where to go next

- [Creating Sub-projects](02-creating-projects.md) — add more apps, shared libraries, and TypeScript tools
- [Building and Flashing](03-build-and-flash.md) — build options, verbose output, multiple boards
- [Managing Boards](04-boards.md) — adding boards, SVD files, linker script sizes
- [Debugging in VSCode](05-vscode.md) — breakpoints, live watch, register view
