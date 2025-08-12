#=============================================================================
# FPGA Synthesis Makefile for FFT Hardware Accelerator
#=============================================================================
# Description: Makefile for FPGA synthesis using Vivado and Quartus
#              Supports Xilinx and Intel FPGA families
# Author:      Vyges IP Development Team
# Date:        2025-07-21
# License:     Apache-2.0
#=============================================================================

# Configuration
FPGA_FAMILY ?= ice40
FPGA_PART ?= hx8k-ct256
TOOL ?= openfpga
TOP_MODULE = fft_top
RTL_DIR = ../../rtl
CONSTRAINTS_DIR = constraints
BUILD_DIR = build
REPORTS_DIR = reports

# Tool-specific settings
ifeq ($(TOOL),openfpga)
    # Open source FPGA flow
    SYNTH_CMD = make
    SYNTH_FLAGS = -C openfpga
    SYNTH_TARGET = $(FPGA_FAMILY)_synth
    IMPL_CMD = make
    IMPL_FLAGS = -C openfpga
    IMPL_TARGET = $(FPGA_FAMILY)_pnr
    BITSTREAM_CMD = make
    BITSTREAM_FLAGS = -C openfpga
    BITSTREAM_TARGET = $(FPGA_FAMILY)_bitstream
else ifeq ($(TOOL),vivado)
    SYNTH_CMD = vivado
    SYNTH_FLAGS = -mode batch -source
    SYNTH_SCRIPT = vivado_synth.tcl
    IMPL_CMD = vivado
    IMPL_FLAGS = -mode batch -source
    IMPL_SCRIPT = vivado_impl.tcl
    BITSTREAM_CMD = vivado
    BITSTREAM_FLAGS = -mode batch -source
    BITSTREAM_SCRIPT = vivado_bitstream.tcl
else ifeq ($(TOOL),quartus)
    SYNTH_CMD = quartus_map
    SYNTH_FLAGS = --read_settings_files=on
    IMPL_CMD = quartus_fit
    IMPL_FLAGS = --read_settings_files=on
    BITSTREAM_CMD = quartus_asm
    BITSTREAM_FLAGS = --read_settings_files=on
endif

# Default target
all: synth impl bitstream

# Create directories
$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(REPORTS_DIR):
	mkdir -p $(REPORTS_DIR)

# Synthesis
synth: $(BUILD_DIR) $(REPORTS_DIR)
ifeq ($(TOOL),openfpga)
	$(SYNTH_CMD) $(SYNTH_FLAGS) $(SYNTH_TARGET) FPGA_PART=$(FPGA_PART)
else ifeq ($(TOOL),vivado)
	$(SYNTH_CMD) $(SYNTH_FLAGS) $(SYNTH_SCRIPT) -tclargs $(FPGA_PART) $(TOP_MODULE)
else ifeq ($(TOOL),quartus)
	$(SYNTH_CMD) $(SYNTH_FLAGS) $(TOP_MODULE) --part=$(FPGA_PART)
endif

# Implementation
impl: synth
ifeq ($(TOOL),openfpga)
	$(IMPL_CMD) $(IMPL_FLAGS) $(IMPL_TARGET) FPGA_PART=$(FPGA_PART)
else ifeq ($(TOOL),vivado)
	$(IMPL_CMD) $(IMPL_FLAGS) $(IMPL_SCRIPT) -tclargs $(FPGA_PART) $(TOP_MODULE)
else ifeq ($(TOOL),quartus)
	$(IMPL_CMD) $(IMPL_FLAGS) $(TOP_MODULE)
endif

# Bitstream generation
bitstream: impl
ifeq ($(TOOL),openfpga)
	$(BITSTREAM_CMD) $(BITSTREAM_FLAGS) $(BITSTREAM_TARGET) FPGA_PART=$(FPGA_PART)
else ifeq ($(TOOL),vivado)
	$(BITSTREAM_CMD) $(BITSTREAM_FLAGS) $(BITSTREAM_SCRIPT) -tclargs $(FPGA_PART) $(TOP_MODULE)
else ifeq ($(TOOL),quartus)
	$(BITSTREAM_CMD) $(BITSTREAM_FLAGS) $(TOP_MODULE)
endif

# Timing analysis
timing: impl
ifeq ($(TOOL),openfpga)
	make -C openfpga $(FPGA_FAMILY)_timing FPGA_PART=$(FPGA_PART)
else ifeq ($(TOOL),vivado)
	$(SYNTH_CMD) $(SYNTH_FLAGS) vivado_timing.tcl -tclargs $(FPGA_PART) $(TOP_MODULE)
else ifeq ($(TOOL),quartus)
	quartus_sta $(TOP_MODULE) --do_timing_analysis
endif

# Resource utilization
resources: synth
ifeq ($(TOOL),openfpga)
	make -C openfpga resources FPGA_FAMILY=$(FPGA_FAMILY)
else ifeq ($(TOOL),vivado)
	@echo "Resource utilization report:"
	@grep -A 20 "Resource Utilization" $(REPORTS_DIR)/synth_1/synth_1.rpt
else ifeq ($(TOOL),quartus)
	@echo "Resource utilization report:"
	@cat $(TOP_MODULE).fit.rpt | grep -A 20 "Resource Usage Summary"
endif

# Power analysis
power: impl
ifeq ($(TOOL),vivado)
	$(SYNTH_CMD) $(SYNTH_FLAGS) vivado_power.tcl -tclargs $(FPGA_PART) $(TOP_MODULE)
else ifeq ($(TOOL),quartus)
	quartus_pow $(TOP_MODULE) --do_power_analysis
endif

# Simulation
sim: $(BUILD_DIR)
ifeq ($(TOOL),vivado)
	$(SYNTH_CMD) $(SYNTH_FLAGS) vivado_sim.tcl -tclargs $(FPGA_PART) $(TOP_MODULE)
else ifeq ($(TOOL),quartus)
	quartus_sim $(TOP_MODULE) --do_functional_sim
endif

# Clean
clean:
ifeq ($(TOOL),openfpga)
	make -C openfpga clean
else
	rm -rf $(BUILD_DIR)
	rm -rf $(REPORTS_DIR)
	rm -rf *.jou
	rm -rf *.log
	rm -rf *.str
	rm -rf *.bit
	rm -rf *.sof
	rm -rf *.rpt
	rm -rf *.qpf
	rm -rf *.qsf
endif

# Help
help:
	@echo "FPGA Synthesis Makefile"
	@echo "======================"
	@echo ""
	@echo "Available targets:"
	@echo "  all        - Complete synthesis, implementation, and bitstream"
	@echo "  synth      - Run synthesis only"
	@echo "  impl       - Run implementation (requires synthesis)"
	@echo "  bitstream  - Generate bitstream (requires implementation)"
	@echo "  timing     - Run timing analysis"
	@echo "  resources  - Show resource utilization"
	@echo "  power      - Run power analysis"
	@echo "  sim        - Run simulation"
	@echo "  clean      - Clean build artifacts"
	@echo "  help       - Show this help"
	@echo ""
	@echo "Configuration:"
	@echo "  FPGA_FAMILY - FPGA family (ice40, ecp5, xilinx7, xilinx-ultrascale, intel-cyclone)"
	@echo "  FPGA_PART   - Specific FPGA part number"
	@echo "  TOOL        - Synthesis tool (openfpga, vivado, quartus)"
	@echo ""
	@echo "Open Source FPGA Flow:"
	@echo "  TOOL=openfpga FPGA_FAMILY=ice40 FPGA_PART=hx8k-ct256 make all"
	@echo "  TOOL=openfpga FPGA_FAMILY=ecp5 make all"
	@echo "  TOOL=openfpga FPGA_FAMILY=xilinx7 make all"

.PHONY: all synth impl bitstream timing resources power sim clean help 