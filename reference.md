# Quick Temp Commands

cd ~/Projects/codebase-approx-variant-sampler
rm -rf build
mkdir build
cd build
cmake .. -DLLVM_DIR=/usr/lib/llvm-18/lib/cmake/llvm
make
cd ../
clang -emit-llvm -O1 -c ~/Projects/codebase-approx-variant-sampler/SimpleCode.cpp -o ~/Projects/codebase-approx-variant-sampler/SimpleCode.bc
opt -load-pass-plugin ./build/passes/FPApprox.so -O1 -disable-output ./SimpleCode.bc


below has calls correctly
cd ~/Projects/codebase-approx-variant-sampler
rm -rf build
mkdir build
cd build
cmake .. -DLLVM_DIR=/usr/lib/llvm-18/lib/cmake/llvm
make
cd ../
clang -emit-llvm -O0 -c ~/Projects/codebase-approx-variant-sampler/SimpleCode.cpp -o ~/Projects/codebase-approx-variant-sampler/SimpleCode.bc
opt -load-pass-plugin ./build/passes/FPApprox.so -O1 -disable-output ./SimpleCode.bc




# Dont use

opt -load-pass-plugin ./build/passes/FPApprox.so \
    -passes="fp-collector" \
    -disable-output ./SimpleCode.bc
cd ~/Projects/codebase-approx-variant-sampler
opt -load-pass-plugin ./build/passes/FPApprox.so \
    -passes="fp-collector" \
    -disable-output ./SimpleCode.bc

cat fp_ops.json

opt -dot-callgraph SimpleCode.bc
dot -Tpng callgraph.dot -o callgraph.png

opt -view-callgraph SimpleCode.bc


# First compile something to bitcode
clang -O0 -emit-llvm -c SimpleCode.cpp -o SimpleCode.cpp

# Run the pass
opt -load-pass-plugin ./build/passes/FPApprox.so \
    -passes="fp-collector" \
    your_file.bc -o /dev/null

# Check the output
cat fp_ops.json

# Dependencies
sudo apt install llvm clang

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
