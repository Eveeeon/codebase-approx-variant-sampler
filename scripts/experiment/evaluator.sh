#!/usr/bin/env bash
set -euo pipefail

#########################################
# GLOBAL
#########################################

SCRIPT_NAME="evaluator"
THIS_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
START_SCRIPT="$THIS_DIR/start_script.sh"
# Bootstap global paths and helpers through the start script
# shellcheck source=/dev/null
source "$START_SCRIPT"

#########################################
# READ CONFIG
#########################################
# PATHS
EXPERIMENT_DIR="$ROOT/$(toml_get "$PROJ_CONFIG_PATH" "experiments")/$(toml_get "$EXP_CONFIG_PATH" "id")"
ENRG_BRG_BIN="$ROOT/$(toml_get "$PROJ_CONFIG_PATH" "enrg_brg_install_dir")/energibridge"

# PROJECT CONFIG
COMPILER="$(toml_get "$PROJ_CONFIG_PATH" "llvm_compiler")"

# EXPERIMENT CONFIG
SUBJECT_PROJ_NAME="$(toml_get "$EXP_CONFIG_PATH" "source_project_name")"
ENRG_BRG_INTERVAL="$(toml_get "$EXP_CONFIG_PATH" "enrg_brg_interval")"
EXPERIMENT_ID="$(toml_get "$EXP_CONFIG_PATH" "id")"

# BUILD VARS FROM CONFIG
COMMAND_DIR="$EXPERIMENT_DIR/commands"
MEASUREMENT_DIR="$EXPERIMENT_DIR/measurements"

out_msg_separator
out_msg "==================== STARTING $SCRIPT_NAME ===================="

#########################################
# EXECUTE AND MEASURE BINARIES
#########################################
out_msg_separator
out_msg "EXECUTING binary command strings through EnergiBridge"


for BINARY_FILE in "$COMMAND_DIR"/*; do
    VARIANT_ID="$(basename "$BINARY_FILE")"
    run_code "$ENRG_BRG_BIN" -o  "$MEASUREMENT_DIR/$VARIANT_ID.csv" -i "$ENRG_BRG_INTERVAL" "$BINARY_FILE"
done




out_msg "==================== ENDING $SCRIPT_NAME ===================="