# Cross-Platform Yosys Testing Guide

This guide explains how to run the same Yosys test cases on both macOS and Ubuntu to identify platform-specific issues.

## Test Structure

Each issue has its own directory with:
- **Test files** (`.sv` files)
- **Makefile** with OS detection
- **Logs** stored in the same directory
- **Results** that can be compared across platforms

## Running Tests on macOS

```bash
# Navigate to test directory
cd fast-fourier-transform-ip/yosys_test

# Run all tests
make test

# Run individual issues
make issue1  # Memory synthesis hanging
make issue2  # Frontend detection  
make issue3  # Security assertions
make issue4  # SystemVerilog support

# View results
make show_all_results
```

## Running Tests on Ubuntu

```bash
# Navigate to test directory
cd fast-fourier-transform-ip/yosys_test

# Setup environment (first time only)
chmod +x setup_ubuntu.sh
./setup_ubuntu.sh

# Run all tests
make test

# Run individual issues
make issue1  # Memory synthesis hanging
make issue2  # Frontend detection
make issue3  # Security assertions
make issue4  # SystemVerilog support

# View results
make show_all_results
```

## Comparing Results

### Log Files Location
- **macOS**: `fast-fourier-transform-ip/yosys_test/issue*/test_*.log`
- **Ubuntu**: Same location, logs will be created when tests run

### Key Differences to Look For

1. **Issue 1 (Memory Hanging)**
   - Check if large memory synthesis hangs on Ubuntu but not macOS
   - Compare synthesis times between platforms
   - Look for different timeout behaviors

2. **Issue 2 (Frontend Detection)**
   - Should work the same on both platforms
   - If different, indicates platform-specific Yosys behavior

3. **Issue 3 (Security Assertions)**
   - Compare how different Yosys versions handle security constructs
   - Look for version-specific error messages

4. **Issue 4 (SystemVerilog Support)**
   - Check for consistent feature support across platforms
   - Identify any platform-specific SystemVerilog limitations

## Expected Results

### macOS (Yosys 0.55)
- Should handle all basic SystemVerilog features
- May have timeout issues with large memory
- Frontend detection should work automatically

### Ubuntu (Yosys 0.33 or 0.55)
- May have different SystemVerilog support levels
- Could show different timeout behaviors
- May have different error messages for unsupported features

## Troubleshooting

### Common Issues

1. **Timeout command not found**
   - macOS: Uses Perl-based timeout
   - Ubuntu: Uses standard `timeout` command

2. **Yosys version differences**
   - Check version with `yosys --version`
   - Compare feature support between versions

3. **Permission issues**
   - Run `chmod +x setup_ubuntu.sh` on Ubuntu
   - Ensure Makefiles are executable

### Getting Help

If you encounter issues:
1. Check the log files in each issue directory
2. Compare results between platforms
3. Look for specific error messages
4. Check Yosys version differences

## Next Steps

After running tests on both platforms:

1. **Identify Real Issues**: Compare logs to see which issues are actually reproducible
2. **Create Minimal Test Cases**: For any real issues, create the smallest possible examples
3. **File GitHub Issues**: Submit focused, reproducible issues to the Yosys repository
4. **Document Workarounds**: Note any platform-specific solutions or workarounds
