#include "llvm/Pass.h"
#include "llvm/IR/Module.h"
#include "llvm/Passes/PassBuilder.h"
#include "llvm/Passes/PassPlugin.h"
#include "llvm/Support/raw_ostream.h"

using namespace llvm;

namespace {

    // ExamplePass struct inherists from from PassInfoMixin<ExamplePass>
// PassInfoMixin<***> is a templated base class, instantiated with *** itself
// This is called CRTP (Curiously Recurring Template Pattern):
// The derived class is passed as a template parameter to its base class to provide shared functionality at compilation
struct ExamplePass : public PassInfoMixin<ExamplePass> {
    // PreservedAnalyses returns what analysis remains valid after any modification on the pass
    PreservedAnalyses run(Module &M, ModuleAnalysisManager &AM) {
        for (auto &F : M) {
            errs() << "I saw a function called " << F.getName() << "!\n";
        }
        return PreservedAnalyses::all();
    };
};

}

extern "C" LLVM_ATTRIBUTE_WEAK ::llvm::PassPluginLibraryInfo
llvmGetPassPluginInfo() {
    return {
        .APIVersion = LLVM_PLUGIN_API_VERSION,
        .PluginName = "Example Pass",
        .PluginVersion = "v0.1",
        .RegisterPassBuilderCallbacks = [](PassBuilder &PB) {
            PB.registerPipelineStartEPCallback(
                [](ModulePassManager &MPM, OptimizationLevel Level) {
                    MPM.addPass(ExamplePass());
                });
        }
    };
}
