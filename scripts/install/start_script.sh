#!/usr/bin/env bash
set -euo pipefail

# SUBDIRECTORY BOOTSTRAPPER
# Runs the main start_script.sh in the scripts directory
# Scripts in each dir are unaware of their location except from the start scripts

# Used at the start of every script to find the root directory and load helpers
# Call after setting the SCRIPT_NAME

THIS_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SCRIPT_DIR="$(cd "$THIS_DIR/.." && pwd)"
# Run main start script
# shellcheck source=/dev/null
source "$SCRIPT_DIR/start_script.sh"