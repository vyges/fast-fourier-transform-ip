# FFT Hardware Accelerator Architecture

**IP Name:** fast-fourier-transform-ip  
**Version:** 1.0.0  
**Created:** 2025-07-21T05:38:04Z  
**Updated:** 2025-07-21T05:38:04Z  
**Author:** Vyges IP Development Team  

## 1. Architecture Overview

The FFT hardware accelerator implements an in-place radix-2 decimation-in-frequency (DIF) algorithm over a single shared working memory: log2(N) stages of N/2 butterflies, for N up to 1024 points. The memory has one port and the engine makes one access per cycle, so each butterfly takes 6 cycles in sequence (read A, read B, read W, wait for data, write A', write B'). The butterflies are not overlapped; this is a sequential datapath, not a 6-stage pipeline. After the last stage a bit-reverse pass puts the results in natural order. Optional per-stage rescaling (divide by 2) prevents overflow and maintains signal integrity.

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
│  │  ┌──────────────────────────┐  ┌──────────────────────┐    │ │
│  │  │   Data (in place)        │  │  Twiddle table       │    │ │
│  │  │   1024 x 32-bit words    │  │  512 x 32-bit words  │    │ │
│  │  │   {imag, real}           │  │  firmware-loaded     │    │ │
│  │  └──────────────────────────┘  └──────────────────────┘    │ │
│  │        one port, one access per cycle                       │ │
│  └─────────────────────────────────────────────────────────────┘ │
│         │                │                │                     │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │            6-Cycle Butterfly Sequence (not overlapped)      │ │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐       │ │
│  │  │ Cycle 0 │  │ Cycle 1 │  │ Cycle 2 │  │ Cycle 3 │       │ │
│  │  │ Read A  │  │ Read B  │  │ Read W  │  │  Wait   │       │ │
│  │  │ address │  │ address │  │ (A data)│  │ (B data)│       │ │
│  │  └─────────┘  └─────────┘  └─────────┘  └─────────┘       │ │
│  │  ┌─────────┐  ┌─────────┐                                  │ │
│  │  │ Cycle 4 │  │ Cycle 5 │                                  │ │
│  │  │ Write A'│  │ Write B'│                                  │ │
│  │  │         │  │         │                                  │ │
│  │  └─────────┘  └─────────┘                                  │ │
│  └─────────────────────────────────────────────────────────────┘ │
│         │                │                │                     │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                  Rescaling Subsystem                        │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │ │
│  │  │   Stage     │  │   Scale     │  │   Overflow  │         │ │
│  │  │   Scaling   │  │  Factor     │  │  Detection  │         │ │
│  │  │  (engine)   │  │  (engine)   │  │  (engine)   │         │ │
│  │  └─────────────┘  └─────────────┘  └─────────────┘         │ │
│  └─────────────────────────────────────────────────────────────┘ │
│         │                │                │                     │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │     APB     │  │     AXI     │  │ Interrupt   │             │
│  │ Interface   │  │ Interface   │  │ Controller  │             │
│  └─────────────┘  └─────────────┘  └─────────────┘             │
└─────────────────────────────────────────────────────────────────┘
```

## 2. Butterfly Datapath

### 2.1 Butterfly Sequence Details

Each butterfly occupies the single memory port for 6 cycles. The engine registers its address, so read data for an address issued on cycle t arrives on cycle t+2. The next butterfly starts only after the previous one has written B'.

#### Cycle 0: Read A
- **Function:** Issue the address of operand A
- **Operations:**
  - In stage s of an N-point FFT the butterfly span is N >> (s+1); A is the butterfly index with a 0 inserted at bit log2(span), B is A + span
- **Latency:** 1 clock cycle

#### Cycle 1: Read B
- **Function:** Issue the address of operand B
- **Latency:** 1 clock cycle

#### Cycle 2: Read W
- **Function:** Capture A; issue the twiddle address
- **Operations:**
  - Twiddle index k = (butterfly index mod span) << s, read from the twiddle table (engine address 0x1000 + k)
- **Latency:** 1 clock cycle

#### Cycle 3: Wait
- **Function:** Capture B while the twiddle word is returned
- **Latency:** 1 clock cycle

#### Cycle 4: Write A'
- **Function:** Compute both results and write A'
- **Operations:**
  - A' = (A + B) >> sh
  - B' = ((A - B) × W) >> (15 + sh), where (A-B) × W is a full complex product:
    real = (A_real-B_real)×W_real - (A_imag-B_imag)×W_imag,
    imag = (A_real-B_real)×W_imag + (A_imag-B_imag)×W_real
  - sh = 1 on a scaled stage, else 0
  - rounding_mode adds half an LSB before each shift; saturation_en clamps to [-32768, 32767], otherwise the low 16 bits are kept (wrap)
  - A butterfly with any component that did not fit 16 bits counts as an overflow (when overflow_detect is set)
- **Latency:** 1 clock cycle

#### Cycle 5: Write B'
- **Function:** Write B'; advance the butterfly / stage counters
- **Latency:** 1 clock cycle

### 2.2 Sequencer Control with Rescaling

```
┌─────────────────────────────────────────────────────────────┐
│                    Engine Sequencer                          │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │   Stage     │  │  Butterfly  │  │   Phase     │         │
│  │  Counter    │  │  Counter    │  │  (0..5)     │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │   Index     │  │   Stage     │  │  Overflow   │         │
│  │  Counter    │  │  Scaled     │  │  Counters   │         │
│  │ (scan/swap) │  │   Flag      │  │             │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
└─────────────────────────────────────────────────────────────┘
```

## 3. Rescaling Subsystem

### 3.1 Rescaling Architecture

The rescaling logic is part of the engine (`rtl/fft_fft_engine.sv`); the separate `fft_rescale_unit.sv` and `fft_scale_factor_tracker.sv` files in `rtl/` are not instantiated. Rescaling is active only when FFT_CTRL[4] rescale_en and FFT_CONFIG[19] overflow_detect are both set. A scaled stage halves every butterfly result of that stage:

```
┌─────────────────────────────────────────────────────────────┐
│                  Rescaling Subsystem                         │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │   Overflow  │  │   Rescale   │  │   Scale     │         │
│  │  Detection  │  │   Logic     │  │  Factor     │         │
│  │             │  │             │  │  Tracker    │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
│           │                │                │               │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              Rescaling Control Logic                    │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │ │
│  │  │   Rescale   │  │   Rounding  │  │  Saturation │     │ │
│  │  │   Mode      │  │   Control   │  │   Logic     │     │ │
│  │  └─────────────┘  └─────────────┘  └─────────────┘     │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### 3.2 Overflow Detection Logic

A butterfly overflows when any of the four result components (A' and B', real and imaginary), after the stage's shift, lies outside the signed 16-bit range [-32768, 32767]. When overflow_detect is set, each such butterfly increments `overflow_count` (saturating at 255), records its stage in `last_overflow_stage`, and sets `overflow_detected` for the rest of the run. `max_overflow_magnitude` is not measured and reads 0.

### 3.3 Rescaling Logic

Whether a stage is scaled is decided before the stage starts, not per butterfly:

```
sh = 1 on a scaled stage, else 0
A' = (A + B) >> sh
B' = ((A - B) * W) >> (15 + sh)
```

### 3.4 Scale Factor Tracking

When FFT_CTRL[5] scale_track_en is set, the engine counts the scaled stages of the run. The count is cleared at launch and reported in FFT_STATUS[13:6] and SCALE_FACTOR[7:0]; it never exceeds log2(N). The output equals the true FFT divided by 2^scale_factor. `stage_count` reports the number of stages completed in the run.

### 3.5 Rescaling Modes

The FFT accelerator supports two rescaling modes:

#### Mode 0: Block floating point (Default)
- Before stage 0 the engine reads the input once (N+2 cycles) to check its range
- A stage is scaled only if one of its input components lies outside [-2^13, 2^13), the range that cannot grow past 16 bits in one stage
- Scales only where needed, keeping more precision for small inputs

#### Mode 1: Divide by N
- Every stage is scaled by 2, so the result is X/N and the scale factor is log2(N)
- Provides uniform scaling across all stages

## 4. Memory Architecture

### 4.1 Working Memory Organization

The FFT accelerator uses one working memory that holds both the data (computed in place) and the twiddle table. BUFFER_SEL and FFT_CTRL[2] buffer_swap only drive the FFT_STATUS buffer_active bit and the buffer-swap interrupt; there is no second data buffer.

```
┌─────────────────────────────────────────────────────────────┐
│                    Working Memory (2048 x 32)               │
├─────────────────────────────────────────────────────────────┤
│  [   0 – 1023]  data, word i = {imag[31:16], real[15:0]}    │
│                 engine address 0x0000 + i                    │
│                 APB sample window 0x1000 – 0x1FFC            │
│                 (FFT_USE_APB_DATA)                           │
│  [1024 – 1535]  twiddle, word k = {cos[31:16], -sin[15:0]}  │
│                 engine address 0x1000 + k                    │
│                 APB twiddle window 0x0800 – 0x0FFC           │
│  [1536 – 2047]  unused                                       │
└─────────────────────────────────────────────────────────────┘
```

The single write port is shared in priority order: APB sample write, APB twiddle write, engine write. Firmware loads samples and twiddles before starting a run.

### 4.2 Memory Access Patterns

#### Input Data Access Pattern
For an N-point FFT with log2(N) stages:

Butterfly pairs (A, B) for N = 16, in issue order:

```
Stage 0 (span 8): (0,8) (1,9) (2,10) (3,11) (4,12) (5,13) (6,14) (7,15)
Stage 1 (span 4): (0,4) (1,5) (2,6) (3,7) (8,12) (9,13) (10,14) (11,15)
Stage 2 (span 2): (0,2) (1,3) (4,6) (5,7) (8,10) (9,11) (12,14) (13,15)
Stage 3 (span 1): (0,1) (2,3) (4,5) (6,7) (8,9) (10,11) (12,13) (14,15)
```

After stage log2(N)-1 the REORDER pass swaps word i with word bitrev(i) for every i < bitrev(i), so bin k ends up in word k (natural order).

#### Address Generation Logic
```verilog
// span = N >> (stage + 1); b = butterfly index, 0 .. N/2-1
addr_a        = ((b & ~(span-1)) << 1) | (b & (span-1));
addr_b        = addr_a | span;

// Twiddle exponent: W_N^k with k = (b mod span) * 2^stage
twiddle_index = (b & (span-1)) << stage;
```

### 4.3 Memory Interface Timing with Rescaling

```
Phase:          0       1       2       3       4       5
                │       │       │       │       │       │
Address:        A       B       W       -       A       B
Read data:                      A       B       W
Write:                                          A'      B'
Compute:                                        A', B' (from A, B, W)
```

One butterfly every 6 cycles. A run is about 6·(N/2)·log2(N) cycles for the butterflies, plus about 3N for the bit-reverse pass, plus N+2 for the input scan in rescale mode 0.

### 4.4 Physical Memory Implementation

The 2048×32-bit data + twiddle store (1536 words used) has two physical implementations, selected by a compile-time `define`. The logical memory architecture (Sections 4.1–4.3) is identical in both modes — only the underlying storage element changes.

#### Default mode (FPGA / simulation)

A behavioural array tagged with `(* ram_style = "block" *)` for synthesis-tool BRAM inference. Verilator and commercial FPGA tool-chains both consume this directly — no external memory connections are required, and the FFT macro is fully self-contained.

#### Wrapper-bus mode (`+define+FFT_USE_SRAM_MACRO`)

The behavioural array is replaced by a thin `fft_data_sram` wrapper that translates the internal 2048×32 access protocol into eight top-level SRAM bus signals. The IP itself instantiates no PDK-specific macros; instead, the SoC integrator places two 1024×32 SRAM banks at the user-project-wrapper level, adjacent to the FFT macro, and connects them to the bus.

```
                    ┌──────────────────┐    ┌──────────────────┐
                    │  SRAM Bank 0     │    │  SRAM Bank 1     │
                    │  1024 × 32       │    │  1024 × 32       │
                    └────────┬─────────┘    └────────┬─────────┘
                       rdata │                  rdata│
              ┌──────────────┴──────────────────────┴────────┐
              │  shared addr / wdata / ben / rwb / clk       │
              │  per-bank en[1:0]                            │
              └──────────────────────┬───────────────────────┘
                                     │ NORTH-edge SRAM bus
                              ┌──────┴───────┐
                              │   FFT Macro  │
                              │   (fft_top)  │
                              └──────────────┘
```

This pattern keeps PDK-specific timing and area characteristics out of the IP, allows SoC-level floorplanning to position the macros for short routes, and enables the IP to harden standalone with a black-box `fft_data_sram` model. The bus port list and pin-clustering convention are documented in `README.md` ("Memory Topology") and `vyges-metadata.json`.

## 5. Twiddle Factor Generation

### 5.1 Table Organization

There is no twiddle ROM in the design (`fft_twiddle_rom.sv` is not instantiated). Firmware loads the twiddle table into the working memory through the APB twiddle window (0x0800–0x0FFC, word k = paddr[10:2]) before the first run, N/2 words for the N it runs (512 words for 1024 points). Word k holds:

```
W_N^k = cos(2πk/N) - j*sin(2πk/N) = e^(-j·2πk/N)
word k = {cos(2πk/N)[31:16], -sin(2πk/N)[15:0]}   (Q1.15)
```

#### Table Structure
```
┌─────────────────────────────────────────────────────────────┐
│                    Twiddle Factor Table                     │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │   Address   │  │    Real     │  │  Imaginary  │         │
│  │   Decoder   │  │  Component  │  │ Component   │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
│           │                │                │               │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │       fft_memory[1024 + k], k = 0 .. N/2-1              │ │
│  │  ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐     │ │
│  │  │ W_0 │ │ W_1 │ │ W_2 │ │ W_3 │ │ W_4 │ │ ... │     │ │
│  │  └─────┘ └─────┘ └─────┘ └─────┘ └─────┘ └─────┘     │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### 5.2 Symmetry Exploitation

The DIF butterfly uses only exponents k < N/2, so the table holds N/2 words. The engine does not exploit further symmetries:

```
W_N^(N/2+k) = -W_N^k
W_N^(N-k) = W_N^k*
W_N^(N/4+k) = j*W_N^k
```

These identities are not used to shrink the table; every one of the N/2 words is stored.

### 5.3 Twiddle Factor Precision

- **Format:** 16-bit fixed-point (Q1.15 format)
- **Range:** -1.0 to +1.0
- **Precision:** 2^-15 ≈ 3.05e-5
- **Storage:** 32 bits per twiddle factor (cos in [31:16], -sin in [15:0])

## 6. Control Unit Architecture

### 6.1 State Machine with Rescaling

Engine states (`rtl/fft_fft_engine.sv`):

```
IDLE ──▶ CONFIG ──▶ LOAD ──▶ [SCAN] ──▶ COMPUTE ──▶ REORDER ──▶ DONE ──▶ IDLE
            │                (rescale mode 0 only)
            └──(illegal length)──▶ ERROR ──▶ IDLE
```

#### State Descriptions

- **IDLE:** Waiting for start. A run launches when FFT_CTRL[0] is high while the engine is idle; if start stays high, the next run launches as soon as one finishes
- **CONFIG:** FFT_CONFIG and the FFT_CTRL run bits were latched at launch; the length is checked. log2(N) must be 1..min(FFT_MAX_LENGTH_LOG2, 10); anything else goes to ERROR
- **LOAD:** Waits for the memory to be ready
- **SCAN:** Rescale mode 0 with rescaling on only: reads the input once to decide whether stage 0 is scaled
- **COMPUTE:** log2(N) stages of N/2 butterflies, 6 cycles each
- **REORDER:** Bit-reverse pass, results in natural order
- **DONE:** One cycle (fft_done), then IDLE
- **ERROR:** One cycle (fft_error) for a rejected length, then IDLE; no computation runs

FFT_CTRL[1] reset aborts a run from any state: the engine is idle on the next cycle and issues no further write. FFT_STATUS done and error hold from the end of a run until the next run starts; busy is high from launch until done.

### 6.2 Control Signals with Rescaling

| Signal | Direction | Description |
|--------|-----------|-------------|
| `fft_start_i` | input | Start FFT computation |
| `fft_reset_i` | input | Reset FFT engine |
| `fft_busy_o` | output | FFT computation in progress |
| `fft_done_o` | output | FFT computation complete |
| `fft_error_o` | output | FFT computation error |
| `rescaling_active_o` | output | High while a scaled stage is being computed |
| `scale_factor_o` | output | Number of scaled stages so far |
| `stage_count_o` | output | Stages completed |
| `overflow_detected_o` | output | Some butterfly in this run overflowed |
| `overflow_count_o` | output | Overflowing butterflies (saturates at 255) |
| `last_overflow_stage_o` | output | Stage of the last overflow |
| `max_overflow_magnitude_o` | output | Not measured; reads 0 |

## 7. Interface Controllers

### 7.1 APB Interface Controller

The APB interface (in `rtl/fft_memory_interface.sv`) provides register access (0x0000–0x07FC), the twiddle write window (0x0800–0x0FFC, paddr[12:11] = 01) and, with `FFT_USE_APB_DATA`, the sample write window (0x1000–0x1FFC, paddr[12] = 1). The windows are write-only; other addresses read 0. INT_STATUS (0x0018) is write-1-to-clear. The port list is:

```verilog
// APB Slave Interface (ports of fft_top / memory_interface)
(
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

### 7.2 AXI Interface Controller

The AXI port is present on `fft_top` but tied off in the current RTL: the ready outputs are held high, `axi_rvalid_o` is held low and read data is 0. It carries no data. The port list is:

```verilog
// AXI Slave Interface (ports of fft_top; tied off)
(
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

## 8. Performance Optimization

Note: the items in this section are design guidelines, not features of the current RTL, which uses the sequential 6-cycle butterfly and single-port memory described above.

### 8.1 Datapath Optimization with Rescaling

- **Balanced Stages:** Each pipeline stage has similar latency
- **Register Balancing:** Minimizes clock-to-clock delay
- **Clock Gating:** Reduces power consumption during idle periods
- **Bypass Logic:** Handles data hazards efficiently
- **Rescaling Integration:** Rescaling logic integrated into pipeline

### 8.2 Memory Optimization

- **Burst Transfers:** Optimizes memory bandwidth utilization
- **Prefetching:** Reduces memory access latency
- **Bank Interleaving:** Improves memory access parallelism
- **Cache-Friendly:** Optimizes for spatial and temporal locality

### 8.3 Arithmetic Optimization

- **Carry-Save Addition:** Reduces critical path delay
- **Booth Encoding:** Optimizes multiplication performance
- **Saturation Arithmetic:** Prevents overflow/underflow
- **Rounding Control:** Configurable rounding modes
- **Rescaling Optimization:** Efficient rescaling algorithms

## 9. Power Management

Note: the current RTL has no clock gating, power states or voltage scaling; the engine and the APB interface share one clock (pclk_i is assumed equal to clk_i). This section describes possible implementation-level techniques.

### 9.1 Clock Domain Management

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
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │ │
│  │  │  Rescaling  │  │   Scale     │  │  Overflow   │     │ │
│  │  │   Clock     │  │  Factor     │  │  Detection  │     │ │
│  │  │   Gate      │  │   Clock     │  │   Clock     │     │ │
│  │  │             │  │   Gate      │  │   Gate      │     │ │
│  │  └─────────────┘  └─────────────┘  └─────────────┘     │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### 9.2 Power States

| State | Description | Clock Gating | Power Consumption |
|-------|-------------|--------------|-------------------|
| Active | FFT computation | Disabled | 100% |
| Idle | Waiting for start | Memory + Interface | 10% |
| Sleep | Power-down mode | All domains | 1% |

### 9.3 Dynamic Power Reduction

- **Clock Gating:** Gates unused pipeline stages
- **Memory Gating:** Gates unused memory banks
- **Interface Gating:** Gates unused interface logic
- **Voltage Scaling:** Dynamic voltage/frequency scaling
- **Rescaling Gating:** Gates rescaling logic when disabled

## 10. Error Handling and Debug

Note: in the current RTL the only error condition is a rejected FFT length at launch (FFT_CONFIG[11:0] equal to 0 or above min(FFT_MAX_LENGTH_LOG2, 10)), which sets FFT_STATUS.error, raises INT_STATUS[1] / fft_error_o if enabled, and runs no computation. Overflow is reported through the status counters, not as an error. Parity, timeout, range and state checks, performance and pipeline monitors and the debug interface listed below are not implemented.

### 10.1 Error Detection

- **Parity Checking:** Memory data integrity
- **Timeout Detection:** FFT computation timeout
- **Range Checking:** Address and data range validation
- **State Validation:** State machine consistency checking
- **Overflow Detection:** Automatic overflow detection and handling

### 10.2 Debug Features

- **Performance Counters:** Cycle count, throughput measurement
- **Pipeline Monitors:** Stage utilization monitoring
- **Memory Monitors:** Access pattern analysis
- **Error Logging:** Detailed error information storage
- **Rescaling Monitors:** Scale factor tracking and overflow statistics

### 10.3 Test and Debug Interface

```verilog
// Debug Interface with Rescaling Support
module fft_debug_interface (
    input  logic        debug_clk_i,
    input  logic        debug_enable_i,
    input  logic [7:0]  debug_addr_i,
    output logic [31:0] debug_data_o,
    input  logic [31:0] debug_data_i,
    input  logic        debug_write_i,
    input  logic [7:0]  scale_factor_i,
    input  logic        overflow_detected_i
);
```

## 11. Implementation Considerations

### 11.1 Synthesis Guidelines

- **Clock Constraints:** Define clock domains and relationships
- **Timing Constraints:** Set up timing requirements for all paths
- **Area Constraints:** Define area budgets for different modules
- **Power Constraints:** Set up power optimization directives
- **Rescaling Constraints:** Define rescaling logic timing requirements

### 11.2 Physical Design Considerations

- **Floorplanning:** Optimize module placement for timing
- **Clock Distribution:** Design clock tree for minimal skew
- **Power Distribution:** Design power grid for voltage drop
- **Signal Integrity:** Consider crosstalk and noise effects
- **Rescaling Logic Placement:** Optimize placement of rescaling logic

### 11.3 Verification Strategy

- **Unit Testing:** Test individual modules in isolation
- **Integration Testing:** Test module interactions
- **System Testing:** Test complete FFT functionality
- **Performance Testing:** Verify timing and throughput requirements
- **Rescaling Testing:** Verify rescaling functionality and scale factor tracking
- **Golden Model Comparison:** `tb/golden/run_golden.py` (`make test-golden`) compares every output bin word for word with a fixed-point reference model, plus the scale factor and overflow count, over configurations from 8 to 1024 points; `make test-golden-netlist` runs the same cases on the synthesized netlist

This architecture document provides the technical foundation for implementing the FFT hardware accelerator with automatic rescaling and scale factor tracking according to the design specification. The modular design allows for easy customization and optimization for different target applications and performance requirements.
