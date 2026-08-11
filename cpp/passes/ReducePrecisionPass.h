#pragma once

#include "llvm/IR/PassManager.h"

struct ReducePrecisionPass
    : public llvm::PassInfoMixin<ReducePrecisionPass> {

    llvm::PreservedAnalyses run(
        llvm::Module &M,
        llvm::ModuleAnalysisManager &MAM);
};