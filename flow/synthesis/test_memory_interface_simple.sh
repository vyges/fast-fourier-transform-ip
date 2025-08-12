#!/bin/bash
echo "Testing memory_interface synthesis with optimized RTL..."
# Use the actual updated RTL instead of creating a temporary simplified version
yosys -p "read_verilog -sv ../../rtl/memory_interface.sv; hierarchy -top memory_interface; synth -top memory_interface; stat"
echo "memory_interface synthesis completed" 