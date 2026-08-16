# Approximate Variant Sampler

A sampling tool for generating and evaluating variants of a C/C++ application, where variants have reduced floating-point precision floating-point operations. The tool measures the energy/accuracy trade-off across variation strategies. Variants are randomly generated, however, they are evaluated by various metrics that inform strategy.

# Overview
```
("Subject" i.e. Source Code)
    |
    ▼
Pre-Adapter
Compiles subject to a single bitcode file
    |
    ▼
Variant Generator
Generates variant plans containing decision logic and evaluation metrics of the floating-point operation reduction selection
    |
    ▼
Builder
Creates the bitcode variants and compiles them to binaries
    |
    ▼
Post-Adapter
Builds the execution commands for the experiment, providing any input to pass to the subject binary
    |
    ▼
Evaluator
Runs the experiment, executing the binaries and capturing the raw output and energy consumption
    |
    ▼
(Raw Subject Output)
(Energy Measurements)
```