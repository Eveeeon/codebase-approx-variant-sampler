#include "Common.h"

#include "llvm/IR/DerivedTypes.h"
#include "llvm/IR/Instructions.h"

#include <string>

using namespace llvm;

bool isFlop(Instruction &irInstr) {
  Type *irType = irInstr.getType();

  if (!irType) {
    return false;
  }

  if (irType->isFloatingPointTy()) {
    return true;
  }

  if (auto *irVectType = dyn_cast<VectorType>(irType)) {
    if (irVectType->getElementType()->isFloatingPointTy()) {
      return true;
    }
  }

  return false;
}

bool isBinaryOp(Instruction &irInstr) {
  BinaryOperator *irBinOp = dyn_cast<BinaryOperator>(&irInstr);

  if (!irBinOp) {
    return false;
  }

  return true;
}

bool isBFlop(Instruction &irInstr) {
  return isFlop(irInstr) && isBinaryOp(irInstr);
}

Type *getFPType(const std::string &fpTypeName, LLVMContext &ctx) {

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

std::string nameFPType(Type *irType) {

  if (irType->isHalfTy()) {
    return "fp16";
  }

  if (irType->isFloatTy()) {
    return "fp32";
  }

  if (irType->isDoubleTy()) {
    return "fp64";
  }

  FixedVectorType *vecType = dyn_cast<FixedVectorType>(irType);

  if (vecType) {
    Type *elemType = vecType->getElementType();
    unsigned numElements = vecType->getNumElements();

    std::string elemName = nameFPType(elemType);

    return "vec_" + std::to_string(numElements) + "_" + elemName;
  }

  return "unhandled";
}