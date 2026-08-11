#!/usr/bin/env bash
set -euo pipefail

#########################################
# GLOBAL
#########################################

SCRIPT_NAME="compile_subject.sh"
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# LOG_PATH=

# Load helpers
# shellcheck source=/dev/null
source "$SCRIPT_DIR/helpers.sh"
out_msg_separator
out_msg "==================== STARTING $SCRIPT_NAME ===================="
out_msg "Root directory: $ROOT"

#########################################
# READ CONFIG
#########################################
out_msg "READING config"

CONFIG_PATH="$ROOT/config/experiment_config.toml"
OUT_DIR="$ROOT/$(toml_get "$CONFIG_PATH" "out")"
SUBJECT_DIR="$ROOT/$(toml_get "$CONFIG_PATH" "subject")"
COMPILER="$(toml_get "$CONFIG_PATH" "llvm_compiler")"
SRC_FILE_TYPE="$(toml_get "$CONFIG_PATH" "source_file_type")"
SRC_FILE_MATCH="*.$SRC_FILE_TYPE"
SUBJECT_BC="$ROOT/$(toml_get "$CONFIG_PATH" "subject_bc")"

#########################################
# COMPILE TO BITCODE
#########################################
out_msg_separator
out_msg "COMPILING subject to bitcode"

out_msg "CLEARING temporary output directory"
TEMP_DIR="$OUT_DIR/temp"
rm -rf "$TEMP_DIR"
mkdir "$TEMP_DIR"

TEMP_FILES=()
out_msg_separator
out_msg "COMPILING each $SRC_FILE_TYPE to temporary bitcode files"
while IFS= read -r -d '' src; do
    TEMP_FILE="$(mktemp "$TEMP_DIR/XXXXXX.bc")"
    "$COMPILER" -emit-llvm -O0 c "$src" -o "$TEMP_FILE"
    TEMP_FILES+=("$TEMP_FILE")
done < <(find "$SUBJECT_DIR" -name "$SRC_FILE_MATCH" -print0 | sort -z)
out_msg_separator
out_msg "LINKING all temporary bitcode files into $SUBJECT_BC"
llvm-link "${TEMP_FILES[@]}" -o "$SUBJECT_BC"
out_msg_separator
out_msg "CLEARING temporary output directory"
rm -rf "$TEMP_DIR"
mkdir "$TEMP_DIR"
out_msg_separator

out_msg "==================== ENDING $SCRIPT_NAME ===================="