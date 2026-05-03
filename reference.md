# Quick Temp Commands

cd ~/Projects/codebase-approx-variant-sampler
rm -rf build
mkdir build
cd build
cmake .. -DLLVM_DIR=/usr/lib/llvm-18/lib/cmake/llvm
make

clang -emit-llvm -O1 -c ~/Projects/codebase-approx-variant-sampler/SimpleCode.cpp -o ~/Projects/codebase-approx-variant-sampler/SimpleCode.bc
opt -load-pass-plugin ./build/passes/FPApprox.so -O1 -disable-output ./SimpleCode.bc


# Build Pass Plugin
cd ~/.../codebase-approx-variant-sampler
mkdir build
cd build
cmake .. -DLLVM_DIR=/usr/lib/llvm-18/lib/cmake/llvm
make


# Run IR
clang -emit-llvm -O1 -c ~/Projects/codebase-approx-variant-sampler/SimpleCode.cpp -o ~/Projects/codebase-approx-variant-sampler/SimpleCode.bc
opt -load-pass-plugin ./build/passes/FPApprox.so -O1 -disable-output ./SimpleCode.bc

# Examples
Basic implementation:
https://github.com/banach-space/llvm-tutor/blob/main/HelloWorld/HelloWorld.cpp
Skeleton:
https://github.com/sampsyo/llvm-pass-skeleton
Template:
