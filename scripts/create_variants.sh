#!/usr/bin/env bash
set -euo pipefail

#########################################
# GLOBAL
#########################################

SCRIPT_NAME="create_variants.sh"
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
LLVM_DIR="$ROOT/$(toml_get "$CONFIG_PATH" "llvm_dir")"
CPP_BUILD_DIR="$ROOT/$(toml_get "$CONFIG_PATH" "cpp_build_dir")"
COMPILER="$(toml_get "$CONFIG_PATH" "llvm_compiler")"
PASSES_LIB="$ROOT/$(toml_get "$CONFIG_PATH" "passes_library")"
SUBJECT_BC="$ROOT/$(toml_get "$CONFIG_PATH" "subject_bc")"
OPTIMIZATION="$(toml_get "$CONFIG_PATH" "optimization")"
EXPORT_PASS="$(toml_get "$CONFIG_PATH" "export_pass")"
TRANSFORM_PASS="$(toml_get "$CONFIG_PATH" "transform_pass")"
EXPORT_GRAPH="$ROOT/$(toml_get "$CONFIG_PATH" "export_graph")"
EXPERIMENT_DIR="$ROOT/$(toml_get "$CONFIG_PATH" "experiments")/$(toml_get "$CONFIG_PATH" "id")"
PYTHON_DIR="$ROOT/$(toml_get "$CONFIG_PATH" "python_dir")"

#########################################
# RUN EXPORT GRAPH PASS
#########################################
out_msg_separator
out_msg "RUNNING export pass"

#opt -load-pass-plugin "$PASSES_LIB" "-$OPTIMIZATION" -passes="$EXPORT_PASS" --graph-export-path="$EXPORT_GRAPH" -disable-output "$SUBJECT_BC"
opt -load-pass-plugin "$PASSES_LIB" -passes="$EXPORT_PASS" --graph-export-path="$EXPORT_GRAPH" -disable-output "$SUBJECT_BC"

out_msg "Exported graph: $EXPORT_GRAPH"

#########################################
# IMPORT GRAPH AND GENERATE VARIANT PLANS
#########################################
out_msg_separator
out_msg "RUNNING variant generator"
cd "$PYTHON_DIR"
# shellcheck source=/dev/null
source .venv/bin/activate
python3 -m variant_generator.generate_variants "$ROOT" "$CONFIG_PATH"
out_msg "Variants plans generated"
cd "$ROOT"

#########################################
# APPLY VARIANT PLANS
#########################################
out_msg_separator
out_msg "APLLYING variant plans to subject"

PLANS_DIR="$EXPERIMENT_DIR/plans"
BC_DIR="$EXPERIMENT_DIR/bitcode"
BIN_DIR="$EXPERIMENT_DIR/variants"
mkdir -p "$BC_DIR"
mkdir -p "$BIN_DIR"

COMP_PASS_COUNT=0
COMP_FAIL_COUNT=0
for PLAN_FILE in "$PLANS_DIR"/*.json; do
    VARIANT_ID="$(basename "$PLAN_FILE" .json)"
    VARIANT_BC="$BC_DIR/$VARIANT_ID.bc"
    VARIANT_BIN="$BIN_DIR/$VARIANT_ID"
    opt -load-pass-plugin "$PASSES_LIB" -passes="${TRANSFORM_PASS},instcombine" --plan-file-path="$PLAN_FILE" -o $VARIANT_BC "$SUBJECT_BC"
    if "$COMPILER" "$VARIANT_BC" -o "$VARIANT_BIN" 2>&1; then
        COMP_PASS_COUNT=$((COMP_PASS_COUNT + 1))
    else
        COMP_FAIL_COUNT=$((COMP_FAIL_COUNT + 1))
    fi
done    

echo "SUCCESSFULLY compiled: $COMP_PASS_COUNT"
echo "FAILED to compile: $COMP_FAIL_COUNT"


out_msg "==================== ENDING $SCRIPT_NAME ===================="