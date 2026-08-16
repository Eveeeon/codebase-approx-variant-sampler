#!/usr/bin/env bash
set -euo pipefail

#########################################
# GLOBAL
#########################################

SCRIPT_NAME="setup"
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
ENRG_BRG_BIN="$ROOT/$(toml_get "$PROJ_CONFIG_PATH" "enrg_brg_install_dir")/energibridge"
OUT_DIR="$ROOT/$(toml_get "$PROJ_CONFIG_PATH" "out")"

# BUILD OUT DIRECTORY
OUT_EXP_DIR="$ROOT/$OUT_DIR/$(toml_get "$PROJ_CONFIG_PATH" "experiments_dir")"
OUT_BC_DIR="$ROOT/$OUT_DIR/$(toml_get "$PROJ_CONFIG_PATH" "subject_bc_dir")"
OUT_GRAPH_DIR="$ROOT/$OUT_DIR/$(toml_get "$PROJ_CONFIG_PATH" "export_graph_dir")"

# EXPERIMENT CONFIG
EXPERIMENT_ID="$(toml_get "$EXP_CONFIG_PATH" "id")"

# BUILD EXPERIMENT DIRECTORY
EXPERIMENT_DIR="$OUT_DIR/experiments/$EXPERIMENT_ID"
EXP_BINARY_DIR="$EXPERIMENT_DIR/binary"
EXP_BITCODE_DIR="$EXPERIMENT_DIR/bitcode"
EXP_EX_CMD_DIR="$EXPERIMENT_DIR/execution_commands"
EXP_ENERGY_DIR="$EXPERIMENT_DIR/energy"
EXP_PLAN_DIR="$EXPERIMENT_DIR/plans"
EXP_STDOUT_DIR="$EXPERIMENT_DIR/stdout"

#########################################
# CREATING OUT DIR
#########################################
out_msg "CREATING out directories"
mkdir -p "$OUT_EXP_DIR"
mkdir -p "$OUT_BC_DIR"
mkdir -p "$OUT_GRAPH_DIR" 


out_msg "CREATING $EXPERIMENT_DIR, removing any previous runs"
rm -rf "$EXPERIMENT_DIR"
mkdir -p "$EXP_BINARY_DIR"
mkdir -p "$EXP_BITCODE_DIR"
mkdir -p "$EXP_EX_CMD_DIR"
mkdir -p "$EXP_ENERGY_DIR"
mkdir -p "$EXP_PLAN_DIR"
mkdir -p "$EXP_STDOUT_DIR"

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
out_msg_separator
out_msg "GRANTING group access"

out_msg "GRANTING read access to the MSR files for EnergiBridge measurement"
out_msg "must be run after every reboot"

if ! [ "$(getent group msr)" ]; then
    out_msg "CREATING msr system group"
    sudo groupadd --system msr
else
    out_msg "msr group already exists"
fi

if ! id -nG "$USER" | grep -qw msr; then
    out_msg "Adding user '$USER' to msr system group"
    sudo usermod -aG msr "$USER"
    out_msg "RESTARTING '$USER' SESSION in order for group addition to be applied"
    exec su -l "$USER"
else
    out_msg "User '$USER' is already a member of the msr group"
fi

out_msg "LOADING msr kernal module"
sudo modprobe msr


if ! compgen -G "/dev/cpu/*/msr"; then
    out_msg "ERROR: Could not find msr device files, something went wrong..."
    exit 1
else
    out_msg "SETTING msr device file ownership to the msr group"
    sudo chgrp msr /dev/cpu/*/msr
    sudo chmod g+r /dev/cpu/*/msr
fi


out_msg "GRANTING the EnergiBridge binary low-level harware permissions"
sudo setcap cap_sys_rawio=ep "$ENRG_BRG_BIN"

out_msg "==================== ENDING $SCRIPT_NAME ===================="
