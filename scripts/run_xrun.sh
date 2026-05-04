#!/bin/bash
# Author: Alican Yengec
# run_xrun.sh - Run a single UVM test with Xcelium (xrun)
#
# Usage:
#   ./run_xrun.sh [TEST_NAME] [SEED]
#
# Examples:
#   ./run_xrun.sh                          # default: cpu_basic_alu_test
#   ./run_xrun.sh cpu_load_store_test      # specific test
#   ./run_xrun.sh cpu_random_test 12345    # specific seed
#   ./run_xrun.sh cpu_basic_alu_test +TRACE_REF
#   ./run_xrun.sh cpu_basic_alu_test 12345 +TRACE_REF

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

TEST=${1:-cpu_basic_alu_test}
if [[ $# -gt 0 ]]; then
  shift
fi

SEED=random
if [[ $# -gt 0 && "$1" != +* ]]; then
  SEED=$1
  shift
fi

CLI_EXTRA_ARGS="$*"

echo "============================================"
echo "  RV32I CPU UVM Testbench"
echo "  Test: $TEST"
echo "  Seed: $SEED"
if [[ -n "$CLI_EXTRA_ARGS" || -n "$EXTRA_ARGS" ]]; then
  echo "  Extra args: $EXTRA_ARGS $CLI_EXTRA_ARGS"
fi
echo "============================================"

# Create output directory
OUT_DIR="output/${TEST}_${SEED}"
mkdir -p "$OUT_DIR"

xrun \
  -uvm \
  -sv \
  -access +rwc \
  -coverage all \
  -covoverwrite \
  -f files.f \
  +UVM_TESTNAME=${TEST} \
  +UVM_VERBOSITY=UVM_MEDIUM \
  -seed ${SEED} \
  -timescale 1ns/1ps \
  -l "${OUT_DIR}/xrun.log" \
  -xmlibdirname "${OUT_DIR}/xcelium.d" \
  -covworkdir "${OUT_DIR}/cov_work" \
  +define+AXI4L_DATA_WIDTH=32 \
  +define+AXI4L_ADDR_WIDTH=32 \
  $EXTRA_ARGS \
  $CLI_EXTRA_ARGS

echo ""
echo "============================================"
echo "  Test: $TEST completed"
echo "  Log:  ${OUT_DIR}/xrun.log"
echo "============================================"

# Check for UVM errors
if grep -q "TEST PASSED" "${OUT_DIR}/xrun.log"; then
  echo "  Result: PASS"
  exit 0
else
  echo "  Result: FAIL"
  exit 1
fi
