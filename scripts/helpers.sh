#!/usr/bin/env bash

# Make sure file exists so it can be appended to for logging
function ensure_file_exists() {
    local FILE

    FILE="$1"
    mkdir -p "$(dirname "$FILE")"
    if ! [ -e "$FILE" ] ; then
        touch "$FILE"
    fi
}


# Handle messages, write to logs and/or to terminal
function out_msg() {
    local TIMESTAMP
    local MSG

    TIMESTAMP="$(date +%Y-%m-%d~%H:%M:%S)"
    MSG="[$TIMESTAMP] ~~ $1"

    if [[ -v EXPERIMENT_ID ]]; then
        MSG="INFO $TIMESTAMP [experiment=$EXPERIMENT_ID] $SCRIPT_NAME ~~ $1"
    else
        MSG="INFO $TIMESTAMP [] $SCRIPT_NAME ~~ $1"
    fi

    # to terminal
    echo "$MSG"

    # to log file, if defined in script
    if [[ -v LOG_FILE ]]; then
        if [[ -v SCRIPT_NAME ]]; then
            ensure_file_exists "$LOG_FILE"
            printf '%s\n' "$MSG" >> "$LOG_FILE"
        fi
    fi
}

function run_code() {
    local OUTPUT
    local STATUS

        OUTPUT="$("$@" 2>&1)" || STATUS=$?

    if [[ -n "${OUTPUT:-}" ]]; then
        out_msg "$OUTPUT"
    fi

    return "${STATUS:-0}"
}

# Write a separater line to the out_msg
function out_msg_separator() {
    local SEPARATOR
    SEPARATOR="#########################################"
    out_msg $SEPARATOR
}

# Handle error messages
function error_msg() {
    out_msg "[ERROR]: $1"
}

# Read simple TOML files
# only handles simple one-to-one key,value pairs
function toml_get() {
    local KEY
    local KEY_REGEX
    local VAL_REGEX
    local CONFIG_PATH

    CONFIG_PATH="$1"
    KEY="$2"
    KEY_REGEX="^\s*${KEY}\s*="
    VAL_REGEX='s/[^=]*=\s*"?([^"#]+)"?\s*$/\1/'
    grep -E "$KEY_REGEX" "$CONFIG_PATH" \
        | head -1 \
        | sed -E "$VAL_REGEX"
}