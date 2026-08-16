#!/usr/bin/env bash
set -euo pipefail

#########################################
# GLOBAL
#########################################

SCRIPT_NAME="builder"
THIS_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
START_SCRIPT="$THIS_DIR/start_script.sh"
# Bootstap global paths and helpers through the start script
# shellcheck source=/dev/null
source "$START_SCRIPT"

#########################################
# READ CONFIG
#########################################
# PATHS
PASSES_LIB="$ROOT/$(toml_get "$PROJ_CONFIG_PATH" "passes_library")"
OUT_DIR="$ROOT/$(toml_get "$PROJ_CONFIG_PATH" "out")"

# BUILD OUT DIRECTORY
OUT_BC_DIR="$OUT_DIR/$(toml_get "$PROJ_CONFIG_PATH" "subject_bc_dir")"

# PROJECT CONFIG
COMPILER="$(toml_get "$PROJ_CONFIG_PATH" "llvm_compiler")"
TRANSFORM_PASS="$(toml_get "$PROJ_CONFIG_PATH" "transform_pass")"

# EXPERIMENT CONFIG
SUBJECT_PROJ_NAME="$(toml_get "$EXP_CONFIG_PATH" "source_project_name")"
EXPERIMENT_ID="$(toml_get "$EXP_CONFIG_PATH" "id")"

# BUILD VARS FROM CONFIG
SUBJECT_BC="$OUT_BC_DIR/$SUBJECT_PROJ_NAME.bc"

# BUILD EXPERIMENT DIRECTORY
EXPERIMENT_DIR="$OUT_DIR/experiments/$EXPERIMENT_ID"
EXP_BINARY_DIR="$EXPERIMENT_DIR/binary"
EXP_BITCODE_DIR="$EXPERIMENT_DIR/bitcode"
EXP_PLAN_DIR="$EXPERIMENT_DIR/plans"


out_msg_separator
out_msg "==================== STARTING $SCRIPT_NAME ===================="

#########################################
# APPLY VARIANT PLANS
#########################################
out_msg_separator
out_msg "APLLYING variant plans to subject"

NUM_FILES="$(ls -1 "$EXP_PLAN_DIR" | wc -l)"
COMP_PASS_COUNT=0
COMP_FAIL_COUNT=0
TOTAL_COUNT=0
for PLAN_FILE in "$EXP_PLAN_DIR"/*.json; do
    VARIANT_ID="$(basename "$PLAN_FILE" .json)"
    VARIANT_BC="$EXP_BITCODE_DIR/$VARIANT_ID.bc"
    VARIANT_BIN="$EXP_BINARY_DIR/$VARIANT_ID"
    run_code opt -load-pass-plugin "$PASSES_LIB" -passes="${TRANSFORM_PASS},instcombine" --plan-file-path="$PLAN_FILE" -o "$VARIANT_BC" "$SUBJECT_BC"
    if "$COMPILER" "$VARIANT_BC" -o "$VARIANT_BIN" 2>&1; then
        COMP_PASS_COUNT=$((COMP_PASS_COUNT + 1))
    else
        COMP_FAIL_COUNT=$((COMP_FAIL_COUNT + 1))
    fi
    TOTAL_COUNT=$((TOTAL_COUNT + 1))
    if [ $((TOTAL_COUNT % 100)) -eq 0 ]; then 
        out_msg "$TOTAL_COUNT/$NUM_FILES"
    fi
done    

out_msg "SUCCESSFULLY compiled: $COMP_PASS_COUNT"
out_msg "FAILED to compile: $COMP_FAIL_COUNT"


out_msg "==================== ENDING $SCRIPT_NAME ===================="