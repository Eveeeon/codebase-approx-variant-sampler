#include "ExportGraphPass.h"
#include "ReducePrecisionPass.h"

#include "llvm/Passes/PassBuilder.h"
#include "llvm/Passes/PassPlugin.h"

using namespace llvm;

extern "C" LLVM_ATTRIBUTE_WEAK PassPluginLibraryInfo
llvmGetPassPluginInfo() {

  return {
      LLVM_PLUGIN_API_VERSION,
      "FPApprox",
      "v0.1",

      [](PassBuilder &PB) {

        PB.registerPipelineParsingCallback(
            [](StringRef Name,
               ModulePassManager &MPM,
               ArrayRef<PassBuilder::PipelineElement>) {

              if (Name == "export-graph") {
                MPM.addPass(ExportGraphPass());
                return true;
              }

              if (Name == "reduce-precision") {
                MPM.addPass(ReducePrecisionPass());
                return true;
              }

              return false;
            });
      }};
}