# Fast Fourier Transform (FFT) Hardware Accelerator Design Specification

**IP Name:** fast-fourier-transform-ip  
**Version:** 1.0.0  
**Created:** 2025-07-21T05:38:04Z  
**Updated:** 2025-07-21T05:38:04Z  
**Author:** Vyges IP Development Team  
**License:** Apache-2.0  

## 1. Overview

This document specifies the design of a high-performance Fast Fourier Transform (FFT) hardware accelerator that supports configurable power-of-2 FFT lengths up to 1024 points. The design implements an in-place radix-2 decimation-in-frequency (DIF) FFT algorithm over a single working memory, followed by a bit-reverse pass so results are in natural order. The design includes optional per-stage rescaling to prevent overflow and provides output scale factor tracking for proper signal reconstruction.

### 1.1 Key Features

- **Configurable FFT Length:** 2 to 1024 points (power of 2); the working memory holds 1024 data words, so FFT_MAX_LENGTH_LOG2 values above 10 add no capacity
- **Data Precision:** 16-bit fixed-point input/output data
- **Twiddle Factors:** 16-bit complex coefficients
- **Single Working Memory:** Data computed in place; BUFFER_SEL / buffer swap drive a status bit and an interrupt only
- **Memory Mapped Interface:** APB interface for host processor access (the AXI port is tied off)
- **Performance:** One butterfly computation in 6 clock cycles
- **Sequential Datapath:** One memory access per cycle; butterflies are not overlapped
- **Natural-Order Output:** Bin k is word k
- **Automatic Rescaling:** Per-stage divide-by-2 (every stage, or only where needed) to prevent overflow
- **Scale Factor Tracking:** Output scale factor for proper signal reconstruction

### 1.2 Performance Targets

- **Throughput:** About 37.8k cycles per 1024-point run including stream-out (Section 8)
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
│  │  ┌──────────────────────────┐  ┌──────────────────────┐    │ │
│  │  │   Data (in place)        │  │  Twiddle table       │    │ │
│  │  │   1024 x 32-bit words    │  │  512 x 32-bit words  │    │ │
│  │  │   {imag, real}           │  │  firmware-loaded     │    │ │
│  │  └──────────────────────────┘  └──────────────────────┘    │ │
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
│  │  │   Stage     │  │   Scale     │  │   Overflow  │         │ │
│  │  │   Scaling   │  │  Factor     │  │  Detection  │         │ │
│  │  │             │  │  Count      │  │             │         │ │
│  │  └─────────────┘  └─────────────┘  └─────────────┘         │ │
│  └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 Memory Organization

The FFT accelerator uses one working memory (2048 x 32-bit, 1536 words used):

- **Data (words 0–1023):** Input samples, overwritten in place by the results; word i = {imag[31:16], real[15:0]} (Q1.15)
- **Twiddle table (words 1024–1535):** Loaded by firmware at boot; word k = {cos(2πk/N)[31:16], -sin(2πk/N)[15:0]}; N/2 words for the N being run
- **Memory Mapping:** Twiddle and (with `FFT_USE_APB_DATA`) sample write windows on APB; results leave through the configured memory backend or the stream-out port

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

The AXI port is present but tied off in the current RTL: ready outputs are held high, `axi_rvalid_o` is held low and read data is 0.

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
| `fft_done_o` | output | 1 | One-cycle pulse at the end of a run, gated by INT_ENABLE[0] |
| `fft_error_o` | output | 1 | One-cycle pulse on a rejected length, gated by INT_ENABLE[1] |

## 4. Memory Map

### 4.1 Register Map

| Address Offset | Register Name | Access | Description |
|----------------|---------------|--------|-------------|
| 0x0000 | FFT_CTRL | R/W | FFT Control Register |
| 0x0004 | FFT_STATUS | R | FFT Status Register |
| 0x0008 | FFT_CONFIG | R/W | FFT Configuration Register |
| 0x000C | FFT_LENGTH | R/W | FFT Length Register (stored, not used by the engine) |
| 0x0010 | BUFFER_SEL | R/W | Buffer Selection Register |
| 0x0014 | INT_ENABLE | R/W | Interrupt Enable Register |
| 0x0018 | INT_STATUS | RW1C | Interrupt Status Register (write 1 to clear) |
| 0x001C | SCALE_FACTOR | R | Output Scale Factor Register |
| 0x0020 | RESCALE_CTRL | R/W | Rescaling Control Register (stored, not used by the engine) |
| 0x0024 | OVERFLOW_STATUS | R | Overflow Status Register |

### 4.2 Data Memory Map

| Address Range | Memory | Description |
|---------------|--------|-------------|
| 0x0000-0x07FC | Registers | paddr[12:11] = 00 |
| 0x0800-0x0FFC | Twiddle window (write-only) | paddr[12:11] = 01; word k = paddr[10:2], 512 words |
| 0x1000-0x1FFC | Sample window (write-only, `FFT_USE_APB_DATA` only) | paddr[12] = 1; word i = paddr[11:2], 1024 words |

There are no other buffer windows; other addresses read 0 and ignore writes.

### 4.3 Register Bit Definitions

#### FFT_CTRL Register (0x0000)
| Bits | Name | Access | Description |
|------|------|--------|-------------|
| [0] | FFT_START | R/W | Start FFT computation |
| [1] | FFT_RESET | R/W | Reset FFT engine |
| [2] | BUFFER_SWAP | R/W | Toggle the buffer_active status bit (raises the buffer-swap interrupt on its rising edge) |
| [3] | RESERVED | R/W | Not used |
| [4] | RESCALE_EN | R/W | Enable rescaling (also requires FFT_CONFIG[19]) |
| [5] | SCALE_TRACK_EN | R/W | Enable scale factor tracking |
| [7:6] | RESERVED | R/W | Not used |
| [8] | STREAM_ENABLE | R/W | Arm the bin streamer (`FFT_USE_STREAM_OUT` builds only) |
| [31:9] | RESERVED | R/W | Not used |

A run launches when FFT_START is high while the engine is idle; if it stays high, the next run starts as soon as one finishes, so the recommended start is a pulse (write 1, then 0). FFT_CTRL[5:4] and FFT_CONFIG are latched at launch; writes during a run apply to the next run. FFT_RESET aborts a run: the engine is idle on the next cycle and issues no further write.

#### FFT_STATUS Register (0x0004)
| Bits | Name | Access | Description |
|------|------|--------|-------------|
| [0] | FFT_BUSY | R | FFT computation in progress |
| [1] | FFT_DONE | R | Run complete; held from the end of a run until the next run starts |
| [2] | FFT_ERROR | R | Length rejected at launch; held until the next run starts |
| [3] | BUFFER_ACTIVE | R | Active buffer indicator |
| [4] | RESCALE_ACTIVE | R | High while a scaled stage is being computed |
| [5] | OVERFLOW_DETECTED | R | Set once any butterfly in the run overflowed |
| [13:6] | SCALE_FACTOR | R | Number of scaled stages |
| [21:14] | STAGE_COUNT | R | Stages completed in the run |
| [29:22] | OVERFLOW_COUNT | R | Overflowing butterflies (saturates at 255) |
| [31:30] | RESERVED | R | Reserved bits |

#### FFT_CONFIG Register (0x0008)
| Bits | Name | Access | Description |
|------|------|--------|-------------|
| [11:0] | FFT_LENGTH_LOG2 | R/W | Log2 of FFT length, 1 to min(FFT_MAX_LENGTH_LOG2, 10); 0 or a larger value is rejected at launch (FFT_ERROR) |
| [15:12] | RESERVED | R | Reserved bits |
| [16] | RESCALE_MODE | R/W | 0 = block floating point (a stage is scaled only when an input lies outside [-2^13, 2^13)), 1 = every stage scaled (X/N) |
| [17] | ROUNDING_MODE | R/W | 0 = truncate, 1 = add half an LSB before each shift |
| [18] | SATURATION_EN | R/W | 1 = clamp to [-32768, 32767], 0 = wrap (low 16 bits kept) |
| [19] | OVERFLOW_DETECT | R/W | Enable overflow detection |
| [31:20] | RESERVED | R | Reserved bits |

#### INT_ENABLE Register (0x0014) / INT_STATUS Register (0x0018)
| Bits | Name | Access (INT_STATUS) | Description |
|------|------|--------|-------------|
| [0] | DONE | RW1C | End of a run |
| [1] | ERROR | RW1C | Length rejected at launch |
| [2] | BUFFER_SWAP | RW1C | FFT_CTRL[2] rising |
| [3] | OVERFLOW | RW1C | First overflow of a run |
| [4] | RESCALE | RW1C | A scaled stage starts |
| [7:5] | RESERVED | R | Reserved bits |

An INT_STATUS bit is set on the rising edge of its event while the matching INT_ENABLE bit is set, and stays set until software writes 1 to that bit.

#### SCALE_FACTOR Register (0x001C)
| Bits | Name | Access | Description |
|------|------|--------|-------------|
| [7:0] | SCALE_FACTOR | R | Number of scaled stages (counted when SCALE_TRACK_EN); never exceeds log2(N). Output = true FFT / 2^SCALE_FACTOR |
| [15:8] | STAGE_COUNT | R | Number of stages processed |
| [23:16] | RESERVED | R | Reserved bits |
| [31:24] | OVERFLOW_COUNT | R | Number of overflowing butterflies (saturates at 255) |

#### RESCALE_CTRL Register (0x0020)

This register is stored and reads back, but the current RTL does not use its fields; rescaling is controlled by FFT_CTRL[5:4] and FFT_CONFIG[19:16].

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
| [23:16] | MAX_OVERFLOW_MAGNITUDE | R | Not measured; reads 0 |
| [31:24] | RESERVED | R | Reserved bits |

## 5. FFT Algorithm Implementation

### 5.1 Radix-2 DIF Algorithm with Rescaling

The FFT accelerator implements an in-place radix-2 decimation-in-frequency (DIF) algorithm: log2(N) stages of N/2 butterflies. In stage s the butterfly span is N >> (s+1); each butterfly combines words A and A + span using twiddle W_N^k with k = (butterfly index mod span) << s. After the last stage a bit-reverse pass swaps word i with word bitrev(i), so bin k ends up in word k (natural order).

With rescaling enabled, the result is:
```
X_out(k) = X(k) / 2^scale_factor
```

Where:
- `W_N^k` is the twiddle factor: `W_N^k = e^(-j2πk/N)`
- `scale_factor` is the number of scaled stages

### 5.2 Butterfly Operation with Rescaling

Each butterfly operation performs:

```
A' = (A + B) >> sh
B' = ((A - B) * W_N^k) >> (15 + sh)
```

sh = 1 on a scaled stage, else 0. ROUNDING_MODE adds half an LSB before each shift; SATURATION_EN clamps to [-32768, 32767], otherwise the value wraps.

**Timing:** 6 clock cycles per butterfly operation, not overlapped with the next butterfly

### 5.3 Butterfly Sequence

The working memory has one port and the engine makes one access per cycle; read data arrives two cycles after the address is issued.

1. **Cycle 0:** Read A
2. **Cycle 1:** Read B
3. **Cycle 2:** Read twiddle W (A data returns)
4. **Cycle 3:** Wait (B data returns)
5. **Cycle 4:** Compute A' and B' (W data returns); write A'
6. **Cycle 5:** Write B'

### 5.4 Rescaling Implementation

#### Rescaling Logic

Rescaling is implemented in the engine (`rtl/fft_fft_engine.sv`) and is active only when FFT_CTRL[4] RESCALE_EN and FFT_CONFIG[19] OVERFLOW_DETECT are both set. The decision is per stage, made before the stage starts:

- **RESCALE_MODE = 1:** every stage is scaled; the result is X/N and the scale factor is log2(N).
- **RESCALE_MODE = 0 (block floating point):** before stage 0 the engine reads the input once (N+2 cycles); a stage is scaled only if one of its input components lies outside [-2^13, 2^13), the range that cannot grow past 16 bits in one stage.

A butterfly whose result does not fit 16 bits is counted in OVERFLOW_COUNT (when OVERFLOW_DETECT is set) regardless of rescaling.

#### Scale Factor Tracking

When SCALE_TRACK_EN is set, the engine counts the scaled stages of a run. The count is cleared at launch and never exceeds log2(N).

## 6. Memory Architecture

### 6.1 Working Memory

```
┌──────────────────────────────────────────┐
│  Working memory, 2048 x 32-bit           │
│  [   0 – 1023]  data (in place)          │
│  [1024 – 1535]  twiddle table            │
│  [1536 – 2047]  unused                   │
└──────────────────────────────────────────┘
```

### 6.2 Buffer Switching Logic

There is one data region; the input is overwritten by the results. BUFFER_SEL and FFT_CTRL[2] BUFFER_SWAP only set or toggle the FFT_STATUS BUFFER_ACTIVE bit and raise the buffer-swap interrupt. Firmware must not write samples while a run is in progress: the APB write takes priority on the single write port and the engine's write for that cycle is lost.

### 6.3 Memory Requirements

| FFT Length | Data Words Used | Twiddle Words Used | Total Used |
|------------|-------------------|-------------------|--------------|
| 256 | 256 (1 KB) | 128 (0.5 KB) | 1.5 KB |
| 512 | 512 (2 KB) | 256 (1 KB) | 3 KB |
| 1024 | 1024 (4 KB) | 512 (2 KB) | 6 KB |

The memory is sized for 1024 points (8 KB array, 6 KB used) whatever the length being run.

## 7. Twiddle Factor Generation

### 7.1 Table Organization

There is no twiddle ROM (`fft_twiddle_rom.sv` is not instantiated). Firmware loads the twiddle table through the APB twiddle window (0x0800–0x0FFC) before the first run:

```
W_N^k = cos(2πk/N) - j*sin(2πk/N)
word k = {cos(2πk/N)[31:16], -sin(2πk/N)[15:0]}   (Q1.15)
```

### 7.2 Table Size Requirements

| FFT Length | Table Entries | Table Size |
|------------|-------------|----------|
| 256 | 128 | 0.5 KB |
| 512 | 256 | 1 KB |
| 1024 | 512 | 2 KB |

### 7.3 Twiddle Factor Access

- **Address Generation:** Based on current FFT stage and butterfly index
- **Symmetry Exploitation:** None; all N/2 words are stored
- **Precision:** 16-bit fixed-point representation

## 8. Performance Analysis

### 8.1 Throughput Calculation

For a 1024-point FFT:
- **Butterfly Operations:** (1024/2) × log2(1024) = 5,120 butterflies
- **Butterfly Cycles:** 5,120 × 6 = 30,720 cycles
- **Bit-Reverse Pass:** about 3N = 3,072 cycles
- **Input Scan (rescale mode 0 only):** N + 2 = 1,026 cycles
- **Measured, start to last streamed bin:** about 36.8k–37.8k cycles

### 8.2 Latency Analysis

Cycle counts measured from the start pulse to the last streamed bin (stream-out included):

| FFT Length | Butterfly Count | Total Cycles (measured) |
|------------|----------------|--------------|
| 256 | 1,024 | ~7.6k–7.9k |
| 512 | 2,304 | ~17.3k |
| 1024 | 5,120 | ~36.8k–37.8k |

### 8.3 Resource Utilization

| Resource | Count | Description |
|----------|-------|-------------|
| DSP Blocks | 4 | Complex multiplier (2) + Complex adder (2) |
| BRAM | 8 | Working memory (data + twiddle table) |
| Registers | ~5K | Pipeline registers and control logic |
| LUTs | ~15K | Address generation and control logic |
| Scale Factor Logic | ~1K | Rescaling and scale factor tracking |

## 9. Power Management

Note: the current RTL has no power domains, power states or clock gating; this section lists implementation-level options.

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

- **Invalid FFT Length:** FFT_CONFIG[11:0] equal to 0 or above min(FFT_MAX_LENGTH_LOG2, 10) is rejected at launch. The engine enters ERROR for one cycle and no computation runs. (The length field is log2(N), so every legal value is a power of 2.)

This is the only error condition in the current RTL. Memory-range, timeout, ECC/parity and rescaling-overflow errors are not implemented; arithmetic overflow is reported through the status counters, not as an error.

### 10.2 Error Reporting

- **Status Register:** FFT_STATUS[2] FFT_ERROR, held until the next run starts
- **Interrupt Generation:** INT_STATUS[1] (RW1C) and the `fft_error_o` pulse, when INT_ENABLE[1] is set
- **Error Logging:** No error-code register
- **Overflow Tracking:** Overflow events logged in OVERFLOW_STATUS

## 11. Verification Strategy

### 11.1 Test Vectors

- **Unit Tests:** Individual butterfly operation verification
- **Integration Tests:** Complete FFT computation verification
- **Performance Tests:** Throughput and latency measurement
- **Corner Cases:** Edge cases and error conditions
- **Rescaling Tests:** Overflow and rescaling verification
- **Golden Model:** `tb/golden/run_golden.py` (`make test-golden`) compares every output bin word for word with a fixed-point reference model, plus the scale factor and overflow count, over 8 configurations (8 to 1024 points; plain, rounding, saturation, wrap, both rescale modes), and checks that FFT_STATUS done holds and INT_STATUS[0] holds until written with 1. `make test-golden-netlist` runs the same cases on the synthesized netlist.

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
├── fft_fft_top.sv              # Top-level module (fft_top)
├── fft_fft_engine.sv           # FFT engine: addressing, butterfly, rescaling,
│                               #   scale factor, overflow counters, bit-reverse pass
├── fft_memory_interface.sv     # APB registers and windows, working memory, AXI tie-off
├── fft_fft_control.sv          # Control, buffer status, interrupt pending bits
├── fft_bin_streamer.sv         # FFT_USE_STREAM_OUT post-completion walker
├── fft_bus_master.sv           # FFT_USE_BUS_MASTER memory master (design draft)
├── fft_ctrl_tlul.sv            # TL-UL wrapper
├── fft_rescale_unit.sv         # Not instantiated
├── fft_scale_factor_tracker.sv # Not instantiated
└── fft_twiddle_rom.sv          # Not instantiated (twiddles are firmware-loaded)
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

The single in-place working memory keeps the design compact, while the memory-mapped interface provides easy integration with host processors. The sequential 6-cycle butterfly matches the one-access-per-cycle memory contract while maintaining design simplicity and reliability. The automatic rescaling feature prevents overflow and maintains signal integrity, while the scale factor tracking enables proper signal reconstruction in the host application. 