#include "llvm/Pass.h"
#include "llvm/IR/Module.h"
#include "llvm/IR/Instructions.h"
#include "llvm/Passes/PassBuilder.h"
#include "llvm/Passes/PassPlugin.h"
#include "llvm/Support/raw_ostream.h"
#include "llvm/IR/Function.h"
#include "llvm/Analysis/CallGraph.h"
#include "llvm/Support/FileSystem.h"
#include "llvm/Support/JSON.h"
#include "llvm/Support/raw_ostream.h"
#include <map>
#include <cmath>
#include <cstdlib>
#include <vector>
#include <unordered_map>

using namespace llvm;

// Helpers --------------------------------------------------------------

static bool isFPOp(const Instruction &irInstr) {
    Type *irType = irInstr.getType();
    if (!irType) return false;
    if (irType->isFloatingPointTy()) return true;
    // check if it is a vector of floating point types
    if (auto *irVectType = dyn_cast<VectorType>(irType))
        if (irVectType->getElementType()->isFloatingPointTy()) return true;
    return false;
}

static std::string nameFPType(Type *irType) {
    // typical types, add more to extend in future
    if (irType->isHalfTy())   return "f16";
    if (irType->isFloatTy())  return "f32";
    if (irType->isDoubleTy()) return "f64";

    // handle vectors of floating point types
    FixedVectorType *vecType = dyn_cast<FixedVectorType>(irType);
    if (vecType) {
        // get type and number of elements
        Type *elemType = vecType->getElementType();
        unsigned numElements = vecType->getNumElements();
        std::string elemName = nameFPType(elemType);
        // type value is vec_length_type
        // e.g. vec_5_f32
        return "vec_" + std::to_string(numElements) + "_" + elemName ;
    }

    return "unhandled";
}
// Data structs --------------------------------------------------------------

struct FlopMeta {
    int flopId;
    int blockId;
    int funcId;
    std::string opCode;
    std::string fpType; 
};

struct FuncMeta {
    int funcId;
    std::string name;
    std::vector<FlopMeta> flops;
    std::vector<int> callsFuncId;
};


// Main logic --------------------------------------------------------------

// Assign unique ids to each function
std::unordered_map<const Function*, int> assignFuncIds(Module &irModule) {
    std::unordered_map<const Function*, int> funcIds;
    int funcId = 0;
    for (auto &irFunc : irModule)
        // skip empty definitions
        if (!irFunc.isDeclaration()) {
            funcIds[&irFunc] = funcId;
            funcId++;
        }
    return funcIds;
}

std::vector<FuncMeta> buildFuncMetas(Module &irModule, std::unordered_map<const Function*, int> funcIds, CallGraph &irCallGraph) {
    std::vector<FuncMeta> functions;
    int opId = 0;
    int blockId = 0;
    for (auto &irFunc : irModule) {
        // functions
        if (funcIds.count(&irFunc)) {
            // create new funcMeta
            int funcId = funcIds[&irFunc];
            FuncMeta funcMeta {
                funcId,
                irFunc.getName().str(),
                {},
                {}
            };
            // get called function ids
            for (auto &irCall : *irCallGraph[&irFunc]) {
                const Function *irCalled = irCall.second->getFunction();
                if (funcIds.count(irCalled)) {
                    funcMeta.callsFuncId.push_back(funcIds[irCalled]);
                }
            }
            // get flops
            // basic blocks
            for (auto &irBlock : irFunc) {
                // instructions
                for (auto &irInstr: irBlock) {
                    if (isFPOp(irInstr)) {
                        funcMeta.flops.push_back({
                            opId,
                            blockId,
                            funcId,
                            std::string(Instruction::getOpcodeName(irInstr.getOpcode())),
                            nameFPType(irInstr.getType())
                        });
                    }
                    // increment opId outside of check so ops are globally unique
                    opId ++;
                }
                blockId ++;
            }
            functions.push_back(funcMeta);
        }
    }
    return functions;
}

// Export --------------------------------------------------------------

void exportToJson(const std::string &moduleName, std::vector<FuncMeta> &functions) {
    json::Array jsonFunctions;
    // convert to json array of json objects
    for (auto &func : functions) {
        json::Array jsonCalls;
        for (int calledFuncId : func.callsFuncId) {
            jsonCalls.push_back(calledFuncId);
        }

        json::Array jsonFlops;
        for (FlopMeta &flop : func.flops) {
            json::Object jsonFlop;
            jsonFlop["flopId"] = flop.flopId;
            jsonFlop["blockId"] = flop.blockId;
            jsonFlop["funcId"] = flop.funcId;
            jsonFlop["opCode"] = flop.opCode;
            jsonFlop["fpType"] = flop.fpType;
            jsonFlops.push_back(std::move(jsonFlop));
        }

        json::Object jsonFunc;
        jsonFunc["funcId"] = func.funcId;
        jsonFunc["name"] = func.name;
        jsonFunc["calls"] = std::move(jsonCalls);
        jsonFunc["flops"] = std::move(jsonFlops);
        jsonFunctions.push_back(std::move(jsonFunc));
    }
    json::Object jsonModule;
    jsonModule["name"] = moduleName;
    jsonModule["functions"] = std::move(jsonFunctions);
    
    std::error_code outError;
    raw_fd_ostream out("fpgraph_pass_out.json", outError, sys::fs::OF_Text);
    if (outError) {
        errs() << "Could not write to JSON\n";
        return;
    }
    out << json::Value(std::move(jsonModule)) << "\n";
}


// ExportGraphPass struct inherists from from PassInfoMixin<ExportGraphPass>
// PassInfoMixin<***> is a templated base class, instantiated with *** itself
// This is called CRTP (Curiously Recurring Template Pattern):
// The derived class is passed as a template parameter to its base class to provide shared functionality at compilation
struct ExportGraphPass : public PassInfoMixin<ExportGraphPass> {
    // PreservedAnalyses returns what analysis remains valid after any modification on the pass
    PreservedAnalyses run(Module &irModule, ModuleAnalysisManager &irMAM) {
        auto &irCallGraph = irMAM.getResult<CallGraphAnalysis>(irModule);
        auto funcIds = assignFuncIds(irModule);
        auto funcs = buildFuncMetas(irModule, funcIds, irCallGraph);
        exportToJson(irModule.getName().str(), funcs);
        return PreservedAnalyses::all();
    }
};

extern "C" LLVM_ATTRIBUTE_WEAK ::llvm::PassPluginLibraryInfo
llvmGetPassPluginInfo() {
    return {
        .APIVersion = LLVM_PLUGIN_API_VERSION,
        .PluginName = "Export Graph Pass",
        .PluginVersion = "v0.1",
        .RegisterPassBuilderCallbacks = [](PassBuilder &PB) {
            PB.registerPipelineStartEPCallback(
                [](ModulePassManager &MPM, OptimizationLevel Level) {
                    MPM.addPass(ExportGraphPass());
                });
        }
    };
}
