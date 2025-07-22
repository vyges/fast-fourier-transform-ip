#=============================================================================
# Synthesis Makefile for FFT Hardware Accelerator
#=============================================================================
# Description: Makefile for Yosys synthesis of FFT hardware accelerator
#              with automatic rescaling and scale factor tracking.
#              Follows Vyges conventions for synthesis flow.
# Author:      Vyges IP Development Team
# Date:        2025-07-21
# License:     Apache-2.0
#=============================================================================

# Configuration
DESIGN_NAME = fft_top
RTL_DIR = ../../rtl
SYNTH_DIR = .
REPORTS_DIR = reports
NETLISTS_DIR = netlists

# Yosys configuration
YOSYS_CMD = yosys
YOSYS_FLAGS = -q

# Default target
all: synth_generic reports

# Create directories
$(REPORTS_DIR):
	mkdir -p $(REPORTS_DIR)

$(NETLISTS_DIR):
	mkdir -p $(NETLISTS_DIR)

# Generic synthesis
synth_generic: $(REPORTS_DIR) $(NETLISTS_DIR)
	@echo "Running generic synthesis for $(DESIGN_NAME)..."
	$(YOSYS_CMD) $(YOSYS_FLAGS) -p "read_verilog -sv $(RTL_DIR)/fft_top.sv; read_verilog -sv $(RTL_DIR)/fft_engine.sv; read_verilog -sv $(RTL_DIR)/fft_control.sv; read_verilog -sv $(RTL_DIR)/memory_interface.sv; read_verilog -sv $(RTL_DIR)/rescale_unit.sv; read_verilog -sv $(RTL_DIR)/scale_factor_tracker.sv; read_verilog -sv $(RTL_DIR)/twiddle_rom_synth.sv; hierarchy -top $(DESIGN_NAME); check; stat; synth -top $(DESIGN_NAME); opt -purge; clean; stat; write_verilog -noattr -noexpr -nohex -nodec $(NETLISTS_DIR)/$(DESIGN_NAME)_synth_generic.v; write_json $(NETLISTS_DIR)/$(DESIGN_NAME)_synth_generic.json; tee -o $(REPORTS_DIR)/synthesis_report_generic.txt stat"
	@echo "Generic synthesis completed!"

# Technology-specific synthesis (requires libraries)
synth_xilinx: $(REPORTS_DIR) $(NETLISTS_DIR)
	@echo "Running Xilinx synthesis for $(DESIGN_NAME)..."
	$(YOSYS_CMD) $(YOSYS_FLAGS) -p "read_verilog -sv $(RTL_DIR)/fft_top.sv; read_verilog -sv $(RTL_DIR)/fft_engine.sv; read_verilog -sv $(RTL_DIR)/fft_control.sv; read_verilog -sv $(RTL_DIR)/memory_interface.sv; read_verilog -sv $(RTL_DIR)/rescale_unit.sv; read_verilog -sv $(RTL_DIR)/scale_factor_tracker.sv; read_verilog -sv $(RTL_DIR)/twiddle_rom_synth.sv; hierarchy -top $(DESIGN_NAME); check; stat; synth -top $(DESIGN_NAME); opt -purge; dfflibmap; abc; clean; stat; write_verilog -noattr -noexpr -nohex -nodec $(NETLISTS_DIR)/$(DESIGN_NAME)_synth.v; write_json $(NETLISTS_DIR)/$(DESIGN_NAME)_synth.json; tee -o $(REPORTS_DIR)/synthesis_report.txt stat; tee -o $(REPORTS_DIR)/timing_report.txt timing -full"
	@echo "Xilinx synthesis completed!"

# Generate reports
reports: synth_generic
	@echo "Generating synthesis reports..."
	@if [ -f synthesis_report_generic.txt ]; then \
		echo "Synthesis report generated: synthesis_report_generic.txt"; \
		head -20 synthesis_report_generic.txt; \
	else \
		echo "No synthesis report found"; \
	fi

# Clean
clean:
	@echo "Cleaning synthesis artifacts..."
	rm -rf $(REPORTS_DIR)
	rm -rf $(NETLISTS_DIR)
	rm -f *.v
	rm -f *.json
	rm -f *.txt
	rm -f *.log

# Help
help:
	@echo "FFT Synthesis Makefile"
	@echo "====================="
	@echo ""
	@echo "Available targets:"
	@echo "  all              - Run generic synthesis and generate reports (default)"
	@echo "  synth_generic    - Run generic synthesis"
	@echo "  synth_xilinx     - Run Xilinx-specific synthesis (requires libraries)"
	@echo "  reports          - Generate synthesis reports"
	@echo "  clean            - Clean synthesis artifacts"
	@echo "  help             - Show this help message"
	@echo ""
	@echo "Configuration:"
	@echo "  DESIGN_NAME      - Top module name ($(DESIGN_NAME))"
	@echo "  RTL_DIR          - RTL source directory ($(RTL_DIR))"
	@echo "  YOSYS_CMD        - Yosys command ($(YOSYS_CMD))"
	@echo ""
	@echo "Examples:"
	@echo "  make synth_generic"
	@echo "  make reports"
	@echo "  make clean"

.PHONY: all synth_generic synth_xilinx reports clean help 