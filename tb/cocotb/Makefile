#=============================================================================
# Cocotb Testbench Makefile for FFT Hardware Accelerator
#=============================================================================
# Description: Makefile for Cocotb-based verification of FFT accelerator
#              Supports multiple simulators and comprehensive test scenarios
# Author:      Vyges IP Development Team
# Date:        2025-07-21
# License:     Apache-2.0
#=============================================================================

# Configuration
SIMULATOR ?= verilator
TOP_MODULE = fft_top
RTL_DIR = ../../rtl
TB_DIR = .
WORK_DIR = work
COVERAGE = 1
VERBOSE = 1

# Python environment
PYTHONPATH := $(PYTHONPATH):$(TB_DIR)
COCOTB_REDUCED_LOG_FMT = 1

# Simulator-specific settings
ifeq ($(SIMULATOR),verilator)
    SIM_CMD = verilator
    SIM_FLAGS = --cc --exe --build --trace --coverage
    SIM_FILES = $(RTL_DIR)/*.sv
    SIM_TARGET = obj_dir/V$(TOP_MODULE)
    RUN_CMD = $(SIM_TARGET)
    COCOTB_HDL_TIMEPRECISION = 1ps
    COCOTB_HDL_TIMEUNIT = 1ns
else ifeq ($(SIMULATOR),icarus)
    SIM_CMD = iverilog
    SIM_FLAGS = -g2012 -I$(RTL_DIR) -o $(WORK_DIR)/$(TOP_MODULE).vvp
    SIM_FILES = $(RTL_DIR)/*.sv
    SIM_TARGET = $(WORK_DIR)/$(TOP_MODULE).vvp
    RUN_CMD = vvp $(SIM_TARGET)
    COCOTB_HDL_TIMEPRECISION = 1ps
    COCOTB_HDL_TIMEUNIT = 1ns
else ifeq ($(SIMULATOR),vcs)
    SIM_CMD = vcs
    SIM_FLAGS = -full64 -sverilog -debug_all -timescale=1ns/1ps
    SIM_FILES = $(RTL_DIR)/*.sv
    SIM_TARGET = simv
    RUN_CMD = ./$(SIM_TARGET)
    COCOTB_HDL_TIMEPRECISION = 1ps
    COCOTB_HDL_TIMEUNIT = 1ns
else ifeq ($(SIMULATOR),modelsim)
    SIM_CMD = vsim
    SIM_FLAGS = -do "run -all; quit"
    SIM_FILES = $(RTL_DIR)/*.sv
    SIM_TARGET = work.$(TOP_MODULE)
    RUN_CMD = $(SIM_CMD) $(SIM_TARGET) $(SIM_FLAGS)
    COCOTB_HDL_TIMEPRECISION = 1ps
    COCOTB_HDL_TIMEUNIT = 1ns
endif

# Cocotb settings
MODULE = test_fft_basic
TOPLEVEL = $(TOP_MODULE)
TOPLEVEL_LANG = verilog

# Test configuration
TEST_NAME ?= all
COCOTB_LOG_LEVEL = INFO

# Coverage settings
ifeq ($(COVERAGE),1)
    COCOTB_COVERAGE = 1
    COVERAGE_DIR = coverage
    COVERAGE_REPORT = $(COVERAGE_DIR)/coverage.xml
endif

# Verbose settings
ifeq ($(VERBOSE),1)
    COCOTB_VERBOSE = 1
endif

# Default target
all: compile run

# Compilation target
compile:
	@echo "Compiling FFT design with $(SIMULATOR)..."
	@mkdir -p $(WORK_DIR)
ifeq ($(SIMULATOR),verilator)
	$(SIM_CMD) $(SIM_FLAGS) $(SIM_FILES) -o $(SIM_TARGET)
else ifeq ($(SIMULATOR),icarus)
	$(SIM_CMD) $(SIM_FLAGS) $(SIM_FILES)
else ifeq ($(SIMULATOR),vcs)
	$(SIM_CMD) $(SIM_FLAGS) $(SIM_FILES) -o $(SIM_TARGET)
else ifeq ($(SIMULATOR),modelsim)
	vlib work
	vlog -sv $(SIM_FILES)
endif

# Run target
run: compile
	@echo "Running Cocotb tests with $(SIMULATOR)..."
	@mkdir -p $(COVERAGE_DIR)
	MODULE=$(MODULE) TOPLEVEL=$(TOPLEVEL) TOPLEVEL_LANG=$(TOPLEVEL_LANG) \
	COCOTB_REDUCED_LOG_FMT=$(COCOTB_REDUCED_LOG_FMT) \
	COCOTB_HDL_TIMEPRECISION=$(COCOTB_HDL_TIMEPRECISION) \
	COCOTB_HDL_TIMEUNIT=$(COCOTB_HDL_TIMEUNIT) \
	COCOTB_LOG_LEVEL=$(COCOTB_LOG_LEVEL) \
	$(if $(COCOTB_VERBOSE),COCOTB_VERBOSE=$(COCOTB_VERBOSE),) \
	$(if $(COCOTB_COVERAGE),COCOTB_COVERAGE=$(COCOTB_COVERAGE),) \
	$(RUN_CMD)

# Test-specific targets
test_basic: compile
	@echo "Running basic FFT functionality tests..."
	MODULE=test_fft_basic TOPLEVEL=$(TOPLEVEL) TOPLEVEL_LANG=$(TOPLEVEL_LANG) \
	COCOTB_REDUCED_LOG_FMT=$(COCOTB_REDUCED_LOG_FMT) \
	COCOTB_HDL_TIMEPRECISION=$(COCOTB_HDL_TIMEPRECISION) \
	COCOTB_HDL_TIMEUNIT=$(COCOTB_HDL_TIMEUNIT) \
	COCOTB_LOG_LEVEL=$(COCOTB_LOG_LEVEL) \
	$(if $(COCOTB_VERBOSE),COCOTB_VERBOSE=$(COCOTB_VERBOSE),) \
	$(if $(COCOTB_COVERAGE),COCOTB_COVERAGE=$(COCOTB_COVERAGE),) \
	$(RUN_CMD)

test_rescaling: compile
	@echo "Running FFT rescaling tests..."
	MODULE=test_fft_rescaling TOPLEVEL=$(TOPLEVEL) TOPLEVEL_LANG=$(TOPLEVEL_LANG) \
	COCOTB_REDUCED_LOG_FMT=$(COCOTB_REDUCED_LOG_FMT) \
	COCOTB_HDL_TIMEPRECISION=$(COCOTB_HDL_TIMEPRECISION) \
	COCOTB_HDL_TIMEUNIT=$(COCOTB_HDL_TIMEUNIT) \
	COCOTB_LOG_LEVEL=$(COCOTB_LOG_LEVEL) \
	$(if $(COCOTB_VERBOSE),COCOTB_VERBOSE=$(COCOTB_VERBOSE),) \
	$(if $(COCOTB_COVERAGE),COCOTB_COVERAGE=$(COCOTB_COVERAGE),) \
	$(RUN_CMD)

test_edge_cases: compile
	@echo "Running FFT edge case tests..."
	MODULE=test_fft_edge_cases TOPLEVEL=$(TOPLEVEL) TOPLEVEL_LANG=$(TOPLEVEL_LANG) \
	COCOTB_REDUCED_LOG_FMT=$(COCOTB_REDUCED_LOG_FMT) \
	COCOTB_HDL_TIMEPRECISION=$(COCOTB_HDL_TIMEPRECISION) \
	COCOTB_HDL_TIMEUNIT=$(COCOTB_HDL_TIMEUNIT) \
	COCOTB_LOG_LEVEL=$(COCOTB_LOG_LEVEL) \
	$(if $(COCOTB_VERBOSE),COCOTB_VERBOSE=$(COCOTB_VERBOSE),) \
	$(if $(COCOTB_COVERAGE),COCOTB_COVERAGE=$(COCOTB_COVERAGE),) \
	$(RUN_CMD)

test_all: test_basic test_rescaling test_edge_cases
	@echo "All Cocotb tests completed."

# Performance test
test_performance: compile
	@echo "Running FFT performance tests..."
	MODULE=test_fft_basic TOPLEVEL=$(TOPLEVEL) TOPLEVEL_LANG=$(TOPLEVEL_LANG) \
	COCOTB_REDUCED_LOG_FMT=$(COCOTB_REDUCED_LOG_FMT) \
	COCOTB_HDL_TIMEPRECISION=$(COCOTB_HDL_TIMEPRECISION) \
	COCOTB_HDL_TIMEUNIT=$(COCOTB_HDL_TIMEUNIT) \
	COCOTB_LOG_LEVEL=WARNING \
	$(RUN_CMD) +test=performance

# Coverage report
coverage: run
ifeq ($(COVERAGE),1)
	@echo "Generating coverage report..."
	@mkdir -p $(COVERAGE_DIR)
	@if [ -f $(COVERAGE_REPORT) ]; then \
		echo "Coverage report generated: $(COVERAGE_REPORT)"; \
		# Copy coverage reports to public directory for GitHub Pages \
		mkdir -p ../../public/coverage; \
		cp -r $(COVERAGE_DIR)/* ../../public/coverage/ 2>/dev/null || echo "No coverage files to copy"; \
		# Generate coverage summary \
		echo "Coverage Summary:" > ../../public/coverage_summary.txt; \
		echo "=================" >> ../../public/coverage_summary.txt; \
		echo "Generated: $(shell date -u)" >> ../../public/coverage_summary.txt; \
		echo "Test Files: test_fft_basic.py, test_fft_rescaling.py, test_fft_edge_cases.py" >> ../../public/coverage_summary.txt; \
		echo "Total Tests: 15+" >> ../../public/coverage_summary.txt; \
		echo "Coverage Areas:" >> ../../public/coverage_summary.txt; \
		echo "- Basic FFT functionality" >> ../../public/coverage_summary.txt; \
		echo "- Rescaling and overflow detection" >> ../../public/coverage_summary.txt; \
		echo "- Edge cases and boundary conditions" >> ../../public/coverage_summary.txt; \
		echo "- APB interface testing" >> ../../public/coverage_summary.txt; \
		echo "- Memory interface testing" >> ../../public/coverage_summary.txt; \
		echo "- Performance testing" >> ../../public/coverage_summary.txt; \
		echo "- Error handling" >> ../../public/coverage_summary.txt; \
		echo "Coverage files available in: public/coverage/" >> ../../public/coverage_summary.txt; \
	else \
		echo "No coverage data found"; \
	fi
endif

# Waveform viewing
waves:
ifeq ($(SIMULATOR),verilator)
	@echo "Opening waveforms with GTKWave..."
	@if [ -f dump.vcd ]; then \
		gtkwave dump.vcd; \
	else \
		echo "No waveform file found. Run simulation first."; \
	fi
else ifeq ($(SIMULATOR),icarus)
	@echo "Opening waveforms with GTKWave..."
	@if [ -f dump.vcd ]; then \
		gtkwave dump.vcd; \
	else \
		echo "No waveform file found. Run simulation first."; \
	fi
else ifeq ($(SIMULATOR),vcs)
	@echo "Opening waveforms with DVE..."
	@if [ -f vcdplus.vpd ]; then \
		dve -vpd vcdplus.vpd; \
	else \
		echo "No waveform file found. Run simulation first."; \
	fi
else ifeq ($(SIMULATOR),modelsim)
	@echo "Opening waveforms with ModelSim..."
	@if [ -f wave.do ]; then \
		vsim -do wave.do; \
	else \
		echo "No waveform file found. Run simulation first."; \
	fi
endif

# Clean target
clean:
	@echo "Cleaning build artifacts..."
	@rm -rf $(WORK_DIR)
	@rm -rf obj_dir
	@rm -rf simv
	@rm -rf simv.daidir
	@rm -rf csrc
	@rm -rf ucli.key
	@rm -rf dump.vcd
	@rm -rf vcdplus.vpd
	@rm -rf wave.do
	@rm -rf transcript
	@rm -rf work
	@rm -rf $(COVERAGE_DIR)
	@rm -rf __pycache__
	@rm -rf *.pyc
	@find . -name "*.log" -delete
	@find . -name "*.vcd" -delete
	@find . -name "*.vpd" -delete

# Help target
help:
	@echo "FFT Cocotb Testbench Makefile"
	@echo "============================="
	@echo ""
	@echo "Available targets:"
	@echo "  all              - Compile and run all tests (default)"
	@echo "  compile          - Compile the design"
	@echo "  run              - Run the default test"
	@echo "  test_basic       - Run basic FFT functionality tests"
	@echo "  test_rescaling   - Run FFT rescaling tests"
	@echo "  test_edge_cases  - Run FFT edge case tests"
	@echo "  test_all         - Run all test modules"
	@echo "  test_performance - Run performance tests"
	@echo "  coverage         - Generate coverage report"
	@echo "  waves            - View waveforms"
	@echo "  clean            - Clean build artifacts"
	@echo "  help             - Show this help message"
	@echo ""
	@echo "Configuration variables:"
	@echo "  SIMULATOR        - Simulator to use (verilator, icarus, vcs, modelsim)"
	@echo "  COVERAGE         - Enable coverage (1 or 0)"
	@echo "  VERBOSE          - Enable verbose output (1 or 0)"
	@echo "  TEST_NAME        - Specific test to run"
	@echo ""
	@echo "Examples:"
	@echo "  make SIMULATOR=verilator test_basic"
	@echo "  make SIMULATOR=icarus test_rescaling COVERAGE=1"
	@echo "  make SIMULATOR=vcs test_all VERBOSE=1"

# Phony targets
.PHONY: all compile run test_basic test_rescaling test_all test_performance coverage waves clean help 