#=============================================================================
# FFT Testbench Makefile
#=============================================================================
# Description: Makefile for FFT hardware accelerator testbench
#              Supports multiple simulators and test configurations
# Author:      Vyges IP Development Team
# Date:        2025-07-21
# License:     Apache-2.0
#=============================================================================

# Configuration
SIMULATOR ?= verilator
TOP_MODULE = tb_simple
RTL_DIR = ../../rtl
TB_DIR = .
WORK_DIR = work
COVERAGE = 1
# The IP's own RTL. fft_ctrl_tlul.sv is the SoC's TL-UL wrapper: it imports the SoC's
# tlul_pkg and is compiled by the SoC, not by this testbench.
RTL_FILES = $(filter-out $(RTL_DIR)/fft_ctrl_tlul.sv,$(wildcard $(RTL_DIR)/*.sv))

# Simulator-specific settings
ifeq ($(SIMULATOR),verilator)
    SIM_CMD = verilator
    SIM_FLAGS = --cc --exe --build --trace --coverage --timing -Wno-lint -Wno-MULTITOP --top-module tb_simple -I$(RTL_DIR)
    SIM_FILES = $(RTL_FILES) tb_simple.sv verilator_tb_simple.cpp
    SIM_TARGET = obj_dir/Vtb_simple
    RUN_CMD = ./obj_dir/Vtb_simple
else ifeq ($(SIMULATOR),iverilog)
    SIM_CMD = iverilog
    SIM_FLAGS = -g2012 -Wall -I$(RTL_DIR) -I$(TB_DIR)
    SIM_FILES = $(RTL_FILES) $(TB_DIR)/*.sv
    SIM_TARGET = $(WORK_DIR)/$(TOP_MODULE)
    RUN_CMD = vvp $(SIM_TARGET)
else ifeq ($(SIMULATOR),vcs)
    SIM_CMD = vcs
    SIM_FLAGS = -full64 -sverilog -debug_all +v2k
    SIM_FILES = $(RTL_FILES) $(TB_DIR)/*.sv
    SIM_TARGET = simv
    RUN_CMD = ./$(SIM_TARGET)
else ifeq ($(SIMULATOR),modelsim)
    SIM_CMD = vlog
    SIM_FLAGS = -work $(WORK_DIR) -sv
    SIM_FILES = $(RTL_FILES) $(TB_DIR)/*.sv
    SIM_TARGET = $(WORK_DIR)/$(TOP_MODULE)
    RUN_CMD = vsim -c -do "run -all; quit" $(SIM_TARGET)
endif

# Coverage settings
ifeq ($(COVERAGE),1)
    ifeq ($(SIMULATOR),verilator)
        SIM_FLAGS += --coverage-line --coverage-toggle --coverage-user
    else ifeq ($(SIMULATOR),vcs)
        SIM_FLAGS += -cm line+cond+fsm+branch+tgl
    endif
endif

# Default target
all: compile run

# Create work directory
$(WORK_DIR):
	mkdir -p $(WORK_DIR)

# Compile
compile: $(WORK_DIR)
	mkdir -p waveforms
ifeq ($(SIMULATOR),verilator)
	$(SIM_CMD) $(SIM_FLAGS) $(SIM_FILES)
else ifeq ($(SIMULATOR),iverilog)
	$(SIM_CMD) $(SIM_FLAGS) -o $(SIM_TARGET) $(SIM_FILES)
else ifeq ($(SIMULATOR),vcs)
	$(SIM_CMD) $(SIM_FLAGS) -o $(SIM_TARGET) $(SIM_FILES)
else ifeq ($(SIMULATOR),modelsim)
	vlib $(WORK_DIR)
	$(SIM_CMD) $(SIM_FLAGS) $(SIM_FILES)
	vsim -c -do "vsim $(TOP_MODULE); quit"
endif

# Run simulation
run: compile
	mkdir -p waveforms
	$(RUN_CMD)
	@if [ "$(SIMULATOR)" = "verilator" ]; then \
		if [ -d obj_dir ]; then \
			cp obj_dir/*.vcd . 2>/dev/null || true; \
		fi; \
	fi

# Explicit Verilator test target for workflow
.PHONY: test_verilator

test_verilator:
	$(MAKE) SIMULATOR=verilator compile
	$(MAKE) SIMULATOR=verilator run
	@if [ -d obj_dir ]; then \
		cp obj_dir/*.vcd . 2>/dev/null || true; \
	fi

# Clean
clean:
	rm -rf $(WORK_DIR)
	rm -rf obj_dir
	rm -f simv
	rm -f *.vcd
	rm -f *.log
	rm -f *.coverage

# Test targets. tb_simple (compile / run) only elaborates the core; the named tests run the
# bit-exact golden regression (../golden), which checks every output word against a fixed-point
# model, on the cases each name covers.
GOLDEN = python3 ../golden/run_golden.py

test_basic:
	$(GOLDEN) n8_small_plain n16_impulse n256_small_round_sat

test_rescaling:
	$(GOLDEN) n256_full_rescale n512_mid_rescale_rnd n1024_divide_by_n

test_overflow:
	$(GOLDEN) n1024_wrap_overflow

test_performance:
	$(GOLDEN) n1024_firmware_sine

# Individual module tests with VCD generation
test_twiddle_rom:
	@echo "Testing twiddle ROM module..."
	iverilog -g2012 -Wall ../../rtl/twiddle_rom.sv tb_twiddle_rom.sv
	vvp a.out
	@echo "VCD file generated: twiddle_rom_test.vcd"

test_rescale_unit:
	@echo "Testing rescale unit module..."
	iverilog -g2012 -Wall ../../rtl/rescale_unit.sv tb_rescale_unit.sv
	vvp a.out
	@echo "VCD file generated: rescale_unit_test.vcd"

test_all_modules: test_twiddle_rom test_rescale_unit
	@echo "All module tests completed!"

# Coverage targets
coverage: run
ifeq ($(SIMULATOR),verilator)
	verilator_coverage --annotate coverage_annotated coverage.dat
else ifeq ($(SIMULATOR),vcs)
	dve -full64 -cov -dir *.vdb
endif

# Waveform viewing
waves:
ifeq ($(SIMULATOR),verilator)
	gtkwave $(TOP_MODULE).vcd
else ifeq ($(SIMULATOR),vcs)
	dve -full64 -vpd vcdplus.vpd
else ifeq ($(SIMULATOR),modelsim)
	vsim -gui $(SIM_TARGET)
endif

# Lint check
lint:
ifeq ($(SIMULATOR),verilator)
	verilator --lint-only -Wno-MULTITOP -I$(RTL_DIR) $(RTL_FILES)
else ifeq ($(SIMULATOR),vcs)
	$(SIM_CMD) -full64 -sverilog -lint-only $(RTL_FILES)
endif

# Help
help:
	@echo "Available targets:"
	@echo "  all          - Compile and run simulation"
	@echo "  compile      - Compile the design"
	@echo "  run          - Run simulation"
	@echo "  clean        - Clean generated files"
	@echo "  test_basic   - Golden regression: small transforms (8, 16, 256 points)"
	@echo "  test_rescaling - Golden regression: scaled transforms (256 to 1024 points)"
	@echo "  test_overflow - Golden regression: unscaled 1024 points that overflow"
	@echo "  test_performance - Golden regression: 1024-point sine, with its cycle count"
	@echo "  coverage     - Generate coverage report"
	@echo "  waves        - View waveforms"
	@echo "  lint         - Run linting"
	@echo "  help         - Show this help"
	@echo ""
	@echo "Configuration:"
	@echo "  SIMULATOR    - Simulator to use (verilator|iverilog|vcs|modelsim)"
	@echo "  COVERAGE     - Enable coverage (0|1)"

.PHONY: all compile run clean test_basic test_rescaling test_overflow test_performance coverage waves lint help 