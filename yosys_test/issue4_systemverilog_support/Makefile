# Test Makefile for SystemVerilog feature support consistency
# Tests various SystemVerilog constructs to identify inconsistencies

YOSYS_CMD ?= yosys

.PHONY: test test_parse test_synth test_elaborate clean help show_results

help:
	@echo "SystemVerilog Feature Support Test Cases"
	@echo "======================================="
	@echo "test_parse     - Test parsing of SystemVerilog features"
	@echo "test_synth     - Test synthesis of SystemVerilog features"
	@echo "test_elaborate - Test elaboration (proc) of SystemVerilog features"
	@echo "test           - Run all tests"
	@echo "clean          - Remove test artifacts"
	@echo "show_results   - Show test results"
	@echo ""
	@echo "Variables:"
	@echo "  YOSYS_CMD - Yosys command (default: yosys)"

test: test_parse test_elaborate test_synth
	@echo "All tests completed"

test_parse:
	@echo "Testing parsing of SystemVerilog features..."
	@echo "Command: $(YOSYS_CMD) -p 'read_verilog -sv test_sv_features.sv; hierarchy -top test_sv_features; stat'"
	@echo "Expected: Should parse without errors"
	@echo "Log: test_parse.log"
	@echo "----------------------------------------"
	@$(YOSYS_CMD) -p 'read_verilog -sv test_sv_features.sv; hierarchy -top test_sv_features; stat' > test_parse.log 2>&1; \
	if [ $$? -eq 0 ]; then \
		echo "Parse test PASSED"; \
	else \
		echo "Parse test FAILED"; \
	fi

test_elaborate:
	@echo "Testing elaboration (proc) of SystemVerilog features..."
	@echo "Command: $(YOSYS_CMD) -p 'read_verilog -sv test_sv_features.sv; hierarchy -top test_sv_features; proc; stat'"
	@echo "Expected: Should elaborate without errors"
	@echo "Log: test_elaborate.log"
	@echo "----------------------------------------"
	@$(YOSYS_CMD) -p 'read_verilog -sv test_sv_features.sv; hierarchy -top test_sv_features; proc; stat' > test_elaborate.log 2>&1; \
	if [ $$? -eq 0 ]; then \
		echo "Elaboration test PASSED"; \
	else \
		echo "Elaboration test FAILED"; \
	fi

test_synth:
	@echo "Testing synthesis of SystemVerilog features..."
	@echo "Command: $(YOSYS_CMD) -p 'read_verilog -sv test_sv_features.sv; hierarchy -top test_sv_features; synth -top test_sv_features; stat'"
	@echo "Expected: Should synthesize without errors"
	@echo "Log: test_synth.log"
	@echo "----------------------------------------"
	@$(YOSYS_CMD) -p 'read_verilog -sv test_sv_features.sv; hierarchy -top test_sv_features; synth -top test_sv_features; stat' > test_synth.log 2>&1; \
	if [ $$? -eq 0 ]; then \
		echo "Synthesis test PASSED"; \
	else \
		echo "Synthesis test FAILED"; \
	fi

clean:
	rm -f *.log *.json *.txt

show_results:
	@echo "=== PARSE TEST RESULTS ==="
	@if [ -f test_parse.log ]; then \
		echo "Last 10 lines of test_parse.log:"; \
		tail -10 test_parse.log; \
	else \
		echo "test_parse.log not found"; \
	fi
	@echo ""
	@echo "=== ELABORATION TEST RESULTS ==="
	@if [ -f test_elaborate.log ]; then \
		echo "Last 10 lines of test_elaborate.log:"; \
		tail -10 test_elaborate.log; \
	else \
		echo "test_elaborate.log not found"; \
	fi
	@echo ""
	@echo "=== SYNTHESIS TEST RESULTS ==="
	@if [ -f test_synth.log ]; then \
		echo "Last 10 lines of test_synth.log:"; \
		tail -10 test_synth.log; \
	else \
		echo "test_synth.log not found"; \
	fi
