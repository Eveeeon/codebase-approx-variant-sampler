add_llvm_pass_plugin(FPApprox
    passes.cpp
    ExportGraphPass.cpp
    ReducePrecisionPass.cpp
    Common.cpp
)