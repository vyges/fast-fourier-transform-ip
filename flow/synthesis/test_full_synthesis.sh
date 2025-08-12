#!/bin/bash
echo "Testing full synthesis..."
yosys -q -p "read_verilog -sv ../../rtl/fft_top.sv; read_verilog -sv ../../rtl/fft_engine.sv; read_verilog -sv ../../rtl/fft_control.sv; read_verilog -sv ../../rtl/memory_interface.sv; read_verilog -sv ../../rtl/rescale_unit.sv; read_verilog -sv ../../rtl/scale_factor_tracker.sv; read_verilog -sv twiddle_rom_synth.sv; hierarchy -top fft_top; check; stat; synth -top fft_top; opt -purge; clean; stat"
echo "Full synthesis completed" 