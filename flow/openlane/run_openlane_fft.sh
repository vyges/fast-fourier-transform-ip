#!/bin/bash

#=============================================================================
# OpenLane FFT Hardware Accelerator Integration Script
#=============================================================================
# Description: Script to run FFT design through OpenLane flow with multiple PDKs
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
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Print functions
print_header() {
    echo -e "${BLUE}==========================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}==========================================${NC}"
}

print_section() {
    echo -e "${CYAN}=== $1 ===${NC}"
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
PROJECT_ROOT="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"
FFT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Default values
PDK="gf180mcu"
DESIGN_NAME="fft_top"
TAG="$(date +%Y%m%d_%H%M%S)"
VERBOSE=false
CLEAN=false

# Function to show usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Options:
    -p, --pdk PDK           PDK to use (gf180mcu, sky130A, ihp-sg13g2) [default: gf180mcu]
    -d, --design NAME       Design name [default: fft_top]
    -t, --tag TAG           Run tag [default: timestamp]
    -v, --verbose           Enable verbose output
    -c, --clean             Clean previous runs before starting
    -h, --help              Show this help message

Examples:
    $0 -p gf180mcu -t fft_test_001
    $0 -p sky130A -v -c
    $0 -p ihp-sg13g2 -d fft_top -t mixed_signal_test

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--pdk)
            PDK="$2"
            shift 2
            ;;
        -d|--design)
            DESIGN_NAME="$2"
            shift 2
            ;;
        -t|--tag)
            TAG="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -c|--clean)
            CLEAN=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Validate PDK
case $PDK in
    gf180mcu|sky130A|ihp-sg13g2)
        print_info "Using PDK: $PDK"
        ;;
    *)
        print_error "Unsupported PDK: $PDK"
        print_info "Supported PDKs: gf180mcu, sky130A, ihp-sg13g2"
        exit 1
        ;;
esac

# Function to check prerequisites
check_prerequisites() {
    print_section "Checking Prerequisites"
    
    # Check if we're in the right directory
    if [[ ! -f "$FFT_DIR/rtl/fft_top.sv" ]]; then
        print_error "FFT RTL files not found. Please run from the correct directory."
        exit 1
    fi
    
    # Check if OpenLane is available
    if ! command -v docker &> /dev/null; then
        print_error "Docker not found. Please install Docker first."
        exit 1
    fi
    
    # Check if OpenLane Docker image is available
    if ! docker images | grep -q "ghcr.io/the-openroad-project/openlane"; then
        print_warning "OpenLane Docker image not found. Will pull automatically."
    fi
    
    print_success "Prerequisites check passed"
}

# Function to prepare design files
prepare_design() {
    print_section "Preparing Design Files"
    
    # Create OpenLane design directory
    local openlane_design_dir="$SCRIPT_DIR/designs/$DESIGN_NAME"
    mkdir -p "$openlane_design_dir"
    
    # Copy RTL files
    print_info "Copying RTL files..."
    cp "$FFT_DIR/rtl"/*.sv "$openlane_design_dir/"
    
    # Create Verilog file list
    cat > "$openlane_design_dir/verilog_files.txt" << EOF
fft_top.sv
fft_control.sv
fft_engine.sv
memory_interface.sv
rescale_unit.sv
scale_factor_tracker.sv
twiddle_rom.sv
twiddle_rom_synth.sv
EOF
    
    # Copy configuration files
    if [[ "$PDK" == "gf180mcu" ]]; then
        cp "$SCRIPT_DIR/config_gf180mcu.tcl" "$openlane_design_dir/config.tcl"
    else
        cp "$SCRIPT_DIR/config.tcl" "$openlane_design_dir/config.tcl"
    fi
    
    # Copy pin order configuration
    cp "$SCRIPT_DIR/pin_order.cfg" "$openlane_design_dir/"
    
    print_success "Design files prepared"
}

# Function to clean previous runs
clean_previous_runs() {
    if [[ "$CLEAN" == true ]]; then
        print_section "Cleaning Previous Runs"
        
        local openlane_design_dir="$SCRIPT_DIR/designs/$DESIGN_NAME"
        if [[ -d "$openlane_design_dir/runs" ]]; then
            print_info "Removing previous runs..."
            rm -rf "$openlane_design_dir/runs"
        fi
        
        print_success "Previous runs cleaned"
    fi
}

# Function to run OpenLane flow
run_openlane_flow() {
    print_section "Running OpenLane Flow"
    
    local openlane_design_dir="$SCRIPT_DIR/designs/$DESIGN_NAME"
    local openlane_root="$SCRIPT_DIR"
    
    print_info "Design: $DESIGN_NAME"
    print_info "PDK: $PDK"
    print_info "Tag: $TAG"
    print_info "Working directory: $openlane_design_dir"
    
    # Change to OpenLane directory
    cd "$openlane_root"
    
    # Run OpenLane flow
    local verbose_flag=""
    if [[ "$VERBOSE" == true ]]; then
        verbose_flag="-v"
    fi
    
    print_info "Starting OpenLane flow..."
    
    if docker run --rm \
        -v "$(pwd):/openlane" \
        -v "$openlane_design_dir:/openlane/designs/$DESIGN_NAME" \
        ghcr.io/the-openroad-project/openlane:latest \
        flow.tcl \
        -design "$DESIGN_NAME" \
        -pdk "$PDK" \
        -tag "$TAG" \
        $verbose_flag; then
        
        print_success "OpenLane flow completed successfully"
    else
        print_error "OpenLane flow failed"
        exit 1
    fi
}

# Function to generate reports
generate_reports() {
    print_section "Generating Reports"
    
    local openlane_design_dir="$SCRIPT_DIR/designs/$DESIGN_NAME"
    local run_dir="$openlane_design_dir/runs/$TAG"
    local reports_dir="$run_dir/reports"
    
    if [[ -d "$reports_dir" ]]; then
        print_info "Reports available in: $reports_dir"
        
        # List available reports
        echo
        print_info "Available Reports:"
        find "$reports_dir" -name "*.rpt" -o -name "*.json" | while read -r report; do
            echo "  - $(basename "$report")"
        done
        
        # Show key metrics
        if [[ -f "$reports_dir/synthesis/1-synthesis.stat.rpt" ]]; then
            echo
            print_info "Synthesis Results:"
            cat "$reports_dir/synthesis/1-synthesis.stat.rpt"
        fi
        
        if [[ -f "$reports_dir/placement/placement.stat.rpt" ]]; then
            echo
            print_info "Placement Results:"
            cat "$reports_dir/placement/placement.stat.rpt"
        fi
        
        if [[ -f "$reports_dir/routing/routing.stat.rpt" ]]; then
            echo
            print_info "Routing Results:"
            cat "$reports_dir/routing/routing.stat.rpt"
        fi
    else
        print_warning "Reports directory not found"
    fi
}

# Function to show results summary
show_results_summary() {
    print_section "Results Summary"
    
    local openlane_design_dir="$SCRIPT_DIR/designs/$DESIGN_NAME"
    local run_dir="$openlane_design_dir/runs/$TAG"
    local results_dir="$run_dir/results"
    
    if [[ -d "$results_dir" ]]; then
        print_info "Results available in: $results_dir"
        
        # List final results
        echo
        print_info "Final Results:"
        find "$results_dir" -type f | while read -r result; do
            echo "  - $(basename "$result")"
        done
        
        # Check for GDS file
        if [[ -f "$results_dir/final/gds/$DESIGN_NAME.gds" ]]; then
            print_success "GDS file generated: $results_dir/final/gds/$DESIGN_NAME.gds"
        fi
        
        # Check for LEF file
        if [[ -f "$results_dir/final/lef/$DESIGN_NAME.lef" ]]; then
            print_success "LEF file generated: $results_dir/final/lef/$DESIGN_NAME.lef"
        fi
        
        # Check for netlist
        if [[ -f "$results_dir/final/verilog/gl/$DESIGN_NAME.v" ]]; then
            print_success "Gate-level netlist generated: $results_dir/final/verilog/gl/$DESIGN_NAME.v"
        fi
    else
        print_warning "Results directory not found"
    fi
}

# Main execution
main() {
    print_header "OpenLane FFT Hardware Accelerator Integration"
    echo "This script runs the FFT design through OpenLane flow with $PDK PDK"
    echo
    
    check_prerequisites
    clean_previous_runs
    prepare_design
    run_openlane_flow
    generate_reports
    show_results_summary
    
    print_header "Integration Complete"
    print_success "FFT design successfully processed with OpenLane and $PDK PDK"
    echo
    print_info "Next steps:"
    echo "  1. Review the generated reports in the reports directory"
    echo "  2. Check the final GDS, LEF, and netlist files"
    echo "  3. Validate the design with DRC and LVS checks"
    echo "  4. Consider running with different PDKs for comparison"
}

# Run main function
main "$@" 