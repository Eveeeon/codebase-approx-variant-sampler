#!/usr/bin/env bash
set -euo pipefail

#########################################
# GLOBAL
#########################################

SCRIPT_NAME="variant_generator"
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
PYTHON_DIR="$ROOT/$(toml_get "$PROJ_CONFIG_PATH" "python_dir")"
EXPORT_GRAPH="$ROOT/$(toml_get "$PROJ_CONFIG_PATH" "export_graph")"

# PROJECT CONFIG
COMPILER="$(toml_get "$PROJ_CONFIG_PATH" "llvm_compiler")"
EXPORT_PASS="$(toml_get "$PROJ_CONFIG_PATH" "export_pass")"
TRANSFORM_PASS="$(toml_get "$PROJ_CONFIG_PATH" "transform_pass")"

# EXPERIMENT CONFIG
SUBJECT_PROJ_NAME="$(toml_get "$EXP_CONFIG_PATH" "source_project_name")"
EXPERIMENT_ID="$(toml_get "$EXP_CONFIG_PATH" "id")"

# BUILD VARS FROM CONFIG
SUBJECT_BC="$SUBJECT_BC_DIR/$SUBJECT_PROJ_NAME.bc"

out_msg_separator
out_msg "==================== STARTING $SCRIPT_NAME ===================="

#########################################
# RUN EXPORT GRAPH PASS
#########################################
out_msg_separator
out_msg "RUNNING export pass"

#opt -load-pass-plugin "$PASSES_LIB" "-O1" -passes="$EXPORT_PASS" --graph-export-path="$EXPORT_GRAPH" -disable-output "$SUBJECT_BC"
opt -load-pass-plugin "$PASSES_LIB" -passes="$EXPORT_PASS" --graph-export-path="$EXPORT_GRAPH" -disable-output "$SUBJECT_BC"

out_msg "Exported graph: $EXPORT_GRAPH"

#########################################
# IMPORT GRAPH AND GENERATE VARIANT PLANS
#########################################
out_msg_separator
out_msg "CREATING variant plan files"
cd "$PYTHON_DIR"
# shellcheck source=/dev/null
source .venv/bin/activate
run_code python3 -m variant_generator.generate_variants "$ROOT" "$PROJ_CONFIG_PATH" "$EXP_CONFIG_PATH" "$LOG_FILE"
out_msg "Variants plans generated"
cd "$ROOT"

out_msg "==================== ENDING $SCRIPT_NAME ===================="