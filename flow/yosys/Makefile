#==============================================================================
# Fast Fourier Transform IP Yosys Synthesis Makefile
#==============================================================================
# Description: Makefile for running Yosys synthesis and gate analysis on FFT IP
# Author:      Vyges Team
# Date:        2025-07-29
# Version:     1.0.0
#==============================================================================

# Yosys executable
YOSYS = yosys

# Configuration
DESIGN_NAME = fft_top
RTL_DIR = ../../rtl
BUILD_DIR = build
REPORTS_DIR = reports

# Synthesis targets
.PHONY: all gate_analysis comprehensive_report clean help

# Default target
all: gate_analysis comprehensive_report

# Create directories
$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(REPORTS_DIR):
	mkdir -p $(REPORTS_DIR)

# Generate gate analysis report
gate_analysis: $(REPORTS_DIR)
	@echo "Generating gate-level analysis report..."
	@python3 gate_analysis.py
	@echo "Gate analysis report generated: gate_analysis_report.md"

# Generate comprehensive report (synthesis + gate analysis)
comprehensive_report: gate_analysis
	@echo "Generating comprehensive analysis report..."
	@echo "# Fast Fourier Transform IP Comprehensive Analysis Report" > $(REPORTS_DIR)/comprehensive_report.md
	@echo "Generated: $(shell date)" >> $(REPORTS_DIR)/comprehensive_report.md
	@echo "" >> $(REPORTS_DIR)/comprehensive_report.md
	@echo "## Executive Summary" >> $(REPORTS_DIR)/comprehensive_report.md
	@echo "" >> $(REPORTS_DIR)/comprehensive_report.md
	@echo "This report provides a comprehensive analysis of the FFT IP synthesis:" >> $(REPORTS_DIR)/comprehensive_report.md
	@echo "- Gate-level analysis with detailed transistor counts" >> $(REPORTS_DIR)/comprehensive_report.md
	@echo "- Synthesis statistics and resource utilization" >> $(REPORTS_DIR)/comprehensive_report.md
	@echo "- Performance analysis and design trade-offs" >> $(REPORTS_DIR)/comprehensive_report.md
	@echo "- FFT-specific considerations and optimizations" >> $(REPORTS_DIR)/comprehensive_report.md
	@echo "" >> $(REPORTS_DIR)/comprehensive_report.md
	@echo "## Gate-Level Analysis" >> $(REPORTS_DIR)/comprehensive_report.md
	@echo "" >> $(REPORTS_DIR)/comprehensive_report.md
	@if [ -f gate_analysis_report.md ]; then cat gate_analysis_report.md >> $(REPORTS_DIR)/comprehensive_report.md; fi
	@echo "" >> $(REPORTS_DIR)/comprehensive_report.md
	@echo "## Synthesis Statistics" >> $(REPORTS_DIR)/comprehensive_report.md
	@echo "" >> $(REPORTS_DIR)/comprehensive_report.md
	@if [ -f ../synthesis/synthesis_analysis_report.md ]; then cat ../synthesis/synthesis_analysis_report.md >> $(REPORTS_DIR)/comprehensive_report.md; fi
	@echo "" >> $(REPORTS_DIR)/comprehensive_report.md
	@echo "## Files Generated" >> $(REPORTS_DIR)/comprehensive_report.md
	@echo "" >> $(REPORTS_DIR)/comprehensive_report.md
	@echo "- \`fft_top_synth_generic.v\`: Synthesized netlist" >> $(REPORTS_DIR)/comprehensive_report.md
	@echo "- \`fft_top_synth_generic.json\`: JSON representation" >> $(REPORTS_DIR)/comprehensive_report.md
	@echo "- \`gate_analysis_report.md\`: Gate-level analysis report" >> $(REPORTS_DIR)/comprehensive_report.md
	@echo "- \`synthesis_analysis_report.md\`: Synthesis analysis report" >> $(REPORTS_DIR)/comprehensive_report.md
	@echo "Comprehensive report generated: $(REPORTS_DIR)/comprehensive_report.md"

# Clean target
clean:
	rm -rf $(BUILD_DIR) $(REPORTS_DIR)
	rm -f gate_analysis_report.md

# Help target
help:
	@echo "Fast Fourier Transform IP Yosys Synthesis Makefile"
	@echo "=================================================="
	@echo ""
	@echo "Available targets:"
	@echo "  gate_analysis      - Generate gate-level analysis report"
	@echo "  comprehensive_report - Generate comprehensive analysis report"
	@echo "  all                - Run complete analysis flow"
	@echo "  clean              - Clean build artifacts"
	@echo "  help               - Show this help message"
	@echo ""
	@echo "Example usage:"
	@echo "  make all"
	@echo "  make gate_analysis"
	@echo "  make comprehensive_report"
	@echo ""
	@echo "Note: This Makefile analyzes existing synthesis outputs from"
	@echo "      the synthesis directory. Run synthesis first if needed."

.PHONY: all gate_analysis comprehensive_report clean help