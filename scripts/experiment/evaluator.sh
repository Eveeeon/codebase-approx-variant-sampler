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
OUT_DIR="$ROOT/$(toml_get "$PROJ_CONFIG_PATH" "out")"

# EXPERIMENT CONFIG
SUBJECT_PROJ_NAME="$(toml_get "$EXP_CONFIG_PATH" "source_project_name")"
ENRG_BRG_INTERVAL="$(toml_get "$EXP_CONFIG_PATH" "enrg_brg_interval")"
EXPERIMENT_ID="$(toml_get "$EXP_CONFIG_PATH" "id")"
STDOUT_FILE_TYPE="$(toml_get "$EXP_CONFIG_PATH" "stdout_file_type")"
STDERR_FILE_TYPE="$(toml_get "$EXP_CONFIG_PATH" "stderr_file_type")"
REPEAT_VARIANT="$(toml_get "$EXP_CONFIG_PATH" "repeat_variant")"
REPEAT_EVALUATION="$(toml_get "$EXP_CONFIG_PATH" "repeat_evaluation")"
PAUSE="$(toml_get "$EXP_CONFIG_PATH" "pause_between_variants")"
TIMEOUT="$(toml_get "$EXP_CONFIG_PATH" "execution_timeout")"


# BUILD EXPERIMENT DIRECTORY
EXPERIMENT_DIR="$OUT_DIR/experiments/$EXPERIMENT_ID"
EXP_BINARY_DIR="$EXPERIMENT_DIR/binary"
EXP_BITCODE_DIR="$EXPERIMENT_DIR/bitcode"
EXP_EX_CMD_DIR="$EXPERIMENT_DIR/execution_commands"
EXP_ENERGY_DIR="$EXPERIMENT_DIR/energy"
EXP_PLAN_DIR="$EXPERIMENT_DIR/plans"
EXP_STDOUT_DIR="$EXPERIMENT_DIR/stdout"
EXP_STDERR_DIR="$EXPERIMENT_DIR/stderr"

out_msg_separator
out_msg "==================== STARTING $SCRIPT_NAME ===================="

#########################################
# EVALUATION FILES
#########################################
NUM_VARIANT="$(ls -1 "$EXP_EX_CMD_DIR" | wc -l)"
out_msg "EVALUATING $NUM_VARIANT vartiants of $SUBJECT_PROJ_NAME for experiment $EXPERIMENT_ID"

#########################################
# EXECUTE AND MEASURE BINARY OUTPUT
# OUTPUT
#########################################
out_msg_separator
out_msg "EVALUATING output of the variants"
out_msg "EXECUTING binary command strings directly, sending stdout to file"
out_msg "Timeout per execution: $TIMEOUT"
RUN_COUNT=0
out_msg "Output Evaluation ~~ Complete: $RUN_COUNT/$NUM_VARIANT"
for COMMAND_FILE in "$EXP_EX_CMD_DIR"/*; do
    VARIANT_ID="$(basename "$COMMAND_FILE" .sh)"
    STDOUT_FILE="$EXP_STDOUT_DIR/$VARIANT_ID.$STDOUT_FILE_TYPE"
    STDERR_FILE="$EXP_STDERR_DIR/$VARIANT_ID.$STDERR_FILE_TYPE"
    timeout "$TIMEOUT" "$COMMAND_FILE" > "$STDOUT_FILE" 2> "$STDERR_FILE" || true
    RUN_COUNT=$((RUN_COUNT + 1))
    if [ $((RUN_COUNT % 25)) -eq 0 ]; then 
        out_msg "Output Evaluation ~~ Complete: $RUN_COUNT/$NUM_VARIANT"
    fi
done
out_msg "Output Evaluation ~~ Complete: $RUN_COUNT/$NUM_VARIANT"


#########################################
# EXECUTE AND MEASURE BINARY ENERGY
# ENERGY
#########################################
out_msg_separator
out_msg "EVALUATING energy of the variant output"
out_msg "EXECUTING binary command strings through EnergiBridge, without capturing stdout"

function run_repeated() {
    local COMMAND_FILE
    local REPEATS

    COMMAND_FILE="$1"
    REPEATS="$2"
    for i in $(seq 1 "$REPEATS"); do
        bash "$COMMAND_FILE"
    done
}

TIMEOUT_FOR_REPEATS=$((TIMEOUT * REPEAT_VARIANT))

out_msg "Energy Evaluation ~~ $REPEAT_EVALUATION repeat evaluations of $REPEAT_VARIANT executions of $NUM_VARIANT variants"

CURRENT_EVAL=1
for i in $(seq 1 "$REPEAT_EVALUATION"); do
    CURRENT_EVAL_DIR="$EXP_ENERGY_DIR/$CURRENT_EVAL"
    mkdir -p "$CURRENT_EVAL_DIR"
    
    VARIANT_RUN_COUNT=0
    out_msg "Energy Evalutaion $CURRENT_EVAL of $REPEAT_EVALUATION ~~ ~~ ~~ ~~"
    for COMMAND_FILE in $(find "$EXP_EX_CMD_DIR" -maxdepth 1 -type f | shuf); do
        VARIANT_ID="$(basename "$COMMAND_FILE" .sh)"
        # Pause for a cooldown between variants
        sleep "$PAUSE"
        # Execute
        "$ENRG_BRG_BIN" -o  "$CURRENT_EVAL_DIR/$VARIANT_ID.csv" \
            -i "$ENRG_BRG_INTERVAL" \
            -m "$TIMEOUT_FOR_REPEATS" \
            bash -c "$(declare -f run_repeated); run_repeated '$COMMAND_FILE' '$REPEAT_VARIANT' >/dev/null 2>&1"
        VARIANT_RUN_COUNT=$((VARIANT_RUN_COUNT + 1))
        if [ $((VARIANT_RUN_COUNT % 25)) -eq 0 ]; then 
            out_msg "Energy Evaluation $CURRENT_EVAL of $REPEAT_EVALUATION ~~ Variants Complete: $VARIANT_RUN_COUNT/$NUM_VARIANT"
        fi
    done
    out_msg "Energy Evaluation $CURRENT_EVAL of $REPEAT_EVALUATION ~~ Variants Complete: $VARIANT_RUN_COUNT/$NUM_VARIANT"
    CURRENT_EVAL=$((CURRENT_EVAL +1))
done

out_msg "==================== ENDING $SCRIPT_NAME ===================="