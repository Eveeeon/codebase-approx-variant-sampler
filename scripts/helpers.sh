#!/usr/bin/env bash

# Handle messages, write to logs and/or to terminal
function out_msg() {
    local TIMESTAMP
    local MSG

    TIMESTAMP="$(date +%Y-%m-%d~%H:%M:%S)"
    MSG="[$TIMESTAMP] ~~ $1"

    # to terminal
    echo "$MSG"

    # to log file, define globally
    if [[ -v LOG_PATH ]]; then
        $MSG >> "$LOG_PATH"
    fi

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
toml_get() {
    local KEY
    local KEY_REGEX
    local VAL_REGEX
    local CONFIG_PATH

    CONFIG_PATH="$1"
    KEY="$2"
    KEY_REGEX="^\s*${KEY}\s*="
    VAL_REGEX='s/.*=\s*"?([^"#]+)"?.*/\1/'
    grep -E "$KEY_REGEX" "$CONFIG_PATH" \
        | head -1 \
        | sed -E "$VAL_REGEX" \
        | tr -d '[:space:]'
}