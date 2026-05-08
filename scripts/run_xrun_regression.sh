#!/bin/bash
# Author: Alican Yengec
# run_xrun_regression.sh - Compile once, run all tests, and produce summary
#
# Usage: ./run_xrun_regression.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

TESTS=(
  cpu_basic_alu_test
  cpu_alu_imm_corner_test
  cpu_load_store_test
  cpu_branch_test
  cpu_branch_corner_test
  cpu_jump_x0_test
  cpu_reg_coverage_sweep_test
  cpu_mem_lane_sweep_test
  cpu_regfile_semantics_test
  cpu_address_boundary_test
  cpu_misaligned_access_test
  cpu_misaligned_control_test
  cpu_invalid_decode_test
  cpu_axi_wait_state_test
  cpu_axi_error_test
  cpu_branch_unit_force_test
  cpu_illegal_instr_test
  cpu_random_test
)

PASS=0
FAIL=0
RESULTS=""

echo "============================================"
echo "  RV32I CPU UVM Regression"
echo "  Tests: ${#TESTS[@]}"
echo "============================================"
echo ""

echo "--- Compile/elaborate once ---"
bash compile_xrun.sh
echo ""

for TEST in "${TESTS[@]}"; do
  echo "--- Running: $TEST ---"
  if bash run_xrun_snapshot.sh "$TEST" random; then
    RESULTS="${RESULTS}  PASS  $TEST\n"
    PASS=$((PASS + 1))
  else
    RESULTS="${RESULTS}  FAIL  $TEST\n"
    FAIL=$((FAIL + 1))
  fi
  echo ""
done

echo "============================================"
echo "  Regression Summary"
echo "============================================"
echo -e "$RESULTS"
echo "--------------------------------------------"
echo "  PASS: $PASS / ${#TESTS[@]}"
echo "  FAIL: $FAIL / ${#TESTS[@]}"
echo "============================================"

if [ $FAIL -gt 0 ]; then
  exit 1
else
  exit 0
fi
