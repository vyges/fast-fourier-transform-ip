# FFT Hardware Accelerator API Reference

**IP Name:** fast-fourier-transform-ip  
**Version:** 1.0.0  
**Created:** 2025-07-21T05:38:04Z  
**Updated:** 2025-07-21T05:38:04Z  
**Author:** Vyges IP Development Team  

## 1. Overview

This API reference provides detailed specifications for the Fast Fourier Transform (FFT) hardware accelerator interfaces, registers, and programming model. The FFT accelerator supports power-of-two FFT lengths up to 1024 points (the working memory holds 1024 data words and 512 twiddle words), a single shared working memory with buffer-select status, and optional per-stage rescaling to prevent overflow.

### 1.1 Interface Summary

| Interface | Protocol | Data Width | Max Frequency | Purpose |
|-----------|----------|------------|---------------|---------|
| APB | APB3 | 32-bit | 100 MHz | Control and configuration |
| AXI | AXI4 | 64-bit | 1 GHz | Port present but tied off (ready high, no read data); not used for data transfer |
| Interrupt | Pulse | 1-bit | - | Event notification (one-cycle pulse gated by INT_ENABLE) |

## 2. Module Interface

### 2.1 Top-Level Module Declaration

```verilog
module fft_top #(
    parameter int FFT_MAX_LENGTH_LOG2 = 12,    // Maximum FFT length (log2)
    parameter int FFT_DATA_WIDTH = 16,         // Input/output data width
    parameter int FFT_TWIDDLE_WIDTH = 16,      // Twiddle factor width
    parameter int FFT_APB_ADDR_WIDTH = 16,     // APB address width
    parameter int FFT_AXI_ADDR_WIDTH = 32,     // AXI address width
    parameter int FFT_AXI_DATA_WIDTH = 64      // AXI data width
) (
    // Clock and Reset
    input  logic        clk_i,                 // System clock
    input  logic        reset_n_i,             // Active-low reset
    
    // APB Interface
    input  logic        pclk_i,                // APB clock
    input  logic        preset_n_i,            // APB reset
    input  logic        psel_i,                // APB select
    input  logic        penable_i,             // APB enable
    input  logic        pwrite_i,              // APB write enable
    input  logic [FFT_APB_ADDR_WIDTH-1:0] paddr_i, // APB address
    input  logic [31:0] pwdata_i,              // APB write data
    output logic [31:0] prdata_o,              // APB read data
    output logic        pready_o,              // APB ready
    
    // AXI Interface
    input  logic        axi_aclk_i,            // AXI clock
    input  logic        axi_areset_n_i,        // AXI reset
    input  logic [FFT_AXI_ADDR_WIDTH-1:0] axi_awaddr_i,   // AXI write address
    input  logic        axi_awvalid_i,         // AXI write address valid
    output logic        axi_awready_o,         // AXI write address ready
    input  logic [FFT_AXI_DATA_WIDTH-1:0] axi_wdata_i,    // AXI write data
    input  logic        axi_wvalid_i,          // AXI write data valid
    output logic        axi_wready_o,          // AXI write data ready
    input  logic [FFT_AXI_ADDR_WIDTH-1:0] axi_araddr_i,   // AXI read address
    input  logic        axi_arvalid_i,         // AXI read address valid
    output logic        axi_arready_o,         // AXI read address ready
    output logic [FFT_AXI_DATA_WIDTH-1:0] axi_rdata_o,    // AXI read data
    output logic        axi_rvalid_o,          // AXI read data valid
    input  logic        axi_rready_i,          // AXI read data ready
    
    // Interrupt Interface
    output logic        fft_done_o,            // FFT completion interrupt
    output logic        fft_error_o            // FFT error interrupt
    // Further ports (SRAM macro bus, bus-master port, streaming bin
    // output) are present depending on compile-time defines; see
    // rtl/fft_fft_top.sv.
);
```

### 2.2 Parameter Definitions

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| `FFT_MAX_LENGTH_LOG2` | int | 12 | 1-12 | Maximum FFT length as log2. The working memory supports at most 1024 points, so values above 10 add no capacity |
| `FFT_DATA_WIDTH` | int | 16 | 8-32 | Input/output data width in bits |
| `FFT_TWIDDLE_WIDTH` | int | 16 | 8-32 | Twiddle factor width in bits |
| `FFT_APB_ADDR_WIDTH` | int | 16 | 8-32 | APB address bus width |
| `FFT_AXI_ADDR_WIDTH` | int | 32 | 16-64 | AXI address bus width |
| `FFT_AXI_DATA_WIDTH` | int | 64 | 32-512 | AXI data bus width |

## 3. Register Map

### 3.1 Register Address Map

| Address | Register Name | Access | Reset Value | Description |
|---------|---------------|--------|-------------|-------------|
| 0x0000 | FFT_CTRL | R/W | 0x00000000 | FFT Control Register |
| 0x0004 | FFT_STATUS | R | 0x00000000 | FFT Status Register |
| 0x0008 | FFT_CONFIG | R/W | 0x00000000 | FFT Configuration Register |
| 0x000C | FFT_LENGTH | R/W | 0x00000400 | FFT Length Register |
| 0x0010 | BUFFER_SEL | R/W | 0x00000000 | Buffer Selection Register |
| 0x0014 | INT_ENABLE | R/W | 0x00000000 | Interrupt Enable Register |
| 0x0018 | INT_STATUS | RW1C | 0x00000000 | Interrupt Status Register (write 1 to clear) |
| 0x001C | SCALE_FACTOR | R | 0x00000000 | Output Scale Factor Register |
| 0x0020 | RESCALE_CTRL | R/W | 0x00000000 | Rescaling Control Register |
| 0x0024 | OVERFLOW_STATUS | R | 0x00000000 | Overflow Status Register |
| 0x0028 | ERROR_CODE | - | - | Not implemented (reads 0) |
| 0x002C | CYCLE_COUNT | - | - | Not implemented (reads 0) |
| 0x0030 | POWER_CTRL | - | - | Not implemented (reads 0, writes ignored) |
| 0x0034 | DEBUG_CTRL | - | - | Not implemented (reads 0, writes ignored) |
| 0x0038 | DEBUG_DATA | - | - | Not implemented (reads 0, writes ignored) |

The register window is 0x0000-0x07FC (`paddr[12:11] = 00`); only the offsets 0x0000-0x0024 are decoded. FFT_CONFIG and the run bits of FFT_CTRL are latched when a run launches; writes during a run apply to the next run.

### 3.2 Memory Address Map

| Address Range | Memory | Access | Size | Description |
|---------------|--------|--------|------|-------------|
| 0x0800-0x0FFC | Twiddle table | W | 2 KB (512 words) | `paddr[12:11] = 01`; word `k = paddr[10:2]`. Firmware loads N/2 twiddle words at boot; there is no ROM |
| 0x1000-0x1FFC | Sample data | W | 4 KB (1024 words) | `paddr[12] = 1`, only when compiled with `FFT_USE_APB_DATA`; word `i = paddr[11:2]` |

Both windows are write-only from APB: reads return 0, and there is no APB readback of results. Addresses 0x2000 and above are not decoded. Results stay in the working memory (words 0..N-1) and are read through the memory backend or the streaming bin output (`FFT_USE_STREAM_OUT`).

## 4. Register Definitions

### 4.1 FFT_CTRL Register (0x0000)

**Access:** Read/Write  
**Reset Value:** 0x00000000

| Bits | Name | Access | Description |
|------|------|--------|-------------|
| [0] | FFT_START | R/W | Start FFT computation (level; not auto-cleared) |
| [1] | FFT_RESET | R/W | Abort the run and hold the engine idle (level; not auto-cleared) |
| [2] | BUFFER_SWAP | R/W | Toggle the buffer-active status bit |
| [3] | - | R/W | Stored, no effect |
| [4] | RESCALE_EN | R/W | Enable rescaling (requires FFT_CONFIG[19]) |
| [5] | SCALE_TRACK_EN | R/W | Enable scale factor tracking |
| [7:6] | - | R/W | Stored, no effect |
| [8] | STREAM_ENABLE | R/W | Arm the post-completion bin streamer (`FFT_USE_STREAM_OUT` builds only) |
| [31:9] | - | R/W | Stored, no effect |

**Bit Descriptions:**

- **FFT_START (bit 0):** A run launches when this bit is high while the engine is idle. The bit is not cleared by hardware; if it stays high, the next run starts as soon as one finishes. The recommended start is a pulse (write 1, then write 0).
- **FFT_RESET (bit 1):** When set to 1, aborts a run: the engine is idle on the next cycle and issues no further memory write. Software clears it.
- **BUFFER_SWAP (bit 2):** A write of 1 toggles FFT_STATUS[3] (buffer active) and, on the rising edge, raises the buffer-swap interrupt if enabled. There is one working memory; the bit does not select a different data buffer.
- **RESCALE_EN (bit 4):** When set to 1 together with FFT_CONFIG[19], enables per-stage rescaling (see FFT_CONFIG[16]).
- **SCALE_TRACK_EN (bit 5):** When set to 1, the scale factor counts the scaled stages.
- **STREAM_ENABLE (bit 8):** Arms the post-completion bin streamer; no effect unless compiled with `FFT_USE_STREAM_OUT`.
- Bits [5:4] are latched at launch; writes during a run apply to the next run.

### 4.2 FFT_STATUS Register (0x0004)

**Access:** Read Only  
**Reset Value:** 0x00000000

| Bits | Name | Access | Description |
|------|------|--------|-------------|
| [0] | FFT_BUSY | R | FFT computation in progress |
| [1] | FFT_DONE | R | FFT computation complete (held until the next run starts) |
| [2] | FFT_ERROR | R | Run rejected (held until the next run starts) |
| [3] | BUFFER_ACTIVE | R | Buffer-active status bit |
| [4] | RESCALE_ACTIVE | R | A scaled stage is being computed |
| [5] | OVERFLOW_DETECTED | R | Overflow detected during the run |
| [13:6] | SCALE_FACTOR | R | Number of scaled stages |
| [21:14] | STAGE_COUNT | R | Stages completed in the run |
| [29:22] | OVERFLOW_COUNT | R | Overflowing butterflies (saturates at 255) |
| [31:30] | RESERVED | R | Reserved bits (read as 0) |

**Bit Descriptions:**

- **FFT_BUSY (bit 0):** High from launch until done.
- **FFT_DONE (bit 1):** Set at the end of a run and held until the next run starts, so polling firmware does not miss it.
- **FFT_ERROR (bit 2):** Set when a launch is rejected because FFT_CONFIG[11:0] is not a legal length (0, or above min(FFT_MAX_LENGTH_LOG2, 10)); no computation runs. Held until the next run starts.
- **BUFFER_ACTIVE (bit 3):** Status bit toggled by FFT_CTRL[2] and set by BUFFER_SEL; it does not select a different data buffer.
- **RESCALE_ACTIVE (bit 4):** High while a scaled stage is being computed.
- **OVERFLOW_DETECTED (bit 5):** Set once any butterfly in the run overflowed.
- **SCALE_FACTOR (bits 13:6):** Same value as SCALE_FACTOR[7:0].
- **STAGE_COUNT (bits 21:14):** Number of stages completed in the run.
- **OVERFLOW_COUNT (bits 29:22):** Same value as OVERFLOW_STATUS[7:0].

### 4.3 FFT_CONFIG Register (0x0008)

**Access:** Read/Write  
**Reset Value:** 0x00000000

| Bits | Name | Access | Description |
|------|------|--------|-------------|
| [11:0] | FFT_LENGTH_LOG2 | R/W | Log2 of FFT length (1-10) |
| [15:12] | - | R/W | Stored, no effect |
| [16] | RESCALE_MODE | R/W | Rescaling mode (0=block floating point per stage, 1=every stage) |
| [17] | ROUNDING_MODE | R/W | Rounding mode (0=truncate, 1=round) |
| [18] | SATURATION_EN | R/W | Enable saturation arithmetic |
| [19] | OVERFLOW_DETECT | R/W | Enable overflow detection |
| [31:20] | - | R/W | Stored, no effect |

**Bit Descriptions:**

- **FFT_LENGTH_LOG2 (bits 11:0):** Logarithm base 2 of the FFT length. Legal values are 1 to min(FFT_MAX_LENGTH_LOG2, 10), i.e. 2 to 1024 points with the default parameter. Any other value is rejected at launch: FFT_STATUS[2] is set, the error interrupt fires if enabled, and no computation runs.
- **RESCALE_MODE (bit 16):** Takes effect only when FFT_CTRL[4] and FFT_CONFIG[19] are both set. 1: every stage is scaled by 1/2; the result is X/N and the scale factor is log2(N). 0 (block floating point): before stage 0 the engine reads the input once, and a stage is scaled only if one of its input components lies outside [-2^13, 2^13).
- **ROUNDING_MODE (bit 17):** 0 = truncate; 1 = add half an LSB before each shift.
- **SATURATION_EN (bit 18):** 1 = clamp results to [-32768, 32767]; 0 = wrap (low 16 bits kept).
- **OVERFLOW_DETECT (bit 19):** When set to 1, enables overflow counting and is required, with FFT_CTRL[4], for rescaling.
- The register is latched at launch; writes during a run apply to the next run.

### 4.4 SCALE_FACTOR Register (0x001C)

**Access:** Read Only  
**Reset Value:** 0x00000000

| Bits | Name | Access | Description |
|------|------|--------|-------------|
| [7:0] | SCALE_FACTOR | R | Number of scaled stages (log2 of the total scaling) |
| [15:8] | STAGE_COUNT | R | Number of stages completed |
| [23:16] | RESERVED | R | Reserved bits (read as 0) |
| [31:24] | OVERFLOW_COUNT | R | Number of overflowing butterflies |

**Bit Descriptions:**

- **SCALE_FACTOR (bits 7:0):** Number of stages that were scaled by 1/2, counted when FFT_CTRL[5] is set. It never exceeds log2(N). The output equals the true FFT divided by 2^SCALE_FACTOR.
- **STAGE_COUNT (bits 15:8):** Number of FFT stages completed in the run.
- **OVERFLOW_COUNT (bits 31:24):** Number of butterflies with a component that did not fit 16 bits (counted when FFT_CONFIG[19] is set), saturating at 255.

### 4.5 RESCALE_CTRL Register (0x0020)

**Access:** Read/Write  
**Reset Value:** 0x00000000

| Bits | Name | Access | Description |
|------|------|--------|-------------|
| [31:0] | RESCALE_CTRL | R/W | Stored and readable; no effect on the engine |

**Bit Descriptions:**

- The register is stored and reads back what was written, but the engine does not use it. Rescaling is controlled by FFT_CTRL[4], FFT_CTRL[5] and FFT_CONFIG[19:16]; the overflow and rescale interrupts are enabled by INT_ENABLE[3] and [4].

### 4.6 OVERFLOW_STATUS Register (0x0024)

**Access:** Read Only  
**Reset Value:** 0x00000000

| Bits | Name | Access | Description |
|------|------|--------|-------------|
| [7:0] | OVERFLOW_COUNT | R | Total overflow count |
| [15:8] | LAST_OVERFLOW_STAGE | R | Stage where last overflow occurred |
| [23:16] | MAX_OVERFLOW_MAGNITUDE | R | Not measured; reads 0 |
| [31:24] | RESERVED | R | Reserved bits (read as 0) |

**Bit Descriptions:**

- **OVERFLOW_COUNT (bits 7:0):** Number of butterflies with a component that did not fit 16 bits, saturating at 255.
- **LAST_OVERFLOW_STAGE (bits 15:8):** FFT stage of the last overflowing butterfly.
- **MAX_OVERFLOW_MAGNITUDE (bits 23:16):** Not measured; always reads 0.

### 4.7 FFT_LENGTH Register (0x000C)

**Access:** Read/Write  
**Reset Value:** 0x00000400 (1024)

| Bits | Name | Access | Description |
|------|------|--------|-------------|
| [15:0] | FFT_LENGTH | R/W | FFT length in points |
| [31:16] | RESERVED | R | Reserved bits (read as 0) |

**Bit Descriptions:**

- **FFT_LENGTH (bits 15:0):** The number of points in the FFT, for software reference. The register is stored and readable, but the engine takes the length from FFT_CONFIG[11:0]; keep the two consistent (N = 1 << FFT_CONFIG[11:0], at most 1024).

### 4.8 BUFFER_SEL Register (0x0010)

**Access:** Read/Write  
**Reset Value:** 0x00000000

| Bits | Name | Access | Description |
|------|------|--------|-------------|
| [0] | BUFFER_A_SEL | R/W | Force the buffer-active status to A |
| [1] | BUFFER_B_SEL | R/W | Force the buffer-active status to B (takes priority over bit 0) |
| [31:2] | - | R/W | Stored, no effect |

**Bit Descriptions:**

- **BUFFER_A_SEL (bit 0) / BUFFER_B_SEL (bit 1):** Set the internal buffer-active state reported in FFT_STATUS[3]; FFT_CTRL[2] and FFT_CTRL[1] take priority. The IP has a single working memory; these bits do not select a different data buffer, and there is no background loading or automatic swap.

### 4.9 INT_ENABLE Register (0x0014)

**Access:** Read/Write  
**Reset Value:** 0x00000000

| Bits | Name | Access | Description |
|------|------|--------|-------------|
| [0] | FFT_DONE_EN | R/W | Enable FFT completion interrupt |
| [1] | FFT_ERROR_EN | R/W | Enable FFT error interrupt |
| [2] | BUFFER_SWAP_EN | R/W | Enable buffer swap interrupt |
| [3] | OVERFLOW_EN | R/W | Enable overflow interrupt |
| [4] | RESCALE_EN | R/W | Enable rescaling interrupt |
| [7:5] | - | R/W | Stored, no effect |
| [31:8] | - | R/W | Stored, not used |

**Bit Descriptions:**

- **FFT_DONE_EN (bit 0):** When set to 1, enables the completion pending bit and the `fft_done_o` pulse.
- **FFT_ERROR_EN (bit 1):** When set to 1, enables the error pending bit and the `fft_error_o` pulse.
- **BUFFER_SWAP_EN (bit 2):** When set to 1, enables the buffer swap pending bit.
- **OVERFLOW_EN (bit 3):** When set to 1, enables the overflow pending bit.
- **RESCALE_EN (bit 4):** When set to 1, enables the rescaling pending bit.

### 4.10 INT_STATUS Register (0x0018)

**Access:** Read / Write-1-to-Clear (RW1C)  
**Reset Value:** 0x00000000

| Bits | Name | Access | Description |
|------|------|--------|-------------|
| [0] | FFT_DONE_PENDING | RW1C | FFT completion interrupt pending |
| [1] | FFT_ERROR_PENDING | RW1C | FFT error interrupt pending |
| [2] | BUFFER_SWAP_PENDING | RW1C | Buffer swap interrupt pending |
| [3] | OVERFLOW_PENDING | RW1C | Overflow interrupt pending |
| [4] | RESCALE_PENDING | RW1C | Rescaling interrupt pending |
| [31:5] | RESERVED | R | Reserved bits (read as 0) |

**Bit Descriptions:**

Each pending bit is set on the rising edge of its event while the matching INT_ENABLE bit is set, and stays set until software writes 1 to that bit. Writing 0 leaves a bit unchanged.

- **FFT_DONE_PENDING (bit 0):** Set at the end of a run.
- **FFT_ERROR_PENDING (bit 1):** Set when a launch is rejected for an illegal length.
- **BUFFER_SWAP_PENDING (bit 2):** Set on a rising edge of FFT_CTRL[2].
- **OVERFLOW_PENDING (bit 3):** Set on the first overflow of a run.
- **RESCALE_PENDING (bit 4):** Set when a scaled stage starts.

## 5. Memory Interface

### 5.1 Data Format

#### Input Data Format

Input data is stored in 32-bit words with the following format (Q1.15):

```
[31:16] - Imaginary component (16-bit signed)
[15:0]  - Real component (16-bit signed)
```

Twiddle word `k` (written to 0x0800 + 4k) is `{cos(2*pi*k/N)[31:16], -sin(2*pi*k/N)[15:0]}`, i.e. W_N^k = e^(-j*2*pi*k/N), in Q1.15. Firmware loads N/2 words for the N it runs.

#### Output Data Format

Output data is stored in 32-bit words with the same format as input data:

```
[31:16] - Imaginary component (16-bit signed)
[15:0]  - Real component (16-bit signed)
```

Results are in natural order: bin `k` is word `k` (the engine runs a bit-reverse pass after the last stage). The output equals the true FFT divided by 2^SCALE_FACTOR.

### 5.2 Memory Access Patterns

#### Sequential Access

For sequential data loading and reading:

```c
// Load input data sequentially (sample window, FFT_USE_APB_DATA builds)
for (int i = 0; i < fft_length; i++) {
    uint32_t addr = FFT_BASE + 0x1000 + (i * 4);
    uint32_t data = ((uint32_t)(uint16_t)input_imag[i] << 16) | (uint16_t)input_real[i];
    write_reg(addr, data);
}
```

#### Burst Access

For high-performance burst transfers:

**Note:** BURST_CONFIG and burst transfers are not implemented in the current RTL: reads of an unmapped register offset return 0 and writes are ignored. The example is kept for reference only.

```c
// Burst load input data
void burst_load_data(uint32_t *data, uint32_t length) {
    // Configure burst transfer
    write_reg(BURST_CONFIG, 0x01);
    
    // Perform burst write
    for (int i = 0; i < length; i += 4) {
        burst_write(INPUT_BUFFER_A_BASE + i, &data[i], 4);
    }
}
```

## 6. APB Interface Protocol

### 6.1 APB Transfer Timing

The APB interface follows the APB3 protocol specification:

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

### 6.2 APB Read Transfer

```c
// APB read transfer example
uint32_t apb_read(uint32_t address) {
    // Set address
    paddr = address;
    pwrite = 0;
    psel = 1;
    
    // First cycle
    penable = 0;
    wait_clock();
    
    // Second cycle
    penable = 1;
    wait_clock();
    
    // Read data
    uint32_t data = prdata;
    
    // End transfer
    psel = 0;
    penable = 0;
    
    return data;
}
```

### 6.3 APB Write Transfer

```c
// APB write transfer example
void apb_write(uint32_t address, uint32_t data) {
    // Set address and data
    paddr = address;
    pwdata = data;
    pwrite = 1;
    psel = 1;
    
    // First cycle
    penable = 0;
    wait_clock();
    
    // Second cycle
    penable = 1;
    wait_clock();
    
    // Wait for ready
    while (!pready) {
        wait_clock();
    }
    
    // End transfer
    psel = 0;
    penable = 0;
}
```

## 7. AXI Interface Protocol

### 7.1 AXI Write Transfer

**Note:** In the current RTL the AXI port is tied off: the ready outputs are held high, `axi_rvalid_o` stays low and `axi_rdata_o` reads 0, and writes are discarded. The examples below show generic AXI handshakes only.

The AXI interface supports burst transfers for high-bandwidth data transfer:

```c
// AXI write burst transfer
void axi_write_burst(uint32_t address, uint32_t *data, uint32_t length) {
    // Write address channel
    axi_awaddr = address;
    axi_awvalid = 1;
    
    while (!axi_awready) {
        wait_clock();
    }
    axi_awvalid = 0;
    
    // Write data channel
    for (int i = 0; i < length; i++) {
        axi_wdata = data[i];
        axi_wvalid = 1;
        
        while (!axi_wready) {
            wait_clock();
        }
    }
    axi_wvalid = 0;
}
```

### 7.2 AXI Read Transfer

```c
// AXI read burst transfer
void axi_read_burst(uint32_t address, uint32_t *data, uint32_t length) {
    // Read address channel
    axi_araddr = address;
    axi_arvalid = 1;
    
    while (!axi_arready) {
        wait_clock();
    }
    axi_arvalid = 0;
    
    // Read data channel
    for (int i = 0; i < length; i++) {
        axi_rready = 1;
        
        while (!axi_rvalid) {
            wait_clock();
        }
        
        data[i] = axi_rdata;
    }
    axi_rready = 0;
}
```

## 8. Interrupt Interface

### 8.1 Interrupt Generation

Interrupts are generated based on the INT_ENABLE register settings. The top-level outputs are one-cycle pulses; the latched record of each event is the matching INT_STATUS pending bit:

```c
// Interrupt generation logic
assign fft_done_o  = fft_done  & int_enable[0];  // one-cycle pulse at end of run
assign fft_error_o = fft_error & int_enable[1];  // one-cycle pulse on a rejected launch
```

### 8.2 Interrupt Handling

```c
// Interrupt service routine
void fft_interrupt_handler(void) {
    uint32_t int_status = read_reg(INT_STATUS);
    
    // Handle FFT completion
    if (int_status & 0x01) {
        handle_fft_completion();
        write_reg(INT_STATUS, 0x01);  // Clear interrupt
    }
    
    // Handle FFT error
    if (int_status & 0x02) {
        handle_fft_error();
        write_reg(INT_STATUS, 0x02);  // Clear interrupt
    }
    
    // Handle buffer swap
    if (int_status & 0x04) {
        handle_buffer_swap();
        write_reg(INT_STATUS, 0x04);  // Clear interrupt
    }
    
    // Handle overflow
    if (int_status & 0x08) {
        handle_overflow();
        write_reg(INT_STATUS, 0x08);  // Clear interrupt
    }
    
    // Handle rescaling
    if (int_status & 0x10) {
        handle_rescaling();
        write_reg(INT_STATUS, 0x10);  // Clear interrupt
    }
}
```

## 9. Rescaling and Scale Factor Management

### 9.1 Rescaling Configuration

```c
// Configure rescaling
void configure_rescaling(void) {
    // Enable automatic rescaling
    write_reg(FFT_CTRL, read_reg(FFT_CTRL) | 0x10);  // Set RESCALE_EN
    
    // Enable scale factor tracking
    write_reg(FFT_CTRL, read_reg(FFT_CTRL) | 0x20);  // Set SCALE_TRACK_EN
    
    // Set rescaling mode (0=block floating point per stage, 1=every stage, X/N)
    write_reg(FFT_CONFIG, read_reg(FFT_CONFIG) & ~0x10000);  // Mode 0
    
    // Enable overflow detection
    write_reg(FFT_CONFIG, read_reg(FFT_CONFIG) | 0x80000);  // Set OVERFLOW_DETECT
}
```

### 9.2 Scale Factor Reading

```c
// Read scale factor information
void read_scale_factor_info(void) {
    uint32_t scale_factor_reg = read_reg(SCALE_FACTOR);
    uint8_t total_scale = scale_factor_reg & 0xFF;
    uint8_t stage_count = (scale_factor_reg >> 8) & 0xFF;
    uint8_t overflow_count = (scale_factor_reg >> 24) & 0xFF;
    
    printf("Scaled stages: %d (output = FFT / %d)\n", total_scale, 1 << total_scale);
    printf("Stages Processed: %d\n", stage_count);
    printf("Overflowing butterflies: %d\n", overflow_count);
}
```

### 9.3 Output Data Reconstruction

```c
// Reconstruct original signal magnitude (needs more than 16 bits)
void reconstruct_signal(const uint32_t *output_data, int32_t *re, int32_t *im,
                        uint32_t length) {
    uint32_t scale_factor_reg = read_reg(SCALE_FACTOR);
    uint8_t total_scale = scale_factor_reg & 0xFF;
    
    // Output = true FFT / 2^total_scale
    for (int i = 0; i < length; i++) {
        int16_t real_part = (int16_t)(output_data[i] & 0xFFFF);
        int16_t imag_part = (int16_t)(output_data[i] >> 16);
        
        // Scale back by the accumulated scale factor
        re[i] = (int32_t)real_part * (1 << total_scale);
        im[i] = (int32_t)imag_part * (1 << total_scale);
    }
}
```

## 10. Error Handling

### 10.1 Error Codes

The only error the engine reports is a rejected length: when a run is launched with FFT_CONFIG[11:0] equal to 0 or above min(FFT_MAX_LENGTH_LOG2, 10), the engine enters ERROR for one cycle, FFT_STATUS[2] is set and held until the next run starts, INT_STATUS[1] and `fft_error_o` fire if INT_ENABLE[1] is set, and no computation runs. Recovery is to write a legal length to FFT_CONFIG[11:0] and start again.

**Note:** The ERROR_CODE register and the codes in the table below are not implemented in the current RTL: reads of an unmapped register offset return 0 and writes are ignored. The example is kept for reference only.

| Error Code | Description | Recovery Action |
|------------|-------------|-----------------|
| 0x00 | No error | None |
| 0x01 | Invalid FFT length | Set valid FFT length |
| 0x02 | Memory overflow | Reset memory pointers |
| 0x03 | Timeout error | Restart FFT computation |
| 0x04 | Data corruption | Reload input data |
| 0x05 | Twiddle factor error | Reset twiddle ROM |
| 0x06 | Pipeline error | Reset FFT engine |
| 0x07 | Interface error | Reset interface logic |
| 0x08 | Rescaling overflow | Excessive rescaling required |
| 0x09 | Scale factor overflow | Scale factor exceeded maximum |

### 10.2 Error Recovery

```c
// Error recovery function
void handle_fft_error(void) {
    uint32_t error_code = read_reg(ERROR_CODE);
    
    switch (error_code) {
        case 0x01:  // Invalid FFT length
            write_reg(FFT_LENGTH, 1024);  // Set default length
            break;
            
        case 0x02:  // Memory overflow
            write_reg(FFT_CTRL, 0x02);    // Reset FFT engine
            break;
            
        case 0x03:  // Timeout error
            write_reg(FFT_CTRL, 0x01);    // Restart FFT
            break;
            
        case 0x04:  // Data corruption
            reload_input_data();
            write_reg(FFT_CTRL, 0x01);    // Restart FFT
            break;
            
        case 0x08:  // Rescaling overflow
            // Disable rescaling and retry
            write_reg(FFT_CTRL, read_reg(FFT_CTRL) & ~0x10);
            write_reg(FFT_CTRL, 0x01);    // Restart FFT
            break;
            
        case 0x09:  // Scale factor overflow
            // Reset scale factor and retry
            write_reg(FFT_CTRL, 0x02);    // Reset FFT engine
            break;
            
        default:
            // Unknown error - reset everything
            write_reg(FFT_CTRL, 0x02);    // Reset FFT engine
            break;
    }
}
```

## 11. Performance Monitoring

### 11.1 Performance Counters

**Note:** CYCLE_COUNT, POWER_MONITOR and MEMORY_BANDWIDTH are not implemented in the current RTL: reads of an unmapped register offset return 0 and writes are ignored. The example is kept for reference only. A run takes about 6 * (N/2) * log2(N) cycles for the butterflies (one memory access per cycle, 6 cycles per butterfly, not pipelined), plus about 3N for the bit-reverse pass, plus N+2 for the input scan in rescale mode 0. Measured from the start pulse to the last streamed bin: about 7.6k-7.9k cycles for 256 points, 17.3k for 512 and 36.8k-37.8k for 1024.

```c
// Performance monitoring functions
uint32_t get_cycle_count(void) {
    return read_reg(CYCLE_COUNT);
}

uint32_t get_throughput(uint32_t fft_length) {
    uint32_t cycles = get_cycle_count();
    return (fft_length * 1000000) / cycles;  // MSPS
}

void print_performance_stats(void) {
    printf("FFT Performance Statistics:\n");
    printf("  Cycle Count: %u\n", get_cycle_count());
    printf("  Throughput: %u MSPS\n", get_throughput(read_reg(FFT_LENGTH)));
    printf("  Power Consumption: %u mW\n", read_reg(POWER_MONITOR));
    printf("  Memory Bandwidth: %u MB/s\n", read_reg(MEMORY_BANDWIDTH));
    
    // Rescaling statistics
    uint32_t scale_factor_reg = read_reg(SCALE_FACTOR);
    uint8_t total_scale = scale_factor_reg & 0xFF;
    uint8_t overflow_count = (scale_factor_reg >> 24) & 0xFF;
    printf("  Total Scale Factor: 2^%d\n", total_scale);
    printf("  Overflow Events: %d\n", overflow_count);
}
```

### 11.2 Debug Interface

**Note:** DEBUG_CTRL, DEBUG_BREAKPOINT, DEBUG_ADDR and DEBUG_DATA are not implemented in the current RTL: reads of an unmapped register offset return 0 and writes are ignored. The example is kept for reference only.

```c
// Debug interface functions
void enable_debug_mode(void) {
    write_reg(DEBUG_CTRL, 0x01);
}

void set_debug_breakpoint(uint32_t stage, uint32_t condition) {
    write_reg(DEBUG_BREAKPOINT, (stage << 8) | condition);
}

uint32_t read_debug_data(uint32_t address) {
    write_reg(DEBUG_ADDR, address);
    return read_reg(DEBUG_DATA);
}
```

## 12. Power Management

### 12.1 Power States

| State | Description | Power Consumption | Wake-up Time |
|-------|-------------|-------------------|--------------|
| Active | FFT computation | 100% | - |
| Idle | Waiting for start | 10% | 1 cycle |
| Sleep | Power-down mode | 1% | 100 cycles |

### 12.2 Power Control

**Note:** POWER_CTRL, the FFT_CTRL[7] power-down bit and the FFT_CONFIG[22] clock-gate bit are not implemented in the current RTL: reads of an unmapped register offset return 0 and writes are ignored. The example is kept for reference only.

```c
// Power management functions
void enter_sleep_mode(void) {
    write_reg(POWER_CTRL, 0x01);  // Enable power down
    write_reg(FFT_CTRL, 0x80);    // Set POWER_DOWN bit
}

void exit_sleep_mode(void) {
    write_reg(FFT_CTRL, 0x00);    // Clear POWER_DOWN bit
    write_reg(POWER_CTRL, 0x00);  // Disable power down
    
    // Wait for power up
    delay_cycles(100);
}

void enable_clock_gating(void) {
    write_reg(FFT_CONFIG, read_reg(FFT_CONFIG) | 0x00400000);  // Set CLOCK_GATE_EN
}
```

## 13. Compliance and Standards

### 13.1 Interface Compliance

- **APB Interface:** Compliant with AMBA APB3 specification
- **AXI Interface:** Compliant with AMBA AXI4 specification
- **Reset Interface:** Compliant with AMBA reset specification

### 13.2 Timing Compliance

- **Setup Time:** 1.0 ns minimum
- **Hold Time:** 0.5 ns minimum
- **Clock-to-Q:** 2.0 ns maximum
- **Maximum Frequency:** 1 GHz

### 13.3 Power Compliance

- **Static Power:** < 1 mW
- **Dynamic Power:** < 50 mW at 1 GHz
- **Leakage Current:** < 1 μA

This API reference provides comprehensive information for programming and interfacing with the FFT hardware accelerator with automatic rescaling and scale factor tracking. For additional details, please refer to the user guide and architecture documents. 