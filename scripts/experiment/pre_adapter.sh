#!/usr/bin/env bash
set -euo pipefail

#########################################
# GLOBAL
#########################################

SCRIPT_NAME="pre_adapter"
THIS_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
START_SCRIPT="$THIS_DIR/start_script.sh"
# Bootstap global paths and helpers through the start script
# shellcheck source=/dev/null
source "$START_SCRIPT"

#########################################
# READ CONFIG
#########################################

# PATHS
OUT_DIR="$ROOT/$(toml_get "$PROJ_CONFIG_PATH" "out")"
SUBJECT_DIR="$ROOT/$(toml_get "$PROJ_CONFIG_PATH" "subject")"

# BUILD OUT DIRECTORY
OUT_BC_DIR="$OUT_DIR/$(toml_get "$PROJ_CONFIG_PATH" "subject_bc_dir")"

# PROJECT CONFIG
COMPILER="$(toml_get "$PROJ_CONFIG_PATH" "llvm_compiler")"

# EXPERIMENT CONFIG
SUBJECT_PROJ_NAME="$(toml_get "$EXP_CONFIG_PATH" "source_project_name")"
SRC_FILE_TYPE="$(toml_get "$EXP_CONFIG_PATH" "source_file_type")"
read -r -a COMPILE_FLAGS <<< "$(toml_get "$EXP_CONFIG_PATH" "c_compile_flags")"
read -r -a CPP_FLAGS <<< "$(toml_get "$EXP_CONFIG_PATH" "cppflags")"

# BUILD VARS FROM CONFIG
SRC_FILE_MATCH="*.$SRC_FILE_TYPE"
SUBJECT_BC="$OUT_BC_DIR/$SUBJECT_PROJ_NAME.bc"

out_msg_separator
out_msg "==================== STARTING $SCRIPT_NAME ===================="
out_msg "TARGETING subject: $SUBJECT_PROJ_NAME"
#########################################
# COMPILE SUBJECT TO BITCODE
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
    run_code "$COMPILER" -emit-llvm -O1 -c "${COMPILE_FLAGS[@]}" "${CPP_FLAGS[@]}" "$src" -o "$TEMP_FILE"
    TEMP_FILES+=("$TEMP_FILE")
done < <(find "$SUBJECT_DIR" -name "$SRC_FILE_MATCH" -print0 | sort -z)
out_msg_separator
out_msg "LINKING all temporary bitcode files into $SUBJECT_BC"
mkdir -p "$OUT_BC_DIR"
run_code llvm-link "${TEMP_FILES[@]}" -o "$SUBJECT_BC"
out_msg_separator
out_msg "CLEARING temporary output directory"
rm -rf "$TEMP_DIR"
out_msg_separator
out_msg "==================== ENDING $SCRIPT_NAME ===================="