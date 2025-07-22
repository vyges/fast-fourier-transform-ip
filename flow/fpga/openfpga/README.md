# Open Source FPGA Flow for FFT Hardware Accelerator

## Overview

This directory contains the complete open source FPGA implementation flow for the FFT Hardware Accelerator using industry-standard open source tools. The flow supports multiple FPGA families and follows Vyges conventions for FPGA development.

## Supported FPGA Families

### 1. Lattice iCE40 (IceStorm)
- **Tools**: Yosys, NextPNR, IcePack, IceTime, IceProg
- **Devices**: iCE40-HX8K, iCE40-UP5K, iCE40-LP8K
- **Status**: ✅ Fully supported

### 2. Lattice ECP5 (PrjTrellis)
- **Tools**: Yosys, NextPNR-ECP5, ECPPack
- **Devices**: ECP5-25K, ECP5-85K, ECP5-85F
- **Status**: ✅ Fully supported

### 3. Xilinx 7-Series (SymbiFlow)
- **Tools**: Yosys, VPR, SymbiFlow
- **Devices**: Artix-7, Kintex-7, Virtex-7
- **Status**: 🔄 Partially supported (requires SymbiFlow setup)

## Directory Structure

```
openfpga/
├── Makefile                    # Main build system
├── constraints/                # Constraint files
│   ├── hx8k-ct256.pcf         # iCE40 pin constraints
│   └── timing.sdc             # Timing constraints
├── build/                      # Build artifacts (generated)
├── reports/                    # Synthesis reports (generated)
├── netlists/                   # Synthesis netlists (generated)
└── README.md                   # This file
```

## Prerequisites

### Required Tools

The following tools must be installed and available in your PATH:

#### Core Tools
- **Yosys** ≥0.39 - RTL synthesis
- **NextPNR** ≥0.6 - Place and route
- **ABC** - Logic optimization

#### iCE40 Tools (IceStorm)
- **IcePack** - Bitstream generation
- **IceTime** - Timing analysis
- **IceProg** - Device programming

#### ECP5 Tools (PrjTrellis)
- **ECPPack** - Bitstream generation
- **NextPNR-ECP5** - ECP5-specific place and route

#### Xilinx 7-Series Tools (SymbiFlow)
- **VPR** - Place and route
- **SymbiFlow** - Bitstream generation

### Installation

#### Ubuntu/Debian
```bash
# Core tools
sudo apt-get install yosys nextpnr-ice40 nextpnr-ecp5

# iCE40 tools
sudo apt-get install fpga-icestorm

# ECP5 tools
sudo apt-get install fpga-trellis

# SymbiFlow (requires additional setup)
# Follow SymbiFlow installation guide
```

#### macOS
```bash
# Using Homebrew
brew install yosys nextpnr icestorm prjtrellis

# SymbiFlow requires manual installation
```

## Usage

### Basic Flow

#### 1. iCE40 Flow
```bash
# Complete iCE40 flow
make ice40_all FPGA_PART=hx8k-ct256

# Individual steps
make ice40_synth
make ice40_pnr
make ice40_bitstream
make ice40_timing
```

#### 2. ECP5 Flow
```bash
# Complete ECP5 flow
make ecp5_all

# Individual steps
make ecp5_synth
make ecp5_pnr
make ecp5_bitstream
```

#### 3. Xilinx 7-Series Flow
```bash
# Complete Xilinx 7-series flow
make xilinx7_all

# Individual steps
make xilinx7_synth
make xilinx7_pnr
make xilinx7_bitstream
```

### Configuration

#### Environment Variables
```bash
# FPGA family selection
export FPGA_FAMILY=ice40    # ice40, ecp5, xilinx7

# Device selection
export FPGA_PART=hx8k-ct256 # Device-specific part number

# Top module
export TOP_MODULE=fft_top   # Top-level module name
```

#### Available Targets
```bash
# Synthesis
make ice40_synth      # iCE40 synthesis
make ecp5_synth       # ECP5 synthesis
make xilinx7_synth    # Xilinx 7-series synthesis
make fpga_synth       # Generic synthesis

# Place and Route
make ice40_pnr        # iCE40 place and route
make ecp5_pnr         # ECP5 place and route
make xilinx7_pnr      # Xilinx 7-series place and route

# Bitstream Generation
make ice40_bitstream  # iCE40 bitstream
make ecp5_bitstream   # ECP5 bitstream
make xilinx7_bitstream # Xilinx 7-series bitstream

# Analysis
make ice40_timing     # iCE40 timing analysis
make reports          # Generate synthesis reports
make resources        # Resource utilization analysis

# Programming
make program_ice40    # Program iCE40 device

# Utilities
make clean            # Clean build artifacts
make help             # Show help
```

## Constraint Files

### Pin Constraints (PCF)
- **Format**: Lattice PCF format
- **Purpose**: Physical pin assignments
- **Location**: `constraints/<device>.pcf`

### Timing Constraints (SDC)
- **Format**: Synopsys Design Constraints (SDC)
- **Purpose**: Timing specifications
- **Location**: `constraints/timing.sdc`

## Build Artifacts

### Generated Files
```
build/
├── fft_top_ice40.asc      # iCE40 place and route result
├── fft_top_ice40.bin      # iCE40 bitstream
├── fft_top_ecp5.config    # ECP5 configuration
├── fft_top_ecp5.bit       # ECP5 bitstream
└── fft_top_xilinx7.bit    # Xilinx 7-series bitstream

reports/
├── synthesis_report.txt   # Synthesis summary
├── ice40_timing.txt       # iCE40 timing analysis
└── resources_*.txt        # Resource utilization

netlists/
├── fft_top_ice40.json     # iCE40 synthesis netlist
├── fft_top_ecp5.json      # ECP5 synthesis netlist
└── fft_top_xilinx7.json   # Xilinx 7-series synthesis netlist
```

## Performance Characteristics

### Resource Utilization (Estimated)
- **LUTs**: ~15,000 (varies by FPGA family)
- **FFs**: ~8,000
- **BRAM**: ~20 blocks (for twiddle ROM)
- **DSP**: ~50 (if available)

### Timing Performance
- **Maximum Frequency**: 100 MHz (typical)
- **FFT Throughput**: 1 FFT per 4,096 cycles (for 4K-point FFT)
- **Latency**: ~4,096 cycles (for 4K-point FFT)

## Troubleshooting

### Common Issues

#### 1. Yosys Synthesis Errors
```bash
# Check SystemVerilog syntax
yosys -p "read_verilog -sv rtl/fft_top.sv; check"

# Verify module hierarchy
yosys -p "read_verilog -sv rtl/*.sv; hierarchy -top fft_top"
```

#### 2. NextPNR Place and Route Errors
```bash
# Check constraint file syntax
nextpnr-ice40 --hx8k --json netlists/fft_top_ice40.json --pcf constraints/hx8k-ct256.pcf --asc build/test.asc

# Verify device support
nextpnr-ice40 --list-devices
```

#### 3. Timing Violations
```bash
# Analyze timing
make ice40_timing

# Review timing.sdc constraints
cat constraints/timing.sdc
```

### Debug Commands

#### Synthesis Debug
```bash
# Verbose synthesis
yosys -v 2 -p "read_verilog -sv rtl/*.sv; hierarchy -top fft_top; synth_ice40 -top fft_top -json netlists/debug.json"
```

#### Place and Route Debug
```bash
# Verbose place and route
nextpnr-ice40 --hx8k --json netlists/fft_top_ice40.json --pcf constraints/hx8k-ct256.pcf --asc build/debug.asc --verbose
```

## Integration with Vyges Workflow

### GitHub Actions Integration
The open source FPGA flow is integrated with the Vyges GitHub Actions workflow:

```yaml
# .github/workflows/build-and-test.yml
- name: Install FPGA tools
  run: |
    sudo apt-get install yosys nextpnr-ice40 fpga-icestorm

- name: Run FPGA synthesis
  run: |
    cd flow/fpga/openfpga
    make ice40_synth
    make reports
```

### Continuous Integration
- **Synthesis**: Automated synthesis on every commit
- **Timing**: Timing analysis and reporting
- **Resources**: Resource utilization tracking
- **Bitstream**: Bitstream generation for testing

## Contributing

### Adding New FPGA Families
1. Create new synthesis target in `Makefile`
2. Add device-specific constraints
3. Update documentation
4. Add to CI/CD pipeline

### Improving Constraints
1. Update `constraints/timing.sdc` for better timing
2. Optimize `constraints/*.pcf` for specific boards
3. Add device-specific optimizations

## References

### Tool Documentation
- [Yosys Manual](https://yosyshq.net/yosys/documentation.html)
- [NextPNR Documentation](https://github.com/YosysHQ/nextpnr)
- [IceStorm Documentation](http://www.clifford.at/icestorm/)
- [PrjTrellis Documentation](https://github.com/YosysHQ/prjtrellis)
- [SymbiFlow Documentation](https://symbiflow.readthedocs.io/)

### Vyges Conventions
- [Vyges FPGA Flow Guide](https://vyges.com/docs/fpga-flows)
- [Vyges Constraint Standards](https://vyges.com/docs/constraints)
- [Vyges Tool Integration](https://vyges.com/docs/tool-integration)

## License

This FPGA flow is licensed under the Apache-2.0 License. See the main project LICENSE file for details.

## Support

For issues and questions:
- **GitHub Issues**: Create an issue in the project repository
- **Vyges Documentation**: [https://vyges.com/docs](https://vyges.com/docs)
- **Community Forum**: [https://vyges.com/community](https://vyges.com/community) 