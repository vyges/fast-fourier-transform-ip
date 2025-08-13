# Test Makefile for memory synthesis hanging issue
# Tests both large and small memory arrays to compare behavior

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
else
    # Linux - use standard timeout
    TIMEOUT_CMD = timeout $(TIMEOUT)
endif

.PHONY: test test_large test_small test_large_manual clean help

help:
	@echo "Memory Synthesis Test Cases"
	@echo "=========================="
	@echo "test_large        - Test large memory (64K) with timeout"
	@echo "test_large_manual - Test large memory (64K) without timeout"
	@echo "test_small        - Test small memory (256) - should work"
	@echo "test              - Run both tests with timeout"
	@echo "clean             - Remove test artifacts"
	@echo ""
	@echo "Variables:"
	@echo "  YOSYS_CMD - Yosys command (default: yosys)"
	@echo "  TIMEOUT   - Timeout in seconds (default: 60)"

test: test_small test_large
	@echo "All tests completed"

test_small:
	@echo "Testing small memory (256 entries)..."
	@echo "Command: $(YOSYS_CMD) -p 'read_verilog -sv test_small_memory.sv; hierarchy -top test_small_memory; synth -top test_small_memory; stat'"
	@echo "Expected: Should complete quickly (under 10 seconds)"
	@echo "Log: test_small.log"
	@echo "----------------------------------------"
	@$(YOSYS_CMD) -p 'read_verilog -sv test_small_memory.sv; hierarchy -top test_small_memory; synth -top test_small_memory; stat' > test_small.log 2>&1
	@echo "Small memory test completed. Check test_small.log for details."

test_large:
	@echo "Testing large memory (64K entries) with $(TIMEOUT)s timeout..."
	@echo "Command: $(TIMEOUT_CMD) $(YOSYS_CMD) -p 'read_verilog -sv test_large_memory.sv; hierarchy -top test_large_memory; synth -top test_large_memory; stat'"
	@echo "Expected: May hang or take very long time"
	@echo "Log: test_large.log"
	@echo "----------------------------------------"
	@$(TIMEOUT_CMD) $(YOSYS_CMD) -p 'read_verilog -sv test_large_memory.sv; hierarchy -top test_large_memory; synth -top test_large_memory; stat' > test_large.log 2>&1; \
	if [ $$? -eq 124 ]; then \
		echo "Large memory test TIMED OUT after $(TIMEOUT)s"; \
	else \
		echo "Large memory test completed"; \
	fi

test_large_manual:
	@echo "Testing large memory (64K entries) WITHOUT timeout..."
	@echo "Command: $(YOSYS_CMD) -p 'read_verilog -sv test_large_memory.sv; hierarchy -top test_large_memory; synth -top test_large_memory; stat'"
	@echo "WARNING: This may hang indefinitely. Use Ctrl+C to stop."
	@echo "Log: test_large_manual.log"
	@echo "----------------------------------------"
	@$(YOSYS_CMD) -p 'read_verilog -sv test_large_memory.sv; hierarchy -top test_large_memory; synth -top test_large_memory; stat' > test_large_manual.log 2>&1

clean:
	rm -f *.log *.json *.txt

show_results:
	@echo "=== SMALL MEMORY TEST RESULTS ==="
	@if [ -f test_small.log ]; then \
		echo "Last 10 lines of test_small.log:"; \
		tail -10 test_small.log; \
	else \
		echo "test_small.log not found"; \
	fi
	@echo ""
	@echo "=== LARGE MEMORY TEST RESULTS ==="
	@if [ -f test_large.log ]; then \
		echo "Last 10 lines of test_large.log:"; \
		tail -10 test_large.log; \
	else \
		echo "test_large.log not found"; \
	fi
