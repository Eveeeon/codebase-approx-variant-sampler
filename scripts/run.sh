#!/usr/bin/env bash
set -euo pipefail

THIS_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

"$THIS_DIR/experiment/setup.sh"
"$THIS_DIR/experiment/pre_adapter.sh"
"$THIS_DIR/experiment/variant_generator.sh"
"$THIS_DIR/experiment/builder.sh"
"$THIS_DIR/experiment/post_adapter.sh"
"$THIS_DIR/experiment/evaluator.sh"
"$THIS_DIR/experiment/aggregator.sh"