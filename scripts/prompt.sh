#!/usr/bin/env bash
# prompt.sh -- interactive prompt helpers sourced by other scripts
# Source this file: source "$(dirname "$0")/prompt.sh"

# ask_required VAR "Question" [default]
ask_required() {
    local _var="$1"
    local _question="$2"
    local _current="${3:-}"
    local _answer=""
    while true; do
        if [ -n "$_current" ]; then
            printf "  %s [%s]: " "$_question" "$_current"
        else
            printf "  %s: " "$_question"
        fi
        read -r _answer
        _answer="${_answer:-$_current}"
        if [ -n "$_answer" ]; then
            printf -v "$_var" '%s' "$_answer"
            return 0
        fi
        echo "    (required -- please enter a value)"
    done
}

# ask_optional VAR "Question" [default]
ask_optional() {
    local _var="$1"
    local _question="$2"
    local _default="${3:-}"
    local _answer=""
    if [ -n "$_default" ]; then
        printf "  %s (optional) [%s]: " "$_question" "$_default"
    else
        printf "  %s (optional, press Enter to skip): " "$_question"
    fi
    read -r _answer
    _answer="${_answer:-$_default}"
    printf -v "$_var" '%s' "$_answer"
}

# ask_choice VAR "Question" OPTION1 OPTION2 ...
# User picks by number or types value directly.
ask_choice() {
    local _var="$1"
    local _question="$2"
    shift 2
    local _options=("$@")
    echo "  $_question"
    local i=1
    for opt in "${_options[@]}"; do
        printf "    %d) %s\n" "$i" "$opt"
        ((i++))
    done
    local _answer=""
    while true; do
        printf "  Choice [1-%d]: " "${#_options[@]}"
        read -r _answer
        # Match by typed value
        for opt in "${_options[@]}"; do
            if [ "$_answer" = "$opt" ]; then
                printf -v "$_var" '%s' "$_answer"
                return 0
            fi
        done
        # Match by number
        if [[ "$_answer" =~ ^[0-9]+$ ]] && \
           [ "$_answer" -ge 1 ] && [ "$_answer" -le "${#_options[@]}" ]; then
            printf -v "$_var" '%s' "${_options[$((_answer-1))]}"
            return 0
        fi
        echo "    (invalid -- enter a number between 1 and ${#_options[@]})"
    done
}

# list_boards ROOT
# Prints one board name per line -- use with: mapfile -t ARR < <(list_boards ROOT)
list_boards() {
    local _root="$1"
    for d in "$_root"/boards/*/; do
        [ -d "$d" ] && printf '%s\n' "$(basename "$d")"
    done
}

# list_apps ROOT
# Prints one C app name per line
list_apps() {
    local _root="$1"
    for dot_board in "$_root"/*/.board; do
        [ -f "$dot_board" ] && printf '%s\n' "$(basename "$(dirname "$dot_board")")"
    done
}

# list_shared ROOT
# Prints one shared lib name per line
list_shared() {
    local _root="$1"
    local _reserved="boards scripts .vscode"
    for d in "$_root"/*/; do
        local dname
        dname="$(basename "$d")"
        if [ -d "$d/src" ] && [ ! -f "$d/.board" ] && [ ! -f "$d/package.json" ]; then
            local is_reserved=0
            for r in $_reserved; do
                [ "$dname" = "$r" ] && is_reserved=1 && break
            done
            [ "$is_reserved" -eq 0 ] && printf '%s\n' "$dname"
        fi
    done
}

# read_array ARRAYNAME COMMAND [ARGS...]
# Portable replacement for: mapfile -t ARRAYNAME < <(COMMAND ARGS...)
# Works on bash 3.2 (macOS default) and bash 4+.
read_array() {
    local _arrname="$1"; shift
    local _line
    local _i=0
    while IFS= read -r _line; do
        eval "${_arrname}[$_i]=\"\$_line\""
        ((_i++)) || true
    done < <("$@")
}
