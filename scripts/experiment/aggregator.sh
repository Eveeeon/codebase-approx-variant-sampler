#!/usr/bin/env bash
set -euo pipefail

#########################################
# GLOBAL
#########################################

SCRIPT_NAME="aggregator"
THIS_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
START_SCRIPT="$THIS_DIR/start_script.sh"
# Bootstap global paths and helpers through the start script
# shellcheck source=/dev/null
source "$START_SCRIPT"

#########################################
# READ CONFIG
#########################################

# PATHS
PYTHON_DIR="$ROOT/$(toml_get "$PROJ_CONFIG_PATH" "python_dir")"

out_msg_separator
out_msg "==================== STARTING $SCRIPT_NAME ===================="

#########################################
# AGGREGATE OUTPUT
#########################################
out_msg_separator
out_msg "AGGREGATING OUTPUT"
cd "$PYTHON_DIR"
# shellcheck source=/dev/null
source .venv/bin/activate
run_code python3 -m aggregator.consolidate_output "$ROOT" "$PROJ_CONFIG_PATH" "$EXP_CONFIG_PATH" "$LOG_FILE"
cd "$ROOT"

out_msg "==================== ENDING $SCRIPT_NAME ===================="