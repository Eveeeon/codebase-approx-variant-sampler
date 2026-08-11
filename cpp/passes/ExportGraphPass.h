#pragma once

#include "llvm/IR/PassManager.h"

struct ExportGraphPass
    : public llvm::PassInfoMixin<ExportGraphPass> {

    llvm::PreservedAnalyses run(
        llvm::Module &M,
        llvm::ModuleAnalysisManager &MAM);
};