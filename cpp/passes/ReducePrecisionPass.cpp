#include "ReducePrecisionPass.h"
#include "Common.h"
#include "Model.h"

#include "llvm/IR/IRBuilder.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/Module.h"
#include "llvm/Passes/PassBuilder.h"
#include "llvm/Support/JSON.h"
#include "llvm/Support/MemoryBuffer.h"
#include <llvm-18/llvm/IR/Instruction.h>
#include "llvm/Support/CommandLine.h"
#include <string>
#include <vector>

using namespace llvm;

// Arguments --------------------------------------------------------------

static cl::opt<std::string> PlanFilePath(
  "plan-file-path",
  cl::desc("Full path of the single variant plan file created by the varaiant generator.")
);

// Main logic --------------------------------------------------------------

// loads the plan into map of instruction id to FlopChange
std::unordered_map<int, FlopChange> loadFlopChanges(LLVMContext &ctx) {
  std::unordered_map<int, FlopChange> flopChanges;

  auto dataBuffer = MemoryBuffer::getFile(PlanFilePath);
  if (!dataBuffer) {
    outMsg("Could not read JSON: ", PlanFilePath, "/n");
    return flopChanges;
  }

  auto dataJson = json::parse((*dataBuffer)->getBuffer());
  if (!dataJson) {
    outMsg("Could not parse JSON: ", PlanFilePath, "/n");
    return flopChanges;
  }

  json::Object *dataObj = dataJson->getAsObject();
  if (!dataObj) {
    outMsg("Parsed JSON not object structure: ", PlanFilePath, "/n");
    return flopChanges;
  }

  json::Array *changes = dataObj->getArray("changes");
  if (!changes) {
    outMsg("Parsed JSON does not have a list of changes: ", PlanFilePath, "/n");
    return flopChanges;
  }

  for (auto &change : *changes) {
    json::Object *changeObj = change.getAsObject();
    if (!changeObj) {
      outMsg("Parsed JSON list contains invalid data: ", PlanFilePath, "/n");
      continue;
    }

    auto flopId = changeObj->getInteger("flopId");
    auto fromTypeName = changeObj->getString("fromTypeName");
    auto toTypeName = changeObj->getString("toTypeName");
    if (!flopId || !fromTypeName || !toTypeName) {
      outMsg("Parsed JSON list contains missing data: ", PlanFilePath, "/n");
      continue;
    }

    Type *fromType = getFPType(std::string(*fromTypeName), ctx);
    Type *toType = getFPType(std::string(*toTypeName), ctx);
    if (!fromType || !toType) {
      outMsg("Invalid types for: ", *flopId, " in ", PlanFilePath, "/n");
      continue;
    }

    flopChanges[(int)*flopId] = {(int)*flopId, fromType, toType};
  }
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

PreservedAnalyses ReducePrecisionPass::run(
    Module &irModule,
    ModuleAnalysisManager &irMAM) {

    auto flopChanges = loadFlopChanges(irModule.getContext());
    if (flopChanges.empty()) {
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

  return PreservedAnalyses::none();
}