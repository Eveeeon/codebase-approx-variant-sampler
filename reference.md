# Quick Temp Commands

## 1 build passes
cd ~/Projects/codebase-approx-variant-sampler
rm -rf build && mkdir build && cd build
cmake .. -DLLVM_DIR=/usr/lib/llvm-18/lib/cmake/llvm
make
cd ../

## 2 compile code to bitcode
clang -emit-llvm -O1 -c SimpleCode.cpp -o SimpleCode.bc

## 3 run graph export pass
opt -load-pass-plugin ./build/passes/FPApprox.so \
    -passes="export-graph" -disable-output SimpleCode.bc

## 4 python logic to generate plan

## 5 apply changes from plan and instcombine to remove redundant casts
opt -load-pass-plugin ./build/passes/FPApprox.so \
    -passes="reduce-precision,instcombine" SimpleCode.bc -o SimpleCode_mutated.bc

## 6 compile mutated bitcode to a binary
clang SimpleCode_mutated.bc -o SimpleCode_mutated



cd ~/Projects/codebase-approx-variant-sampler
rm -rf build
mkdir build
cd build
cmake .. -DLLVM_DIR=/usr/lib/llvm-18/lib/cmake/llvm
make
cd ../
clang -emit-llvm -O0 -c ~/Projects/codebase-approx-variant-sampler/SimpleCode.cpp -o ~/Projects/codebase-approx-variant-sampler/SimpleCode.bc
opt -load-pass-plugin ./build/passes/FPApprox.so -O1 -disable-output ./SimpleCode.bc



# Guide

## 1 build passes
cd ~/Projects/codebase-approx-variant-sampler
rm -rf build && mkdir build && cd build
cmake .. -DLLVM_DIR=/usr/lib/llvm-18/lib/cmake/llvm
make
cd ../

## 2 compile code to bitcode
clang -emit-llvm -O0 -c SimpleCode.cpp -o SimpleCode.bc

## 3 run graph export pass
opt -load-pass-plugin ./build/passes/FPApprox.so \
    -passes="export-graph" -disable-output SimpleCode.bc

## 4 python logic to generate plan

## 5 apply changes from plan and instcombine to remove redundant casts
opt -load-pass-plugin ./build/passes/FPApprox.so \
    -passes="reduce-precision,instcombine" SimpleCode.bc -o SimpleCode_mutated.bc

## 6 compile mutated bitcode to a binary
clang SimpleCode_mutated.bc -o SimpleCode_mutated


# Dependencies
sudo apt install llvm clang


# Examples
Basic implementation:
https://github.com/banach-space/llvm-tutor/blob/main/HelloWorld/HelloWorld.cpp
Skeleton:
https://github.com/sampsyo/llvm-pass-skeleton
Template:


# References

## Get Instruction Operands
https://llvm.org/doxygen/classllvm_1_1User.html

## Create truncated FP
https://llvm.org/doxygen/classllvm_1_1IRBuilderBase.html#a3daad285be67a14ff0a10d520966486d

## Create binary operation
https://llvm.org/doxygen/classllvm_1_1BinaryOperator.html#a8f385eda0f71b4e8199b296fbc8e0da9

## Insert Instruction
https://llvm.org/doxygen/classllvm_1_1Instruction.html

## Replace operations
https://llvm.org/docs/ProgrammersManual.html#making-simple-changes

## Remove redudant ops
https://llvm.org/docs/Passes.html#instcombine-combine-redundant-instructions