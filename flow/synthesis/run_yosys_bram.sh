#!/usr/bin/env bash
set -euo pipefail

# Example usage:
# ./run_yosys_bram.sh --top top --target xilinx rtl/*.sv tb/*.sv

TOP="top"
TARGET="generic"
FILES=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --top) TOP="$2"; shift 2;;
    --target) TARGET="$2"; shift 2;; # xilinx or intel or generic
    *) FILES+=("$1"); shift;;
  esac
done

if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "No Verilog/SystemVerilog files provided."
  exit 1
fi

# Build read_verilog command
READ_CMD="read_verilog -sv"
for f in "${FILES[@]}"; do
  READ_CMD+=" $f"
done

# Run Yosys with our script and input files
yosys "${FILES[@]}" -s synth_bram_yosys.ys
