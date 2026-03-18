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
    # Read SHARED entries from libs.mk to add shared library include paths
    shared_paths=""
    if [ -f "$ROOT/$app/libs.mk" ]; then
        while IFS= read -r line; do
            case "$line" in
                SHARED*=*)
                    # Extract the path after += or =, e.g. "../shared-comms" -> "shared-comms"
                    shared_dir="$(echo "$line" | sed 's/.*=[[:space:]]*//' | tr -d ' 	')"
                    # Strip leading ../
                    shared_name="$(echo "$shared_dir" | sed 's|^\.\./||')"
                    if [ -n "$shared_name" ]; then
                        shared_paths="${shared_paths}:${shared_name}"
                    fi
                    ;;
            esac
        done < "$ROOT/$app/libs.mk"
    fi
    APP_DATA="${APP_DATA}${app}|${board}|${mcu_def}|${openocd_target}|${svd_path}|${mcu_family}|${shared_paths}
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
        "mcu_family":     parts[5] if len(parts) > 5 else "",
        "shared_paths":   [p for p in parts[6].split(":") if p] if len(parts) > 6 else [],
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

# -- c_cpp_properties.json (one per app, written into each app's .vscode/) ----
# In a multi-root workspace each app is its own workspace root.
# VSCode resolves ${workspaceFolder} to the app directory when editing files
# inside that root -- so we write a separate c_cpp_properties.json into each
# app's own .vscode/ folder. Paths are relative to the app directory.
for app in apps:
    mcu_family_parts = app["mcu_family"].split("/") if app.get("mcu_family") else []
    family_leaf = mcu_family_parts[-1] if mcu_family_parts else ""

    config = {
        "name": app["name"],
        "includePath": [
            "${workspaceFolder}/src/**",
            "${workspaceFolder}/submodules/libopencm3/include",
            f"${{workspaceFolder}}/submodules/libopencm3/include/libopencm3/stm32/{family_leaf}",
        ] + [
            f"${{workspaceFolder}}/../{s}/src/**" for s in app["shared_paths"]
        ] + [
            f"${{workspaceFolder}}/../{s}/inc" for s in app["shared_paths"]
        ],
        "defines": [app["mcu_def"]],
        "compilerPath": arm_gcc,
        "compilerArgs": [f"-D{app['mcu_def']}"],
        "cStandard": "c99",
        "cppStandard": "c++17",
        "intelliSenseMode": "gcc-arm",
    }

    app_vscode = os.path.join(root, app["name"], ".vscode")
    os.makedirs(app_vscode, exist_ok=True)
    app_cpp_props = os.path.join(app_vscode, "c_cpp_properties.json")
    with open(app_cpp_props, "w") as f:
        json.dump({"configurations": [config], "version": 4}, f, indent=4)
        f.write("\n")

# Also write combined config at root level for files opened from root workspace
root_configs = []
for app in apps:
    mcu_family_parts = app["mcu_family"].split("/") if app.get("mcu_family") else []
    family_leaf = mcu_family_parts[-1] if mcu_family_parts else ""
    root_configs.append({
        "name": app["name"],
        "includePath": [
            f"${{workspaceFolder}}/{app['name']}/src/**",
            f"${{workspaceFolder}}/{app['name']}/submodules/libopencm3/include",
            f"${{workspaceFolder}}/{app['name']}/submodules/libopencm3/include/libopencm3/stm32/{family_leaf}",
        ] + [
            f"${{workspaceFolder}}/{s}/src/**" for s in app["shared_paths"]
        ] + [
            f"${{workspaceFolder}}/{s}/inc" for s in app["shared_paths"]
        ],
        "defines": [app["mcu_def"]],
        "compilerPath": arm_gcc,
        "compilerArgs": [f"-D{app['mcu_def']}"],
        "cStandard": "c99",
        "cppStandard": "c++17",
        "intelliSenseMode": "gcc-arm",
    })
with open(os.path.join(vscode, "c_cpp_properties.json"), "w") as f:
    json.dump({"configurations": root_configs, "version": 4}, f, indent=4)
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

# -- c_cpp_properties.json for shared libraries ------------------------------
# If a shared library has its own libopencm3 submodule (for IntelliSense only),
# write a c_cpp_properties.json into its .vscode/ folder.
# No MCU define is set -- shared code must be family-agnostic.
for sh in shared_apps:
    ocm3_inc = os.path.join(root, sh, "submodules", "libopencm3", "include")
    if not os.path.isdir(ocm3_inc):
        continue
    sh_vscode = os.path.join(root, sh, ".vscode")
    os.makedirs(sh_vscode, exist_ok=True)

    # shims/ must come before libopencm3/include so shim headers
    # intercept #include <libopencm3/stm32/i2c.h> etc.
    sh_include_path = ["${workspaceFolder}/src/**", "${workspaceFolder}/inc"]
    shims_dir = os.path.join(root, sh, "shims")
    if os.path.isdir(shims_dir):
        sh_include_path.append("${workspaceFolder}/shims")
    sh_include_path.append("${workspaceFolder}/submodules/libopencm3/include")

    sh_config = {
        "name": sh,
        "includePath": sh_include_path,
        "defines": [],
        "compilerPath": arm_gcc,
        "cStandard": "c99",
        "cppStandard": "c++17",
        "intelliSenseMode": "gcc-arm",
    }
    with open(os.path.join(sh_vscode, "c_cpp_properties.json"), "w") as f:
        json.dump({"configurations": [sh_config], "version": 4}, f, indent=4)
        f.write("\n")
    print(f"==> Created {sh}/.vscode/c_cpp_properties.json (libopencm3 IntelliSense)")

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
