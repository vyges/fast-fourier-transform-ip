# Fast Fourier Transform (FFT) Hardware Accelerator Design Specification

**IP Name:** fast-fourier-transform-ip  
**Version:** 1.0.0  
**Created:** 2025-07-21T05:38:04Z  
**Updated:** 2025-07-21T05:38:04Z  
**Author:** Vyges IP Development Team  
**License:** Apache-2.0  

## 1. Overview

This document specifies the design of a high-performance Fast Fourier Transform (FFT) hardware accelerator that supports configurable FFT lengths from 256 to 4096 points. The design implements a radix-2 decimation-in-frequency (DIF) FFT algorithm with double-buffered memory architecture for optimal throughput and background data transfer capabilities. The design includes automatic rescaling after each FFT stage to prevent overflow and provides output scale factor tracking for proper signal reconstruction.

### 1.1 Key Features

- **Configurable FFT Length:** 256 to 4096 points (power of 2)
- **Data Precision:** 16-bit fixed-point input/output data
- **Twiddle Factors:** 16-bit complex coefficients
- **Double Buffering:** Input and output memory banks for background transfer
- **Memory Mapped Interface:** APB/AXI interface for host processor access
- **Performance:** One butterfly computation in 6 clock cycles
- **Pipelined Architecture:** Optimized for high throughput
- **Automatic Rescaling:** Rescaling after each FFT stage to prevent overflow
- **Scale Factor Tracking:** Output scale factor for proper signal reconstruction

### 1.2 Performance Targets

- **Throughput:** ~167 MSPS (Mega Samples Per Second) at 1 GHz clock
- **Latency:** Configurable based on FFT length
- **Power Efficiency:** Optimized for low-power operation
- **Area:** Target < 50K gates for 1024-point FFT
- **Dynamic Range:** Maintained through automatic rescaling

## 2. Architecture Overview

### 2.1 Top-Level Block Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                    FFT Hardware Accelerator                     │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐         │
│  │   Control   │    │   Address   │    │   Status    │         │
│  │   Logic     │    │  Generator  │    │  Register   │         │
│  └─────────────┘    └─────────────┘    └─────────────┘         │
│           │                │                   │               │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                    Memory Interface                         │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │ │
│  │  │   Input     │  │   Output    │  │  Twiddle    │         │ │
│  │  │  Buffer A   │  │  Buffer A   │  │   Factor    │         │ │
│  │  │  (16-bit)   │  │  (16-bit)   │  │   ROM       │         │ │
│  │  └─────────────┘  └─────────────┘  └─────────────┘         │ │
│  │  ┌─────────────┐  ┌─────────────┐                          │ │
│  │  │   Input     │  │   Output    │                          │ │
│  │  │  Buffer B   │  │  Buffer B   │                          │ │
│  │  │  (16-bit)   │  │  (16-bit)   │                          │ │
│  │  └─────────────┘  └─────────────┘                          │ │
│  └─────────────────────────────────────────────────────────────┘ │
│           │                │                   │               │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                    FFT Engine                               │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │ │
│  │  │ Butterfly   │  │   Complex   │  │   Complex   │         │ │
│  │  │ Processing  │  │ Multiplier  │  │   Adder     │         │ │
│  │  │ Unit        │  │             │  │             │         │ │
│  │  └─────────────┘  └─────────────┘  └─────────────┘         │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │ │
│  │  │   Rescale   │  │   Scale     │  │   Overflow  │         │ │
│  │  │   Logic     │  │  Factor     │  │  Detection  │         │ │
│  │  │             │  │  Tracker    │  │             │         │ │
│  │  └─────────────┘  └─────────────┘  └─────────────┘         │ │
│  └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 Memory Organization

The FFT accelerator implements a double-buffered memory architecture:

- **Input Buffers (A & B):** Each buffer can store one complete FFT dataset
- **Output Buffers (A & B):** Each buffer stores computed FFT results
- **Twiddle Factor ROM:** Pre-computed complex coefficients for all FFT lengths
- **Memory Mapping:** All buffers are memory-mapped to host processor

## 3. Interface Specification

### 3.1 Clock and Reset Interface

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| `clk_i` | input | 1 | System clock |
| `reset_n_i` | input | 1 | Active-low asynchronous reset |

### 3.2 APB Interface (Primary)

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| `pclk_i` | input | 1 | APB clock |
| `preset_n_i` | input | 1 | APB reset (active-low) |
| `psel_i` | input | 1 | APB select |
| `penable_i` | input | 1 | APB enable |
| `pwrite_i` | input | 1 | APB write enable |
| `paddr_i` | input | 16 | APB address |
| `pwdata_i` | input | 32 | APB write data |
| `prdata_o` | output | 32 | APB read data |
| `pready_o` | output | 1 | APB ready |

### 3.3 AXI Interface (Alternative)

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| `axi_aclk_i` | input | 1 | AXI clock |
| `axi_areset_n_i` | input | 1 | AXI reset (active-low) |
| `axi_awaddr_i` | input | 32 | AXI write address |
| `axi_awvalid_i` | input | 1 | AXI write address valid |
| `axi_awready_o` | output | 1 | AXI write address ready |
| `axi_wdata_i` | input | 64 | AXI write data |
| `axi_wvalid_i` | input | 1 | AXI write data valid |
| `axi_wready_o` | output | 1 | AXI write data ready |
| `axi_araddr_i` | input | 32 | AXI read address |
| `axi_arvalid_i` | input | 1 | AXI read address valid |
| `axi_arready_o` | output | 1 | AXI read address ready |
| `axi_rdata_o` | output | 64 | AXI read data |
| `axi_rvalid_o` | output | 1 | AXI read data valid |
| `axi_rready_i` | input | 1 | AXI read data ready |

### 3.4 Interrupt Interface

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| `fft_done_o` | output | 1 | FFT computation complete |
| `fft_error_o` | output | 1 | FFT computation error |

## 4. Memory Map

### 4.1 Register Map

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

### 4.2 Data Memory Map

| Address Range | Memory | Description |
|---------------|--------|-------------|
| 0x1000-0x1FFF | Input Buffer A | Input data buffer A |
| 0x2000-0x2FFF | Input Buffer B | Input data buffer B |
| 0x3000-0x3FFF | Output Buffer A | Output data buffer A |
| 0x4000-0x4FFF | Output Buffer B | Output data buffer B |

### 4.3 Register Bit Definitions

#### FFT_CTRL Register (0x0000)
| Bits | Name | Access | Description |
|------|------|--------|-------------|
| [0] | FFT_START | R/W | Start FFT computation |
| [1] | FFT_RESET | R/W | Reset FFT engine |
| [2] | BUFFER_SWAP | R/W | Swap input/output buffers |
| [3] | MODE_SEL | R/W | Mode selection (0=APB, 1=AXI) |
| [4] | RESCALE_EN | R/W | Enable automatic rescaling |
| [5] | SCALE_TRACK_EN | R/W | Enable scale factor tracking |
| [31:6] | RESERVED | R | Reserved bits |

#### FFT_STATUS Register (0x0004)
| Bits | Name | Access | Description |
|------|------|--------|-------------|
| [0] | FFT_BUSY | R | FFT computation in progress |
| [1] | FFT_DONE | R | FFT computation complete |
| [2] | FFT_ERROR | R | FFT computation error |
| [3] | BUFFER_ACTIVE | R | Active buffer indicator |
| [4] | RESCALE_ACTIVE | R | Rescaling in progress |
| [5] | OVERFLOW_DETECTED | R | Overflow detected during computation |
| [31:6] | RESERVED | R | Reserved bits |

#### FFT_CONFIG Register (0x0008)
| Bits | Name | Access | Description |
|------|------|--------|-------------|
| [11:0] | FFT_LENGTH_LOG2 | R/W | Log2 of FFT length (8-12) |
| [15:12] | RESERVED | R | Reserved bits |
| [16] | RESCALE_MODE | R/W | Rescaling mode (0=divide by 2, 1=divide by N) |
| [17] | ROUNDING_MODE | R/W | Rounding mode (0=truncate, 1=round) |
| [18] | SATURATION_EN | R/W | Enable saturation arithmetic |
| [19] | OVERFLOW_DETECT | R/W | Enable overflow detection |
| [31:20] | RESERVED | R | Reserved bits |

#### SCALE_FACTOR Register (0x001C)
| Bits | Name | Access | Description |
|------|------|--------|-------------|
| [7:0] | SCALE_FACTOR | R | Total scale factor applied (log2) |
| [15:8] | STAGE_COUNT | R | Number of stages processed |
| [23:16] | RESERVED | R | Reserved bits |
| [31:24] | OVERFLOW_COUNT | R | Number of overflow events |

#### RESCALE_CTRL Register (0x0020)
| Bits | Name | Access | Description |
|------|------|--------|-------------|
| [0] | RESCALE_EN | R/W | Enable rescaling after each stage |
| [1] | SCALE_TRACK_EN | R/W | Enable scale factor tracking |
| [2] | OVERFLOW_INT_EN | R/W | Enable overflow interrupt |
| [3] | RESCALE_INT_EN | R/W | Enable rescaling interrupt |
| [7:4] | RESCALE_THRESHOLD | R/W | Rescaling threshold (bits) |
| [31:8] | RESERVED | R | Reserved bits |

#### OVERFLOW_STATUS Register (0x0024)
| Bits | Name | Access | Description |
|------|------|--------|-------------|
| [7:0] | OVERFLOW_COUNT | R | Total overflow count |
| [15:8] | LAST_OVERFLOW_STAGE | R | Stage where last overflow occurred |
| [23:16] | MAX_OVERFLOW_MAGNITUDE | R | Maximum overflow magnitude |
| [31:24] | RESERVED | R | Reserved bits |

## 5. FFT Algorithm Implementation

### 5.1 Radix-2 DIF Algorithm with Rescaling

The FFT accelerator implements a radix-2 decimation-in-frequency (DIF) algorithm with automatic rescaling:

```
X(k) = X_even(k) + W_N^k * X_odd(k)
X(k + N/2) = X_even(k) - W_N^k * X_odd(k)
```

After each stage, the data is rescaled to prevent overflow:
```
X_rescaled(k) = X(k) / 2^scale_factor
```

Where:
- `X_even(k)` and `X_odd(k)` are even and odd indexed samples
- `W_N^k` is the twiddle factor: `W_N^k = e^(-j2πk/N)`
- `scale_factor` is the accumulated scaling factor

### 5.2 Butterfly Operation with Rescaling

Each butterfly operation performs:

```
A' = (A + B) / 2
B' = ((A - B) * W_N^k) / 2
```

**Timing:** 6 clock cycles per butterfly operation

### 5.3 Pipeline Stages with Rescaling

1. **Stage 1 (1 cycle):** Address generation and memory read
2. **Stage 2 (1 cycle):** Data alignment and twiddle factor fetch
3. **Stage 3 (1 cycle):** Complex addition (A + B)
4. **Stage 4 (1 cycle):** Complex subtraction (A - B)
5. **Stage 5 (1 cycle):** Complex multiplication with twiddle factor
6. **Stage 6 (1 cycle):** Rescaling and memory write

### 5.4 Rescaling Implementation

#### Rescaling Logic
```verilog
// Rescaling after each butterfly operation
always_comb begin
    if (rescaling_enabled) begin
        // Check for overflow
        if (|result[15:14] || |result[31:30]) begin
            // Overflow detected - rescale by 2
            rescaled_result = result >> 1;
            scale_factor_increment = 1;
        end else begin
            // No overflow - no rescaling needed
            rescaled_result = result;
            scale_factor_increment = 0;
        end
    end else begin
        // Rescaling disabled
        rescaled_result = result;
        scale_factor_increment = 0;
    end
end
```

#### Scale Factor Tracking
```verilog
// Scale factor accumulator
always_ff @(posedge clk_i or negedge reset_n_i) begin
    if (!reset_n_i) begin
        total_scale_factor <= 8'h00;
    end else if (fft_start) begin
        total_scale_factor <= 8'h00;
    end else if (scale_factor_increment) begin
        total_scale_factor <= total_scale_factor + 1;
    end
end
```

## 6. Memory Architecture

### 6.1 Double Buffering Strategy

```
┌─────────────────┐    ┌─────────────────┐
│   Input Buffer  │    │  Output Buffer  │
│       A         │    │       A         │
│  (Processing)   │    │  (Processing)   │
└─────────────────┘    └─────────────────┘
         │                       │
         ▼                       ▼
┌─────────────────┐    ┌─────────────────┐
│   Input Buffer  │    │  Output Buffer  │
│       B         │    │       B         │
│  (Background)   │    │  (Background)   │
└─────────────────┘    └─────────────────┘
```

### 6.2 Buffer Switching Logic

- **Active Buffer:** Currently being processed by FFT engine
- **Background Buffer:** Available for host processor data transfer
- **Switch Trigger:** FFT completion or explicit buffer swap command
- **Atomic Switch:** Ensures data integrity during buffer transitions

### 6.3 Memory Requirements

| FFT Length | Input Buffer Size | Output Buffer Size | Total Memory |
|------------|-------------------|-------------------|--------------|
| 256 | 1 KB | 1 KB | 4 KB |
| 512 | 2 KB | 2 KB | 8 KB |
| 1024 | 4 KB | 4 KB | 16 KB |
| 2048 | 8 KB | 8 KB | 32 KB |
| 4096 | 16 KB | 16 KB | 64 KB |

## 7. Twiddle Factor Generation

### 7.1 ROM Organization

Pre-computed twiddle factors stored in ROM:

```
W_N^k = cos(2πk/N) - j*sin(2πk/N)
```

### 7.2 ROM Size Requirements

| FFT Length | ROM Entries | ROM Size |
|------------|-------------|----------|
| 256 | 128 | 2 KB |
| 512 | 256 | 4 KB |
| 1024 | 512 | 8 KB |
| 2048 | 1024 | 16 KB |
| 4096 | 2048 | 32 KB |

### 7.3 Twiddle Factor Access

- **Address Generation:** Based on current FFT stage and butterfly index
- **Symmetry Exploitation:** Uses trigonometric symmetry to reduce ROM size
- **Precision:** 16-bit fixed-point representation

## 8. Performance Analysis

### 8.1 Throughput Calculation

For a 1024-point FFT:
- **Butterfly Operations:** 1024 × log2(1024) = 10,240 butterflies
- **Clock Cycles:** 10,240 × 6 = 61,440 cycles
- **Throughput at 1 GHz:** 1,000,000,000 / 61,440 ≈ 16.3 MSPS

### 8.2 Latency Analysis

| FFT Length | Butterfly Count | Total Cycles | Latency (μs @ 1GHz) |
|------------|----------------|--------------|---------------------|
| 256 | 2,048 | 12,288 | 12.3 |
| 512 | 4,608 | 27,648 | 27.6 |
| 1024 | 10,240 | 61,440 | 61.4 |
| 2048 | 22,528 | 135,168 | 135.2 |
| 4096 | 49,152 | 294,912 | 294.9 |

### 8.3 Resource Utilization

| Resource | Count | Description |
|----------|-------|-------------|
| DSP Blocks | 4 | Complex multiplier (2) + Complex adder (2) |
| BRAM | 8 | Input/Output buffers + Twiddle ROM |
| Registers | ~5K | Pipeline registers and control logic |
| LUTs | ~15K | Address generation and control logic |
| Scale Factor Logic | ~1K | Rescaling and scale factor tracking |

## 9. Power Management

### 9.1 Power Domains

- **Core Domain:** FFT engine and control logic
- **Memory Domain:** Input/output buffers
- **Interface Domain:** APB/AXI interface logic
- **Rescaling Domain:** Rescaling logic and scale factor tracking

### 9.2 Power States

| State | Description | Power Consumption |
|-------|-------------|-------------------|
| Active | FFT computation in progress | 100% |
| Idle | Waiting for start command | 10% |
| Sleep | Power-down mode | 1% |

### 9.3 Clock Gating

- **Memory Banks:** Clock gated when not accessed
- **Pipeline Stages:** Clock gated during idle periods
- **Interface Logic:** Clock gated when no transfers active
- **Rescaling Logic:** Clock gated when rescaling disabled

## 10. Error Handling

### 10.1 Error Conditions

- **Invalid FFT Length:** Non-power-of-2 or out-of-range length
- **Memory Overflow:** Buffer access beyond allocated space
- **Timeout Error:** FFT computation exceeds maximum cycles
- **Data Corruption:** ECC/parity errors in memory
- **Rescaling Overflow:** Excessive rescaling required

### 10.2 Error Reporting

- **Status Register:** Error flags in FFT_STATUS register
- **Interrupt Generation:** FFT_ERROR interrupt signal
- **Error Logging:** Error codes stored in dedicated registers
- **Overflow Tracking:** Overflow events logged in OVERFLOW_STATUS

## 11. Verification Strategy

### 11.1 Test Vectors

- **Unit Tests:** Individual butterfly operation verification
- **Integration Tests:** Complete FFT computation verification
- **Performance Tests:** Throughput and latency measurement
- **Corner Cases:** Edge cases and error conditions
- **Rescaling Tests:** Overflow and rescaling verification

### 11.2 Coverage Goals

- **Functional Coverage:** 100% of FFT algorithm paths
- **Code Coverage:** >95% RTL code coverage
- **Interface Coverage:** 100% of bus protocol sequences
- **Error Coverage:** 100% of error handling paths
- **Rescaling Coverage:** 100% of rescaling scenarios

## 12. Implementation Guidelines

### 12.1 RTL Coding Standards

- **Naming Convention:** snake_case for signals and modules
- **Clock Domain:** Single clock domain design
- **Reset Strategy:** Asynchronous reset, synchronous release
- **Synthesis:** Fully synthesizable RTL

### 12.2 File Organization

```
rtl/
├── fft_top.sv              # Top-level module
├── fft_engine.sv           # FFT computation engine
├── butterfly_unit.sv       # Butterfly processing unit
├── rescale_unit.sv         # Rescaling logic
├── scale_factor_tracker.sv # Scale factor tracking
├── memory_interface.sv     # Memory interface logic
├── address_generator.sv    # Address generation logic
├── twiddle_rom.sv          # Twiddle factor ROM
├── apb_interface.sv        # APB interface
├── axi_interface.sv        # AXI interface
└── fft_control.sv          # Control logic
```

### 12.3 Testbench Structure

```
tb/
├── tb_fft_top.sv           # Top-level testbench
├── fft_test_vectors.sv     # Test vector generation
├── fft_monitor.sv          # Response monitoring
├── fft_scoreboard.sv       # Result verification
└── rescale_test.sv         # Rescaling verification
```

## 13. Future Enhancements

### 13.1 Scalability

- **Variable Radix:** Support for radix-4 and radix-8 algorithms
- **Mixed Precision:** Support for different input/output precisions
- **Multi-Channel:** Support for multiple FFT channels
- **Adaptive Rescaling:** Dynamic rescaling based on signal characteristics

### 13.2 Performance Optimizations

- **Parallel Processing:** Multiple butterfly units
- **Memory Optimization:** Advanced memory access patterns
- **Pipeline Optimization:** Reduced latency implementations
- **Rescaling Optimization:** Optimized rescaling algorithms

### 13.3 Interface Enhancements

- **DMA Support:** Direct memory access for high-throughput applications
- **Streaming Interface:** Real-time streaming data support
- **Advanced Protocols:** Support for AXI-Stream and other protocols
- **Scale Factor Interface:** Dedicated interface for scale factor reporting

## 14. Conclusion

This design specification provides a comprehensive framework for implementing a high-performance FFT hardware accelerator with automatic rescaling and scale factor tracking following Vyges conventions. The design meets all specified requirements while providing flexibility for future enhancements and optimizations.

The double-buffered architecture ensures optimal throughput with background data transfer capabilities, while the memory-mapped interface provides easy integration with host processors. The 6-cycle butterfly operation meets the performance requirement while maintaining design simplicity and reliability. The automatic rescaling feature prevents overflow and maintains signal integrity, while the scale factor tracking enables proper signal reconstruction in the host application. 