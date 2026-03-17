#!/usr/bin/env bash
# gen-vscode.sh -- regenerate .vscode/ configs and .code-workspace
# Usage: gen-vscode.sh [--workspace-only]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VSCODE="$ROOT/.vscode"
WORKSPACE_ONLY="${1:-}"
PROJECT_NAME="$(basename "$ROOT")"

mkdir -p "$VSCODE"

# -- Detect tool paths (works on macOS Homebrew and Linux) --------------------
detect_tool() {
    # $1 = primary binary name, rest = fallback absolute paths
    local _name="$1"; shift
    local _found
    _found="$(which "$_name" 2>/dev/null || true)"
    [ -n "$_found" ] && echo "$_found" && return
    for candidate in "$@"; do
        [ -x "$candidate" ] && echo "$candidate" && return
    done
    # Return the which-based path even if missing -- gives a clear path in settings
    echo "/usr/bin/$_name"
}

detect_brew_prefix() {
    local bp
    bp="$(brew --prefix 2>/dev/null || true)"
    echo "${bp:-/usr/local}"
}

BREW="$(detect_brew_prefix)"

ARM_GCC="$(detect_tool arm-none-eabi-gcc \
    "$BREW/bin/arm-none-eabi-gcc" \
    /opt/homebrew/bin/arm-none-eabi-gcc \
    /usr/local/bin/arm-none-eabi-gcc)"

ARM_GDB="$(detect_tool arm-none-eabi-gdb \
    "$BREW/bin/arm-none-eabi-gdb" \
    /opt/homebrew/bin/arm-none-eabi-gdb \
    /usr/local/bin/arm-none-eabi-gdb \
    "$(which gdb-multiarch 2>/dev/null || true)")"

OPENOCD="$(detect_tool openocd \
    "$BREW/bin/openocd" \
    /opt/homebrew/bin/openocd \
    /usr/local/bin/openocd)"

ARM_TOOLCHAIN_DIR="$(dirname "$ARM_GCC")"

# -- Discover C apps (have a .board file) -------------------------------------
C_APPS=()
for dot_board in "$ROOT"/*/.board; do
    [ -f "$dot_board" ] || continue
    C_APPS+=("$(basename "$(dirname "$dot_board")")")
done

# -- Discover TS projects (have package.json, no .board) ----------------------
TS_APPS=()
for d in "$ROOT"/*/; do
    dname="$(basename "$d")"
    if [ -f "$d/package.json" ] && [ ! -f "$d/.board" ]; then
        TS_APPS+=("$dname")
    fi
done

# -- Discover shared libs (src/, no .board, no package.json) ------------------
SHARED_APPS=()
_RESERVED="boards scripts .vscode"
for d in "$ROOT"/*/; do
    dname="$(basename "$d")"
    if [ -d "$d/src" ] && [ ! -f "$d/.board" ] && [ ! -f "$d/package.json" ]; then
        is_reserved=0
        for r in $_RESERVED; do
            [ "$dname" = "$r" ] && is_reserved=1 && break
        done
        [ "$is_reserved" -eq 0 ] && SHARED_APPS+=("$dname")
    fi
done

# -- Helper: read a variable from board.mk ------------------------------------
board_var() {
    local board_mk="$1"
    local var="$2"
    grep -E "^${var}[[:space:]]*:?=" "$board_mk" \
        | head -1 \
        | sed 's/.*:=\s*//' \
        | tr -d ' \t'
}

# -- Build pipe-delimited app data for Python ---------------------------------
APP_DATA=""
for app in "${C_APPS[@]+"${C_APPS[@]}"}"; do
    board="$(cat "$ROOT/$app/.board")"
    board_mk="$ROOT/boards/$board/board.mk"
    mcu_family="$(board_var "$board_mk" MCU_FAMILY)"
    mcu_def="$(echo "$mcu_family" | tr '[:lower:]' '[:upper:]' | tr -d '/')"
    openocd_target="$(board_var "$board_mk" OPENOCD_TARGET)"
    svd_raw="$(board_var "$board_mk" SVD_FILE)"
    if [ -n "$svd_raw" ]; then
        # SVD_FILE may contain a make expression like:
        #   $(dir $(lastword $(MAKEFILE_LIST)))STM32F767.svd
        # Extract just the filename (last component after closing paren or slash)
        svd_file="$(echo "$svd_raw" | sed 's/.*[)\/]//')"
        # The file lives beside board.mk in the board directory
        svd_path="\${workspaceFolder}/boards/${board}/${svd_file}"
    else
        svd_path=""
    fi
    APP_DATA="${APP_DATA}${app}|${board}|${mcu_def}|${openocd_target}|${svd_path}
"
done

TS_DATA=""
for ts in "${TS_APPS[@]+"${TS_APPS[@]}"}"; do
    TS_DATA="${TS_DATA}${ts}
"
done

SHARED_DATA=""
for sh in "${SHARED_APPS[@]+"${SHARED_APPS[@]}"}"; do
    SHARED_DATA="${SHARED_DATA}${sh}
"
done

# -- Python generates all JSON (avoids shell JSON formatting bugs) -------------
python3 - \
    "$ROOT" "$VSCODE" "$PROJECT_NAME" "$WORKSPACE_ONLY" \
    "$APP_DATA" "$TS_DATA" "$SHARED_DATA" \
    "$ARM_GCC" "$ARM_GDB" "$OPENOCD" "$ARM_TOOLCHAIN_DIR" \
<< 'PYEOF'
import sys, json, os, subprocess

root             = sys.argv[1]
vscode           = sys.argv[2]
project_name     = sys.argv[3]
workspace_only   = sys.argv[4]
app_data_raw     = sys.argv[5]
ts_data_raw      = sys.argv[6]
shared_data_raw  = sys.argv[7]
arm_gcc          = sys.argv[8]
arm_gdb          = sys.argv[9]
openocd          = sys.argv[10]
arm_toolchain    = sys.argv[11]

# Parse app data
apps = []
for line in app_data_raw.splitlines():
    line = line.strip()
    if not line:
        continue
    parts = line.split("|")
    apps.append({
        "name":           parts[0],
        "board":          parts[1],
        "mcu_def":        parts[2],
        "openocd_target": parts[3],
        "svd_path":       parts[4] if len(parts) > 4 else "",
    })

ts_apps     = [l.strip() for l in ts_data_raw.splitlines()     if l.strip()]
shared_apps = [l.strip() for l in shared_data_raw.splitlines() if l.strip()]

workspace_file = os.path.join(root, f"{project_name}.code-workspace")

# -- .code-workspace ----------------------------------------------------------
# Collect all sub-project names to exclude from the root folder view.
# Each sub-project is already visible as its own workspace root -- showing
# them inside the root folder too causes duplicates in the explorer.
all_sub_names = (
    [app["name"] for app in apps] +
    ts_apps +
    shared_apps
)

# Build files.exclude for the root folder: hide each sub-project folder
root_excludes = {name + "/": True for name in all_sub_names}
# Also hide other clutter from the root view
root_excludes.update({
    "**/.git":          True,
    "**/.gitmodules":   False,  # keep visible -- useful to see
})

root_folder = {
    "path": ".",
    "name": f"{project_name} (root)",
}

folders = [root_folder]
for app in apps:
    folders.append({"path": app["name"]})
for ts in ts_apps:
    folders.append({"path": ts})
for sh in shared_apps:
    folders.append({"path": sh, "name": f"{sh} (shared)"})

workspace = {
    "folders": folders,
    "settings": {
        # Apply files.exclude only to the root folder via folder-scoped settings
        # VSCode applies top-level settings to all folders; to scope to root only
        # we use the folder path key pattern.
        "files.exclude": root_excludes,
    },
}

with open(workspace_file, "w") as f:
    json.dump(workspace, f, indent=4)
    f.write("\n")
print(f"==> Updated {project_name}.code-workspace")

if workspace_only == "--workspace-only":
    sys.exit(0)

if not apps:
    print("No C sub-projects found -- skipping VSCode config generation.")
    sys.exit(0)

print(f"==> Generating .vscode configs for: {' '.join(a['name'] for a in apps)}")
print(f"    arm-none-eabi-gcc : {arm_gcc}")
print(f"    openocd           : {openocd}")

# -- c_cpp_properties.json ----------------------------------------------------
configs = []
for app in apps:
    configs.append({
        "name": app["name"],
        "includePath": [
            f"${{workspaceFolder}}/{app['name']}/src/**",
            f"${{workspaceFolder}}/{app['name']}/submodules/libopencm3/include",
        ],
        "defines": [app["mcu_def"]],
        "compilerPath": arm_gcc,
        "cStandard": "c99",
        "cppStandard": "c++17",
        "intelliSenseMode": "gcc-arm",
    })

with open(os.path.join(vscode, "c_cpp_properties.json"), "w") as f:
    json.dump({"configurations": configs, "version": 4}, f, indent=4)
    f.write("\n")

# -- tasks.json ---------------------------------------------------------------
tasks = []
for app in apps:
    for cmd in ("build", "clean"):
        tasks.append({
            "label":          f"{cmd} {app['name']}",
            "type":           "shell",
            "command":        f"make {cmd} APP={app['name']}",
            "options":        {"cwd": "${workspaceFolder}"},
            "group":          "build",
            "problemMatcher": ["$gcc"],
        })

with open(os.path.join(vscode, "tasks.json"), "w") as f:
    json.dump({"version": "2.0.0", "tasks": tasks}, f, indent=4)
    f.write("\n")

# -- launch.json --------------------------------------------------------------
launch_configs = []
for app in apps:
    launch_configs.append({
        "name":            f"Debug {app['name']}",
        "type":            "cortex-debug",
        "request":         "launch",
        "servertype":      "openocd",
        "configFiles":     [
            "interface/stlink.cfg",
            f"target/{app['openocd_target']}.cfg",
        ],
        "executable":      f"${{workspaceFolder}}/{app['name']}/build/firmware.elf",
        "runToEntryPoint": "main",
        "preLaunchTask":   f"build {app['name']}",
        "svdFile":         app["svd_path"],
        "liveWatch":       {"enabled": True, "samplesPerSecond": 4},
        "gdbPath":         arm_gdb,
    })

with open(os.path.join(vscode, "launch.json"), "w") as f:
    json.dump({"version": "0.2.0", "configurations": launch_configs}, f, indent=4)
    f.write("\n")

# -- settings.json -- only create if missing, preserve user's tool paths ------
settings_path = os.path.join(vscode, "settings.json")
if not os.path.exists(settings_path):
    settings = {
        "cortex-debug.openocdPath":      openocd,
        "cortex-debug.armToolchainPath": arm_toolchain,
        "cortex-debug.gdbPath":          arm_gdb,
        "C_Cpp.default.compilerPath":    arm_gcc,
        "editor.formatOnSave":           True,
        "files.associations": {
            "*.mk":   "makefile",
            ".board": "plaintext",
        },
    }
    with open(settings_path, "w") as f:
        json.dump(settings, f, indent=4)
        f.write("\n")
    print("==> Created .vscode/settings.json with detected tool paths")
else:
    print("==> Skipped .vscode/settings.json (already exists -- preserving your paths)")

print("==> VSCode configs regenerated successfully.")
print("    Run 'make vscode' again after any board.mk or .board change.")
PYEOF
