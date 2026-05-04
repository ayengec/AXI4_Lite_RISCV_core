#!/bin/bash
# compile_xrun.sh - Compile/elaborate the RV32I CPU UVM testbench once.
#
# Usage:
#   ./compile_xrun.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

BUILD_DIR="output/build"
LOG="${BUILD_DIR}/compile.log"
SNAPSHOT="cpu_tb_top_snap"

mkdir -p "$BUILD_DIR"

echo "============================================"
echo "  RV32I CPU UVM Compile/Elaborate"
echo "  Snapshot: $SNAPSHOT"
echo "  Build:    $BUILD_DIR"
echo "============================================"

xrun \
  -uvm \
  -sv \
  -access +rwc \
  -coverage all \
  -f files.f \
  -timescale 1ns/1ps \
  -xmlibdirname "${BUILD_DIR}/xcelium.d" \
  -snapshot "$SNAPSHOT" \
  -elaborate \
  -l "$LOG" \
  +define+AXI4L_DATA_WIDTH=32 \
  +define+AXI4L_ADDR_WIDTH=32 \
  $EXTRA_ARGS

echo ""
echo "============================================"
echo "  Compile/elaborate completed"
echo "  Log: $LOG"
echo "============================================"
