#!/bin/bash
echo "Testing scale_factor_tracker synthesis..."
yosys -q -p "read_verilog -sv ../../rtl/scale_factor_tracker.sv; hierarchy -top scale_factor_tracker; synth -top scale_factor_tracker; stat"
echo "scale_factor_tracker synthesis completed" 