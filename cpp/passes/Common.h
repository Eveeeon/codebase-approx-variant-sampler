#pragma once

#include "llvm/IR/Instruction.h"
#include "llvm/IR/LLVMContext.h"
#include "llvm/IR/Type.h"
#include "llvm/Support/raw_ostream.h"

#include <string>

using namespace llvm;

template <typename... Rest> void outMsg(const Rest &...messages) {
  errs() << "FPApprox: ";
  (errs() << ... << messages);
}

bool isFlop(Instruction &irInstr);

bool isBinaryOp(Instruction &irInstr);

bool isBFlop(Instruction &irInstr);

Type *getFPType(const std::string &fpTypeName, LLVMContext &ctx);

std::string nameFPType(Type *irType);