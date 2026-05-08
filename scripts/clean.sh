#!/bin/bash
# Author: Alican Yengec
# clean.sh - Clean simulation artifacts
#
# Usage: ./clean.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "Cleaning simulation artifacts..."

rm -rf output/
rm -rf xcelium.d/
rm -rf waves.shm/
rm -rf cov_work/
rm -rf merged_cov*/
rm -f *.log *.key *.diag *.err
rm -f transcript
rm -f *.env

echo "Clean done."
