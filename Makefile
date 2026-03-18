###############################################################################
# stm32-baremetal-monorepo-template -- Root Makefile
#
#  make new-app                                  -- interactive: pick type + answer questions
#  make new-app TYPE=c APP=<appname> BOARD=nucleo_f767zi [SHARED=shared-comms]
#  make new-app TYPE=shared NAME=shared-comms
#  make new-app TYPE=ts APP=mytools
#
#  make add-shared [APP=<appname> SHARED=shared-comms]
#  make change-board [APP=<appname> BOARD=nucleo_g474re]
#  make add-board [BOARD=... MCU_FAMILY=... ARCH=... FLASH_BASE=... ...]
#  make remove-board [BOARD=nucleo_h743zi]
#
#  make build [APP=<appname>]
#  make clean [APP=<appname>]
#  make flash APP=<appname> [TOOL=openocd|jlink] [SERIAL=xxx]
#
#  make vscode
#  make list-apps
#  make init
###############################################################################

# -- Discovery ----------------------------------------------------------------
# C apps: folders with a .board file AND a Makefile
# (board-specific shared libs have .board but no Makefile -- excluded here)
C_APPS := $(foreach d,$(wildcard */),$(if $(and $(wildcard $(d).board),$(wildcard $(d)Makefile)),$(d:/=),))

# Board-specific shared libs: folders with .board, src/, but no Makefile
BS_SHARED_LIBS := $(foreach d,$(wildcard */),\
    $(if $(and $(wildcard $(d).board),$(wildcard $(d)src)),\
        $(if $(wildcard $(d)Makefile),,$(d:/=)),))

# Shared libs: folders with src/, no .board, no package.json, not reserved
_RESERVED := boards scripts .vscode
SHARED_LIBS := $(foreach d,$(wildcard */),\
    $(if $(wildcard $(d)src),\
        $(if $(wildcard $(d).board),,\
            $(if $(filter $(d:/=),$(_RESERVED)),,\
                $(if $(wildcard $(d)package.json),,$(d:/=)))),))

.PHONY: all init new-app add-shared change-board \
        add-board remove-board build clean flash vscode list-apps \
        add-upstream upstream-sync

all: build

###############################################################################
# init
###############################################################################
init:
	git submodule update --init --recursive
	@if [ ! -f README.md ]; then \
	    echo ""; \
	    echo "==> Creating README.md..."; \
	    { \
	        echo "# $$(basename $$(pwd))"; \
	        echo ""; \
	        echo "This project was created using [stm32-baremetal-monorepo-template](https://github.com/Vishal1419/stm32-baremetal-monorepo-template)."; \
	        echo ""; \
	        echo "## About"; \
	        echo ""; \
	        echo "Describe your project here."; \
	        echo ""; \
	        echo "## Documentation"; \
	        echo ""; \
	        echo "Template documentation is available at:"; \
	        echo "https://github.com/Vishal1419/stm32-baremetal-monorepo-template/tree/main/.github/docs"; \
	        echo ""; \
	        echo "## Getting started"; \
	        echo ""; \
	        echo "See [Getting Started](https://github.com/Vishal1419/stm32-baremetal-monorepo-template/blob/main/.github/docs/01-getting-started.md) for setup instructions."; \
	    } > README.md; \
	    echo "v  README.md created. Edit it to describe your project."; \
	fi
	git config core.hooksPath .githooks
	@echo "==> Git hooks configured (.githooks/pre-commit active)"

###############################################################################
# add-upstream
###############################################################################
add-upstream:
	@if git remote get-url upstream > /dev/null 2>&1; then \
	    echo "INFO: 'upstream' remote already exists:"; \
	    git remote get-url upstream; \
	else \
	    git remote add upstream https://github.com/Vishal1419/stm32-baremetal-monorepo-template.git; \
	    echo "v  Upstream remote added:"; \
	    echo "   https://github.com/Vishal1419/stm32-baremetal-monorepo-template.git"; \
	    echo "   Run 'make upstream-sync' to pull latest template changes."; \
	fi

###############################################################################
# upstream-sync
###############################################################################
upstream-sync:
	@if ! git remote get-url upstream > /dev/null 2>&1; then \
	    echo ""; \
	    echo "ERROR: No upstream remote configured."; \
	    echo "       Run 'make add-upstream' first."; \
	    echo ""; \
	    exit 1; \
	fi
	@echo "==> Fetching latest changes from upstream template..."
	@git fetch upstream
	@echo ""
	@echo "==> Merging upstream/main into current branch..."
	@echo "    If conflicts occur, resolve them, then run: git commit"
	@echo ""
	@git merge upstream/main --no-edit || ( \
	    echo ""; \
	    echo "Merge conflicts detected. Resolve the conflicts in the files listed"; \
	    echo "above, then stage the resolved files with: git add <file>"; \
	    echo "Then complete the merge with: git commit"; \
	    echo ""; \
	    echo "After merging, run: bash scripts/test.sh"; \
	    exit 1 \
	)
	@echo ""
	@echo "v  Sync complete. Running tests to verify..."
	@echo ""
	@bash scripts/test.sh

###############################################################################
# new-app  (handles c / shared / ts -- interactive when called bare)
###############################################################################
new-app:
ifdef TYPE
    # Non-interactive: TYPE=c APP=... BOARD=... / TYPE=shared NAME=... / TYPE=ts APP=...
    ifeq ($(TYPE),c)
	@test -n "$(APP)"   || (echo "ERROR: APP= is required for TYPE=c";   exit 1)
	@test -n "$(BOARD)" || (echo "ERROR: BOARD= is required for TYPE=c"; exit 1)
	@bash scripts/new-app.sh c "$(APP)" "$(BOARD)" "$(SHARED)"
    else ifeq ($(TYPE),shared)
	@test -n "$(NAME)" || (echo "ERROR: NAME= is required for TYPE=shared"; exit 1)
	@bash scripts/new-app.sh shared "$(NAME)"
    else ifeq ($(TYPE),ts)
	@test -n "$(APP)" || (echo "ERROR: APP= is required for TYPE=ts"; exit 1)
	@bash scripts/new-app.sh ts "$(APP)"
    else
	@echo "ERROR: Unknown TYPE='$(TYPE)'. Use TYPE=c, TYPE=shared, or TYPE=ts"
	@exit 1
    endif
else
    # Interactive: no TYPE supplied -- script asks everything
	@bash scripts/new-app.sh
endif

###############################################################################
# add-shared
###############################################################################
add-shared:
ifdef APP
	@test -n "$(SHARED)" || (echo "ERROR: SHARED= is required when APP= is given"; exit 1)
	@bash scripts/add-shared.sh "$(APP)" "$(SHARED)"
else
	@bash scripts/add-shared.sh
endif

###############################################################################
# change-board
###############################################################################
change-board:
ifdef APP
	@test -n "$(BOARD)" || (echo "ERROR: BOARD= is required when APP= is given"; exit 1)
	@bash scripts/change-board.sh "$(APP)" "$(BOARD)"
else
	@bash scripts/change-board.sh
endif

###############################################################################
# add-board
###############################################################################
add-board:
ifdef BOARD
	@test -n "$(MCU_FAMILY)"     || (echo "ERROR: MCU_FAMILY= required";     exit 1)
	@test -n "$(ARCH)"           || (echo "ERROR: ARCH= required";            exit 1)
	@test -n "$(FLASH_BASE)"     || (echo "ERROR: FLASH_BASE= required";      exit 1)
	@test -n "$(OPENOCD_TARGET)" || (echo "ERROR: OPENOCD_TARGET= required";  exit 1)
	@test -n "$(OPENOCD_BOARD)"  || (echo "ERROR: OPENOCD_BOARD= required";   exit 1)
	@bash scripts/add-board.sh \
	    "$(BOARD)" "$(MCU_FAMILY)" "$(ARCH)" \
	    "$(FPU)" "$(FLOAT_ABI)" "$(FLASH_BASE)" \
	    "$(OPENOCD_TARGET)" "$(OPENOCD_BOARD)" "$(JLINK_DEVICE)"
else
	@bash scripts/add-board.sh
endif

###############################################################################
# remove-board
###############################################################################
remove-board:
ifdef BOARD
	@bash scripts/remove-board.sh "$(BOARD)"
else
	@bash scripts/remove-board.sh
endif

###############################################################################
# build
###############################################################################
ifdef APP
build:
	@test -d "$(APP)" || (echo "ERROR: sub-project '$(APP)' not found"; exit 1)
	@$(MAKE) --no-print-directory -C $(APP) all
else
build:
	@if [ -z "$(C_APPS)" ]; then \
	    echo "No C sub-projects found."; exit 0; \
	fi
	@for app in $(C_APPS); do \
	    echo ""; \
	    echo "=============================="; \
	    echo " Building: $$app"; \
	    echo "=============================="; \
	    $(MAKE) --no-print-directory -C $$app all || exit 1; \
	done
endif

###############################################################################
# clean
###############################################################################
ifdef APP
clean:
	@test -d "$(APP)" || (echo "ERROR: sub-project '$(APP)' not found"; exit 1)
	@$(MAKE) --no-print-directory -C $(APP) clean
else
clean:
	@for app in $(C_APPS); do \
	    echo "==> Cleaning $$app"; \
	    $(MAKE) --no-print-directory -C $$app clean || exit 1; \
	done
endif

###############################################################################
# flash
###############################################################################
flash:
	@test -n "$(APP)" || (echo "ERROR: APP= is required for flash"; exit 1)
	@test -d "$(APP)" || (echo "ERROR: sub-project '$(APP)' not found"; exit 1)
	@$(MAKE) --no-print-directory -C $(APP) flash \
	    SERIAL="$(SERIAL)" FLASH_TOOL="$(TOOL)"

###############################################################################
# vscode
###############################################################################
vscode:
	@bash scripts/gen-vscode.sh

###############################################################################
# list-apps
###############################################################################
list-apps:
	@echo ""
	@echo "+==============================+"
	@echo "|        stm32-baremetal-monorepo-template            |"
	@echo "+==============================+"
	@echo ""
	@echo "-- C Sub-projects --------------"
	@if [ -z "$(C_APPS)" ]; then \
	    echo "  (none)"; \
	else \
	    for app in $(C_APPS); do \
	        board=$$(cat $$app/.board 2>/dev/null || echo "unknown"); \
	        echo "  $$app  ->  $$board"; \
	    done; \
	fi
	@echo ""
		@echo "-- Shared Libraries ------------"
	@if [ -z "$(SHARED_LIBS)" ]; then \
	    echo "  (none)"; \
	else \
	    for lib in $(SHARED_LIBS); do echo "  $$lib"; done; \
	fi
	@echo ""
	@echo "-- Board-specific Shared Libs --"
	@if [ -z "$(BS_SHARED_LIBS)" ]; then \
	    echo "  (none)"; \
	else \
	    for lib in $(BS_SHARED_LIBS); do \
	        board=$$(cat $$lib/.board 2>/dev/null || echo "unknown"); \
	        echo "  $$lib  ->  $$board"; \
	    done; \
	fi
	@echo ""
	@echo "-- Available Boards ------------"
	@for b in boards/*/; do \
	    bname=$$(basename $$b); \
	    users=""; \
	    for app in $(C_APPS); do \
	        if [ "$$(cat $$app/.board 2>/dev/null)" = "$$bname" ]; then \
	            users="$$users $$app"; \
	        fi; \
	    done; \
	    if [ -n "$$users" ]; then \
	        echo "  $$bname  (used by:$$users)"; \
	    else \
	        echo "  $$bname  (unused)"; \
	    fi; \
	done
	@echo ""
