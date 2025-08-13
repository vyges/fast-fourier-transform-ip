# Master Makefile for Yosys Test Cases
# Runs all test cases and generates comprehensive report

YOSYS_CMD ?= yosys
TIMEOUT ?= 60

# Detect OS and set appropriate timeout command
UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
    # macOS - try gtimeout first, fallback to perl timeout
    ifeq ($(shell which gtimeout),)
        TIMEOUT_CMD = perl -e 'alarm shift; exec @ARGV' $(TIMEOUT)
    else
        TIMEOUT_CMD = gtimeout $(TIMEOUT)
    endif
    PLATFORM = macOS
else
    # Linux - use standard timeout
    TIMEOUT_CMD = timeout $(TIMEOUT)
    PLATFORM = Linux
endif

.PHONY: all test clean help report issue1 issue2 issue3 issue4 show_all_results

help:
	@echo "Yosys Test Suite - $(PLATFORM)"
	@echo "================================"
	@echo "all           - Run all test cases"
	@echo "test          - Run all test cases"
	@echo "issue1        - Test memory synthesis hanging"
	@echo "issue2        - Test frontend detection"
	@echo "issue3        - Test security assertions"
	@echo "issue4        - Test SystemVerilog support"
	@echo "report        - Generate test report"
	@echo "show_all_results - Show results from all tests"
	@echo "clean         - Clean all test artifacts"
	@echo ""
	@echo "Variables:"
	@echo "  YOSYS_CMD - Yosys command (default: yosys)"
	@echo "  TIMEOUT   - Timeout in seconds (default: 60)"
	@echo "  Platform  - Detected: $(PLATFORM)"

all: test
	@echo "All tests completed"

test: issue1 issue2 issue3 issue4
	@echo "All test suites completed"

issue1:
	@echo "Running Issue 1: Memory Synthesis Hanging"
	@echo "=========================================="
	@cd issue1_memory_hang && make test
	@echo ""

issue2:
	@echo "Running Issue 2: Frontend Detection"
	@echo "==================================="
	@cd issue2_frontend_detection && make test
	@echo ""

issue3:
	@echo "Running Issue 3: Security Assertions"
	@echo "===================================="
	@cd issue3_security_assertions && make test
	@echo ""

issue4:
	@echo "Running Issue 4: SystemVerilog Support"
	@echo "======================================"
	@cd issue4_systemverilog_support && make test
	@echo ""

report:
	@echo "Generating Yosys Test Report"
	@echo "============================"
	@echo "Platform: $(PLATFORM)"
	@echo "Yosys Command: $(YOSYS_CMD)"
	@echo "Timeout: $(TIMEOUT)s"
	@echo "Date: $(shell date)"
	@echo ""
	@echo "=== SUMMARY ==="
	@echo "Issue 1 (Memory): $(shell cd issue1_memory_hang && if [ -f test_small.log ] && [ -f test_large.log ]; then echo "Completed"; else echo "Not run"; fi)"
	@echo "Issue 2 (Frontend): $(shell cd issue2_frontend_detection && if [ -f test_auto.log ] && [ -f test_explicit.log ]; then echo "Completed"; else echo "Not run"; fi)"
	@echo "Issue 3 (Security): $(shell cd issue3_security_assertions && if [ -f test_yosys.log ] && [ -f test_full.log ]; then echo "Completed"; else echo "Not run"; fi)"
	@echo "Issue 4 (SystemVerilog): $(shell cd issue4_systemverilog_support && if [ -f test_parse.log ] && [ -f test_elaborate.log ] && [ -f test_synth.log ]; then echo "Completed"; else echo "Not run"; fi)"
	@echo ""
	@echo "For detailed results, run: make show_all_results"

show_all_results:
	@echo "=== DETAILED RESULTS ==="
	@echo ""
	@echo "Issue 1: Memory Synthesis Hanging"
	@echo "----------------------------------"
	@cd issue1_memory_hang && make show_results
	@echo ""
	@echo "Issue 2: Frontend Detection"
	@echo "---------------------------"
	@cd issue2_frontend_detection && make show_results
	@echo ""
	@echo "Issue 3: Security Assertions"
	@echo "-----------------------------"
	@cd issue3_security_assertions && make show_results
	@echo ""
	@echo "Issue 4: SystemVerilog Support"
	@echo "------------------------------"
	@cd issue4_systemverilog_support && make show_results

clean:
	@echo "Cleaning all test artifacts..."
	@cd issue1_memory_hang && make clean
	@cd issue2_frontend_detection && make clean
	@cd issue3_security_assertions && make clean
	@cd issue4_systemverilog_support && make clean
	@echo "Cleanup completed"

# Quick individual tests
quick1: issue1
quick2: issue2
quick3: issue3
quick4: issue4
