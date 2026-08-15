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
SUBJECT_BC_DIR="$ROOT/$(toml_get "$PROJ_CONFIG_PATH" "subject_bc_dir")"
EXPERIMENT_DIR="$ROOT/$(toml_get "$PROJ_CONFIG_PATH" "experiments")/$(toml_get "$EXP_CONFIG_PATH" "id")"
# PROJECT CONFIG
COMPILER="$(toml_get "$PROJ_CONFIG_PATH" "llvm_compiler")"
TRANSFORM_PASS="$(toml_get "$PROJ_CONFIG_PATH" "transform_pass")"

# EXPERIMENT CONFIG
SUBJECT_PROJ_NAME="$(toml_get "$EXP_CONFIG_PATH" "source_project_name")"
EXPERIMENT_ID="$(toml_get "$EXP_CONFIG_PATH" "id")"

# BUILD VARS FROM CONFIG
SUBJECT_BC="$SUBJECT_BC_DIR/$SUBJECT_PROJ_NAME.bc"

out_msg_separator
out_msg "==================== STARTING $SCRIPT_NAME ===================="

#########################################
# APPLY VARIANT PLANS
#########################################
out_msg_separator
out_msg "APLLYING variant plans to subject"

PLANS_DIR="$EXPERIMENT_DIR/plans"
BC_DIR="$EXPERIMENT_DIR/bitcode"
BIN_DIR="$EXPERIMENT_DIR/binary"
mkdir -p "$BC_DIR"
mkdir -p "$BIN_DIR"

COMP_PASS_COUNT=0
COMP_FAIL_COUNT=0
for PLAN_FILE in "$PLANS_DIR"/*.json; do
    VARIANT_ID="$(basename "$PLAN_FILE" .json)"
    VARIANT_BC="$BC_DIR/$VARIANT_ID.bc"
    VARIANT_BIN="$BIN_DIR/$VARIANT_ID"
    run_code opt -load-pass-plugin "$PASSES_LIB" -passes="${TRANSFORM_PASS},instcombine" --plan-file-path="$PLAN_FILE" -o $VARIANT_BC "$SUBJECT_BC"
    if "$COMPILER" "$VARIANT_BC" -o "$VARIANT_BIN" 2>&1; then
        COMP_PASS_COUNT=$((COMP_PASS_COUNT + 1))
    else
        COMP_FAIL_COUNT=$((COMP_FAIL_COUNT + 1))
    fi
done    

echo "SUCCESSFULLY compiled: $COMP_PASS_COUNT"
echo "FAILED to compile: $COMP_FAIL_COUNT"


out_msg "==================== ENDING $SCRIPT_NAME ===================="