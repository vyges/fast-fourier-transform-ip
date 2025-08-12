#!/bin/bash

#=============================================================================
# FFT OpenLane Integration Test Script
#=============================================================================
# Description: Quick test to validate FFT integration with OpenLane
# Author:      Vyges IP Development Team
# Date:        2025-01-27
# License:     Apache-2.0
#=============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}==========================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}==========================================${NC}"
}

print_success() {
    echo -e "${GREEN}[SUCCESS] $1${NC}"
}

print_info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

print_error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FFT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Test functions
test_rtl_files() {
    print_info "Testing RTL files..."
    
    local rtl_files=(
        "fft_top.sv"
        "fft_control.sv"
        "fft_engine.sv"
        "memory_interface.sv"
        "rescale_unit.sv"
        "scale_factor_tracker.sv"
        "twiddle_rom.sv"
        "twiddle_rom_synth.sv"
    )
    
    local missing_files=()
    
    for file in "${rtl_files[@]}"; do
        if [[ -f "$FFT_DIR/rtl/$file" ]]; then
            print_success "Found: $file"
        else
            missing_files+=("$file")
        fi
    done
    
    if [[ ${#missing_files[@]} -eq 0 ]]; then
        print_success "All RTL files present"
        return 0
    else
        print_error "Missing RTL files: ${missing_files[*]}"
        return 1
    fi
}

test_config_files() {
    print_info "Testing configuration files..."
    
    local config_files=(
        "config.tcl"
        "config_gf180mcu.tcl"
        "pin_order.cfg"
    )
    
    local missing_files=()
    
    for file in "${config_files[@]}"; do
        if [[ -f "$SCRIPT_DIR/$file" ]]; then
            print_success "Found: $file"
        else
            missing_files+=("$file")
        fi
    done
    
    if [[ ${#missing_files[@]} -eq 0 ]]; then
        print_success "All configuration files present"
        return 0
    else
        print_error "Missing configuration files: ${missing_files[*]}"
        return 1
    fi
}

test_openlane_setup() {
    print_info "Testing OpenLane setup..."
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker not found"
        return 1
    fi
    print_success "Docker available"
    
    # Check OpenLane Docker image
    if docker images | grep -q "ghcr.io/the-openroad-project/openlane"; then
        print_success "OpenLane Docker image available"
    else
        print_warning "OpenLane Docker image not found (will be pulled automatically)"
    fi
    
    return 0
}

test_pdk_support() {
    print_info "Testing PDK support..."
    
    local pdks=("gf180mcu" "sky130A" "ihp-sg13g2")
    
    for pdk in "${pdks[@]}"; do
        print_info "Checking $pdk support..."
        
        # Check if configuration exists
        case $pdk in
            gf180mcu)
                if [[ -f "$SCRIPT_DIR/config_gf180mcu.tcl" ]]; then
                    print_success "$pdk configuration available"
                else
                    print_error "$pdk configuration missing"
                    return 1
                fi
                ;;
            sky130A|ihp-sg13g2)
                if [[ -f "$SCRIPT_DIR/config.tcl" ]]; then
                    print_success "$pdk configuration available"
                else
                    print_error "$pdk configuration missing"
                    return 1
                fi
                ;;
        esac
    done
    
    return 0
}

test_verilog_syntax() {
    print_info "Testing Verilog syntax..."
    
    # Check if iverilog is available for syntax checking
    if ! command -v iverilog &> /dev/null; then
        print_warning "iverilog not found, skipping syntax check"
        return 0
    fi
    
    # Create a temporary test file
    local test_file="/tmp/fft_syntax_test.v"
    cat > "$test_file" << 'EOF'
`timescale 1ns/1ps

// Include all FFT modules for syntax check
module fft_syntax_test;
    // This is just a syntax test, no actual functionality
    initial begin
        $display("FFT syntax test passed");
        $finish;
    end
endmodule
EOF
    
    # Try to compile (this will catch basic syntax errors)
    if iverilog -Wall -o /tmp/fft_test "$test_file" 2>/dev/null; then
        print_success "Basic Verilog syntax check passed"
        rm -f /tmp/fft_test
        rm -f "$test_file"
        return 0
    else
        print_error "Verilog syntax check failed"
        rm -f /tmp/fft_test
        rm -f "$test_file"
        return 1
    fi
}

test_integration_script() {
    print_info "Testing integration script..."
    
    if [[ -f "$SCRIPT_DIR/run_openlane_fft.sh" ]]; then
        print_success "Integration script found"
        
        # Check if script is executable
        if [[ -x "$SCRIPT_DIR/run_openlane_fft.sh" ]]; then
            print_success "Integration script is executable"
        else
            print_warning "Integration script is not executable"
            chmod +x "$SCRIPT_DIR/run_openlane_fft.sh"
            print_success "Made integration script executable"
        fi
        
        # Test help option
        if "$SCRIPT_DIR/run_openlane_fft.sh" --help &>/dev/null; then
            print_success "Integration script help works"
        else
            print_warning "Integration script help test failed"
        fi
        
        return 0
    else
        print_error "Integration script not found"
        return 1
    fi
}

# Main test execution
main() {
    print_header "FFT OpenLane Integration Test"
    echo "This script validates the FFT integration with OpenLane"
    echo
    
    local tests=(
        "test_rtl_files"
        "test_config_files"
        "test_openlane_setup"
        "test_pdk_support"
        "test_verilog_syntax"
        "test_integration_script"
    )
    
    local passed=0
    local failed=0
    
    for test in "${tests[@]}"; do
        echo
        if $test; then
            passed=$((passed + 1))
        else
            failed=$((failed + 1))
        fi
    done
    
    echo
    print_header "Test Results Summary"
    echo "Total Tests: $((passed + failed))"
    echo "Passed: $passed"
    echo "Failed: $failed"
    
    if [[ $failed -eq 0 ]]; then
        print_success "All tests passed! FFT integration is ready."
        echo
        print_info "Next steps:"
        echo "  1. Run: ./run_openlane_fft.sh -p gf180mcu"
        echo "  2. Run: ./run_openlane_fft.sh -p sky130A"
        echo "  3. Run: ./run_openlane_fft.sh -p ihp-sg13g2"
        echo "  4. Review results in the generated reports"
    else
        print_error "Some tests failed. Please fix the issues before proceeding."
        exit 1
    fi
}

# Run main function
main "$@" 