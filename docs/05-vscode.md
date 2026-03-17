# Debugging in VSCode

The workspace is set up so that VSCode knows about every app, every board, and every
build task — without you configuring anything manually. One command regenerates
everything:

```bash
make vscode
```

Run this after creating any new app, adding or removing a board, or changing which
board an app targets.

---

## Opening the workspace

Always open the project using the workspace file, not the folder:

```
File → Open Workspace from File → stm32-baremetal-monorepo-template.code-workspace
```

This gives you a multi-root workspace where each sub-project appears as its own named
root in the sidebar. The root project appears as `stm32-baremetal-monorepo-template (root)`
and contains boards, scripts, and project-level files. Each app appears separately and
only shows its own contents — no duplication.

---

## Installing the recommended extensions

The first time you open the workspace, VSCode will ask if you want to install the
recommended extensions. Say yes. The important ones are:

**Cortex-Debug** — handles everything debug-related. Talks to OpenOCD or J-Link,
loads symbols into the debugger, shows registers and memory, and enables live watch.

**C/C++ (ms-vscode.cpptools)** — provides IntelliSense, error squiggles, go-to-definition,
and hover documentation for your C code.

**Makefile Tools** — lets you run make targets from the command palette.

---

## Building from inside VSCode

Press `Ctrl+Shift+B` (or `Cmd+Shift+B` on macOS) to open the build tasks. You will see
a task for each app:

- `build <appname>` — compiles the firmware
- `clean <appname>` — removes build output

---

## Debugging on hardware

With your board connected via USB:

1. Press `F5` or go to **Run → Start Debugging**
2. Choose the debug configuration for your app — `Debug <appname>`
3. VSCode builds the firmware first, then starts OpenOCD, connects to the chip, loads
   the firmware, and stops at `main()`

From there you have the full debugger experience:
- Step through code line by line with `F10` (step over) and `F11` (step into)
- Set breakpoints by clicking in the gutter
- Inspect local variables and the call stack in the sidebar
- Watch expressions — type any variable or expression in the Watch panel

---

## Live watch — peripheral registers

If your board has an SVD file configured, you get real-time visibility into every
hardware peripheral while your code is running.

In the Cortex-Debug sidebar (the plug icon in the activity bar), expand **Peripherals**.
You will see every peripheral on the chip — GPIOA, GPIOB, TIM2, USART1, RCC, and so on.
Expand any peripheral to see its registers and their current values, updating live as
your code runs.

This is invaluable for debugging hardware issues. Instead of adding `printf` statements
and wondering what the register value is, you can just look.

Both template boards (`nucleo_f767zi` and `nucleo_g474re`) have their SVD files included beside the `linker.ld` and already configured in `board.mk` — peripheral register view works out of the box. For a new board you add yourself, see [Managing Boards → SVD files](04-boards.md#svd-files-for-live-debugging).

---

## What `make vscode` generates

| File | Purpose | Committed to git? |
|------|---------|-----------|
| `stm32-baremetal-monorepo-template.code-workspace` | Multi-root workspace | Yes |
| `.vscode/c_cpp_properties.json` | IntelliSense per app | No |
| `.vscode/tasks.json` | Build and clean tasks per app | No |
| `.vscode/launch.json` | Debug configurations per app | No |
| `.vscode/settings.json` | Machine-specific tool paths | No |
| `.vscode/extensions.json` | Recommended extensions list | Yes |

The workspace file and extensions list are committed to git. The generated files are
gitignored because they contain paths specific to your machine.

`settings.json` is created once with auto-detected paths to your toolchain and OpenOCD.
Running `make vscode` again never overwrites it. To refresh paths after a toolchain
upgrade, delete `.vscode/settings.json` and run `make vscode` again.

---

## Adjusting tool paths manually

If `make vscode` detects the wrong paths, open `.vscode/settings.json` and update:

```json
{
    "cortex-debug.openocdPath":      "/path/to/openocd",
    "cortex-debug.armToolchainPath": "/path/to/arm/bin",
    "cortex-debug.gdbPath":          "/path/to/arm-none-eabi-gdb",
    "C_Cpp.default.compilerPath":    "/path/to/arm-none-eabi-gcc"
}
```

Find the correct paths:
```bash
which arm-none-eabi-gcc
which openocd
which arm-none-eabi-gdb
```
