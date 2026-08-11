#pragma once

#include "llvm/IR/Instructions.h"
#include <llvm-18/llvm/IR/Instruction.h>
#include <string>
#include <vector>

using namespace llvm;

struct FlopChange {
  int flopId;
  Type *fromType;
  Type *toType;
};

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