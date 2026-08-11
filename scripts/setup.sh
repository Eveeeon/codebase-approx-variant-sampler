#!/usr/bin/env bash
set -euo pipefail

#########################################
# GLOBAL
#########################################

SCRIPT_NAME="setup.sh"
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
PASSES_BUILD_DIR="$ROOT/$(toml_get "$CONFIG_PATH" "passes_build_dir")"
PASSES_LIB="$ROOT/$(toml_get "$CONFIG_PATH" "passes_library")"
PYTHON_DIR="$ROOT/$(toml_get "$CONFIG_PATH" "python_dir")"

#########################################
# CREATING OUT DIR
#########################################
out_msg "CREATING out directories"
mkdir -p "out"
mkdir -p "out/experiments"
mkdir -p "out/bitcode" 
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

out_msg "==================== ENDING $SCRIPT_NAME ===================="

# # clean previous build
# rm -rf $CPP_BUILD_DIR
# mkdir $CPP_BUILD_DIR

# # build C++
# cd "$CPP_BUILD_DIR"
# cmake .. -DLLVM_DIR="$LLVM_DIR"
# make
# cd $ROOT



# mkdir -p "$CPP_BUILD_DIR"
# cd "$CPP_BUILD_DIR"

# cmake "$ROOT/cpp" \
#     -DLLVM_DIR="$LLVM_DIR" \
#     -DCMAKE_BUILD_TYPE=Release

# make -j"$(nproc)"

# cd ~/Projects/codebase-approx-variant-sampler
# rm -rf build
# mkdir build
# cd build
# cmake .. -DLLVM_DIR=/usr/lib/llvm-18/lib/cmake/llvm
# make
# cd ../
# clang -emit-llvm -O0 -c ~/Projects/codebase-approx-variant-sampler/SimpleCode.cpp -o ~/Projects/codebase-approx-variant-sampler/SimpleCode.bc
# opt -load-pass-plugin ./build/passes/FPApprox.so -O1 -disable-output ./SimpleCode.bc


# ENERGIBRIDGE_VERSION=v0.0.7

# wget \
#   https://github.com/tdurieux/EnergiBridge/releases/download/v0.0.7/energibridge-v0.0.7-x86_64-unknown-linux-musl.tar.gz
# tar -xzf energibridge-v0.0.7-x86_64-unknown-linux-musl.tar.gz

# sudo mv energibridge /usr/local/bin/
# sudo chmod +x /usr/local/bin/energibridge