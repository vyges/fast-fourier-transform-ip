# Yosys Test Cases

This directory contains focused test cases for specific Yosys issues identified in our development workflow. Each issue has its own directory with minimal, reproducible examples.

## Test Structure

- `issue1_memory_hang/` - Test cases for synthesis hanging with large memory arrays
- `issue2_frontend_detection/` - Test cases for frontend detection failures
- `issue3_security_assertions/` - Test cases for security assertion limitations
- `issue4_systemverilog_support/` - Test cases for inconsistent SystemVerilog support

## Testing Approach

1. **Minimal Examples**: Each test case contains the smallest possible code that reproduces the issue
2. **Exact Commands**: Commands that can be copy-pasted to reproduce the problem
3. **Expected vs Actual**: Clear description of what should happen vs what actually happens
4. **Environment Details**: Yosys version, platform, and exact reproduction steps

## Usage

```bash
# Test a specific issue
cd issue1_memory_hang
make test

# Or run manually
yosys -p "read_verilog -sv test.sv; hierarchy -top test; synth -top test; stat"
```

## Goals

- Create concrete, reproducible test cases for the Yosys team
- Verify issues actually exist before reporting
- Provide minimal examples that can be easily understood and fixed
- Separate real bugs from expected behavior or user error

## Notes

- Each test case should be completely self-contained
- Include exact error messages and behavior
- Test on both Ubuntu and macOS if possible
- Document any workarounds or solutions found
