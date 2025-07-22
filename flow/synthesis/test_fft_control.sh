#!/bin/bash
echo "Testing fft_control synthesis..."
yosys -q -p "read_verilog -sv ../../rtl/fft_control.sv; hierarchy -top fft_control; synth -top fft_control; stat"
echo "fft_control synthesis completed" 