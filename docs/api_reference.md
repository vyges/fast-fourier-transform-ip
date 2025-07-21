# FFT Hardware Accelerator API Reference

**IP Name:** fast-fourier-transform-ip  
**Version:** 1.0.0  
**Created:** 2025-07-21T05:38:04Z  
**Updated:** 2025-07-21T05:38:04Z  
**Author:** Vyges IP Development Team  

## 1. Overview

This API reference provides detailed specifications for the Fast Fourier Transform (FFT) hardware accelerator interfaces, registers, and programming model. The FFT accelerator supports configurable FFT lengths from 256 to 4096 points with double-buffered memory architecture.

### 1.1 Interface Summary

| Interface | Protocol | Data Width | Max Frequency | Purpose |
|-----------|----------|------------|---------------|---------|
| APB | APB3 | 32-bit | 100 MHz | Control and configuration |
| AXI | AXI4 | 64-bit | 1 GHz | High-bandwidth data transfer |
| Interrupt | Level | 1-bit | - | Event notification |

## 2. Module Interface

### 2.1 Top-Level Module Declaration

```verilog
module fft_top #(
    parameter int FFT_MAX_LENGTH_LOG2 = 12,    // Maximum FFT length (log2)
    parameter int DATA_WIDTH = 16,             // Input/output data width
    parameter int TWIDDLE_WIDTH = 16,          // Twiddle factor width
    parameter int APB_ADDR_WIDTH = 16,         // APB address width
    parameter int AXI_ADDR_WIDTH = 32,         // AXI address width
    parameter int AXI_DATA_WIDTH = 64          // AXI data width
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
    input  logic [APB_ADDR_WIDTH-1:0] paddr_i, // APB address
    input  logic [31:0] pwdata_i,              // APB write data
    output logic [31:0] prdata_o,              // APB read data
    output logic        pready_o,              // APB ready
    
    // AXI Interface
    input  logic        axi_aclk_i,            // AXI clock
    input  logic        axi_areset_n_i,        // AXI reset
    input  logic [AXI_ADDR_WIDTH-1:0] axi_awaddr_i,   // AXI write address
    input  logic        axi_awvalid_i,         // AXI write address valid
    output logic        axi_awready_o,         // AXI write address ready
    input  logic [AXI_DATA_WIDTH-1:0] axi_wdata_i,    // AXI write data
    input  logic        axi_wvalid_i,          // AXI write data valid
    output logic        axi_wready_o,          // AXI write data ready
    input  logic [AXI_ADDR_WIDTH-1:0] axi_araddr_i,   // AXI read address
    input  logic        axi_arvalid_i,         // AXI read address valid
    output logic        axi_arready_o,         // AXI read address ready
    output logic [AXI_DATA_WIDTH-1:0] axi_rdata_o,    // AXI read data
    output logic        axi_rvalid_o,          // AXI read data valid
    input  logic        axi_rready_i,          // AXI read data ready
    
    // Interrupt Interface
    output logic        fft_done_o,            // FFT completion interrupt
    output logic        fft_error_o            // FFT error interrupt
);
```

### 2.2 Parameter Definitions

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| `FFT_MAX_LENGTH_LOG2` | int | 12 | 8-12 | Maximum FFT length as log2 |
| `DATA_WIDTH` | int | 16 | 8-32 | Input/output data width in bits |
| `TWIDDLE_WIDTH` | int | 16 | 8-32 | Twiddle factor width in bits |
| `APB_ADDR_WIDTH` | int | 16 | 8-32 | APB address bus width |
| `AXI_ADDR_WIDTH` | int | 32 | 16-64 | AXI address bus width |
| `AXI_DATA_WIDTH` | int | 64 | 32-512 | AXI data bus width |

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
| 0x0018 | INT_STATUS | R | 0x00000000 | Interrupt Status Register |
| 0x001C | ERROR_CODE | R | 0x00000000 | Error Code Register |
| 0x0020 | CYCLE_COUNT | R | 0x00000000 | Cycle Count Register |
| 0x0024 | POWER_CTRL | R/W | 0x00000000 | Power Control Register |
| 0x0028 | DEBUG_CTRL | R/W | 0x00000000 | Debug Control Register |
| 0x002C | DEBUG_DATA | R/W | 0x00000000 | Debug Data Register |

### 3.2 Memory Address Map

| Address Range | Memory | Access | Size | Description |
|---------------|--------|--------|------|-------------|
| 0x1000-0x1FFF | Input Buffer A | R/W | 4 KB | Input data buffer A |
| 0x2000-0x2FFF | Input Buffer B | R/W | 4 KB | Input data buffer B |
| 0x3000-0x3FFF | Output Buffer A | R | 4 KB | Output data buffer A |
| 0x4000-0x4FFF | Output Buffer B | R | 4 KB | Output data buffer B |
| 0x5000-0x5FFF | Twiddle ROM | R | 4 KB | Twiddle factor ROM |

## 4. Register Definitions

### 4.1 FFT_CTRL Register (0x0000)

**Access:** Read/Write  
**Reset Value:** 0x00000000

| Bits | Name | Access | Description |
|------|------|--------|-------------|
| [0] | FFT_START | R/W | Start FFT computation (auto-cleared) |
| [1] | FFT_RESET | R/W | Reset FFT engine (auto-cleared) |
| [2] | BUFFER_SWAP | R/W | Swap input/output buffers |
| [3] | MODE_SEL | R/W | Mode selection (0=APB, 1=AXI) |
| [4] | SCALING_EN | R/W | Enable output scaling |
| [5] | BIT_REVERSE_EN | R/W | Enable bit-reverse addressing |
| [6] | DEBUG_EN | R/W | Enable debug mode |
| [7] | POWER_DOWN | R/W | Power down FFT engine |
| [31:8] | RESERVED | R | Reserved bits (read as 0) |

**Bit Descriptions:**

- **FFT_START (bit 0):** When set to 1, starts FFT computation. This bit is automatically cleared when FFT computation begins.
- **FFT_RESET (bit 1):** When set to 1, resets the FFT engine. This bit is automatically cleared after reset is complete.
- **BUFFER_SWAP (bit 2):** When set to 1, swaps the active input/output buffer pair.
- **MODE_SEL (bit 3):** Selects interface mode (0=APB interface active, 1=AXI interface active).
- **SCALING_EN (bit 4):** When set to 1, enables output scaling to prevent overflow.
- **BIT_REVERSE_EN (bit 5):** When set to 1, enables bit-reverse addressing for output.
- **DEBUG_EN (bit 6):** When set to 1, enables debug mode for performance monitoring.
- **POWER_DOWN (bit 7):** When set to 1, powers down the FFT engine to save power.

### 4.2 FFT_STATUS Register (0x0004)

**Access:** Read Only  
**Reset Value:** 0x00000000

| Bits | Name | Access | Description |
|------|------|--------|-------------|
| [0] | FFT_BUSY | R | FFT computation in progress |
| [1] | FFT_DONE | R | FFT computation complete |
| [2] | FFT_ERROR | R | FFT computation error |
| [3] | BUFFER_ACTIVE | R | Active buffer indicator (0=A, 1=B) |
| [4] | PIPELINE_VALID | R | Pipeline valid signal |
| [5] | MEMORY_READY | R | Memory interface ready |
| [6] | TWIDDLE_READY | R | Twiddle factor ROM ready |
| [7] | POWER_STATE | R | Power state (0=active, 1=powered down) |
| [15:8] | STAGE_COUNT | R | Current pipeline stage |
| [23:16] | BUTTERFLY_COUNT | R | Current butterfly count |
| [31:24] | RESERVED | R | Reserved bits (read as 0) |

**Bit Descriptions:**

- **FFT_BUSY (bit 0):** Set to 1 when FFT computation is in progress.
- **FFT_DONE (bit 1):** Set to 1 when FFT computation is complete.
- **FFT_ERROR (bit 2):** Set to 1 when an error occurs during FFT computation.
- **BUFFER_ACTIVE (bit 3):** Indicates which buffer pair is currently active (0=buffer A, 1=buffer B).
- **PIPELINE_VALID (bit 4):** Set to 1 when the pipeline is valid and processing data.
- **MEMORY_READY (bit 5):** Set to 1 when the memory interface is ready for access.
- **TWIDDLE_READY (bit 6):** Set to 1 when the twiddle factor ROM is ready.
- **POWER_STATE (bit 7):** Indicates current power state (0=active, 1=powered down).
- **STAGE_COUNT (bits 15:8):** Current pipeline stage number (0-5).
- **BUTTERFLY_COUNT (bits 23:16):** Current butterfly operation count within the stage.

### 4.3 FFT_CONFIG Register (0x0008)

**Access:** Read/Write  
**Reset Value:** 0x00000000

| Bits | Name | Access | Description |
|------|------|--------|-------------|
| [11:0] | FFT_LENGTH_LOG2 | R/W | Log2 of FFT length (8-12) |
| [15:12] | RESERVED | R | Reserved bits |
| [16] | SCALING_MODE | R/W | Scaling mode (0=divide by 2, 1=divide by N) |
| [17] | ROUNDING_MODE | R/W | Rounding mode (0=truncate, 1=round) |
| [18] | SATURATION_EN | R/W | Enable saturation arithmetic |
| [19] | OVERFLOW_DETECT | R/W | Enable overflow detection |
| [20] | PIPELINE_FLUSH | R/W | Flush pipeline (auto-cleared) |
| [21] | MEMORY_OPTIMIZE | R/W | Enable memory access optimization |
| [22] | CLOCK_GATE_EN | R/W | Enable clock gating |
| [23] | DEBUG_TRACE | R/W | Enable debug trace output |
| [31:24] | RESERVED | R | Reserved bits (read as 0) |

**Bit Descriptions:**

- **FFT_LENGTH_LOG2 (bits 11:0):** Logarithm base 2 of the FFT length. Valid values are 8-12 (256-4096 points).
- **SCALING_MODE (bit 16):** Selects scaling mode for output (0=divide by 2 each stage, 1=divide by N at end).
- **ROUNDING_MODE (bit 17):** Selects rounding mode (0=truncate, 1=round to nearest).
- **SATURATION_EN (bit 18):** When set to 1, enables saturation arithmetic to prevent overflow.
- **OVERFLOW_DETECT (bit 19):** When set to 1, enables overflow detection and reporting.
- **PIPELINE_FLUSH (bit 20):** When set to 1, flushes the pipeline. This bit is automatically cleared.
- **MEMORY_OPTIMIZE (bit 21):** When set to 1, enables memory access optimization for better performance.
- **CLOCK_GATE_EN (bit 22):** When set to 1, enables clock gating for power savings.
- **DEBUG_TRACE (bit 23):** When set to 1, enables debug trace output for performance analysis.

### 4.4 FFT_LENGTH Register (0x000C)

**Access:** Read/Write  
**Reset Value:** 0x00000400 (1024)

| Bits | Name | Access | Description |
|------|------|--------|-------------|
| [15:0] | FFT_LENGTH | R/W | FFT length in points |
| [31:16] | RESERVED | R | Reserved bits (read as 0) |

**Bit Descriptions:**

- **FFT_LENGTH (bits 15:0):** The number of points in the FFT. Must be a power of 2 between 256 and 4096.

### 4.5 BUFFER_SEL Register (0x0010)

**Access:** Read/Write  
**Reset Value:** 0x00000000

| Bits | Name | Access | Description |
|------|------|--------|-------------|
| [0] | BUFFER_SWAP_EN | R/W | Enable automatic buffer swapping |
| [1] | BUFFER_A_ACTIVE | R/W | Force buffer A as active |
| [2] | BUFFER_B_ACTIVE | R/W | Force buffer B as active |
| [3] | DOUBLE_BUFFER_EN | R/W | Enable double buffering mode |
| [4] | BACKGROUND_LOAD | R/W | Enable background data loading |
| [5] | ATOMIC_SWAP | R/W | Enable atomic buffer swapping |
| [31:6] | RESERVED | R | Reserved bits (read as 0) |

**Bit Descriptions:**

- **BUFFER_SWAP_EN (bit 0):** When set to 1, enables automatic buffer swapping on FFT completion.
- **BUFFER_A_ACTIVE (bit 1):** When set to 1, forces buffer A to be the active buffer.
- **BUFFER_B_ACTIVE (bit 2):** When set to 1, forces buffer B to be the active buffer.
- **DOUBLE_BUFFER_EN (bit 3):** When set to 1, enables double buffering mode.
- **BACKGROUND_LOAD (bit 4):** When set to 1, enables background data loading into inactive buffer.
- **ATOMIC_SWAP (bit 5):** When set to 1, enables atomic buffer swapping to prevent data corruption.

### 4.6 INT_ENABLE Register (0x0014)

**Access:** Read/Write  
**Reset Value:** 0x00000000

| Bits | Name | Access | Description |
|------|------|--------|-------------|
| [0] | FFT_DONE_EN | R/W | Enable FFT completion interrupt |
| [1] | FFT_ERROR_EN | R/W | Enable FFT error interrupt |
| [2] | BUFFER_SWAP_EN | R/W | Enable buffer swap interrupt |
| [3] | OVERFLOW_EN | R/W | Enable overflow interrupt |
| [4] | TIMEOUT_EN | R/W | Enable timeout interrupt |
| [5] | DEBUG_EN | R/W | Enable debug interrupt |
| [31:6] | RESERVED | R | Reserved bits (read as 0) |

**Bit Descriptions:**

- **FFT_DONE_EN (bit 0):** When set to 1, enables FFT completion interrupt.
- **FFT_ERROR_EN (bit 1):** When set to 1, enables FFT error interrupt.
- **BUFFER_SWAP_EN (bit 2):** When set to 1, enables buffer swap interrupt.
- **OVERFLOW_EN (bit 3):** When set to 1, enables overflow interrupt.
- **TIMEOUT_EN (bit 4):** When set to 1, enables timeout interrupt.
- **DEBUG_EN (bit 5):** When set to 1, enables debug interrupt.

### 4.7 INT_STATUS Register (0x0018)

**Access:** Read Only  
**Reset Value:** 0x00000000

| Bits | Name | Access | Description |
|------|------|--------|-------------|
| [0] | FFT_DONE_PENDING | R/W | FFT completion interrupt pending |
| [1] | FFT_ERROR_PENDING | R/W | FFT error interrupt pending |
| [2] | BUFFER_SWAP_PENDING | R/W | Buffer swap interrupt pending |
| [3] | OVERFLOW_PENDING | R/W | Overflow interrupt pending |
| [4] | TIMEOUT_PENDING | R/W | Timeout interrupt pending |
| [5] | DEBUG_PENDING | R/W | Debug interrupt pending |
| [31:6] | RESERVED | R | Reserved bits (read as 0) |

**Bit Descriptions:**

- **FFT_DONE_PENDING (bit 0):** Set to 1 when FFT completion interrupt is pending. Write 1 to clear.
- **FFT_ERROR_PENDING (bit 1):** Set to 1 when FFT error interrupt is pending. Write 1 to clear.
- **BUFFER_SWAP_PENDING (bit 2):** Set to 1 when buffer swap interrupt is pending. Write 1 to clear.
- **OVERFLOW_PENDING (bit 3):** Set to 1 when overflow interrupt is pending. Write 1 to clear.
- **TIMEOUT_PENDING (bit 4):** Set to 1 when timeout interrupt is pending. Write 1 to clear.
- **DEBUG_PENDING (bit 5):** Set to 1 when debug interrupt is pending. Write 1 to clear.

## 5. Memory Interface

### 5.1 Data Format

#### Input Data Format

Input data is stored in 32-bit words with the following format:

```
[31:16] - Real component (16-bit signed)
[15:0]  - Imaginary component (16-bit signed)
```

#### Output Data Format

Output data is stored in 32-bit words with the same format as input data:

```
[31:16] - Real component (16-bit signed)
[15:0]  - Imaginary component (16-bit signed)
```

### 5.2 Memory Access Patterns

#### Sequential Access

For sequential data loading and reading:

```c
// Load input data sequentially
for (int i = 0; i < fft_length; i++) {
    uint32_t addr = INPUT_BUFFER_A_BASE + (i * 4);
    uint32_t data = (input_real[i] << 16) | (input_imag[i] & 0xFFFF);
    write_memory(addr, data);
}
```

#### Burst Access

For high-performance burst transfers:

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

Interrupts are generated based on the INT_ENABLE register settings:

```c
// Interrupt generation logic
always_comb begin
    fft_done_o = (fft_done && int_enable[0]) || int_status[0];
    fft_error_o = (fft_error && int_enable[1]) || int_status[1];
end
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
}
```

## 9. Error Handling

### 9.1 Error Codes

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

### 9.2 Error Recovery

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
            
        default:
            // Unknown error - reset everything
            write_reg(FFT_CTRL, 0x02);    // Reset FFT engine
            break;
    }
}
```

## 10. Performance Monitoring

### 10.1 Performance Counters

The FFT accelerator includes performance monitoring registers:

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
}
```

### 10.2 Debug Interface

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

## 11. Power Management

### 11.1 Power States

| State | Description | Power Consumption | Wake-up Time |
|-------|-------------|-------------------|--------------|
| Active | FFT computation | 100% | - |
| Idle | Waiting for start | 10% | 1 cycle |
| Sleep | Power-down mode | 1% | 100 cycles |

### 11.2 Power Control

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

## 12. Compliance and Standards

### 12.1 Interface Compliance

- **APB Interface:** Compliant with AMBA APB3 specification
- **AXI Interface:** Compliant with AMBA AXI4 specification
- **Reset Interface:** Compliant with AMBA reset specification

### 12.2 Timing Compliance

- **Setup Time:** 1.0 ns minimum
- **Hold Time:** 0.5 ns minimum
- **Clock-to-Q:** 2.0 ns maximum
- **Maximum Frequency:** 1 GHz

### 12.3 Power Compliance

- **Static Power:** < 1 mW
- **Dynamic Power:** < 50 mW at 1 GHz
- **Leakage Current:** < 1 μA

This API reference provides comprehensive information for programming and interfacing with the FFT hardware accelerator. For additional details, please refer to the user guide and architecture documents. 