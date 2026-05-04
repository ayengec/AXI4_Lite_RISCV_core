#!/bin/bash
# run_xrun_snapshot.sh - Run one UVM test from a precompiled Xcelium snapshot.
#
# Usage:
#   ./run_xrun_snapshot.sh [TEST_NAME] [SEED]

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
BUILD_DIR="output/build"
SNAPSHOT="cpu_tb_top_snap"
OUT_DIR="output/${TEST}_${SEED}"

mkdir -p "$OUT_DIR"

if [[ ! -d "${BUILD_DIR}/xcelium.d" ]]; then
  echo "ERROR: Missing compiled Xcelium library: ${BUILD_DIR}/xcelium.d"
  echo "Run ./compile_xrun.sh first."
  exit 2
fi

echo "============================================"
echo "  RV32I CPU UVM Snapshot Run"
echo "  Test:     $TEST"
echo "  Seed:     $SEED"
echo "  Snapshot: $SNAPSHOT"
if [[ -n "$CLI_EXTRA_ARGS" || -n "$EXTRA_ARGS" ]]; then
  echo "  Extra args: $EXTRA_ARGS $CLI_EXTRA_ARGS"
fi
echo "============================================"

xrun \
  -R \
  -xmlibdirname "${BUILD_DIR}/xcelium.d" \
  -snapshot "$SNAPSHOT" \
  +UVM_TESTNAME=${TEST} \
  +UVM_VERBOSITY=UVM_MEDIUM \
  -seed ${SEED} \
  -l "${OUT_DIR}/xrun.log" \
  -covworkdir "${OUT_DIR}/cov_work" \
  $EXTRA_ARGS \
  $CLI_EXTRA_ARGS

echo ""
echo "============================================"
echo "  Test: $TEST completed"
echo "  Log:  ${OUT_DIR}/xrun.log"
echo "============================================"

if grep -q "TEST FAILED" "${OUT_DIR}/xrun.log"; then
  echo "  Result: FAIL"
  grep -c "UVM_ERROR" "${OUT_DIR}/xrun.log" || true
  exit 1
else
  echo "  Result: PASS"
  exit 0
fi
