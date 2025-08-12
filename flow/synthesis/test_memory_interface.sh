#!/bin/bash
echo "Testing memory_interface synthesis..."
yosys -q -p "read_verilog -sv ../../rtl/memory_interface.sv; hierarchy -top memory_interface; synth -top memory_interface; stat"
echo "memory_interface synthesis completed" 