#!/bin/bash

#=============================================================================
# FFT OpenLane Quick Start Script
#=============================================================================
# Description: Quick start script for FFT developers to begin OpenLane integration
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
CYAN='\033[0;36m'
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

# Default values
SERVER_IP=""
SSH_KEY=""
PDK="gf180mcu"
TAG="fft_$(date +%Y%m%d_%H%M%S)"

# Function to show usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Required Options:
    -s, --server SERVER_IP    OpenLane server IP address
    -k, --key SSH_KEY_PATH    Path to SSH private key

Optional Options:
    -p, --pdk PDK             PDK to use (gf180mcu, sky130A) [default: gf180mcu]
    -t, --tag TAG             Run tag [default: timestamp]
    -h, --help                Show this help message

Examples:
    $0 -s 192.168.1.100 -k ~/.ssh/my_key.pem
    $0 -s ec2-xx-xx-xx-xx.compute-1.amazonaws.com -k ~/.ssh/aws_key.pem -p sky130A
    $0 --server 10.0.0.50 --key ~/.ssh/id_rsa --pdk gf180mcu --tag fft_v1

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--server)
            SERVER_IP="$2"
            shift 2
            ;;
        -k|--key)
            SSH_KEY="$2"
            shift 2
            ;;
        -p|--pdk)
            PDK="$2"
            shift 2
            ;;
        -t|--tag)
            TAG="$2"
            shift 2
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

# Validate required parameters
if [[ -z "$SERVER_IP" ]]; then
    print_error "Server IP is required"
    show_usage
    exit 1
fi

if [[ -z "$SSH_KEY" ]]; then
    print_error "SSH key path is required"
    show_usage
    exit 1
fi

if [[ ! -f "$SSH_KEY" ]]; then
    print_error "SSH key file not found: $SSH_KEY"
    exit 1
fi

# Validate PDK
case $PDK in
    gf180mcu|sky130A)
        print_info "Using PDK: $PDK"
        ;;
    *)
        print_error "Unsupported PDK: $PDK"
        print_info "Supported PDKs: gf180mcu, sky130A"
        exit 1
        ;;
esac

# Function to check local prerequisites
check_local_prerequisites() {
    print_header "Checking Local Prerequisites"
    
    # Check if we're in the right directory
    if [[ ! -f "$FFT_DIR/rtl/fft_top.sv" ]]; then
        print_error "FFT RTL files not found. Please run from the FFT project directory."
        exit 1
    fi
    
    # Check RTL files
    local rtl_files=(
        "fft_top.sv"
        "fft_control.sv"
        "fft_engine.sv"
        "memory_interface.sv"
        "rescale_unit.sv"
        "scale_factor_tracker.sv"
        "twiddle_rom.sv"
        # Note: twiddle_rom_synth.sv moved to flow/synthesis/
    )
    
    local missing_files=()
    for file in "${rtl_files[@]}"; do
        if [[ ! -f "$FFT_DIR/rtl/$file" ]]; then
            missing_files+=("$file")
        fi
    done
    
    if [[ ${#missing_files[@]} -eq 0 ]]; then
        print_success "All RTL files present"
    else
        print_error "Missing RTL files: ${missing_files[*]}"
        exit 1
    fi
    
    # Check OpenLane integration files
    if [[ ! -f "$SCRIPT_DIR/run_openlane_fft.sh" ]]; then
        print_error "OpenLane integration script not found"
        exit 1
    fi
    
    print_success "Local prerequisites check passed"
}

# Function to test server connection
test_server_connection() {
    print_header "Testing Server Connection"
    
    print_info "Testing SSH connection to $SERVER_IP..."
    
    if ssh -i "$SSH_KEY" -o ConnectTimeout=10 -o StrictHostKeyChecking=no ubuntu@"$SERVER_IP" "echo 'Connection successful'" 2>/dev/null; then
        print_success "SSH connection successful"
    else
        print_error "SSH connection failed"
        print_info "Please check:"
        print_info "  1. Server IP address is correct"
        print_info "  2. SSH key file exists and has correct permissions"
        print_info "  3. Server is running and accessible"
        exit 1
    fi
    
    # Check if OpenLane is available
    print_info "Checking OpenLane installation..."
    if ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@"$SERVER_IP" "ls -la ~/OpenLane" 2>/dev/null; then
        print_success "OpenLane installation found"
    else
        print_error "OpenLane not found on server"
        exit 1
    fi
}

# Function to upload files
upload_files() {
    print_header "Uploading FFT Design to Server"
    
    # Create remote directory
    print_info "Creating remote directory..."
    ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@"$SERVER_IP" "mkdir -p ~/fft_project"
    
    # Upload RTL files
    print_info "Uploading RTL files..."
    scp -i "$SSH_KEY" -o StrictHostKeyChecking=no -r "$FFT_DIR/rtl/" ubuntu@"$SERVER_IP":~/fft_project/
    
    # Upload synthesis files
    print_info "Uploading synthesis files..."
    scp -i "$SSH_KEY" -o StrictHostKeyChecking=no -r "$FFT_DIR/flow/synthesis/" ubuntu@"$SERVER_IP":~/fft_project/synthesis/
    
    # Upload OpenLane integration files
    print_info "Uploading OpenLane integration files..."
    scp -i "$SSH_KEY" -o StrictHostKeyChecking=no -r "$SCRIPT_DIR/" ubuntu@"$SERVER_IP":~/fft_project/openlane/
    
    # Make scripts executable
    ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@"$SERVER_IP" "chmod +x ~/fft_project/openlane/*.sh"
    
    print_success "Files uploaded successfully"
}

# Function to run OpenLane flow
run_openlane_flow() {
    print_header "Running OpenLane Flow"
    
    print_info "Design: fft_top"
    print_info "PDK: $PDK"
    print_info "Tag: $TAG"
    print_info "Server: $SERVER_IP"
    
    # Test integration first
    print_info "Testing integration..."
    if ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@"$SERVER_IP" "cd ~/fft_project/openlane && ./test_fft_integration.sh"; then
        print_success "Integration test passed"
    else
        print_error "Integration test failed"
        exit 1
    fi
    
    # Run OpenLane flow
    print_info "Starting OpenLane flow (this may take 1-3 hours)..."
    print_info "You can monitor progress with:"
    print_info "  ssh -i $SSH_KEY ubuntu@$SERVER_IP 'tail -f ~/fft_project/openlane/designs/fft_top/runs/$TAG/logs/synthesis.log'"
    
    if ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@"$SERVER_IP" "cd ~/fft_project/openlane && ./run_openlane_fft.sh -p $PDK -t $TAG -v"; then
        print_success "OpenLane flow completed successfully"
    else
        print_error "OpenLane flow failed"
        print_info "Check logs for details:"
        print_info "  ssh -i $SSH_KEY ubuntu@$SERVER_IP 'ls -la ~/fft_project/openlane/designs/fft_top/runs/$TAG/logs/'"
        exit 1
    fi
}

# Function to download results
download_results() {
    print_header "Downloading Results"
    
    # Create local results directory
    local results_dir="fft_results_${PDK}_${TAG}"
    mkdir -p "$results_dir"
    
    print_info "Downloading results to $results_dir..."
    
    # Download results
    scp -i "$SSH_KEY" -o StrictHostKeyChecking=no -r ubuntu@"$SERVER_IP":~/fft_project/openlane/designs/fft_top/runs/"$TAG"/results/ "$results_dir"/
    
    # Download reports
    scp -i "$SSH_KEY" -o StrictHostKeyChecking=no -r ubuntu@"$SERVER_IP":~/fft_project/openlane/designs/fft_top/runs/"$TAG"/reports/ "$results_dir"/
    
    print_success "Results downloaded to $results_dir"
    
    # Show key files
    echo
    print_info "Key generated files:"
    if [[ -f "$results_dir/results/final/gds/fft_top.gds" ]]; then
        print_success "GDS file: $results_dir/results/final/gds/fft_top.gds"
    fi
    
    if [[ -f "$results_dir/results/final/lef/fft_top.lef" ]]; then
        print_success "LEF file: $results_dir/results/final/lef/fft_top.lef"
    fi
    
    if [[ -f "$results_dir/results/final/verilog/gl/fft_top.v" ]]; then
        print_success "Netlist: $results_dir/results/final/verilog/gl/fft_top.v"
    fi
}

# Function to show next steps
show_next_steps() {
    print_header "Next Steps"
    
    echo
    print_info "Your FFT design has been successfully synthesized with $PDK PDK!"
    echo
    print_info "Next steps:"
    echo "  1. Review the results in the downloaded directory"
    echo "  2. Check performance metrics in the reports"
    echo "  3. Validate timing closure and DRC/LVS results"
    echo "  4. Prepare GDS file for tapeout submission"
    echo
    print_info "To run with the other PDK:"
    echo "  $0 -s $SERVER_IP -k $SSH_KEY -p sky130A -t fft_sky130_v1"
    echo
    print_info "To monitor progress in future runs:"
    echo "  ssh -i $SSH_KEY ubuntu@$SERVER_IP 'tail -f ~/fft_project/openlane/designs/fft_top/runs/<tag>/logs/synthesis.log'"
    echo
    print_info "For detailed analysis, see: REMOTE_INTEGRATION_GUIDE.md"
}

# Main execution
main() {
    print_header "FFT OpenLane Quick Start"
    echo "This script will take your FFT design from RTL to silicon-ready GDS"
    echo
    
    check_local_prerequisites
    test_server_connection
    upload_files
    run_openlane_flow
    download_results
    show_next_steps
    
    print_header "Quick Start Complete"
    print_success "Your FFT design is ready for tapeout!"
}

# Run main function
main "$@" 