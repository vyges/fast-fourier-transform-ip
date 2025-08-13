# Test Makefile for frontend detection issue
# Tests whether Yosys can auto-detect SystemVerilog files

YOSYS_CMD ?= yosys

.PHONY: test test_auto test_explicit clean help show_results

help:
	@echo "Frontend Detection Test Cases"
	@echo "============================="
	@echo "test_auto     - Test auto-detection (no explicit flag)"
	@echo "test_explicit - Test with explicit -f verilog frontend"
	@echo "test          - Run both tests"
	@echo "clean         - Remove test artifacts"
	@echo "show_results  - Show test results"
	@echo ""
	@echo "Variables:"
	@echo "  YOSYS_CMD - Yosys command (default: yosys)"

test: test_auto test_explicit
	@echo "All tests completed"

test_auto:
	@echo "Testing auto-detection (no explicit flag)..."
	@echo "Command: $(YOSYS_CMD) -p 'read_verilog -sv test_frontend.sv; hierarchy -top test_frontend; stat'"
	@echo "Expected: Yosys should auto-detect .sv file as SystemVerilog"
	@echo "Log: test_auto.log"
	@echo "----------------------------------------"
	@$(YOSYS_CMD) -p 'read_verilog -sv test_frontend.sv; hierarchy -top test_frontend; stat' > test_auto.log 2>&1; \
	if [ $$? -eq 0 ]; then \
		echo "Auto-detection test PASSED"; \
	else \
		echo "Auto-detection test FAILED"; \
	fi

test_explicit:
	@echo "Testing with explicit -f verilog frontend..."
	@echo "Command: $(YOSYS_CMD) -f verilog -p 'read_verilog -sv test_frontend.sv; hierarchy -top test_frontend; stat'"
	@echo "Expected: Should work regardless of auto-detection"
	@echo "Log: test_explicit.log"
	@echo "----------------------------------------"
	@$(YOSYS_CMD) -f verilog -p 'read_verilog -sv test_frontend.sv; hierarchy -top test_frontend; stat' > test_explicit.log 2>&1; \
	if [ $$? -eq 0 ]; then \
		echo "Explicit frontend test PASSED"; \
	else \
		echo "Explicit frontend test FAILED"; \
	fi

clean:
	rm -f *.log *.json *.txt

show_results:
	@echo "=== AUTO-DETECTION TEST RESULTS ==="
	@if [ -f test_auto.log ]; then \
		echo "Last 10 lines of test_auto.log:"; \
		tail -10 test_auto.log; \
	else \
		echo "test_auto.log not found"; \
	fi
	@echo ""
	@echo "=== EXPLICIT FRONTEND TEST RESULTS ==="
	@if [ -f test_explicit.log ]; then \
		echo "Last 10 lines of test_explicit.log:"; \
		tail -10 test_explicit.log; \
	else \
		echo "test_explicit.log not found"; \
	fi
