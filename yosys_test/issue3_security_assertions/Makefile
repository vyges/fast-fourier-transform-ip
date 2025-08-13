# Test Makefile for security assertion limitations
# Tests different approaches to security validation

YOSYS_CMD ?= yosys

.PHONY: test test_yosys test_full clean help show_results

help:
	@echo "Security Assertion Test Cases"
	@echo "============================="
	@echo "test_yosys  - Test with YOSYS define (should work)"
	@echo "test_full   - Test with full SystemVerilog (may fail)"
	@echo "test        - Run both tests"
	@echo "clean       - Remove test artifacts"
	@echo "show_results - Show test results"
	@echo ""
	@echo "Variables:"
	@echo "  YOSYS_CMD - Yosys command (default: yosys)"

test: test_yosys test_full
	@echo "All tests completed"

test_yosys:
	@echo "Testing with YOSYS define..."
	@echo "Command: $(YOSYS_CMD) -DYOSYS -p 'read_verilog -sv test_security.sv; hierarchy -top test_security; stat'"
	@echo "Expected: Should work with YOSYS define"
	@echo "Log: test_yosys.log"
	@echo "----------------------------------------"
	@$(YOSYS_CMD) -DYOSYS -p 'read_verilog -sv test_security.sv; hierarchy -top test_security; stat' > test_yosys.log 2>&1; \
	if [ $$? -eq 0 ]; then \
		echo "YOSYS define test PASSED"; \
	else \
		echo "YOSYS define test FAILED"; \
	fi

test_full:
	@echo "Testing with full SystemVerilog features..."
	@echo "Command: $(YOSYS_CMD) -p 'read_verilog -sv test_security.sv; hierarchy -top test_security; stat'"
	@echo "Expected: May fail due to security assertion limitations"
	@echo "Log: test_full.log"
	@echo "----------------------------------------"
	@$(YOSYS_CMD) -p 'read_verilog -sv test_security.sv; hierarchy -top test_security; stat' > test_full.log 2>&1; \
	if [ $$? -eq 0 ]; then \
		echo "Full SystemVerilog test PASSED"; \
	else \
		echo "Full SystemVerilog test FAILED"; \
	fi

clean:
	rm -f *.log *.json *.txt

show_results:
	@echo "=== YOSYS DEFINE TEST RESULTS ==="
	@if [ -f test_yosys.log ]; then \
		echo "Last 10 lines of test_yosys.log:"; \
		tail -10 test_yosys.log; \
	else \
		echo "test_yosys.log not found"; \
	fi
	@echo ""
	@echo "=== FULL SYSTEMVERILOG TEST RESULTS ==="
	@if [ -f test_full.log ]; then \
		echo "Last 10 lines of test_full.log:"; \
		tail -10 test_full.log; \
	else \
		echo "test_full.log not found"; \
	fi
