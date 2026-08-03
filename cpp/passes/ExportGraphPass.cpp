#include "llvm/Analysis/CallGraph.h"
#include "llvm/IR/DerivedTypes.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/Instruction.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/Module.h"
#include "llvm/IR/Type.h"
#include "llvm/Pass.h"
#include "llvm/Passes/PassBuilder.h"
#include "llvm/Passes/PassPlugin.h"
#include "llvm/Support/FileSystem.h"
#include "llvm/Support/JSON.h"
#include "llvm/Support/raw_ostream.h"
#include "llvm/Support/CommandLine.h"
#include <cmath>
#include <cstdlib>
#include <string>
#include <unordered_map>
#include <vector>

using namespace llvm;

// Arguments --------------------------------------------------------------

static cl::opt<std::string> GraphExportPath(
  "graph-export-path",
  cl::desc("Full path of the JSON export file from the export graph pass, including file name."),
  cl::value_desc("graphExportPath")
);

// Data structs --------------------------------------------------------------

struct FlopMeta {
  int flopId;
  int blockId;
  int funcId;
  std::string opCode;
  std::string fpType;
  std::vector<int> users;
  std::vector<int> inputs;
};

struct FuncMeta {
  int funcId;
  std::string name;
  std::vector<FlopMeta> flops;
  std::vector<int> callsFuncId;
};

// Helpers --------------------------------------------------------------

// out message helper
template <typename... rest> static void outMsg(const rest &...messages) {
  errs() << "ExportGraphPass";
  (errs() << ... << messages);
}

// check if an instruction is a floating point operation
static bool isFlop(Instruction &irInstr) {
  Type *irType = irInstr.getType();
  if (!irType) {
    return false;
  }
  if (irType->isFloatingPointTy()) {
    return true;
  }
  // check if it is a vector of floating point types
  if (auto *irVectType = dyn_cast<VectorType>(irType)) {
    if (irVectType->getElementType()->isFloatingPointTy()) {
      return true;
    }
  }
  return false;
}

// check if instruction is a binary operation
static bool isBinaryOp(Instruction &irInstr) {
  BinaryOperator *irBinOp = dyn_cast<BinaryOperator>(&irInstr);
  if (!irBinOp) {
    return false;
  }
  return true;
}

// check if an instruction is both a floating point and binary operation
static bool isBFlop(Instruction &irInstr) {
  if (isFlop(irInstr) && isBinaryOp(irInstr)) {
    return true;
  }
  return false;
}

// helper to get text of type name to place into plan JSON
static std::string nameFPType(Type *irType) {
  // typical types, add more to extend in future
  if (irType->isHalfTy()) {
    return "fp16";
  }
  if (irType->isFloatTy()) {
    return "fp32";
  }
  if (irType->isDoubleTy()) {
    return "fp64";
  }

  // handle vectors of floating point types
  FixedVectorType *vecType = dyn_cast<FixedVectorType>(irType);
  if (vecType) {
    // get type and number of elements
    Type *elemType = vecType->getElementType();
    unsigned numElements = vecType->getNumElements();
    std::string elemName = nameFPType(elemType);
    // type value is vec_length_type
    // e.g. vec_5_fp32
    return "vec_" + std::to_string(numElements) + "_" + elemName;
  }

  return "unhandled";
}

// Main logic --------------------------------------------------------------

// assign unique ids to each function
std::unordered_map<const Function *, int> assignFuncIds(Module &irModule) {
  std::unordered_map<const Function *, int> funcIdMap;
  int funcId = 0;
  for (auto &irFunc : irModule)
    // skip empty definitions
    if (!irFunc.isDeclaration()) {
      funcIdMap[&irFunc] = funcId;
      funcId++;
    }
  return funcIdMap;
}

// assign unique id to each floating point operation
std::unordered_map<const Instruction *, int>
assignFlopIds(Module &irModule,
              std::unordered_map<const Function *, int> &funcIdMap) {
  std::unordered_map<const Instruction *, int> flopIdMap;
  int flopId = 0;
  // traverse ir
  for (auto &irFunc : irModule) {
    // functions
    if (funcIdMap.count(&irFunc)) {
      // basic blocks
      for (auto &irBlock : irFunc) {
        // instructions
        for (auto &irInstr : irBlock) {
          if (isBFlop(irInstr)) {
            flopIdMap[&irInstr] = flopId;
          }
          // increment id regardless of it flop instruction so instruction ids
          // globally unique
          flopId++;
        }
      }
    }
  }
  return flopIdMap;
}

// create the funcmeta data containing the flopmetas
std::vector<FuncMeta>
buildFuncMetas(Module &irModule,
               std::unordered_map<const Function *, int> funcIdMap,
               std::unordered_map<const Instruction *, int> flopIdMap,
               CallGraph &irCallGraph) {
  // initialise
  std::vector<FuncMeta> functions;

  int blockId = 0;

  // traverse ir
  for (auto &irFunc : irModule) {
    // functions
    if (funcIdMap.count(&irFunc)) {
      // create new funcMeta
      int funcId = funcIdMap[&irFunc];
      FuncMeta funcMeta{funcId, irFunc.getName().str(), {}, {}};
      // get called function ids
      for (auto &irCall : *irCallGraph[&irFunc]) {
        const Function *irCalled = irCall.second->getFunction();
        if (funcIdMap.count(irCalled)) {
          funcMeta.callsFuncId.push_back(funcIdMap[irCalled]);
        }
      }
      // get flops
      // basic blocks
      for (auto &irBlock : irFunc) {
        // instructions
        for (auto &irInstr : irBlock) {
          if (flopIdMap.count(&irInstr)) {
            int flopId = flopIdMap[&irInstr];

            // get used-by edges, these expect the flop to be the original type,
            // this needs handling if this instruction is changed
            std::vector<int> users;
            for (auto *userVal : irInstr.users()) {
              Instruction *userInstr = dyn_cast<Instruction>(userVal);
              if (userInstr && flopIdMap.count(userInstr))
                users.push_back(flopIdMap[userInstr]);
            }

            // get input edges, the current instruction depends on these
            std::vector<int> inputs;
            for (auto &inputVal : irInstr.operands()) {
              Instruction *inputInstr = dyn_cast<Instruction>(inputVal);
              if (inputInstr && flopIdMap.count(inputInstr))
                inputs.push_back(flopIdMap[inputInstr]);
            }

            // BUILD META AND SCOPE LOCATION
            funcMeta.flops.push_back(
                {flopId, blockId, funcId,
                 std::string(Instruction::getOpcodeName(irInstr.getOpcode())),
                 nameFPType(irInstr.getType()), users, inputs});
          }
        }
        blockId++;
      }
      functions.push_back(funcMeta);
    }
  }
  return functions;
}

// Export --------------------------------------------------------------

void exportToJson(const std::string &moduleName,
                  std::vector<FuncMeta> &functions) {
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
      jsonFlop["users"] = flop.users;
      jsonFlop["inputs"] = flop.inputs;
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
  std::string filename = "fpgraph_pass_out.json";
  raw_fd_ostream out(GraphExportPath, outError, sys::fs::OF_Text);
  if (outError) {
    outMsg("Could not write to JSON: ", filename, "\n");
    return;
  }
  out << json::Value(std::move(jsonModule)) << "\n";
}

// Module and Plugin Definition
// --------------------------------------------------------------

// ExportGraphPass struct inherists from from PassInfoMixin<ExportGraphPass>
// PassInfoMixin<***> is a templated base class, instantiated with *** itself
// This is called CRTP (Curiously Recurring Template Pattern):
// The derived class is passed as a template parameter to its base class to
// provide shared functionality at compilation
struct ExportGraphPass : public PassInfoMixin<ExportGraphPass> {
  // PreservedAnalyses returns what analysis remains valid after any
  // modification on the pass
  PreservedAnalyses run(Module &irModule, ModuleAnalysisManager &irMAM) {
    auto &irCallGraph = irMAM.getResult<CallGraphAnalysis>(irModule);
    auto funcIdMap = assignFuncIds(irModule);
    auto flopIdMap = assignFlopIds(irModule, funcIdMap);
    auto funcs = buildFuncMetas(irModule, funcIdMap, flopIdMap, irCallGraph);
    exportToJson(irModule.getName().str(), funcs);
    outMsg("End\n");
    return PreservedAnalyses::all();
  }
};

extern "C" LLVM_ATTRIBUTE_WEAK ::llvm::PassPluginLibraryInfo
llvmGetPassPluginInfo() {
  return {.APIVersion = LLVM_PLUGIN_API_VERSION,
          .PluginName = "Export Graph Pass",
          .PluginVersion = "v0.1",
          .RegisterPassBuilderCallbacks = [](PassBuilder &PB) {
            PB.registerPipelineParsingCallback(
                [](StringRef Name, ModulePassManager &MPM,
                   ArrayRef<PassBuilder::PipelineElement>) {
                  if (Name == "export-graph") {
                    MPM.addPass(ExportGraphPass());
                    return true;
                  }
                  return false;
                });
          }};
}
