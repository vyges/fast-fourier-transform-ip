#!/bin/bash
# Setup script for running Yosys tests on Ubuntu
# This script verifies tools are available and prepares the test environment

set -e

echo "Setting up Yosys test environment on Ubuntu..."
echo "=============================================="

# Check if we're on Ubuntu
if ! grep -q "Ubuntu" /etc/os-release 2>/dev/null; then
    echo "Warning: This script is designed for Ubuntu systems"
    echo "Current OS: $(cat /etc/os-release | grep PRETTY_NAME)"
fi

# Verify required tools are available
echo "Verifying required tools..."

# Check Yosys
if ! command -v yosys &> /dev/null; then
    echo "ERROR: Yosys not found. Please install it first:"
    echo "  sudo apt install yosys"
    exit 1
fi

# Check Make
if ! command -v make &> /dev/null; then
    echo "ERROR: Make not found. Please install it first:"
    echo "  sudo apt install build-essential"
    exit 1
fi

# Check timeout command
if ! command -v timeout &> /dev/null; then
    echo "ERROR: Timeout command not found. Please install it first:"
    echo "  sudo apt install coreutils"
    exit 1
fi

# Display tool versions
echo "Tool versions:"
echo "  Yosys: $(yosys --version | head -1)"
echo "  Make: $(make --version | head -1)"
echo "  Timeout: $(timeout --version | head -1)"

# Make sure all test files are executable
echo "Setting up test environment..."
chmod +x issue*/Makefile

echo ""
echo "Setup completed successfully!"
echo ""
echo "To run all tests:"
echo "  make test"
echo ""
echo "To run individual issue tests:"
echo "  make issue1  # Memory synthesis hanging"
echo "  make issue2  # Frontend detection"
echo "  make issue3  # Security assertions"
echo "  make issue4  # SystemVerilog support"
echo ""
echo "To see results:"
echo "  make show_all_results"
echo ""
echo "To clean up:"
echo "  make clean"
