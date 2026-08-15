#!/usr/bin/env bash
set -euo pipefail

#########################################
# GLOBAL
#########################################

SCRIPT_NAME="pre_adapter"
THIS_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

"$THIS_DIR/install/install_energibridge.sh"
#/home/eve/Projects/codebase-approx-variant-sampler/scripts/experiment/setup.sh
#/home/eve/Projects/codebase-approx-variant-sampler/scripts/experiment/pre_adapter.sh
#/home/eve/Projects/codebase-approx-variant-sampler/scripts/experiment/variant_generator.sh
#/home/eve/Projects/codebase-approx-variant-sampler/scripts/experiment/builder.sh
#/home/eve/Projects/codebase-approx-variant-sampler/scripts/experiment/post_adapter.sh
#/home/eve/Projects/codebase-approx-variant-sampler/scripts/experiment/evaluator.sh