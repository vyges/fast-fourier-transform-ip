#!/bin/bash
echo "Testing fft_engine synthesis..."
yosys -q -p "read_verilog -sv ../../rtl/fft_engine.sv; hierarchy -top fft_engine; synth -top fft_engine; stat"
echo "fft_engine synthesis completed" 