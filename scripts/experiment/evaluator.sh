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
ENRG_BRG_BIN="$ROOT/$(toml_get "$PROJ_CONFIG_PATH" "enrg_brg_install_dir")/energibridge"

# EXPERIMENT CONFIG
SUBJECT_PROJ_NAME="$(toml_get "$EXP_CONFIG_PATH" "source_project_name")"
ENRG_BRG_INTERVAL="$(toml_get "$EXP_CONFIG_PATH" "enrg_brg_interval")"
EXPERIMENT_ID="$(toml_get "$EXP_CONFIG_PATH" "id")"
STDOUT_FILE_TYPE="$(toml_get "$EXP_CONFIG_PATH" "stdout_file_type")"
REPEAT_VARIANT="$(toml_get "$EXP_CONFIG_PATH" "repeat_variant")"
REPEAT_EVALUATION="$(toml_get "$EXP_CONFIG_PATH" "repeat_evaluation")"

# BUILD EXPERIMENT DIRECTORY
EXPERIMENT_DIR="$OUT_DIR/experiments/$EXPERIMENT_ID"
EXP_BINARY_DIR="$EXPERIMENT_DIR/binary"
EXP_BITCODE_DIR="$EXPERIMENT_DIR/bitcode"
EXP_EX_CMD_DIR="$EXPERIMENT_DIR/execution_commands"
EXP_ENERGY_DIR="$EXPERIMENT_DIR/energy"
EXP_PLAN_DIR="$EXPERIMENT_DIR/plans"
EXP_STDOUT_DIR="$EXPERIMENT_DIR/stdout"

out_msg_separator
out_msg "==================== STARTING $SCRIPT_NAME ===================="

#########################################
# EVALUATION FILES
#########################################
NUM_FILES="$(ls -1 "$EXP_EX_CMD_DIR" | wc -l)"
out_msg "EVALUATING $NUM_FILES vartiants of $SUBJECT_PROJ_NAME for experiment $EXPERIMENT_ID"

#########################################
# EXECUTE AND MEASURE BINARY OUTPUT
# OUTPUT
#########################################
out_msg "EVALUATING output of the variant output"
out_msg "EXECUTING binary command strings directly"

RUN_COUNT=0
out_msg "Evaluated: $RUN_COUNT/$NUM_FILES"
for COMMAND_FILE in "$EXP_EX_CMD_DIR"/*; do
    VARIANT_ID="$(basename "$COMMAND_FILE" .)"
    STDOUT_FILE="$EXP_STDOUT_DIR/$VARIANT_ID.$STDOUT_FILE_TYPE"
    "$COMMAND_FILE" > "$STDOUT_FILE"
    RUN_COUNT=$((RUN_COUNT + 1))
    if [ $((RUN_COUNT % 100)) -eq 0 ]; then 
        out_msg "Completed: $RUN_COUNT/$NUM_FILES"
    fi
done
out_msg "Completed evaluation of output of $RUN_COUNT variants"


#########################################
# EXECUTE AND MEASURE BINARY ENERGY
# ENERGY
#########################################
out_msg "EVALUATING output of the variant output"
out_msg "EXECUTING binary command strings directly"

run_repeated() {
    local COMMAND_FILE
    local REPEATS

    COMMAND_FILE="$1"
    REPEATS="$2"
    for i in $(seq 1 "$REPEATS"); do
        bash "$COMMAND_FILE"
    done
}

EVAL_RUN_COUNT=0
for i in $(seq 1 "$REPEAT_EVALUATION"); do
    VARIANT_RUN_COUNT=0
    out_msg "Evaluated: $RUN_COUNT/$NUM_FILES"
    for COMMAND_FILE in $(find "$EXP_EX_CMD_DIR" -maxdepth 1 -type f | shuf); do
        VARIANT_ID="$(basename "$COMMAND_FILE" .)"
        "$ENRG_BRG_BIN" -o  "$EXP_ENERGY_DIR/$VARIANT_ID.csv"\
            -i "$ENRG_BRG_INTERVAL"  \
            - bash -c "$(declare -f run_repeated); run_repeated '$COMMAND_FILE' '$REPEAT_VARIANT'"
        VARIANT_RUN_COUNT=$((VARIANT_RUN_COUNT + 1))
        if [ $((VARIANT_RUN_COUNT % 100)) -eq 0 ]; then 
            out_msg "Completed: $RUN_COUNT/$NUM_FILES of variant in evaluation $EVAL_RUN_COUNT of $REPEAT_EVALUATION"
        fi
        out_msg "Completed: $RUN_COUNT/$NUM_FILES of variant in evaluation $EVAL_RUN_COUNT of $REPEAT_EVALUATION"
    done
    EVAL_RUN_COUNT=$((EVAL_RUN_COUNT +1))
    out_msg "Completed evaluation of output of $EVAL_RUN_COUNT variants"
done

for CMD_FILE in $(find "$COMMAND_DIR" -maxdepth 1 -type f | shuf); do
    echo "$CMD_FILE"
    VARIANT_ID="$(basename "$CMD_FILE" .)"
    "$ENRG_BRG_BIN" -o  "$ENERGY_DIR/$VARIANT_ID.csv" -i "$ENRG_BRG_INTERVAL" "$CMD_FILE"
done




out_msg "==================== ENDING $SCRIPT_NAME ===================="