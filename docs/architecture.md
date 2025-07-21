# FFT Hardware Accelerator Architecture

**IP Name:** fast-fourier-transform-ip  
**Version:** 1.0.0  
**Created:** 2025-07-21T05:38:04Z  
**Updated:** 2025-07-21T05:38:04Z  
**Author:** Vyges IP Development Team  

## 1. Architecture Overview

The FFT hardware accelerator implements a pipelined radix-2 decimation-in-frequency (DIF) algorithm optimized for high throughput and low latency. The architecture is designed around a 6-stage pipeline that processes one butterfly operation per cycle, meeting the performance requirement of 6 cycles per butterfly.

### 1.1 Core Architecture Components

```
┌─────────────────────────────────────────────────────────────────┐
│                        FFT Accelerator                          │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │   Control   │  │   Address   │  │   Status    │             │
│  │   Unit      │  │  Generator  │  │  Monitor    │             │
│  └─────────────┘  └─────────────┘  └─────────────┘             │
│         │                │                │                     │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                    Memory Subsystem                         │ │
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
│         │                │                │                     │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                    6-Stage Pipeline                         │ │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐       │ │
│  │  │ Stage 1 │  │ Stage 2 │  │ Stage 3 │  │ Stage 4 │       │ │
│  │  │ Address │  │  Data   │  │ Complex │  │ Complex │       │ │
│  │  │  Gen &  │  │ Align & │  │  Add    │  │ Subtract│       │ │
│  │  │  Read   │  │ Twiddle │  │         │  │         │       │ │
│  │  └─────────┘  └─────────┘  └─────────┘  └─────────┘       │ │
│  │  ┌─────────┐  ┌─────────┐                                  │ │
│  │  │ Stage 5 │  │ Stage 6 │                                  │ │
│  │  │ Complex │  │ Memory  │                                  │ │
│  │  │Multiply │  │ Write   │                                  │ │
│  │  └─────────┘  └─────────┘                                  │ │
│  └─────────────────────────────────────────────────────────────┘ │
│         │                │                │                     │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │     APB     │  │     AXI     │  │ Interrupt   │             │
│  │ Interface   │  │ Interface   │  │ Controller  │             │
│  └─────────────┘  └─────────────┘  └─────────────┘             │
└─────────────────────────────────────────────────────────────────┘
```

## 2. Pipeline Architecture

### 2.1 6-Stage Pipeline Details

The FFT accelerator implements a 6-stage pipeline optimized for the butterfly operation:

#### Stage 1: Address Generation and Memory Read
- **Function:** Generate addresses for input data and twiddle factors
- **Operations:**
  - Calculate butterfly pair addresses
  - Generate twiddle factor ROM address
  - Read input data from active buffer
- **Latency:** 1 clock cycle
- **Resources:** Address generation logic, memory interface

#### Stage 2: Data Alignment and Twiddle Factor Fetch
- **Function:** Align data and fetch twiddle factors
- **Operations:**
  - Align complex data pairs
  - Read twiddle factor from ROM
  - Prepare data for arithmetic operations
- **Latency:** 1 clock cycle
- **Resources:** Data alignment logic, twiddle factor ROM

#### Stage 3: Complex Addition
- **Function:** Perform complex addition (A + B)
- **Operations:**
  - Add real components: A_real + B_real
  - Add imaginary components: A_imag + B_imag
  - Handle overflow/underflow
- **Latency:** 1 clock cycle
- **Resources:** Complex adder (2x 16-bit adders)

#### Stage 4: Complex Subtraction
- **Function:** Perform complex subtraction (A - B)
- **Operations:**
  - Subtract real components: A_real - B_real
  - Subtract imaginary components: A_imag - B_imag
  - Handle overflow/underflow
- **Latency:** 1 clock cycle
- **Resources:** Complex subtractor (2x 16-bit subtractors)

#### Stage 5: Complex Multiplication
- **Function:** Multiply subtraction result by twiddle factor
- **Operations:**
  - Complex multiplication: (A-B) × W_N^k
  - Real component: (A_real-B_real)×W_real - (A_imag-B_imag)×W_imag
  - Imaginary component: (A_real-B_real)×W_imag + (A_imag-B_imag)×W_real
- **Latency:** 1 clock cycle
- **Resources:** Complex multiplier (4x 16-bit multipliers + 2x adders)

#### Stage 6: Memory Write
- **Function:** Write results back to memory
- **Operations:**
  - Write A' (addition result) to output buffer
  - Write B' (multiplication result) to output buffer
  - Update address counters
- **Latency:** 1 clock cycle
- **Resources:** Memory interface, address counters

### 2.2 Pipeline Control

```
┌─────────────────────────────────────────────────────────────┐
│                    Pipeline Controller                       │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │   Stage     │  │   Stage     │  │   Stage     │         │
│  │  Enable 1   │  │  Enable 2   │  │  Enable 3   │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │   Stage     │  │   Stage     │  │   Stage     │         │
│  │  Enable 4   │  │  Enable 5   │  │  Enable 6   │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │  Pipeline   │  │   Stall     │  │   Flush     │         │
│  │   Valid     │  │  Control    │  │  Control    │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
└─────────────────────────────────────────────────────────────┘
```

## 3. Memory Architecture

### 3.1 Double-Buffered Memory Organization

The FFT accelerator implements a sophisticated double-buffered memory architecture:

```
┌─────────────────────────────────────────────────────────────┐
│                    Memory Subsystem                         │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐    ┌─────────────────┐                │
│  │   Input Memory  │    │  Output Memory  │                │
│  │                 │    │                 │                │
│  │  ┌─────────────┐│    │┌─────────────┐  │                │
│  │  │   Buffer A  ││    ││  Buffer A   │  │                │
│  │  │  (Active)   ││    ││ (Processing)│  │                │
│  │  └─────────────┘│    │└─────────────┘  │                │
│  │                 │    │                 │                │
│  │  ┌─────────────┐│    │┌─────────────┐  │                │
│  │  │   Buffer B  ││    ││  Buffer B   │  │                │
│  │  │(Background) ││    ││ (Available) │  │                │
│  │  └─────────────┘│    │└─────────────┘  │                │
│  └─────────────────┘    └─────────────────┘                │
│           │                       │                        │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              Buffer Controller                          │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │ │
│  │  │   Active    │  │   Buffer    │  │   Memory    │     │ │
│  │  │  Buffer     │  │   Switch    │  │   Access    │     │ │
│  │  │  Selector   │  │   Logic     │  │  Controller │     │ │
│  │  └─────────────┘  └─────────────┘  └─────────────┘     │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### 3.2 Memory Access Patterns

#### Input Data Access Pattern
For an N-point FFT with log2(N) stages:

```
Stage 0: 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,...
Stage 1: 0,2,4,6,8,10,12,14,1,3,5,7,9,11,13,15,...
Stage 2: 0,4,8,12,1,5,9,13,2,6,10,14,3,7,11,15,...
Stage 3: 0,8,1,9,2,10,3,11,4,12,5,13,6,14,7,15,...
```

#### Address Generation Logic
```verilog
// Butterfly pair address calculation
addr_a = stage_counter * butterfly_spacing + butterfly_index;
addr_b = addr_a + butterfly_spacing;

// Twiddle factor address calculation
twiddle_addr = (stage_counter * butterfly_index) % (N/2);
```

### 3.3 Memory Interface Timing

```
Clock Cycle:    1    2    3    4    5    6
                │    │    │    │    │    │
Address Gen:    ┌────┐
                │    │
Memory Read:         ┌────┐
                     │    │
Data Align:              ┌────┐
                         │    │
Complex Add:                   ┌────┐
                               │    │
Complex Sub:                        ┌────┐
                                   │    │
Complex Mul:                             ┌────┐
                                        │    │
Memory Write:                                  ┌────┐
                                              │    │
```

## 4. Twiddle Factor Generation

### 4.1 ROM Organization

The twiddle factor ROM stores pre-computed complex coefficients:

```
W_N^k = cos(2πk/N) - j*sin(2πk/N)
```

#### ROM Structure
```
┌─────────────────────────────────────────────────────────────┐
│                    Twiddle Factor ROM                       │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │   Address   │  │    Real     │  │  Imaginary  │         │
│  │   Decoder   │  │  Component  │  │ Component   │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
│           │                │                │               │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              ROM Memory Array                           │ │
│  │  ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐     │ │
│  │  │ W_0 │ │ W_1 │ │ W_2 │ │ W_3 │ │ W_4 │ │ ... │     │ │
│  │  └─────┘ └─────┘ └─────┘ └─────┘ └─────┘ └─────┘     │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### 4.2 Symmetry Exploitation

The ROM size is optimized by exploiting trigonometric symmetries:

```
W_N^(N/2+k) = -W_N^k
W_N^(N-k) = W_N^k*
W_N^(N/4+k) = j*W_N^k
```

This reduces ROM size by approximately 75% for large FFT lengths.

### 4.3 Twiddle Factor Precision

- **Format:** 16-bit fixed-point (Q1.15 format)
- **Range:** -1.0 to +1.0
- **Precision:** 2^-15 ≈ 3.05e-5
- **Storage:** 32 bits per twiddle factor (16-bit real + 16-bit imaginary)

## 5. Control Unit Architecture

### 5.1 State Machine

```
┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐
│  IDLE   │───▶│ CONFIG  │───▶│  LOAD   │───▶│ COMPUTE │
│         │    │         │    │         │    │         │
└─────────┘    └─────────┘    └─────────┘    └─────────┘
     ▲              │              │              │
     │              │              │              │
     │              ▼              ▼              ▼
┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐
│  ERROR  │◀───│  DONE   │◀───│  SWAP   │◀───│  DONE   │
│         │    │         │    │         │    │         │
└─────────┘    └─────────┘    └─────────┘    └─────────┘
```

#### State Descriptions

- **IDLE:** Waiting for start command
- **CONFIG:** Loading FFT configuration parameters
- **LOAD:** Loading input data into active buffer
- **COMPUTE:** Executing FFT computation
- **SWAP:** Switching between buffer banks
- **DONE:** FFT computation complete
- **ERROR:** Error condition detected

### 5.2 Control Signals

| Signal | Direction | Description |
|--------|-----------|-------------|
| `fft_start_i` | input | Start FFT computation |
| `fft_reset_i` | input | Reset FFT engine |
| `fft_busy_o` | output | FFT computation in progress |
| `fft_done_o` | output | FFT computation complete |
| `fft_error_o` | output | FFT computation error |
| `stage_valid_o` | output | Pipeline stage valid |
| `buffer_swap_o` | output | Buffer swap request |

## 6. Interface Controllers

### 6.1 APB Interface Controller

The APB interface provides register access and data transfer:

```verilog
// APB Slave Interface
module apb_fft_interface (
    input  logic        pclk_i,
    input  logic        preset_n_i,
    input  logic        psel_i,
    input  logic        penable_i,
    input  logic        pwrite_i,
    input  logic [15:0] paddr_i,
    input  logic [31:0] pwdata_i,
    output logic [31:0] prdata_o,
    output logic        pready_o
);
```

#### APB Register Access Timing

```
PCLK:     ┌───┐ ┌───┐ ┌───┐ ┌───┐ ┌───┐ ┌───┐
          │   │ │   │ │   │ │   │ │   │ │   │
PSEL:     ────┐
              │
PENABLE:      ────┐
                  │
PWRITE:      ────┐
                  │
PADDR:      ────┐
                 │
PWDATA:     ────┐
                 │
PRDATA:         ────┐
                    │
PREADY:         ────┐
                    │
```

### 6.2 AXI Interface Controller

The AXI interface provides high-bandwidth data transfer:

```verilog
// AXI Slave Interface
module axi_fft_interface (
    input  logic        axi_aclk_i,
    input  logic        axi_areset_n_i,
    input  logic [31:0] axi_awaddr_i,
    input  logic        axi_awvalid_i,
    output logic        axi_awready_o,
    input  logic [63:0] axi_wdata_i,
    input  logic        axi_wvalid_i,
    output logic        axi_wready_o,
    input  logic [31:0] axi_araddr_i,
    input  logic        axi_arvalid_i,
    output logic        axi_arready_o,
    output logic [63:0] axi_rdata_o,
    output logic        axi_rvalid_o,
    input  logic        axi_rready_i
);
```

## 7. Performance Optimization

### 7.1 Pipeline Optimization

- **Balanced Stages:** Each pipeline stage has similar latency
- **Register Balancing:** Minimizes clock-to-clock delay
- **Clock Gating:** Reduces power consumption during idle periods
- **Bypass Logic:** Handles data hazards efficiently

### 7.2 Memory Optimization

- **Burst Transfers:** Optimizes memory bandwidth utilization
- **Prefetching:** Reduces memory access latency
- **Bank Interleaving:** Improves memory access parallelism
- **Cache-Friendly:** Optimizes for spatial and temporal locality

### 7.3 Arithmetic Optimization

- **Carry-Save Addition:** Reduces critical path delay
- **Booth Encoding:** Optimizes multiplication performance
- **Saturation Arithmetic:** Prevents overflow/underflow
- **Rounding Control:** Configurable rounding modes

## 8. Power Management

### 8.1 Clock Domain Management

```
┌─────────────────────────────────────────────────────────────┐
│                    Clock Domains                            │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │   System    │  │   Pipeline  │  │  Interface  │         │
│  │   Clock     │  │   Clock     │  │   Clock     │         │
│  │  (1000MHz)  │  │  (1000MHz)  │  │  (1000MHz)  │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
│           │                │                │               │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              Clock Gating Logic                         │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │ │
│  │  │   Memory    │  │  Pipeline   │  │  Interface  │     │ │
│  │  │   Clock     │  │   Clock     │  │   Clock     │     │ │
│  │  │   Gate      │  │   Gate      │  │   Gate      │     │ │
│  │  └─────────────┘  └─────────────┘  └─────────────┘     │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### 8.2 Power States

| State | Description | Clock Gating | Power Consumption |
|-------|-------------|--------------|-------------------|
| Active | FFT computation | Disabled | 100% |
| Idle | Waiting for start | Memory + Interface | 10% |
| Sleep | Power-down mode | All domains | 1% |

### 8.3 Dynamic Power Reduction

- **Clock Gating:** Gates unused pipeline stages
- **Memory Gating:** Gates unused memory banks
- **Interface Gating:** Gates unused interface logic
- **Voltage Scaling:** Dynamic voltage/frequency scaling

## 9. Error Handling and Debug

### 9.1 Error Detection

- **Parity Checking:** Memory data integrity
- **Timeout Detection:** FFT computation timeout
- **Range Checking:** Address and data range validation
- **State Validation:** State machine consistency checking

### 9.2 Debug Features

- **Performance Counters:** Cycle count, throughput measurement
- **Pipeline Monitors:** Stage utilization monitoring
- **Memory Monitors:** Access pattern analysis
- **Error Logging:** Detailed error information storage

### 9.3 Test and Debug Interface

```verilog
// Debug Interface
module fft_debug_interface (
    input  logic        debug_clk_i,
    input  logic        debug_enable_i,
    input  logic [7:0]  debug_addr_i,
    output logic [31:0] debug_data_o,
    input  logic [31:0] debug_data_i,
    input  logic        debug_write_i
);
```

## 10. Implementation Considerations

### 10.1 Synthesis Guidelines

- **Clock Constraints:** Define clock domains and relationships
- **Timing Constraints:** Set up timing requirements for all paths
- **Area Constraints:** Define area budgets for different modules
- **Power Constraints:** Set up power optimization directives

### 10.2 Physical Design Considerations

- **Floorplanning:** Optimize module placement for timing
- **Clock Distribution:** Design clock tree for minimal skew
- **Power Distribution:** Design power grid for voltage drop
- **Signal Integrity:** Consider crosstalk and noise effects

### 10.3 Verification Strategy

- **Unit Testing:** Test individual modules in isolation
- **Integration Testing:** Test module interactions
- **System Testing:** Test complete FFT functionality
- **Performance Testing:** Verify timing and throughput requirements

This architecture document provides the technical foundation for implementing the FFT hardware accelerator according to the design specification. The modular design allows for easy customization and optimization for different target applications and performance requirements.
