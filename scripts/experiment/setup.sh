#!/usr/bin/env bash
set -euo pipefail

#########################################
# GLOBAL
#########################################

SCRIPT_NAME="create_variants"
THIS_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
START_SCRIPT="$THIS_DIR/start_script.sh"
# Bootstap global paths and helpers through the start script
# shellcheck source=/dev/null
source "$START_SCRIPT"
out_msg_separator
out_msg "==================== STARTING $SCRIPT_NAME ===================="
out_msg "Root directory: $ROOT"

#########################################
# READ CONFIG
#########################################
out_msg "READING config"

# PATHS
LLVM_DIR="$ROOT/$(toml_get "$PROJ_CONFIG_PATH" "llvm_dir")"
CPP_BUILD_DIR="$ROOT/$(toml_get "$PROJ_CONFIG_PATH" "cpp_build_dir")"
PYTHON_DIR="$ROOT/$(toml_get "$PROJ_CONFIG_PATH" "python_dir")"

#########################################
# CREATING OUT DIR
#########################################
out_msg "CREATING out directories"
mkdir -p "out"
mkdir -p "out/experiments"
mkdir -p "out/subject_bitcode" 
mkdir -p "out/export"

#########################################
# SETUP PYTHON VENV
#########################################
out_msg_separator
out_msg "CREATING python environment"

cd "$PYTHON_DIR"
if [ ! -d ".venv" ]; then
    python3 -m venv .venv
    out_msg "Created .venv"
fi

# shellcheck source=/dev/null
source .venv/bin/activate
pip install --upgrade pip --quiet
pip install -e . --quiet
pip install -r requirements.txt --quiet

out_msg "Python environment created"

#########################################
# BUILD LLVM PASSES
#########################################
out_msg_separator
out_msg "BUILDING llvm passes"

out_msg "CLEARING previous build"
rm -rf "$CPP_BUILD_DIR"
mkdir "$CPP_BUILD_DIR"

out_msg "Building..."
cd "$CPP_BUILD_DIR"
cmake .. -DLLVM_DIR="$LLVM_DIR"
make
cd "$ROOT"

#########################################
# ENERGIBRIDGE MSR read access
#########################################
out_msg "GRANTING read access to the MSR files for EnergiBridge measurement"
out_msg "must be run after every reboot"
sudo chgrp -R msr /dev/cpu/*/msr
sudo chmod g+r /dev/cpu/*/msr

out_msg "==================== ENDING $SCRIPT_NAME ===================="
