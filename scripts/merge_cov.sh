#!/bin/bash
# merge_cov.sh - Merge per-test Xcelium coverage runs with IMC.
#
# Usage:
#   ./merge_cov.sh
#   ./merge_cov.sh merged_coverage_report_rc

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

OUT_NAME=${1:-merged_coverage_report_rc}
MERGED_DB="cov_work/scope/${OUT_NAME}"
HTML_DIR="${OUT_NAME}_html"
MERGE_TCL="do_merge.tcl"

mkdir -p cov_work/scope

mapfile -t RUN_DIRS < <(find output -path '*/cov_work/scope/test*' -type d | sort)

if [[ ${#RUN_DIRS[@]} -eq 0 ]]; then
  echo "ERROR: No coverage run directories found under output/*/cov_work/scope/test*"
  exit 1
fi

{
  echo "merge ${RUN_DIRS[*]} -out ${OUT_NAME}"
  echo "load -run ${MERGED_DB}"
  echo "report -html -out ${HTML_DIR}"
  echo "exit"
} > "$MERGE_TCL"

echo "============================================"
echo "  IMC Coverage Merge"
echo "  Runs:   ${#RUN_DIRS[@]}"
echo "  DB:     $MERGED_DB"
echo "  HTML:   $HTML_DIR"
echo "  Tcl:    $MERGE_TCL"
echo "============================================"
printf '  %s\n' "${RUN_DIRS[@]}"
echo ""

imc -batch -init "$MERGE_TCL"

echo ""
echo "============================================"
echo "  Coverage merge completed"
echo "  DB:   $SCRIPT_DIR/$MERGED_DB"
echo "  HTML: $SCRIPT_DIR/$HTML_DIR"
echo "============================================"
