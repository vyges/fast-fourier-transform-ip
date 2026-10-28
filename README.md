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

A Fast Fourier Transform (FFT) hardware accelerator supporting configurable power-of-two FFT lengths up to 1024 points, computed in place over a single shared working memory, with memory-mapped interfaces and per-stage rescaling to prevent overflow. Results are returned in natural order.

## Key Features

- **Configurable FFT Length:** 2 to 1024 points (log2(N) = 1 .. 10; the working memory holds at most 1024 samples)
- **Data Precision:** 16-bit fixed-point (Q1.15) input/output data, packed `{imag[31:16], real[15:0]}`
- **Buffer Select / Swap:** Buffer-active status bit and buffer-swap interrupt (one shared working memory)
- **Memory Mapped:** APB register, twiddle and sample windows (the AXI port is tied off)
- **Timing:** 6 cycles per butterfly, one memory access per cycle
- **Natural-Order Output:** A final bit-reverse pass puts bin k in word k
- **Automatic Rescaling:** Per-stage halving prevents overflow during computation
- **Scale Factor Tracking:** Number of scaled stages, for signal reconstruction
- **Interrupt Support:** Completion and error notification

## Architecture

The FFT accelerator implements an in-place radix-2 decimation-in-frequency (DIF) algorithm with per-stage rescaling: log2(N) stages of N/2 butterflies, followed by a bit-reverse pass that leaves the results in natural order. The engine has one memory port and makes one access per cycle, so each butterfly takes 6 cycles, executed in sequence (butterflies are not overlapped):

1. **Read A**
2. **Read B**
3. **Read Twiddle W**
4. **Wait for Read Data**
5. **Write A' = (A + B) >> sh**
6. **Write B' = ((A - B) × W) >> (15 + sh)**, where sh = 1 on a scaled stage, else 0

### Rescaling Subsystem

Rescaling is implemented inside the FFT engine and is active only when FFT_CTRL[4] (rescale_en) and FFT_CONFIG[19] (overflow_detect) are both set.

- **Overflow Detection:** Counts butterflies with a component that does not fit 16 bits
- **Automatic Rescaling:** A scaled stage halves its outputs
- **Scale Factor Tracking:** Counts the scaled stages; output = true FFT / 2^scale_factor
- **Configurable Modes:** Mode 1 halves every stage (result X/N, scale factor log2(N)); mode 0 (block floating point) halves a stage only when one of its inputs lies outside [-2^13, 2^13)

## Implementation

### RTL Structure

```
rtl/
├── fft_fft_top.sv              # Top-level module (fft_top)
├── fft_fft_engine.sv           # FFT computation engine, including rescaling
├── fft_memory_interface.sv     # APB registers, address decode, working memory
├── fft_fft_control.sv          # Control and interrupt logic
├── fft_bin_streamer.sv         # FFT_USE_STREAM_OUT post-completion walker
├── fft_bus_master.sv           # FFT_USE_BUS_MASTER generic memory master
├── fft_ctrl_tlul.sv            # TL-UL bus wrapper
├── fft_rescale_unit.sv         # Not instantiated (dead code)
├── fft_scale_factor_tracker.sv # Not instantiated (dead code)
└── fft_twiddle_rom.sv          # DEPRECATED — dead code, retained for history.
                                #   Twiddles are loaded by firmware at boot via
                                #   APB writes. See docs/firmware-integration.md.
```

### Key Modules

#### fft_fft_top.sv
- Top-level module with APB/AXI interfaces (the AXI port is tied off)
- Instantiates FFT engine, control unit, and memory interface
- Generates interrupt signals

#### fft_fft_engine.sv
- Sequential FFT computation engine: 6 cycles per butterfly, one memory access per cycle
- Implements radix-2 DIF in place, then a bit-reverse pass for natural-order output
- Latches the configuration at launch and rejects illegal lengths (error path)
- Integrates rescaling, rounding and saturation, the scale factor and the overflow statistics
- Address generation and memory interface

#### fft_rescale_unit.sv, fft_scale_factor_tracker.sv
- Not instantiated in any build; the engine performs rescaling and scale factor tracking itself

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

### Verification

`tb/golden/run_golden.py` builds `tb/golden/tb_fft_golden.sv` with Verilator, drives `fft_top` over APB the way firmware does, and compares every output bin word for word with a bit-exact fixed-point reference model, together with the scale factor and overflow count. It covers 8 configurations from 8 to 1024 points: plain, rounding, saturation, wrap, and both rescale modes. The reference model is itself checked against a floating-point FFT. The testbench also checks that FFT_STATUS.done holds and that INT_STATUS[0] holds until written with 1. With `--netlist` the same cases run on the Yosys-synthesized netlist.

```bash
make test-golden           # RTL against the reference model
make test-golden-netlist   # the same cases on the synthesized netlist
```

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

### LibreLane Configuration

The ASIC flow targets sky130A via LibreLane:

```bash
librelane flow/openlane/config.json
```

The configuration hardens `fft_top` with `+define+FFT_USE_SRAM_MACRO`. `flow/openlane/pin_order.cfg` clusters the SRAM bus on the NORTH edge so the SoC integrator can place SRAM banks adjacent to the FFT macro.

### Key Configuration

- **Technology:** sky130A (extends to other PDKs by supplying a matching SRAM macro)
- **Target Frequency:** 40 MHz (25 ns clock period)
- **Die area:** 1500 × 1500 μm
- **Routing:** met1–met5

### Memory Topology

The IP supports two memory implementations, selected at compile time:

- **Default (FPGA / simulation):** an inferred 2048×32 RAM array (`ram_style = "block"` for Xilinx/Intel BRAM inference). No external connections required.
- **ASIC with hard SRAM (`+define+FFT_USE_SRAM_MACRO`):** the IP exposes an SRAM port bus on its top-level boundary and the SoC integrator instantiates two 1024×32 SRAM banks as siblings of the FFT macro at the wrapper level. The IP itself contains no PDK-specific macro instances.

In wrapper-bus mode the following ports are exposed on `fft_top` (and on the `fft_ctrl_tlul` TL-UL wrapper, if used):

| Port            | Dir | Width | Notes                          |
|-----------------|-----|-------|--------------------------------|
| `sram_clk_o`    | out | 1     | Bank clock                     |
| `sram_rwb_o`    | out | 1     | 1 = read, 0 = write            |
| `sram_en_o`     | out | 2     | Per-bank enable (bit 0 = bank 0) |
| `sram_addr_o`   | out | 10    | Word address (1024 deep)       |
| `sram_wdata_o`  | out | 32    | Write data                     |
| `sram_ben_o`    | out | 32    | Bit-enable mask                |
| `sram_rdata0_i` | in  | 32    | Read data from bank 0          |
| `sram_rdata1_i` | in  | 32    | Read data from bank 1          |

The `flow/openlane/pin_order.cfg` clusters these pins on the NORTH edge so SRAM banks placed above the FFT macro route cleanly into the bus.

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

| FFT Length | Butterfly Count | Total Cycles (approx.) | Latency (μs @ 1GHz) |
|------------|----------------|--------------|---------------------|
| 256 | 1,024 | 7,600-7,900 | 7.6-7.9 |
| 512 | 2,304 | 17,300 | 17.3 |
| 1024 | 5,120 | 36,800-37,800 | 36.8-37.8 |

Total cycles are measured from the start pulse to the last streamed bin: about 6 × (N/2) × log2(N) for the butterflies, plus about 3N for the bit-reverse pass, plus N+2 for the input scan when rescale mode 0 is on.

### Resource Utilization

| Resource | Count | Description |
|----------|-------|-------------|
| DSP Blocks | 4 | Complex multiplier (2) + Complex adder (2) |
| BRAM | 8 | Working memory (data and twiddle words) |
| Registers | ~5K | Datapath registers and control logic |
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
| 0x0018 | INT_STATUS | RW1C | Interrupt Status Register (write 1 to clear) |
| 0x001C | SCALE_FACTOR | R | Output Scale Factor Register |
| 0x0020 | RESCALE_CTRL | R/W | Rescaling Control Register |
| 0x0024 | OVERFLOW_STATUS | R | Overflow Status Register |

Registers decode at 0x0000-0x07FC. FFT_STATUS[1] (done) and FFT_STATUS[2] (error) hold from the end of a run until the next run starts. INT_STATUS bits [4:0] are the rescale, overflow, buffer swap, error and done pending bits; each is set on its event while the matching INT_ENABLE bit is set and stays set until software writes 1 to it. FFT_CONFIG and the FFT_CTRL run bits are latched at launch. A length outside log2(N) = 1 .. min(FFT_MAX_LENGTH_LOG2, 10) is rejected at launch and sets FFT_STATUS[2]. OVERFLOW_STATUS[23:16] (max overflow magnitude) is not measured and reads 0.

### Data Memory Map

| Address Range | Memory | Description |
|---------------|--------|-------------|
| 0x0800-0x0FFC | Twiddle window | 512 twiddle words (write-only), word k = {cos(2πk/N), -sin(2πk/N)} in Q1.15 |
| 0x1000-0x1FFC | Sample window | 1024 sample words (write-only, `FFT_USE_APB_DATA` only), word i = {imag, real} |

Results are read through the configured memory backend or the stream-out port; there is no APB readback window.

## Usage Examples

### Basic FFT Operation

```c
// Configure FFT for 1024 points, overflow detection on (needed for rescaling)
write_reg(FFT_CONFIG, 0x80000 | 10);  // overflow_detect | log2(1024)
write_reg(FFT_LENGTH, 1024);

// Enable rescaling
write_reg(FFT_CTRL, 0x30);  // Enable rescaling and scale tracking

// Start FFT computation: pulse start (configuration is latched here)
write_reg(FFT_CTRL, 0x31);  // Start FFT
write_reg(FFT_CTRL, 0x30);  // Deassert start

// Wait for completion (FFT_DONE holds until the next run starts)
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
    
    // Set rescaling mode (0 = halve a stage only when needed, 1 = halve every stage)
    write_reg(FFT_CONFIG, read_reg(FFT_CONFIG) & ~0x10000);
    
    // Enable overflow detection
    write_reg(FFT_CONFIG, read_reg(FFT_CONFIG) | 0x80000);
}
```

## Documentation

- [Design Specification](docs/design_specification.md) - Detailed design specification
- [Architecture](docs/architecture.md) - Architectural details and implementation
- [Firmware Integration Guide](docs/firmware-integration.md) - Host-side boot sequence (twiddle load, FFT_USE_APB_DATA sample window, register setup) and bring-up gotchas
- [Integration Patterns](docs/integration-patterns.md) - SoC-side memory bus integration
- [Stream-Out Mode Design](docs/stream-out-mode-design.md) - FFT_USE_STREAM_OUT post-completion bin streaming
- [Bus-Master Mode Design](docs/bus-master-mode-design.md) - FFT_USE_BUS_MASTER memory access
- [User Guide](docs/user_guide.md) - Integration and usage guide
- [API Reference](docs/api_reference.md) - Register and interface specifications

## Dependencies

- **SystemVerilog:** IEEE 1800-2017
- **ASIC Tools:** LibreLane, sky130A PDK
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
- **Contact:** [vyges.com/contact](https://vyges.com/contact)
- **GitHub:** [vyges](https://github.com/vyges)
- **Documentation:** [docs/](docs/)
