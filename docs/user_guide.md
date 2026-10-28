# FFT Hardware Accelerator User Guide

**IP Name:** fast-fourier-transform-ip  
**Version:** 1.0.0  
**Created:** 2025-07-21T05:38:04Z  
**Updated:** 2025-07-21T05:38:04Z  
**Author:** Vyges IP Development Team  

## 1. Introduction

This user guide provides practical information for integrating and using the Fast Fourier Transform (FFT) hardware accelerator in your system. The FFT accelerator supports configurable power-of-two FFT lengths up to 1024 points over a single shared working memory, with memory-mapped interfaces.

### 1.1 Key Features

- **Configurable FFT Length:** 2 to 1024 points (log2(N) = 1 .. 10)
- **Data Precision:** 16-bit fixed-point (Q1.15) input/output data
- **Buffer Select / Swap:** Buffer-active status bit and buffer-swap interrupt (one shared working memory)
- **Memory Mapped:** APB register, twiddle and sample windows (the AXI port is tied off)
- **Timing:** 6 cycles per butterfly (one memory access per cycle, not pipelined), results in natural order
- **Interrupt Support:** Completion and error notification
- **Automatic Rescaling:** Per-stage halving to prevent overflow during computation
- **Scale Factor Tracking:** Number of scaled stages, for signal reconstruction

### 1.2 System Requirements

- **Clock Frequency:** Up to 1 GHz
- **Memory:** 2048 × 32-bit working memory (1024 data words + 512 twiddle words used) for a 1024-point FFT
- **Interface:** APB or AXI bus support
- **Power:** < 50 mW typical at 1 GHz

## 2. Integration Guide

### 2.1 Module Instantiation

#### Basic APB Interface Instantiation

```verilog
// FFT Accelerator with APB Interface
fft_top #(
    .FFT_MAX_LENGTH_LOG2(10),    // 1024 points; the memory holds at most 1024
    .FFT_DATA_WIDTH(16),         // 16-bit data precision
    .FFT_TWIDDLE_WIDTH(16),      // 16-bit twiddle factors
    .FFT_APB_ADDR_WIDTH(16)      // 16-bit APB address
) fft_inst (
    // Clock and Reset
    .clk_i(clk),
    .reset_n_i(reset_n),
    
    // APB Interface
    .pclk_i(pclk),
    .preset_n_i(preset_n),
    .psel_i(psel),
    .penable_i(penable),
    .pwrite_i(pwrite),
    .paddr_i(paddr),
    .pwdata_i(pwdata),
    .prdata_o(prdata),
    .pready_o(pready),
    
    // Interrupts
    .fft_done_o(fft_done),
    .fft_error_o(fft_error)
);
```

#### AXI Interface Instantiation

```verilog
// FFT Accelerator with AXI Interface
// Note: the AXI port is tied off in the current RTL (ready outputs held
// high, read data 0, rvalid 0). Use the APB interface for all access.
fft_top #(
    .FFT_MAX_LENGTH_LOG2(10),    // 1024 points; the memory holds at most 1024
    .FFT_DATA_WIDTH(16),         // 16-bit data precision
    .FFT_TWIDDLE_WIDTH(16),      // 16-bit twiddle factors
    .FFT_AXI_ADDR_WIDTH(32),     // 32-bit AXI address
    .FFT_AXI_DATA_WIDTH(64)      // 64-bit AXI data
) fft_inst (
    // Clock and Reset
    .clk_i(clk),
    .reset_n_i(reset_n),
    
    // AXI Interface
    .axi_aclk_i(axi_aclk),
    .axi_areset_n_i(axi_areset_n),
    .axi_awaddr_i(axi_awaddr),
    .axi_awvalid_i(axi_awvalid),
    .axi_awready_o(axi_awready),
    .axi_wdata_i(axi_wdata),
    .axi_wvalid_i(axi_wvalid),
    .axi_wready_o(axi_wready),
    .axi_araddr_i(axi_araddr),
    .axi_arvalid_i(axi_arvalid),
    .axi_arready_o(axi_arready),
    .axi_rdata_o(axi_rdata),
    .axi_rvalid_o(axi_rvalid),
    .axi_rready_i(axi_rready),
    
    // Interrupts
    .fft_done_o(fft_done),
    .fft_error_o(fft_error)
);
```

### 2.2 Clock and Reset Configuration

#### Clock Requirements

- **System Clock:** 100 MHz to 1 GHz
- **Clock Stability:** ±100 ppm maximum
- **Clock Duty Cycle:** 45% to 55%
- **Clock Jitter:** < 100 ps RMS

#### Reset Configuration

```verilog
// Reset generation example
always_ff @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        fft_reset_n <= 1'b0;
        reset_counter <= 8'h00;
    end else begin
        if (reset_counter < 8'hFF) begin
            reset_counter <= reset_counter + 1'b1;
            fft_reset_n <= 1'b0;
        end else begin
            fft_reset_n <= 1'b1;
        end
    end
end
```

### 2.3 Memory Mapping

#### APB Memory Map

| Address Range | Register/Memory | Access | Description |
|---------------|-----------------|--------|-------------|
| 0x0000-0x0003 | FFT_CTRL | R/W | FFT Control Register |
| 0x0004-0x0007 | FFT_STATUS | R | FFT Status Register |
| 0x0008-0x000B | FFT_CONFIG | R/W | FFT Configuration Register |
| 0x000C-0x000F | FFT_LENGTH | R/W | FFT Length Register |
| 0x0010-0x0013 | BUFFER_SEL | R/W | Buffer Selection Register |
| 0x0014-0x0017 | INT_ENABLE | R/W | Interrupt Enable Register |
| 0x0018-0x001B | INT_STATUS | RW1C | Interrupt Status Register (write 1 to clear a pending bit) |
| 0x001C-0x001F | SCALE_FACTOR | R | Output Scale Factor Register |
| 0x0020-0x0023 | RESCALE_CTRL | R/W | Rescaling Control Register (stored and readable; not used by the engine) |
| 0x0024-0x0027 | OVERFLOW_STATUS | R | Overflow Status Register |
| 0x0800-0x0FFC | Twiddle window | W | 512 twiddle words, word k = paddr[10:2] |
| 0x1000-0x1FFC | Sample window | W | 1024 sample words, word i = paddr[11:2] (only with `FFT_USE_APB_DATA`) |

The windows are write-only; there is no APB readback of samples or results. Results leave through the configured memory backend or the stream-out port (`FFT_USE_STREAM_OUT`). Registers decode at 0x0000-0x07FC (paddr[12:11] = 00).

#### AXI Memory Map

The AXI port is tied off in the current RTL; the table below is not implemented.

| Address Range | Register/Memory | Access | Description |
|---------------|-----------------|--------|-------------|
| 0x0000-0x0007 | FFT_CTRL | R/W | FFT Control Register |
| 0x0008-0x000F | FFT_STATUS | R | FFT Status Register |
| 0x0010-0x0017 | FFT_CONFIG | R/W | FFT Configuration Register |
| 0x0018-0x001F | FFT_LENGTH | R/W | FFT Length Register |
| 0x0020-0x0027 | BUFFER_SEL | R/W | Buffer Selection Register |
| 0x0028-0x002F | INT_ENABLE | R/W | Interrupt Enable Register |
| 0x0030-0x0037 | INT_STATUS | R | Interrupt Status Register |
| 0x0038-0x003F | SCALE_FACTOR | R | Output Scale Factor Register |
| 0x0040-0x0047 | RESCALE_CTRL | R/W | Rescaling Control Register |
| 0x0048-0x004F | OVERFLOW_STATUS | R | Overflow Status Register |
| 0x1000-0x1FFF | Input Buffer A | R/W | Input data buffer A |
| 0x2000-0x2FFF | Input Buffer B | R/W | Input data buffer B |
| 0x3000-0x3FFF | Output Buffer A | R | Output data buffer A |
| 0x4000-0x4FFF | Output Buffer B | R | Output data buffer B |

## 3. Programming Guide

### 3.1 Basic FFT Operation

#### Step 1: Configure FFT Parameters

```c
// Configure FFT length (1024 points)
#define FFT_LENGTH_LOG2    10
#define FFT_LENGTH         (1 << FFT_LENGTH_LOG2)

// Write FFT configuration
write_reg(FFT_CONFIG, FFT_LENGTH_LOG2);
write_reg(FFT_LENGTH, FFT_LENGTH);

// Configure rescaling (optional but recommended)
configure_fft_rescaling();
```

#### Step 2: Load Input Data

```c
// Load input data through the sample window (FFT_USE_APB_DATA).
// Word format: {imag[31:16], real[15:0]}, Q1.15.
for (int i = 0; i < FFT_LENGTH; i++) {
    uint32_t addr = FFT_SAMPLE_WINDOW_BASE + (i * 4);   // 0x1000
    uint32_t data = ((uint32_t)(uint16_t)input_imag[i] << 16) | (uint16_t)input_real[i];
    write_memory(addr, data);
}
```

#### Step 3: Start FFT Computation

```c
// Start FFT computation: pulse FFT_START (write 1, then 0).
// FFT_CONFIG and the FFT_CTRL run bits are latched at this point.
write_reg(FFT_CTRL, read_reg(FFT_CTRL) | 0x01);
write_reg(FFT_CTRL, read_reg(FFT_CTRL) & ~0x01);

// Wait for completion. FFT_DONE (bit 1) and FFT_ERROR (bit 2) hold
// until the next run starts.
while (!(read_reg(FFT_STATUS) & 0x06)) {
    // Wait for FFT_DONE or FFT_ERROR
}
```

#### Step 4: Read Results

```c
// Read output data through the configured memory backend (or receive it
// on the stream-out port). Results are in natural order: bin k is word k.
for (int i = 0; i < FFT_LENGTH; i++) {
    uint32_t data = read_result_word(i);   // backend-specific
    output_real[i] = (int16_t)(data & 0xFFFF);
    output_imag[i] = (int16_t)(data >> 16);
}

// Read scale factor information
read_scale_factor_info();

// Optionally reconstruct original signal magnitude
if (rescaling_enabled) {
    reconstruct_signal(output_data, FFT_LENGTH);
}
```

### 3.2 Buffer Select and Swap

#### Step 1: Configure Buffer Select

The engine works in place on one shared working memory. BUFFER_SEL and FFT_CTRL[2] (buffer swap) drive only the FFT_STATUS buffer_active bit and the buffer-swap interrupt; software uses them to track which of its own buffers is current. Loading new samples while a run is in progress collides with the engine on the single write port (see firmware-integration.md), so load between runs.

```c
// Select buffer A in the status bit; enable the completion interrupt
write_reg(BUFFER_SEL, 0x01);
write_reg(INT_ENABLE, 0x01);
```

#### Step 2: Load Data into Background Buffer

```c
// Load the next block after the previous run has completed
for (int i = 0; i < FFT_LENGTH; i++) {
    uint32_t addr = FFT_SAMPLE_WINDOW_BASE + (i * 4);
    uint32_t data = ((uint32_t)(uint16_t)input_imag[i] << 16) | (uint16_t)input_real[i];
    write_memory(addr, data);
}
```

#### Step 3: Start Processing and Switch Buffers

```c
// Start FFT computation (pulse FFT_START)
write_reg(FFT_CTRL, 0x01);
write_reg(FFT_CTRL, 0x00);

// Wait for completion interrupt
while (!interrupt_received) {
    // Wait for FFT_DONE interrupt
}

// Toggle the buffer_active status bit (rising edge of BUFFER_SWAP)
write_reg(FFT_CTRL, 0x04);
write_reg(FFT_CTRL, 0x00);
```

### 3.3 Rescaling Configuration

#### Enable Automatic Rescaling

```c
// Configure rescaling functionality
void configure_fft_rescaling(void) {
    // Enable automatic rescaling
    write_reg(FFT_CTRL, read_reg(FFT_CTRL) | 0x10);  // Set RESCALE_EN
    
    // Enable scale factor tracking
    write_reg(FFT_CTRL, read_reg(FFT_CTRL) | 0x20);  // Set SCALE_TRACK_EN
    
    // Set rescaling mode (0 = halve a stage only when one of its inputs lies
    // outside [-2^13, 2^13); 1 = halve every stage, result X/N)
    write_reg(FFT_CONFIG, read_reg(FFT_CONFIG) & ~0x10000);  // Mode 0
    
    // Rescaling needs both FFT_CTRL[4] and FFT_CONFIG[19]. Both registers
    // are latched when the run starts.
    
    // Enable overflow detection
    write_reg(FFT_CONFIG, read_reg(FFT_CONFIG) | 0x80000);  // Set OVERFLOW_DETECT
}
```

#### Read Scale Factor Information

```c
// Read and display scale factor information
void read_scale_factor_info(void) {
    uint32_t scale_factor_reg = read_reg(SCALE_FACTOR);
    uint8_t total_scale = scale_factor_reg & 0xFF;
    uint8_t stage_count = (scale_factor_reg >> 8) & 0xFF;
    uint8_t overflow_count = (scale_factor_reg >> 24) & 0xFF;
    
    // total_scale = number of scaled stages (never more than log2(N));
    // output = true FFT / 2^total_scale.
    printf("Scale Factor: %d (2^%d)\n", 1 << total_scale, total_scale);
    printf("Stages Processed: %d\n", stage_count);
    printf("Overflowing Butterflies: %d\n", overflow_count);  // saturates at 255
}
```

#### Reconstruct Original Signal Magnitude

```c
// Apply inverse scaling to restore original signal magnitude.
// The rescaled value needs more than 16 bits, so widen to 32-bit.
void reconstruct_signal(const uint32_t *output_data, int32_t *re, int32_t *im,
                        uint32_t length) {
    uint32_t scale_factor_reg = read_reg(SCALE_FACTOR);
    uint8_t total_scale = scale_factor_reg & 0xFF;
    
    for (int i = 0; i < length; i++) {
        int16_t real_part = (int16_t)(output_data[i] & 0xFFFF);
        int16_t imag_part = (int16_t)(output_data[i] >> 16);
        
        // Output = true FFT / 2^total_scale
        re[i] = (int32_t)real_part * (1 << total_scale);
        im[i] = (int32_t)imag_part * (1 << total_scale);
    }
}
```

### 3.4 Interrupt Handling

#### Interrupt Service Routine

INT_STATUS is write-1-to-clear. A pending bit is set on its event while the matching INT_ENABLE bit is set and stays set until software writes 1 to it. Bits: [0] done (end of a run), [1] error (rejected length), [2] buffer swap (FFT_CTRL[2] rising), [3] overflow (first overflow of a run), [4] rescale (a scaled stage starts). The `fft_done_o` / `fft_error_o` outputs are one-cycle pulses gated by INT_ENABLE[0] / [1].

```c
void fft_interrupt_handler(void) {
    uint32_t int_status = read_reg(INT_STATUS);
    
    if (int_status & 0x01) {
        // FFT completion interrupt
        fft_complete = true;
        
        // Clear interrupt
        write_reg(INT_STATUS, 0x01);
    }
    
    if (int_status & 0x02) {
        // FFT error interrupt
        fft_error = true;
        
        // Clear interrupt
        write_reg(INT_STATUS, 0x02);
    }
    
    if (int_status & 0x08) {
        // Overflow interrupt
        printf("Overflow detected during FFT computation\n");
        write_reg(INT_STATUS, 0x08);  // Clear interrupt
    }
    
    if (int_status & 0x10) {
        // Rescaling interrupt
        printf("Rescaling applied during FFT computation\n");
        write_reg(INT_STATUS, 0x10);  // Clear interrupt
    }
}
```

#### Interrupt Configuration

```c
// Configure interrupt handling
void configure_fft_interrupts(void) {
    // Enable FFT completion interrupt
    write_reg(INT_ENABLE, 0x01);
    
    // Enable overflow interrupt
    write_reg(INT_ENABLE, read_reg(INT_ENABLE) | 0x08);
    
    // Enable rescaling interrupt
    write_reg(INT_ENABLE, read_reg(INT_ENABLE) | 0x10);
    
    // Register interrupt handler
    register_interrupt_handler(FFT_IRQ_NUM, fft_interrupt_handler);
    
    // Enable interrupts globally
    enable_interrupts();
}
```

## 4. Performance Optimization

### 4.1 Throughput Optimization

#### Optimal FFT Length Selection

| Application | Recommended FFT Length | Cycles per run (approx.) |
|-------------|----------------------|-------------------|
| Audio Processing | 1024 | 36.8k-37.8k |
| Communication | 1024 | 36.8k-37.8k |
| Real-time DSP | 512 | 17.3k |
| Low latency | 256 | 7.6k-7.9k |

Cycle counts are measured from the start pulse to the last streamed bin. Throughput in samples per second is N × f_clk / cycles.

#### Memory Access Optimization

BURST_CONFIG is not implemented in the current RTL: reads return 0 and writes are ignored. APB accepts one word per transfer.

```c
// Burst transfer for improved performance
void burst_load_input_data(uint32_t *input_data, uint32_t length) {
    // Configure burst transfer
    write_reg(BURST_CONFIG, 0x01);
    
    // Perform burst write
    for (int i = 0; i < length; i += 4) {
        burst_write(FFT_SAMPLE_WINDOW_BASE + i, &input_data[i], 4);
    }
}
```

### 4.2 Power Management

#### Dynamic Power Control

```c
// Power management functions
void fft_power_down(void) {
    // Abort any run: the engine is idle on the next cycle and issues
    // no further memory write
    write_reg(FFT_CTRL, 0x02);  // Set FFT_RESET bit
    
    while (read_reg(FFT_STATUS) & 0x01) {
        // Wait for FFT_BUSY to clear
    }
}

void fft_power_up(void) {
    // Clear reset
    write_reg(FFT_CTRL, 0x00);
    
    // Wait for power up
    delay_ms(10);
}
```

#### Clock Gating Control

POWER_CTRL is not implemented in the current RTL: reads return 0 and writes are ignored.

```c
// Enable clock gating for power savings
void enable_clock_gating(void) {
    write_reg(POWER_CTRL, 0x01);  // Enable clock gating
}

void disable_clock_gating(void) {
    write_reg(POWER_CTRL, 0x00);  // Disable clock gating
}
```

## 5. Error Handling

### 5.1 Error Detection and Recovery

#### Error Types and Handling

The engine reports one error: a length rejected at launch. FFT_CONFIG[11:0] must be log2(N) in 1 .. min(FFT_MAX_LENGTH_LOG2, 10). A value of 0 or above the maximum sends the engine to ERROR for one cycle; FFT_STATUS[2] is set and holds until the next run starts, INT_STATUS[1] / `fft_error_o` fire if INT_ENABLE[1] is set, and nothing is computed. There is no error-code register. Overflow during computation is not an error; it is reported through FFT_STATUS[5], the overflow counters and INT_STATUS[3].

```c
typedef enum {
    FFT_ERROR_NONE = 0,
    FFT_ERROR_INVALID_LENGTH
} fft_error_t;

fft_error_t check_fft_error(void) {
    uint32_t status = read_reg(FFT_STATUS);
    
    if (status & 0x04) {
        return FFT_ERROR_INVALID_LENGTH;  // the only error source
    }
    
    return FFT_ERROR_NONE;
}
```

#### Error Recovery Procedures

```c
void recover_from_fft_error(fft_error_t error) {
    switch (error) {
        case FFT_ERROR_INVALID_LENGTH:
            // Write a legal log2(N) and start again
            write_reg(FFT_CONFIG, (read_reg(FFT_CONFIG) & ~0xFFF) | 10);
            write_reg(FFT_LENGTH, 1024);
            write_reg(FFT_CTRL, 0x01);  // Restart FFT (pulse)
            write_reg(FFT_CTRL, 0x00);
            break;
            
        default:
            break;
    }
}
```

### 5.2 Debug and Diagnostics

#### Performance Monitoring

CYCLE_COUNT and POWER_MONITOR are not implemented in the current RTL: reads return 0. Measure cycles with a host timer between the start pulse and FFT_DONE.

```c
// Performance monitoring functions
uint32_t get_fft_cycle_count(void) {
    return read_reg(CYCLE_COUNT);
}

uint32_t get_fft_throughput(void) {
    uint32_t cycles = get_fft_cycle_count();
    uint32_t length = read_reg(FFT_LENGTH);
    return (length * 1000000) / cycles;  // MSPS
}

void print_fft_performance(void) {
    printf("FFT Performance:\n");
    printf("  Cycle Count: %u\n", get_fft_cycle_count());
    printf("  Throughput: %u MSPS\n", get_fft_throughput());
    printf("  Power Consumption: %u mW\n", read_reg(POWER_MONITOR));
    
    // Rescaling statistics
    uint32_t scale_factor_reg = read_reg(SCALE_FACTOR);
    uint8_t total_scale = scale_factor_reg & 0xFF;
    uint8_t overflow_count = (scale_factor_reg >> 24) & 0xFF;
    printf("  Total Scale Factor: 2^%d\n", total_scale);
    printf("  Overflow Events: %d\n", overflow_count);
}
```

#### Debug Interface

DEBUG_CTRL, DEBUG_BREAKPOINT, DEBUG_ADDR and DEBUG_DATA are not implemented in the current RTL: reads return 0 and writes are ignored.

```c
// Debug interface functions
void enable_debug_mode(void) {
    write_reg(DEBUG_CTRL, 0x01);  // Enable debug mode
}

void set_debug_breakpoint(uint32_t stage, uint32_t condition) {
    write_reg(DEBUG_BREAKPOINT, (stage << 8) | condition);
}

uint32_t read_debug_data(uint32_t address) {
    write_reg(DEBUG_ADDR, address);
    return read_reg(DEBUG_DATA);
}
```

## 6. Application Examples

### 6.1 Audio Processing Application

```c
// Audio FFT processing example
void process_audio_fft(int16_t *audio_samples, uint32_t num_samples) {
    // Configure for 1024-point FFT
    write_reg(FFT_LENGTH, 1024);
    write_reg(FFT_CONFIG, 10);  // log2(1024)
    
    // Load audio samples (real only: imag = 0 in [31:16])
    for (int i = 0; i < 1024; i++) {
        uint32_t addr = FFT_SAMPLE_WINDOW_BASE + (i * 4);
        uint32_t data = (uint16_t)audio_samples[i];
        write_memory(addr, data);
    }
    
    // Start FFT computation (pulse)
    write_reg(FFT_CTRL, 0x01);
    write_reg(FFT_CTRL, 0x00);
    
    // Wait for completion (FFT_DONE holds until the next run)
    while (!(read_reg(FFT_STATUS) & 0x02)) {
        // Wait for completion
    }
    
    // Read frequency domain data (natural order, backend-specific read)
    for (int i = 0; i < 1024; i++) {
        uint32_t data = read_result_word(i);
        int16_t re = (int16_t)(data & 0xFFFF);
        int16_t im = (int16_t)(data >> 16);
        frequency_magnitude[i] = sqrt(re * re + im * im);
    }
}
```

### 6.2 Communication System Application

```c
// OFDM communication system example
void process_ofdm_symbol(complex_t *symbol_data, uint32_t fft_size) {
    // Configure FFT for OFDM symbol size
    uint32_t log2_size = log2(fft_size);
    write_reg(FFT_LENGTH, fft_size);
    write_reg(FFT_CONFIG, log2_size);
    
    // Load OFDM symbol data ({imag[31:16], real[15:0]}); fft_size <= 1024
    for (int i = 0; i < fft_size; i++) {
        uint32_t addr = FFT_SAMPLE_WINDOW_BASE + (i * 4);
        uint32_t data = ((uint32_t)(uint16_t)symbol_data[i].imag << 16)
                      | (uint16_t)symbol_data[i].real;
        write_memory(addr, data);
    }
    
    // Start FFT computation (pulse)
    write_reg(FFT_CTRL, 0x01);
    write_reg(FFT_CTRL, 0x00);
    
    // Wait for completion with timeout (a 1024-point run is ~38k engine
    // cycles; size the timeout to the polling loop's speed)
    uint32_t timeout = 0;
    while (!(read_reg(FFT_STATUS) & 0x02) && (timeout < 10000)) {
        timeout++;
    }
    
    if (timeout >= 10000) {
        // Handle timeout error
        handle_fft_timeout();
        return;
    }
    
    // Read frequency domain data (natural order, backend-specific read)
    for (int i = 0; i < fft_size; i++) {
        uint32_t data = read_result_word(i);
        frequency_domain[i].real = (int16_t)(data & 0xFFFF);
        frequency_domain[i].imag = (int16_t)(data >> 16);
    }
}
```

### 6.3 Real-time DSP Application

```c
// Real-time DSP with double buffering
typedef struct {
    uint32_t buffer_a_active;
    uint32_t processing_complete;
    uint32_t data_ready;
} fft_context_t;

fft_context_t fft_ctx = {0};

void real_time_dsp_init(void) {
    // Configure for 512-point FFT (real-time processing)
    write_reg(FFT_LENGTH, 512);
    write_reg(FFT_CONFIG, 9);  // log2(512)
    
    // Select buffer A in the status bit; enable the completion interrupt
    write_reg(BUFFER_SEL, 0x01);
    write_reg(INT_ENABLE, 0x01);
    
    // Register interrupt handler
    register_interrupt_handler(FFT_IRQ_NUM, fft_interrupt_handler);
}

void real_time_dsp_process(int16_t *input_data) {
    // Load the block into the working memory (one shared memory; load
    // only while the engine is idle)
    for (int i = 0; i < 512; i++) {
        uint32_t addr = FFT_SAMPLE_WINDOW_BASE + (i * 4);
        uint32_t data = (uint16_t)input_data[i];  // real only
        write_memory(addr, data);
    }
    
    // Start FFT computation (pulse)
    write_reg(FFT_CTRL, 0x01);
    write_reg(FFT_CTRL, 0x00);
    
    // Track which software buffer is current
    fft_ctx.buffer_a_active = !fft_ctx.buffer_a_active;
    
    // Wait for processing to complete
    while (!fft_ctx.processing_complete) {
        // Wait for interrupt
    }
    
    fft_ctx.processing_complete = false;
}
```

## 7. Troubleshooting

### 7.1 Common Issues and Solutions

#### Issue: FFT Computation Hangs

**Symptoms:** FFT_BUSY remains high indefinitely

**Possible Causes:**
- FFT_START left high: the engine starts a new run as soon as one finishes, so FFT_BUSY is high again almost at once
- Memory backend not returning read data on the expected cycle (read data must arrive two cycles after the engine issues the address)
- Clock frequency too high

An invalid length does not hang the engine: it is rejected at launch and FFT_STATUS[2] (error) is set.

**Solutions:**
```c
// Check FFT configuration (legal log2(N) is 1 .. 10)
uint32_t config = read_reg(FFT_CONFIG);
if ((config & 0xFFF) == 0 || (config & 0xFFF) > 10) {
    // Invalid FFT length
    write_reg(FFT_CONFIG, 10);  // Set to 1024 points
}

// Reset FFT engine
write_reg(FFT_CTRL, 0x02);  // Set reset bit
delay_ms(10);
write_reg(FFT_CTRL, 0x00);  // Clear reset bit
```

#### Issue: Incorrect FFT Results

**Symptoms:** FFT output values are incorrect

**Possible Causes:**
- Input data format mismatch
- Twiddle factor corruption
- Memory alignment issues

**Solutions:**
```c
// Verify input data format: {imag[31:16], real[15:0]}. The sample
// window is write-only, so check the words before they are written.
for (int i = 0; i < FFT_LENGTH; i++) {
    uint32_t data = input_words[i];
    printf("Input[%d]: real=%d, imag=%d\n", 
           i, (int16_t)(data & 0xFFFF), (int16_t)(data >> 16));
}

// Verify the twiddle table is loaded. The engine reads twiddle k from
// fft_memory[1024 + k], populated by firmware via APB writes to the
// twiddle window 0x0800-0x0FFC at boot. There is no ROM — see firmware-integration.md
// for the load sequence. Reading back the APB twiddle window itself is
// write-only; verify the load via a known-pattern FFT (constant input
// produces a single impulse at bin 0).
```

#### Issue: Interrupt Not Generated

**Symptoms:** FFT completes but no interrupt received

**Possible Causes:**
- Interrupt not enabled
- Interrupt controller misconfiguration
- Interrupt signal routing issue

**Solutions:**
```c
// Check interrupt enable status
uint32_t int_enable = read_reg(INT_ENABLE);
printf("Interrupt enable: 0x%08X\n", int_enable);

// Enable interrupts
write_reg(INT_ENABLE, 0x01);

// Check interrupt status. Pending bits are set only while the matching
// INT_ENABLE bit is set; they stay set until written with 1.
uint32_t int_status = read_reg(INT_STATUS);
printf("Interrupt status: 0x%08X\n", int_status);
write_reg(INT_STATUS, int_status);  // clear what was seen
```

### 7.2 Performance Issues

#### Issue: Low Throughput

**Symptoms:** FFT computation takes longer than expected

**Possible Causes:**
- Clock frequency too low
- Memory bandwidth limitation (the engine needs one memory access every cycle; a butterfly takes 6 cycles)
- Memory backend stalls (`mem_ready` low)

MEMORY_LATENCY and MEMORY_OPTIMIZE are not implemented in the current RTL: reads return 0 and writes are ignored.

**Solutions:**
```c
// Check clock frequency
uint32_t clock_freq = get_system_clock_frequency();
printf("System clock: %u MHz\n", clock_freq / 1000000);

// Check memory access patterns
uint32_t memory_latency = read_reg(MEMORY_LATENCY);
printf("Memory latency: %u cycles\n", memory_latency);

// Optimize memory access
write_reg(MEMORY_OPTIMIZE, 0x01);  // Enable memory optimization
```

### 7.3 Power Issues

#### Issue: High Power Consumption

**Symptoms:** Power consumption exceeds specifications

**Possible Causes:**
- Clock gating disabled
- Unused modules active
- High switching activity

POWER_CTRL and POWER_MONITOR are not implemented in the current RTL: reads return 0 and writes are ignored.

**Solutions:**
```c
// Enable power management features
write_reg(POWER_CTRL, 0x01);  // Enable clock gating
write_reg(POWER_CTRL, 0x02);  // Enable power down modes

// Check power consumption
uint32_t power_consumption = read_reg(POWER_MONITOR);
printf("Power consumption: %u mW\n", power_consumption);
```

## 8. Reference Information

### 8.1 Register Reference

#### Control Registers

| Register | Address | Bits | Description |
|----------|---------|------|-------------|
| FFT_CTRL | 0x0000 | [0] | FFT_START - Start FFT computation |
| | | [1] | FFT_RESET - Reset FFT engine |
| | | [2] | BUFFER_SWAP - Swap input/output buffers |
| | | [3] | RESERVED - Not used |
| | | [4] | RESCALE_EN - Enable automatic rescaling (with FFT_CONFIG[19]) |
| | | [5] | SCALE_TRACK_EN - Enable scale factor tracking |
| | | [7:6] | RESERVED - Reserved bits |
| | | [8] | STREAM_ENABLE - Arm the bin streamer (`FFT_USE_STREAM_OUT` builds only) |
| | | [31:9] | RESERVED - Reserved bits |

FFT_START launches a run when it is high while the engine is idle. FFT_RESET aborts a run. FFT_CTRL[5:4] and FFT_CONFIG are latched at launch; writes during a run apply to the next run.

#### Status Registers

| Register | Address | Bits | Description |
|----------|---------|------|-------------|
| FFT_STATUS | 0x0004 | [0] | FFT_BUSY - FFT computation in progress |
| | | [1] | FFT_DONE - FFT computation complete; holds until the next run starts |
| | | [2] | FFT_ERROR - Length rejected at launch; holds until the next run starts |
| | | [3] | BUFFER_ACTIVE - Active buffer indicator |
| | | [4] | RESCALE_ACTIVE - High while a scaled stage is being computed |
| | | [5] | OVERFLOW_DETECTED - Set once any butterfly in the run overflowed |
| | | [13:6] | SCALE_FACTOR - Number of scaled stages |
| | | [21:14] | STAGE_COUNT - Stages completed in the run |
| | | [29:22] | OVERFLOW_COUNT - Overflowing butterflies (saturates at 255) |
| | | [31:30] | RESERVED - Reserved bits |

### 8.2 Timing Specifications

#### FFT Computation Timing

| FFT Length | Butterfly Count | Total Cycles (approx.) | Latency (μs @ 1GHz) |
|------------|----------------|--------------|---------------------|
| 256 | 1,024 | 7,600-7,900 | 7.6-7.9 |
| 512 | 2,304 | 17,300 | 17.3 |
| 1024 | 5,120 | 36,800-37,800 | 36.8-37.8 |

Total cycles are measured from the start pulse to the last streamed bin: about 6 × (N/2) × log2(N) for the butterflies, plus about 3N for the bit-reverse pass, plus N+2 for the input scan when rescale mode 0 is on. Butterflies are executed one after another, 6 cycles each; they are not overlapped.

#### Interface Timing

| Interface | Clock Frequency | Data Width | Bandwidth |
|-----------|----------------|------------|-----------|
| APB | Up to 100 MHz | 32-bit | 400 MB/s |
| AXI | Up to 1 GHz | 64-bit | 8 GB/s |

### 8.3 Power Specifications

#### Power Consumption

| Operating Mode | Power Consumption | Conditions |
|----------------|-------------------|------------|
| Active | 50 mW | 1 GHz, 1024-point FFT |
| Idle | 5 mW | Clock gated, memory active |
| Sleep | 0.5 mW | All domains powered down |

#### Thermal Specifications

| Parameter | Value | Unit |
|-----------|-------|------|
| Junction Temperature | -40 to +125 | °C |
| Thermal Resistance | 50 | °C/W |
| Power Dissipation | 50 | mW |

This user guide provides comprehensive information for integrating and using the FFT hardware accelerator. For additional support, please refer to the architecture document and design specification, or contact the Vyges IP development team. 