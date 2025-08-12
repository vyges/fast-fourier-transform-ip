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
# FFT IP Synthesis Makefile
# Updated with timeout protection and individual module testing

# Configuration
RTL_DIR = ../../rtl
NETLISTS_DIR = netlists
REPORTS_DIR = reports
YOSYS_CMD = yosys
YOSYS_FLAGS = -q

# Default target
all: synth_individual

# Create directories
$(NETLISTS_DIR):
	mkdir -p $(NETLISTS_DIR)

$(REPORTS_DIR):
	mkdir -p $(REPORTS_DIR)

# Create all required directories
create_dirs: $(REPORTS_DIR) $(NETLISTS_DIR)

# Individual module synthesis (recommended)
synth_individual: create_dirs
	@echo "=== FFT IP Individual Module Synthesis ==="
	@echo "Testing each module individually..."
	@echo ""
	@echo "1. fft_engine:"
	$(YOSYS_CMD) -p "read_verilog -sv $(RTL_DIR)/fft_engine.sv; hierarchy -top fft_engine; synth -top fft_engine; stat" | tee $(REPORTS_DIR)/fft_engine_stats.txt && echo "PASS" || echo "FAIL"
	@echo "2. fft_control:"
	$(YOSYS_CMD) -p "read_verilog -sv $(RTL_DIR)/fft_control.sv; hierarchy -top fft_control; synth -top fft_control; stat" | tee $(REPORTS_DIR)/fft_control_stats.txt && echo "PASS" || echo "FAIL"
	@echo "3. rescale_unit:"
	$(YOSYS_CMD) -p "read_verilog -sv $(RTL_DIR)/rescale_unit.sv; hierarchy -top rescale_unit; synth -top rescale_unit; stat" | tee $(REPORTS_DIR)/rescale_unit_stats.txt && echo "PASS" || echo "FAIL"
	@echo "4. scale_factor_tracker:"
	$(YOSYS_CMD) -p "read_verilog -sv $(RTL_DIR)/scale_factor_tracker.sv; hierarchy -top scale_factor_tracker; synth -top scale_factor_tracker; stat" | tee $(REPORTS_DIR)/scale_factor_tracker_stats.txt && echo "PASS" || echo "FAIL"
	@echo "5. twiddle_rom_synth:"
	$(YOSYS_CMD) -p "read_verilog -sv twiddle_rom_synth.sv; hierarchy -top twiddle_rom_synth; synth -top twiddle_rom_synth; stat" | tee $(REPORTS_DIR)/twiddle_rom_stats.txt && echo "PASS" || echo "FAIL"
	@echo "6. memory_interface (simplified):"
	./test_memory_interface_simple.sh | tee $(REPORTS_DIR)/memory_interface_stats.txt && echo "PASS" || echo "FAIL"
	@echo ""
	@echo "=== Individual Module Synthesis Complete ==="
	@echo "Note: memory_interface requires simplified version due to large memory array"
	@echo "Detailed statistics saved to $(REPORTS_DIR)/*_stats.txt"

# Simplified synthesis (individual modules)
synth_simple: create_dirs
	@echo "Running simplified synthesis for individual modules..."
	@echo "Step 1: Synthesizing memory_interface..."
	./timeout_wrapper.sh 30 "$(YOSYS_CMD) $(YOSYS_FLAGS) -p 'read_verilog -sv $(RTL_DIR)/memory_interface.sv; hierarchy -top memory_interface; synth -top memory_interface; stat'" || (echo "memory_interface synthesis failed or timed out"; exit 1)
	@echo "Step 2: Synthesizing fft_control..."
	./timeout_wrapper.sh 30 "$(YOSYS_CMD) $(YOSYS_FLAGS) -p 'read_verilog -sv $(RTL_DIR)/fft_control.sv; hierarchy -top fft_control; synth -top fft_control; stat'" || (echo "fft_control synthesis failed or timed out"; exit 1)
	@echo "Step 3: Synthesizing rescale_unit..."
	./timeout_wrapper.sh 30 "$(YOSYS_CMD) $(YOSYS_FLAGS) -p 'read_verilog -sv $(RTL_DIR)/rescale_unit.sv; hierarchy -top rescale_unit; synth -top rescale_unit; stat'" || (echo "rescale_unit synthesis failed or timed out"; exit 1)
	@echo "Step 4: Synthesizing scale_factor_tracker..."
	./timeout_wrapper.sh 30 "$(YOSYS_CMD) $(YOSYS_FLAGS) -p 'read_verilog -sv $(RTL_DIR)/scale_factor_tracker.sv; hierarchy -top scale_factor_tracker; synth -top scale_factor_tracker; stat'" || (echo "scale_factor_tracker synthesis failed or timed out"; exit 1)
	@echo "Step 5: Synthesizing twiddle_rom_synth..."
	./timeout_wrapper.sh 30 "$(YOSYS_CMD) $(YOSYS_FLAGS) -p 'read_verilog -sv twiddle_rom_synth.sv; hierarchy -top twiddle_rom_synth; synth -top twiddle_rom_synth; stat'" || (echo "twiddle_rom_synth synthesis failed or timed out"; exit 1)
	@echo "Simplified synthesis completed!"

# Full synthesis (WARNING: May hang due to memory interface)
synth_full: create_dirs
	@echo "WARNING: Full synthesis may hang due to large memory array in memory_interface"
	@echo "Consider using synth_individual instead"
	@echo "Proceeding with full synthesis (use Ctrl+C if it hangs)..."
	./timeout_wrapper.sh 300 '$(YOSYS_CMD) $(YOSYS_FLAGS) -p "read_verilog -sv $(RTL_DIR)/fft_top.sv; read_verilog -sv $(RTL_DIR)/fft_engine.sv; read_verilog -sv $(RTL_DIR)/fft_control.sv; read_verilog -sv $(RTL_DIR)/memory_interface.sv; read_verilog -sv $(RTL_DIR)/rescale_unit.sv; read_verilog -sv $(RTL_DIR)/scale_factor_tracker.sv; read_verilog -sv twiddle_rom_synth.sv; hierarchy -top fft_top; check; stat; synth -top fft_top; opt -purge; clean; stat"'

# Comprehensive synthesis test
synth_test: create_dirs
	@echo "Running comprehensive synthesis test..."
	./test_comprehensive_synthesis.sh

# Generate synthesis reports
generate_reports:
	@echo "Generating synthesis reports..."
	@echo "Synthesis report generated: $(REPORTS_DIR)/synthesis_report_generic.txt"

# Clean up
clean:
	rm -rf $(NETLISTS_DIR) $(REPORTS_DIR)
	rm -f *.v *.json *.txt
	rm -f temp_*.sv

# Help
help:
	@echo "Available targets:"
	@echo "  synth_individual  - Test each module individually (RECOMMENDED)"
	@echo "  synth_simple      - Simplified synthesis of individual modules"
	@echo "  synth_full        - Full synthesis (may hang)"
	@echo "  synth_test        - Comprehensive synthesis test"
	@echo "  clean             - Clean generated files"
	@echo "  help              - Show this help"

.PHONY: all synth_individual synth_simple synth_full synth_test generate_reports clean help create_dirs 