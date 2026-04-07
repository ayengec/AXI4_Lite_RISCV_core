#!/bin/bash
# clean.sh
# Made by : Alican Yengec
# Removes all simulation work directories and generated files.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

rm -rf \
  work \
  uvm \
  transcript \
  vsim.wlf \
  modelsim.ini \
  xcelium.d \
  INCA_libs \
  xrun.history \
  xrun.log \
  *.log \
  cov_work \
  *cov_rep* \
  *.vcd \
  *.env \
  *.dsn \
  *.trn \
  *.cmd \
  .simvision \
  waves.shm

echo "Clean done."
