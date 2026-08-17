
# Approximate Variant Sampler

A sampling tool for generating and evaluating variants of a C/C++ application, where variants have reduced floating-point precision floating-point operations. The tool measures the energy/accuracy trade-off across variation strategies. Variants are randomly generated, however, they are evaluated by various metrics that inform strategy.

# Overview

The tool is composed of 5 components that sequentially run the experiment.

<pre>
("Subject" i.e. Source Code)
    |
    |
    |  ◄--- <sub>subject adapter compiler flags</sub>
    ▼
<b>Pre-Adapter</b>
Compiles subject to a single bitcode file
    |
    <sub>subject bitcode file</sub>
    |
    |  ◄--- <sub>experiment configuration - variant selection</sub>
    ▼
<b>Variant Generator</b>
Generates variant plans containing decision logic and evaluation metrics of the floating-point operation reduction selection
    |
    <sub>json plan files for each variant</sub>
    |
    ▼
<b>Builder</b>
Creates the bitcode variants and compiles them to binaries
    |
    <sub>bitcode file for each variant</sub>
    |
    |  ◄--- <sub>subject adapter stdin and args</sub>
    ▼
<b>Post-Adapter</b>
Builds the execution commands for the experiment, providing any input to pass to the subject binary
    |
    <sub>execution command files for each variant</sub>
    |
    |  ◄--- <sub>experiment configuration - evaluation instruction</sub>
    ▼
<b>Evaluator</b>
Runs the experiment, executing the binaries and capturing the raw output and energy consumption
    |
    ▼
(Raw Subject Output)
(Energy Measurements)
</pre>

# Quckstart
### 1. Install the [Required Installations](#Required-Installations)

### 2. Clone the repository
    
    git clone https://github.com/Eveeeon/codebase-approx-variant-sampler.git

### 3. Create a `subject` directory in the project root, and inside, place your source code to be evaluated

### 4. Open `config/project_config.toml` and update:

| Parameter | Description |
|---|---|
| `subject` | Path to the root of the subject source code relative to the root of this project. |
| `llvm_dir` | Path of the installation of LLVM |

    > **_NOTE: All other fields don't need to change for running an experiment._**

### 5. Open `config/experiment_config.toml` and update:
#### **Required**
| Parameter | Description |
|---|---|
| `source_project_name` | Unique name used to identify the subject source code. |
| `id` | Unique identifier for the experiment. |
| `source_file_type` | File extension of the subject source code files.<br/> <sub> <i> Currently supports C and C++ only, but can be extended to all languages that support LLVM compilation.</i> </sub> |
| `from_type` | Floating-point type of the operations in the subject to be reduced. |
| _`to_type` | Floating-point type to which the selected operations will be reduced. <br/> <sub> <i>Currently supports conversions between 64-bit, 32-bit, and 16-bit floating-point types, this can be extended subject to hardware support.</i> </sub>  |
| `reduction_rates` | List of floating-point operation reduction rates to evaluate in the experiment. |
| `variants_per_rate` | Number of variants to generate for each reduction rate. |
| `repeat_variant` | Number of times each variant is repeated within a single measurement to reduce measurement noise. |
| `repeat_evaluation` | Number of times the full energy evaluation is repeated across all variants to improve robustness and reduce measurement variation. <br/> <sub> <i>  Each evaluation processes the variants in a different random order to reduce sequencing bias.</i> </sub>  |
| `compile_flags` | String containing all compiler flags for the subject source code. |
| `stdin` | String containing all stdin values passed to the subject source code during execution. |
| `args` | List of arguments passed to the subject source code during execution. |
| `enrg_brg_platform` | OS/hardware platform on which the experiment is running. Used to determine which version of EnergiBridge to install. |

#### **Optional**

| Parameter | Description |
|---|---|
| `stdout_file_type` | File extension of files to which the subject's stdout is directed. |
| `stderr_file_type` | File extension of files to which the subject's stderr is directed. |
| `pause_between_variants` | Number of seconds to pause between variant evaluations for a cooldown window and reduce the affect of previous evaluations on subsecquent evaluations. |
| `base_seed` | Random number generator seed used to select floating-point operations to be reduction. |
| `enrg_brg_interval` | Time interval between EnergiBridge measurements. |

### 6. ONLY ONCE - Install third-party software (can be skipped if done previously in the current directory)
Run `scripts/install.sh` from the root directory

### 7. Execute the experiment
Run `scripts/run.sh` from the root directory, if prompted, enter sudo password during the setup to ensure the correct permissions are set.

### 8. Get the results
Get the results from the `out/eperiments/<experiment id>/` directory, see [out directory](#out-directory) for details.

# Required Installation

## C
- Build-essential
- Cmake
- LLVM development packaged
- Clang

The project was developed using LLVM/Clang 18.

### Install Latest Version With APT
```
sudo apt update
sudo apt install build-essential cmake llvm clang
```

## Python
Python version >=3.11.

## Bash
A Bash shell is required.

# Project Structure
```
.
├── config/
│   ├── experiment_config.toml
│   └── project_config.toml
├── cpp/
│   ├── build/
│   └── passes/
├── logs/
├── out/
├── python/
│   ├── post_adapter/
│   └── variant_generator/
├── scripts/
│   ├── experiment/
│   │   ├── builder.sh
│   │   ├── evaluator.sh
│   │   ├── post_adapter.sh
│   │   ├── pre_adapter.sh
│   │   ├── setup.sh
│   │   ├── start_script.sh
│   │   └── variant_generator.sh
│   ├── helpers.sh
│   ├── install/
│   │   ├── install_energibridge.sh
│   │   └── start_script.sh
│   ├── run.sh
│   ├── install.sh
│   └── start_script.sh
├── subject/
├── third_party/
```
## OUT Directory

```
├── out
│   ├── experiments
│   │   └── <experiment id>
│   │       ├── binary/
│   │       ├── bitcode/
│   │       ├── energy/
│   │       ├── execution_commands/
│   │       ├── plans/
│   │       ├── stderr/
│   │       └── stdout/
│   ├── graph_export/
│   │   └── <subject name>.json
│   └── subject_bitcode/
│       └── <subject name>.bc
```

| Directory | Contents |
| - | - |
| `experiments/` | Results and intermediate files generated for each experiment. Each subdirectory is identified by the experiment ID. |
| `experiments/<experiment id>/binary/`| Compiled binaries for each variant, identified by `  variant id`. |
| `experiments/<experiment id>/bitcode/`| LLVM bitcode generated for each variant, identified by ` variant id`. |
| `experiments/<experiment id>/energy/` | Energy measurements for each  variant identified by ` variant id` and split into numbered subdirectories for each repeat evaluation.|
| `experiments/<experiment id>/execution_commands/` | Commands used to execute each variant, identified by ` variant id`.|
| `experiments/<experiment id>/plans/` | Reduction plans generated for each variant, identified by ` variant id`. |
| `experiments/<experiment id>/stderr/` | Stderr output from each variant execution (output is only evaluated once per variant), identified by ` variant id`. |
| `experiments/<experiment id>/stdout/` | Stdout output from each variant execution (output is only evaluated once per variant), identified by ` variant id`. |
| `graph_export/` | Graph representations of the identified floating-point operations in the subject source code |
| `subject_bitcode/` | LLVM bitcode generated from the subject source code. |
