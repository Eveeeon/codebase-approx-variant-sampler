#!/usr/bin/env bash
set -e

ROOT=$(dirname "$(realpath "$0")")/..
cd "$ROOT"

mkdir -p cpp/build
mkdir -p out/export
mkdir -p out/bitcode
mkdir -p out/experiments

#########################################
# Build LLVM passes
#########################################

cmake -S cpp \
      -B cpp/build \
      -DLLVM_DIR=/usr/lib/llvm-18/lib/cmake/llvm

cmake --build cpp/build

#########################################
# Compile subject
#########################################

clang -emit-llvm -O1 \
    -c subject/SimpleCode.cpp \
    -o out/bitcode/original.bc

#########################################
# Export graph
#########################################

opt \
    -load-pass-plugin cpp/build/passes/FPApprox.so \
    -passes="export-graph" \
    -disable-output \
    out/bitcode/original.bc

#########################################
# Generate experiment
#########################################

python3 -m variant_generator.generate_plan