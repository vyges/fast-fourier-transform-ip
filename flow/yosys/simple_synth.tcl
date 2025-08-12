# Simple Yosys synthesis script for FFT memory interface
# This script provides clean, focused synthesis output

# Read the memory interface module
read_verilog -sv ../../rtl/memory_interface.sv

# Set the top module
hierarchy -top memory_interface

# Basic synthesis flow
proc
opt
memory
opt

# Show statistics
stat

# Write output
write_verilog -noattr memory_interface_simple.v
