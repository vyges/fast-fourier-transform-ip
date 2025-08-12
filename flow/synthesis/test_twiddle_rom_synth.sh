#!/bin/bash
echo "Testing twiddle_rom_synth synthesis..."
yosys -q -p "read_verilog -sv twiddle_rom_synth.sv; hierarchy -top twiddle_rom_synth; synth -top twiddle_rom_synth; stat"
echo "twiddle_rom_synth synthesis completed" 