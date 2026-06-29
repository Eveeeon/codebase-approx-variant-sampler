#include "llvm/IR/IRBuilder.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/Module.h"
#include "llvm/Passes/PassBuilder.h"
#include "llvm/Passes/PassPlugin.h"
#include "llvm/Support/JSON.h"
#include "llvm/Support/MemoryBuffer.h"
#include "llvm/Support/raw_ostream.h"
#include <llvm-18/llvm/IR/Instruction.h>
#include <string>
#include <unordered_map>
#include <vector>

using namespace llvm;

// Data structs --------------------------------------------------------------

struct FlopChange {
  int flopId;
  Type *fromType;
  Type *toType;
};

// Helpers --------------------------------------------------------------

// out message helper
template <typename... rest> static void outMsg(const rest &...messages) {
  errs() << "ReducePrecisionPass";
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

// gets the llvm type based on the name from the plan JSON
static Type *getFPType(const std::string &fpTypeName, LLVMContext &ctx) {
  if (fpTypeName == "fp16")
    return Type::getHalfTy(ctx);
  if (fpTypeName == "fp32")
    return Type::getFloatTy(ctx);
  if (fpTypeName == "fp64")
    return Type::getDoubleTy(ctx);
  if (fpTypeName.rfind("vec_", 0) == 0) {
    std::string rest = fpTypeName.substr(4);
    auto sep = rest.find("_");
    int count = std::stoi(rest.substr(0, sep));
    std::string elemStr = rest.substr(sep + 1);
    Type *elemType = getFPType(elemStr, ctx);
    if (!elemType)
      return nullptr;
    return VectorType::get(elemType, count, false);
  }
  return nullptr;
}

// Main logic --------------------------------------------------------------

// loads the plan into map of instruction id to FlopChange
std::unordered_map<int, FlopChange> loadFlopChanges(LLVMContext &ctx) {
  std::unordered_map<int, FlopChange> flopChanges;
  std::string filename = "flop_change_plan.json";

  auto dataBuffer = MemoryBuffer::getFile(filename);
  if (!dataBuffer) {
    outMsg("Could not read JSON: ", filename, "/n");
    return flopChanges;
  }

  auto dataJson = json::parse((*dataBuffer)->getBuffer());
  if (!dataJson) {
    outMsg("Could not parse JSON: ", filename, "/n");
    return flopChanges;
  }

  json::Object *dataObj = dataJson->getAsObject();
  if (!dataObj) {
    outMsg("Parsed JSON not object structure: ", filename, "/n");
    return flopChanges;
  }

  json::Array *changes = dataObj->getArray("changes");
  if (!changes) {
    outMsg("Parsed JSON does not have a list of changes: ", filename, "/n");
    return flopChanges;
  }

  for (auto &change : *changes) {
    json::Object *changeObj = change.getAsObject();
    if (!changeObj) {
      outMsg("Parsed JSON list contains invalid data: ", filename, "/n");
      continue;
    }

    auto flopId = changeObj->getInteger("flopId");
    auto fromTypeName = changeObj->getString("fromTypeName");
    auto toTypeName = changeObj->getString("toTypeName");
    if (!flopId || !fromTypeName || !toTypeName) {
      outMsg("Parsed JSON list contains missing data: ", filename, "/n");
      continue;
    }

    Type *fromType = getFPType(std::string(*fromTypeName), ctx);
    Type *toType = getFPType(std::string(*toTypeName), ctx);
    if (!fromType || !toType) {
      outMsg("Invalid types for: ", *flopId, " in ", filename, "/n");
      continue;
    }

    flopChanges[(int)*flopId] = {(int)*flopId, fromType, toType};
  }

  outMsg("Total loaded changes: ", flopChanges.size());
  return flopChanges;
}

// applys type change precision reduction to a single instruction
// adds a cast back to higher precision afterwards to prevent dependency failures
// instcombine must be run after this to remove redudant casts
void applyTypeChange(Instruction &irInstr, Type *toType, Type *fromType) {
  if (!isFlop(irInstr)) {
    outMsg("Invalid type to convert, skipping/n");
    return;
  }

  // start builder at instruction
  IRBuilder<> builder(&irInstr);

  // create lower precision operands for the instrution operations
  Value *truncLhs =
      builder.CreateFPTrunc(irInstr.getOperand(0), toType, "trunc_operand");
  Value *truncRhs =
      builder.CreateFPTrunc(irInstr.getOperand(1), toType, "trunc_operand");

  BinaryOperator *irBinOp = dyn_cast<BinaryOperator>(&irInstr);
  // create the same operation at the lower precision
  Value *truncOperation = BinaryOperator::Create(
      irBinOp->getOpcode(), truncLhs, truncRhs, "trunc_operation", &irInstr);

  // insert new low precision operation before the operation
  builder.SetInsertPoint(irInstr.getNextNode());

  // unmodified users of the operation result will expect the full-precision
  // type replace the original operation (after the truncated one) with a cast
  // to full precision for the unmodified users
  Value *extended = builder.CreateFPExt(truncOperation, fromType, "op_ext");
  irInstr.replaceAllUsesWith(extended);
  // remove the old instruction that is now redundant
  irInstr.eraseFromParent();

  // however, if the users are also truncated, the casts should be skipped
  // after the precision reduction modification pass the standard instcombine
  // pass should be run to eliminate these redundant casts
}

// Pass --------------------------------------------------------------

struct ReducePrecisionPass : public PassInfoMixin<ReducePrecisionPass> {

  PreservedAnalyses run(Module &irModule, ModuleAnalysisManager &irMAM) {
    auto flopChanges = loadFlopChanges(irModule.getContext());
    if (flopChanges.empty()) {
      outMsg("No changes found, no modification made\n");
      return PreservedAnalyses::all();
    }

    // get ordered lists of target instructions and flopchanges
    std::vector<Instruction *> targetInstructions;
    std::vector<FlopChange> targetFlopChanges;

    int opId = 0;
    for (auto &irFunc : irModule) {
      if (irFunc.isDeclaration())
        continue;
      for (auto &irBlock : irFunc) {
        for (auto &irInstr : irBlock) {
          // if instruction is flop and in the plan, add it to targets
          if (isFlop(irInstr) && flopChanges.count(opId)) {
            targetInstructions.push_back(&irInstr);
            targetFlopChanges.push_back(flopChanges[opId]);
          }
          opId++;
        }
      }
    }

    // apply modification to every target instruction
    for (int i = 0; i < (int)targetInstructions.size(); i++) {
      applyTypeChange(*targetInstructions[i], targetFlopChanges[i].toType,
                      targetFlopChanges[i].fromType);
      }

    outMsg("Reduced precision of ", targetInstructions.size(), " operations\n");
    outMsg("end\n");
    return PreservedAnalyses::none();
  }

  static bool isRequired() { return true; }
};

// Plugin registration
// --------------------------------------------------------------

extern "C" LLVM_ATTRIBUTE_WEAK ::llvm::PassPluginLibraryInfo
llvmGetPassPluginInfo() {
  return {.APIVersion = LLVM_PLUGIN_API_VERSION,
          .PluginName = "Reduce Precision Pass",
          .PluginVersion = "v0.1",
          .RegisterPassBuilderCallbacks = [](PassBuilder &PB) {
            PB.registerPipelineParsingCallback(
                [](StringRef Name, ModulePassManager &MPM,
                   ArrayRef<PassBuilder::PipelineElement>) {
                  if (Name == "reduce-precision") {
                    MPM.addPass(ReducePrecisionPass());
                    return true;
                  }
                  return false;
                });
          }};
}