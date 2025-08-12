#=============================================================================
# Generic Yosys Synthesis Script for FFT Hardware Accelerator
#=============================================================================
# Description: Generic Yosys synthesis script for FFT hardware accelerator
#              with automatic rescaling and scale factor tracking.
#              Uses generic technology mapping for portability.
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

# Generic technology mapping
dfflibmap
abc

# Clean up
clean

# Generate statistics after synthesis
stat

# Write netlist
write_verilog -noattr -noexpr -nohex -nodec ../../flow/synthesis/fft_top_synth_generic.v

# Write JSON for further processing
write_json ../../flow/synthesis/fft_top_synth_generic.json

# Generate reports
tee -o ../../flow/synthesis/synthesis_report_generic.txt stat
tee -o ../../flow/synthesis/timing_report_generic.txt timing -full

echo "Generic synthesis completed successfully!" 