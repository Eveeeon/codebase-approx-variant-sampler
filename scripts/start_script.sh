#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJ_CONFIG_PATH="$ROOT/config/project_config.toml"
EXP_CONFIG_PATH="$ROOT/config/experiment_config.toml"
LOG_FILE="$ROOT/logs/$SCRIPT_NAME.log"

# Load helpers
# shellcheck source=/dev/null
source "$SCRIPT_DIR/helpers.sh"