read_verilog -sv ../../rtl/memory_interface.sv
hierarchy -top memory_interface
synth -top memory_interface
stat 