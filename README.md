[![Vyges IP Template](https://img.shields.io/badge/Vyges-IP%20Template-blue?style=flat&logo=github)](https://vyges.com)
[![Use This Template](https://img.shields.io/badge/Use%20This%20Template-vyges--ip--template-brightgreen?style=for-the-badge)](https://github.com/vyges/vyges-ip-template/generate)
[![License](https://img.shields.io/badge/License-Apache%202.0-green.svg)](LICENSE)
[![Template](https://img.shields.io/badge/Template-Repository-orange)](https://github.com/vyges/vyges-ip-template)
[![Design Types](https://img.shields.io/badge/Design%20Types-Digital%20%7C%20Analog%20%7C%20Mixed%20%7C%20Chiplets-purple)](https://vyges.com/docs/design-types)
[![Tools](https://img.shields.io/badge/Tools-Verilator%20%7C%20Yosys%20%7C%20Magic%20%7C%20OpenROAD-blue)](https://vyges.com/docs/tools)
[![Target](https://img.shields.io/badge/Target-ASIC%20%7C%20FPGA-orange)](https://vyges.com/docs/target-platforms)
[![Verification](https://img.shields.io/badge/Verification-Cocotb%20%7C%20SystemVerilog-purple)](https://vyges.com/docs/verification)
[![GitHub Pages](https://img.shields.io/badge/GitHub%20Pages-Live-blue?style=flat&logo=github)](https://vyges.github.io/vyges-ip-template/)
[![Repository](https://img.shields.io/badge/Repository-GitHub-black?style=flat&logo=github)](https://github.com/vyges/vyges-ip-template)
[![Issues](https://img.shields.io/badge/Issues-GitHub-orange?style=flat&logo=github)](https://github.com/vyges/vyges-ip-template/issues)
[![Pull Requests](https://img.shields.io/badge/PRs-Welcome-brightgreen?style=flat&logo=github)](https://github.com/vyges/vyges-ip-template/pulls)

**IP Name:** fast-fourier-transform-ip  
**Version:** 1.0.0  
**Created:** 2025-07-21T05:38:04Z  
**Updated:** 2025-07-21T05:38:04Z  
**Author:** Vyges IP Development Team  
**License:** Apache-2.0  

## Overview

A high-performance Fast Fourier Transform (FFT) hardware accelerator supporting configurable FFT lengths from 256 to 4096 points with double-buffered memory architecture, memory-mapped interfaces, and automatic rescaling functionality to prevent overflow and maintain signal integrity.

## Key Features

- **Configurable FFT Length:** 256, 512, 1024, 2048, 4096 points
- **Data Precision:** 16-bit fixed-point input/output data
- **Double Buffering:** Background data transfer capability
- **Memory Mapped:** APB and AXI interface support
- **High Performance:** 6 cycles per butterfly operation
- **Automatic Rescaling:** Prevents overflow during computation
- **Scale Factor Tracking:** Enables proper signal reconstruction
- **Interrupt Support:** Completion and error notification

## Architecture

The FFT accelerator implements a 6-stage pipelined radix-2 decimation-in-frequency (DIF) algorithm with automatic rescaling:

1. **Address Generation and Memory Read**
2. **Data Alignment and Twiddle Factor Fetch**
3. **Complex Addition**
4. **Complex Subtraction**
5. **Complex Multiplication**
6. **Rescaling and Memory Write**

### Rescaling Subsystem

- **Overflow Detection:** Monitors for overflow conditions
- **Automatic Rescaling:** Divides by 2 when overflow detected
- **Scale Factor Tracking:** Accumulates total scaling applied
- **Configurable Modes:** Divide by 2 each stage or divide by N at end

## Implementation

### RTL Structure

```
rtl/
├── fft_top.sv              # Top-level module
├── fft_engine.sv           # FFT computation engine
├── rescale_unit.sv         # Rescaling logic
├── scale_factor_tracker.sv # Scale factor tracking
├── memory_interface.sv     # Memory interface logic
├── fft_control.sv          # Control logic
└── twiddle_rom.sv          # Twiddle factor ROM
```

### Key Modules

#### fft_top.sv
- Top-level module with APB/AXI interfaces
- Instantiates FFT engine, control unit, and memory interface
- Generates interrupt signals

#### fft_engine.sv
- 6-stage pipelined FFT computation engine
- Implements radix-2 DIF algorithm
- Integrates rescaling functionality
- Address generation and memory interface

#### rescale_unit.sv
- Dedicated rescaling logic with overflow detection
- Supports configurable rescaling modes
- Implements rounding and saturation options

#### scale_factor_tracker.sv
- Accumulates scale factors during FFT computation
- Tracks overflow statistics
- Provides scale factor information for signal reconstruction

## Testing

### Testbench Structure

```
tb/
├── sv_tb/
│   ├── tb_fft_top.sv       # Main testbench
│   └── Makefile           # Testbench Makefile
└── cocotb/
    ├── test_example.py    # Python test examples
    └── Makefile          # Cocotb Makefile
```

### Test Coverage

The testbench includes comprehensive tests for:

- **Basic FFT Functionality:** 1024-point FFT computation
- **Rescaling Tests:** Overflow detection and rescaling
- **Overflow Tests:** Overflow event detection and handling
- **Performance Tests:** Timing and throughput verification

### Running Tests

```bash
# Navigate to testbench directory
cd tb/sv_tb

# Run with Verilator (default)
make all

# Run with different simulator
make all SIMULATOR=iverilog

# Run specific tests
make test_basic
make test_rescaling
make test_overflow
make test_performance

# View waveforms
make waves

# Generate coverage report
make coverage
```

## ASIC Flow

### OpenLane Configuration

The ASIC flow uses OpenLane with sky130B PDK:

```bash
# Navigate to ASIC flow directory
cd flow/openlane

# Run complete flow
make

# Run specific stages
make synthesis
make placement
make routing
make lvs
make drc
```

### Key Configuration

- **Technology:** sky130B
- **Target Frequency:** 1 GHz
- **Target Area:** < 50K gates
- **Power Target:** < 50 mW

## FPGA Flow

### Supported Families

#### Commercial Tools
- **Xilinx:** 7-series, UltraScale, UltraScale+
- **Intel:** Cyclone, Arria, Stratix

#### Open Source Tools
- **Lattice iCE40:** IceStorm flow (Yosys + NextPNR + IcePack)
- **Lattice ECP5:** PrjTrellis flow (Yosys + NextPNR-ECP5 + ECPPack)
- **Xilinx 7-series:** SymbiFlow (Yosys + VPR + SymbiFlow)

### Synthesis Tools

#### Commercial Tools
- **Vivado:** Xilinx FPGA synthesis
- **Quartus:** Intel FPGA synthesis

#### Open Source Tools
- **Yosys:** RTL synthesis and optimization
- **NextPNR:** Place and route
- **IceStorm:** iCE40 bitstream generation
- **PrjTrellis:** ECP5 bitstream generation
- **SymbiFlow:** Xilinx 7-series bitstream generation

### Running FPGA Flow

#### Commercial Tools
```bash
# Navigate to FPGA flow directory
cd flow/fpga

# Run with Vivado (default)
make all

# Run with Quartus
make all TOOL=quartus

# Run specific stages
make synth
make impl
make bitstream

# Analyze results
make timing
make resources
make power
```

#### Open Source Tools
```bash
# Navigate to open source FPGA flow directory
cd flow/fpga/openfpga

# Lattice iCE40 (IceStorm)
make ice40_synth FPGA_PART=hx8k-ct256
make ice40_pnr FPGA_PART=hx8k-ct256
make ice40_bitstream FPGA_PART=hx8k-ct256

# Lattice ECP5 (PrjTrellis)
make ecp5_synth FPGA_PART=85k
make ecp5_pnr FPGA_PART=85k
make ecp5_bitstream FPGA_PART=85k

# Xilinx 7-series (SymbiFlow)
make xilinx7_synth FPGA_PART=xc7a35tcsg324-1
make xilinx7_pnr FPGA_PART=xc7a35tcsg324-1
make xilinx7_bitstream FPGA_PART=xc7a35tcsg324-1

# Generic synthesis (any FPGA family)
make fpga_synth
make reports
make resources
```

## Performance

### Throughput

| FFT Length | Butterfly Count | Total Cycles | Latency (μs @ 1GHz) |
|------------|----------------|--------------|---------------------|
| 256 | 2,048 | 12,288 | 12.3 |
| 512 | 4,608 | 27,648 | 27.6 |
| 1024 | 10,240 | 61,440 | 61.4 |
| 2048 | 22,528 | 135,168 | 135.2 |
| 4096 | 49,152 | 294,912 | 294.9 |

### Resource Utilization

| Resource | Count | Description |
|----------|-------|-------------|
| DSP Blocks | 4 | Complex multiplier (2) + Complex adder (2) |
| BRAM | 8 | Input/Output buffers + Twiddle ROM |
| Registers | ~5K | Pipeline registers and control logic |
| LUTs | ~15K | Address generation and control logic |
| Scale Factor Logic | ~1K | Rescaling and scale factor tracking |

## Memory Map

### Register Map

| Address Offset | Register Name | Access | Description |
|----------------|---------------|--------|-------------|
| 0x0000 | FFT_CTRL | R/W | FFT Control Register |
| 0x0004 | FFT_STATUS | R | FFT Status Register |
| 0x0008 | FFT_CONFIG | R/W | FFT Configuration Register |
| 0x000C | FFT_LENGTH | R/W | FFT Length Register |
| 0x0010 | BUFFER_SEL | R/W | Buffer Selection Register |
| 0x0014 | INT_ENABLE | R/W | Interrupt Enable Register |
| 0x0018 | INT_STATUS | R | Interrupt Status Register |
| 0x001C | SCALE_FACTOR | R | Output Scale Factor Register |
| 0x0020 | RESCALE_CTRL | R/W | Rescaling Control Register |
| 0x0024 | OVERFLOW_STATUS | R | Overflow Status Register |

### Data Memory Map

| Address Range | Memory | Description |
|---------------|--------|-------------|
| 0x1000-0x1FFF | Input Buffer A | Input data buffer A |
| 0x2000-0x2FFF | Input Buffer B | Input data buffer B |
| 0x3000-0x3FFF | Output Buffer A | Output data buffer A |
| 0x4000-0x4FFF | Output Buffer B | Output data buffer B |

## Usage Examples

### Basic FFT Operation

```c
// Configure FFT for 1024 points
write_reg(FFT_CONFIG, 10);  // log2(1024)
write_reg(FFT_LENGTH, 1024);

// Enable rescaling
write_reg(FFT_CTRL, 0x30);  // Enable rescaling and scale tracking

// Start FFT computation
write_reg(FFT_CTRL, 0x31);  // Start FFT

// Wait for completion
while (!(read_reg(FFT_STATUS) & 0x02)) {
    // Wait for FFT_DONE bit
}

// Read scale factor
uint32_t scale_factor = read_reg(SCALE_FACTOR);
printf("Scale factor: %d\n", scale_factor & 0xFF);
```

### Rescaling Configuration

```c
// Configure rescaling functionality
void configure_fft_rescaling(void) {
    // Enable automatic rescaling
    write_reg(FFT_CTRL, read_reg(FFT_CTRL) | 0x10);
    
    // Enable scale factor tracking
    write_reg(FFT_CTRL, read_reg(FFT_CTRL) | 0x20);
    
    // Set rescaling mode (0=divide by 2 each stage)
    write_reg(FFT_CONFIG, read_reg(FFT_CONFIG) & ~0x10000);
    
    // Enable overflow detection
    write_reg(FFT_CONFIG, read_reg(FFT_CONFIG) | 0x80000);
}
```

## Documentation

- [Design Specification](docs/design_specification.md) - Detailed design specification
- [Architecture](docs/architecture.md) - Architectural details and implementation
- [User Guide](docs/user_guide.md) - Integration and usage guide
- [API Reference](docs/api_reference.md) - Register and interface specifications

## Dependencies

- **SystemVerilog:** IEEE 1800-2017
- **ASIC Tools:** OpenLane, sky130B PDK
- **FPGA Tools:** Vivado, Quartus
- **Simulation:** Verilator, Icarus Verilog, ModelSim

## Known Issues and Limitations

### Yosys Memory Synthesis Limitations

**Issue**: The FFT IP uses large memory arrays (e.g., 2048×32-bit memory interface) with `(* ram_style = "block" *)` synthesis attributes to optimize for BRAM inference. However, **Yosys 0.55 and earlier versions have limited support for automatic BRAM inference**.

**Symptoms**:
- Memory arrays are synthesized as individual flip-flops instead of BRAM blocks
- High cell counts: ~136,000 cells for memory interface vs. expected ~500 cells
- `(* ram_style = "block" *)` attributes are ignored during synthesis
- Memory inference works but BRAM mapping fails with "No acceptable bram resources found"

**Root Cause**:
- Yosys 0.55 doesn't natively map `(* ram_style = "block" *)` to BRAM without proper technology libraries
- The `memory_bram` pass requires vendor-specific technology mapping files
- Generic synthesis flows skip the `memory_bram` mapping step

**Workarounds**:
1. **Use vendor-specific synthesis flows**:
   ```bash
   # For Xilinx devices
   yosys -p "read_verilog rtl/*.sv; synth_xilinx -top fft_top"
   
   # For Intel/Altera devices  
   yosys -p "read_verilog rtl/*.sv; synth_intel -top fft_top"
   ```

2. **Upgrade to newer Yosys versions** (0.43+ or latest master builds) which have improved memory inference

3. **Use vendor tools directly** (Vivado, Quartus) which have better BRAM inference support

4. **Manual memory instantiation** using vendor-specific primitives

**Current Status**:
- ✅ Memory inference works (creates `$mem_v2` cells)
- ❌ BRAM mapping fails due to missing technology library
- 🔧 BRAM synthesis scripts are provided for future use
- 📊 Gate count reports show actual synthesized cell counts

**Impact on Design**:
- **Functionality**: ✅ FFT IP works correctly with flip-flop-based memory
- **Area**: ❌ Much larger than optimal (136K vs 500 cells)
- **Power**: ❌ Higher power consumption due to flip-flop array
- **Performance**: ✅ No impact on FFT computation speed

**Future Improvements**:
- Upgrade Yosys to latest version with better BRAM support
- Implement vendor-specific technology mapping
- Add memory generator scripts for common FPGA families
- Create synthesis constraints for optimal memory mapping

## License

Apache-2.0 License - see [LICENSE](LICENSE) for details.

**Important**: The Apache-2.0 license applies to the **hardware IP content** (RTL, documentation, testbenches, etc.) that you create using this template. The template structure, build processes, tooling workflows, and AI context/processing engine are provided as-is for your use but are not themselves licensed under Apache-2.0.

For detailed licensing information, see [LICENSE_SCOPE.md](LICENSE_SCOPE.md).

## Support

For support and questions:
- **Email:** team@vyges.com
- **GitHub:** [vyges](https://github.com/vyges)
- **Documentation:** [docs/](docs/)
