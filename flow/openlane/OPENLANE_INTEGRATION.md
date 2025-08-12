# OpenLane Integration Guide for FFT Hardware Accelerator

## Overview

This document describes how to integrate the Fast Fourier Transform (FFT) Hardware Accelerator with OpenLane for ASIC synthesis and place-and-route using multiple PDKs.

## Supported PDKs

The FFT design supports the following PDKs:

- **GF180MCU** (180nm MCU process) - Recommended for low-power applications
- **Sky130A** (130nm process) - Recommended for high-performance applications  
- **IHP-SG13G2** (130nm BiCMOS) - Recommended for mixed-signal applications

## Prerequisites

1. **OpenLane Setup**: Ensure OpenLane is properly installed and configured
2. **Docker**: Docker must be available and running
3. **PDK Installation**: Target PDK must be installed via `ciel`
4. **RTL Files**: All FFT RTL files must be present in the `rtl/` directory

## Quick Start

### 1. Basic Usage

```bash
# Run with GF180MCU PDK (default)
./run_openlane_fft.sh

# Run with Sky130A PDK
./run_openlane_fft.sh -p sky130A

# Run with IHP-SG13G2 PDK
./run_openlane_fft.sh -p ihp-sg13g2
```

### 2. Advanced Usage

```bash
# Run with custom tag and verbose output
./run_openlane_fft.sh -p gf180mcu -t fft_test_001 -v

# Clean previous runs and start fresh
./run_openlane_fft.sh -p sky130A -c -v

# Run with specific design name
./run_openlane_fft.sh -p ihp-sg13g2 -d fft_top -t mixed_signal_test
```

## Configuration Files

### PDK-Specific Configurations

- **`config.tcl`**: Sky130A and IHP-SG13G2 configuration
- **`config_gf180mcu.tcl`**: GF180MCU-specific configuration
- **`pin_order.cfg`**: Pin placement order for all PDKs

### Key Configuration Differences

| Parameter | GF180MCU | Sky130A | IHP-SG13G2 |
|-----------|----------|---------|------------|
| **Clock Period** | 10.0ns (100MHz) | 1.0ns (1GHz) | 1.0ns (1GHz) |
| **Die Area** | 1500x1500 | 1000x1000 | 1000x1000 |
| **Target Density** | 0.60 | 0.65 | 0.65 |
| **Max Metal Layers** | 4 | 5 | 5 |
| **Power Nets** | vdd/vss | vccd1/vssd1 | vccd1/vssd1 |

## Design Architecture

### RTL Modules

The FFT design consists of the following SystemVerilog modules:

1. **`fft_top.sv`** - Top-level module with APB/AXI interfaces
2. **`fft_control.sv`** - Control logic and state machine
3. **`fft_engine.sv`** - Core FFT computation engine
4. **`memory_interface.sv`** - Memory interface and buffering
5. **`rescale_unit.sv`** - Automatic rescaling logic
6. **`scale_factor_tracker.sv`** - Scale factor tracking
7. **`twiddle_rom.sv`** - Twiddle factor ROM
8. **`flow/synthesis/twiddle_rom_synth.sv`** - Synthesizable twiddle ROM (moved from rtl/)

### Interface Specifications

#### APB Interface
- **Clock**: `pclk_i`
- **Reset**: `preset_n_i` (active-low)
- **Address**: 16-bit (`paddr_i[15:0]`)
- **Data**: 32-bit (`pwdata_i[31:0]`, `prdata_o[31:0]`)
- **Control**: `psel_i`, `penable_i`, `pwrite_i`, `pready_o`

#### AXI Interface
- **Clock**: `axi_aclk_i`
- **Reset**: `axi_areset_n_i` (active-low)
- **Address**: 32-bit (`axi_awaddr_i[31:0]`, `axi_araddr_i[31:0]`)
- **Data**: 64-bit (`axi_wdata_i[63:0]`, `axi_rdata_o[63:0]`)
- **Handshaking**: Valid/Ready signals for all channels

#### Interrupt Interface
- **`fft_done_o`** - FFT computation complete
- **`fft_error_o`** - FFT computation error

## Performance Targets

### GF180MCU (180nm)
- **Target Frequency**: 100 MHz
- **Target Area**: 75,000 gates
- **Target Power**: 75 mW
- **Use Case**: Low-power MCU applications

### Sky130A (130nm)
- **Target Frequency**: 1 GHz
- **Target Area**: 50,000 gates
- **Target Power**: 50 mW
- **Use Case**: High-performance applications

### IHP-SG13G2 (130nm BiCMOS)
- **Target Frequency**: 1 GHz
- **Target Area**: 50,000 gates
- **Target Power**: 50 mW
- **Use Case**: Mixed-signal applications

## Workflow Steps

### 1. Design Preparation
- Copy RTL files to OpenLane design directory
- Select appropriate PDK configuration
- Set up pin order configuration

### 2. Synthesis
- RTL synthesis with Yosys
- Technology mapping to PDK cells
- Timing and area optimization

### 3. Floorplanning
- Die area definition
- Core area placement
- Power distribution network setup

### 4. Placement
- Standard cell placement
- Macro placement (if any)
- Density optimization

### 5. Clock Tree Synthesis
- Clock tree insertion
- Clock skew optimization
- Clock routing

### 6. Routing
- Global routing
- Detailed routing
- Design rule checking

### 7. Verification
- LVS (Layout vs Schematic)
- DRC (Design Rule Check)
- Timing analysis

## Output Files

### Generated Files
- **GDS**: `results/final/gds/fft_top.gds`
- **LEF**: `results/final/lef/fft_top.lef`
- **Netlist**: `results/final/verilog/gl/fft_top.v`
- **Reports**: `reports/` directory with detailed analysis

### Key Reports
- **Synthesis**: `reports/synthesis/1-synthesis.stat.rpt`
- **Placement**: `reports/placement/placement.stat.rpt`
- **Routing**: `reports/routing/routing.stat.rpt`
- **Timing**: `reports/synthesis/1-synthesis.timing.rpt`

## Troubleshooting

### Common Issues

1. **Synthesis Failures**
   - Check RTL syntax and dependencies
   - Verify all required modules are present
   - Check parameter values and constraints

2. **Placement Failures**
   - Adjust die area and core area
   - Check pin placement configuration
   - Verify power distribution setup

3. **Routing Failures**
   - Increase routing layers if available
   - Adjust routing strategy parameters
   - Check design rule violations

4. **Timing Violations**
   - Optimize clock period
   - Adjust synthesis strategy
   - Check critical path analysis

### Debug Commands

```bash
# Check OpenLane version
docker run --rm ghcr.io/the-openroad-project/openlane:latest flow.tcl --help

# Verify PDK installation
~/OpenLane/venv/bin/ciel ls --pdk <pdk_name>

# Check design configuration
cat designs/fft_top/config.tcl

# View synthesis logs
tail -f designs/fft_top/runs/<tag>/logs/synthesis.log
```

## Best Practices

### Design Guidelines
1. **Clock Domain**: Use single clock domain for simplicity
2. **Reset Strategy**: Use synchronous reset for better timing
3. **Memory**: Use synchronous memory for predictable behavior
4. **Interfaces**: Follow standard bus protocols (APB, AXI)

### PDK Selection
1. **GF180MCU**: Choose for low-power, MCU applications
2. **Sky130A**: Choose for high-performance, general-purpose designs
3. **IHP-SG13G2**: Choose for mixed-signal, RF applications

### Optimization
1. **Area**: Use synthesis strategies focused on area optimization
2. **Power**: Enable power-aware synthesis and placement
3. **Timing**: Set realistic clock periods based on PDK capabilities
4. **Routing**: Use appropriate routing strategies for design complexity

## Integration with Vyges Framework

The FFT design is fully integrated with the Vyges IP framework:

- **Metadata**: Complete design metadata in `vyges-metadata.json`
- **Documentation**: Comprehensive documentation in `docs/` directory
- **Testing**: Automated testbenches with cocotb
- **Simulation**: Support for multiple simulators (Verilator, Icarus)

## Next Steps

1. **Run the design** with your preferred PDK
2. **Review the results** and analyze performance metrics
3. **Optimize the design** based on requirements
4. **Validate the design** with DRC and LVS checks
5. **Generate final deliverables** for tapeout

## Support

For issues and questions:
- Check the troubleshooting section above
- Review OpenLane documentation
- Consult PDK-specific documentation
- Contact the Vyges development team 