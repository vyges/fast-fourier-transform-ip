#=============================================================================
# Yosys Synthesis Script for FFT Hardware Accelerator
#=============================================================================
# Description: Yosys synthesis script for FFT hardware accelerator
#              with automatic rescaling and scale factor tracking.
#              Follows Vyges conventions for synthesis flow.
# Author:      Vyges IP Development Team
# Date:        2025-07-21
# License:     Apache-2.0
#=============================================================================

# Read design files
read_verilog -sv ../../rtl/fft_top.sv
read_verilog -sv ../../rtl/fft_engine.sv
read_verilog -sv ../../rtl/fft_control.sv
read_verilog -sv ../../rtl/memory_interface.sv
read_verilog -sv ../../rtl/rescale_unit.sv
read_verilog -sv ../../rtl/scale_factor_tracker.sv
read_verilog -sv ../../rtl/twiddle_rom_synth.sv

# Set top module
hierarchy -top fft_top

# Check design
check

# Generate statistics before synthesis
stat

# Generic synthesis
synth -top fft_top

# Optimize design
opt -purge

# Technology mapping (generic)
dfflibmap -liberty +/xilinx/xc7s50csga324-1L/xc7s50csga324-1L.lib
abc -liberty +/xilinx/xc7s50csga324-1L/xc7s50csga324-1L.lib

# Clean up
clean

# Generate statistics after synthesis
stat

# Write netlist
write_verilog -noattr -noexpr -nohex -nodec ../../flow/synthesis/fft_top_synth.v

# Write JSON for further processing
write_json ../../flow/synthesis/fft_top_synth.json

# Generate reports
tee -o ../../flow/synthesis/synthesis_report.txt stat
tee -o ../../flow/synthesis/timing_report.txt timing -full

echo "Synthesis completed successfully!" 