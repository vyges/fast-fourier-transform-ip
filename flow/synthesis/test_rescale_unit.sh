#!/bin/bash
echo "Testing rescale_unit synthesis..."
yosys -q -p "read_verilog -sv ../../rtl/rescale_unit.sv; hierarchy -top rescale_unit; synth -top rescale_unit; stat"
echo "rescale_unit synthesis completed" 