# Quick Ubuntu Testing Summary

## What We've Built

We've created a comprehensive test suite for Yosys issues with **4 focused test cases**:

1. **Issue 1**: Memory synthesis hanging with large arrays (64K entries)
2. **Issue 2**: Frontend detection for SystemVerilog files  
3. **Issue 3**: Security assertion limitations
4. **Issue 4**: SystemVerilog feature support consistency

## Directory Structure

```
yosys_test/
├── issue1_memory_hang/          # Memory synthesis tests
├── issue2_frontend_detection/    # Frontend detection tests
├── issue3_security_assertions/   # Security assertion tests
├── issue4_systemverilog_support/ # SystemVerilog feature tests
├── Makefile                      # Master Makefile
├── setup_ubuntu.sh              # Ubuntu setup script
└── CROSS_PLATFORM_TESTING.md    # Detailed testing guide
```

## Quick Start on Ubuntu

```bash
# 1. Navigate to test directory
cd fast-fourier-transform-ip/yosys_test

# 2. Setup environment
chmod +x setup_ubuntu.sh
./setup_ubuntu.sh

# 3. Run all tests
make test

# 4. View results
make show_all_results
```

## What Each Test Does

### Issue 1: Memory Hanging
- **Small memory**: 256 entries (should work quickly)
- **Large memory**: 64K entries (may hang/timeout)
- **Purpose**: Test if Yosys hangs with large memory synthesis

### Issue 2: Frontend Detection  
- **Auto-detection**: Test if Yosys auto-detects .sv files
- **Explicit flag**: Test with explicit frontend specification
- **Purpose**: Verify frontend detection behavior

### Issue 3: Security Assertions
- **YOSYS define**: Test with YOSYS macro defined
- **Full features**: Test with full SystemVerilog
- **Purpose**: Check security assertion support

### Issue 4: SystemVerilog Support
- **Parse**: Test parsing of SystemVerilog features
- **Elaborate**: Test elaboration (proc) step
- **Synthesize**: Test full synthesis flow
- **Purpose**: Verify SystemVerilog feature consistency

## Expected Results

- **Issue 1**: May show timeout differences between platforms
- **Issue 2**: Should work the same on both platforms
- **Issue 3**: May show version-specific differences
- **Issue 4**: May reveal platform-specific SystemVerilog limitations

## Key Commands

```bash
make help              # Show all available commands
make issue1           # Test memory synthesis
make issue2           # Test frontend detection
make issue3           # Test security assertions  
make issue4           # Test SystemVerilog support
make show_all_results # View all test results
make clean            # Clean up test artifacts
```

## Log Files

Each test generates logs in its respective directory:
- `issue1_memory_hang/test_*.log`
- `issue2_frontend_detection/test_*.log`
- `issue3_security_assertions/test_*.log`
- `issue4_systemverilog_support/test_*.log`

## Next Steps

1. **Run tests on Ubuntu** and compare with macOS results
2. **Identify real issues** that are reproducible on both platforms
3. **Create minimal test cases** for any confirmed issues
4. **File focused GitHub issues** with concrete examples

## Notes

- All Makefiles automatically detect OS and use appropriate commands
- Tests are designed to be minimal and focused
- Logs are organized by issue for easy comparison
- Setup script handles Ubuntu dependencies automatically
