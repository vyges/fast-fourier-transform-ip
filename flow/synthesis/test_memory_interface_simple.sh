#!/bin/bash
echo "Testing memory_interface synthesis with BRAM inference..."
# Use our new BRAM-aware synthesis script
./run_yosys_bram.sh --top memory_interface --target xilinx ../../rtl/memory_interface.sv
echo "memory_interface BRAM synthesis completed" 