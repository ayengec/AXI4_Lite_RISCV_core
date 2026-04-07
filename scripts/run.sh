#!/usr/bin/env bash
set -euo pipefail

TOP_TB="tb_rv32i_cpu_smoke"
LOG_DIR="logs"
RUN_DIR="xrun_${TOP_TB}"

mkdir -p "${LOG_DIR}"

xrun -sv \
  -clean \
  -access +rwc \
  -linedebug \
  -timescale 1ns/1ps \
  -top "${TOP_TB}" \
  -l "${LOG_DIR}/${TOP_TB}.log" \
  -xmlibdirname "${RUN_DIR}" \
  ../src/rv32i_pkg.sv \
  ../src/rv32i_regfile.sv \
  ../src/rv32i_decoder.sv \
  ../src/rv32i_alu.sv \
  ../src/rv32i_branch_unit.sv \
  ../src/rv32i_cpu.sv \
  ../src//unit_tests/tb_rv32i_cpu_smoke.sv