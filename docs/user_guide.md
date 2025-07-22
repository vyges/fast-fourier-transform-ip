# FFT Hardware Accelerator User Guide

**IP Name:** fast-fourier-transform-ip  
**Version:** 1.0.0  
**Created:** 2025-07-21T05:38:04Z  
**Updated:** 2025-07-21T05:38:04Z  
**Author:** Vyges IP Development Team  

## 1. Introduction

This user guide provides practical information for integrating and using the Fast Fourier Transform (FFT) hardware accelerator in your system. The FFT accelerator supports configurable FFT lengths from 256 to 4096 points with double-buffered memory architecture and memory-mapped interfaces.

### 1.1 Key Features

- **Configurable FFT Length:** 256, 512, 1024, 2048, 4096 points
- **Data Precision:** 16-bit fixed-point input/output data
- **Double Buffering:** Background data transfer capability
- **Memory Mapped:** APB and AXI interface support
- **High Performance:** 6 cycles per butterfly operation
- **Interrupt Support:** Completion and error notification
- **Automatic Rescaling:** Prevents overflow during computation
- **Scale Factor Tracking:** Enables proper signal reconstruction

### 1.2 System Requirements

- **Clock Frequency:** Up to 1 GHz
- **Memory:** Minimum 64 KB for 4096-point FFT
- **Interface:** APB or AXI bus support
- **Power:** < 50 mW typical at 1 GHz

## 2. Integration Guide

### 2.1 Module Instantiation

#### Basic APB Interface Instantiation

```verilog
// FFT Accelerator with APB Interface
fft_top #(
    .FFT_MAX_LENGTH_LOG2(12),    // Support up to 4096 points
    .DATA_WIDTH(16),             // 16-bit data precision
    .TWIDDLE_WIDTH(16),          // 16-bit twiddle factors
    .APB_ADDR_WIDTH(16)          // 16-bit APB address
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
fft_top #(
    .FFT_MAX_LENGTH_LOG2(12),    // Support up to 4096 points
    .DATA_WIDTH(16),             // 16-bit data precision
    .TWIDDLE_WIDTH(16),          // 16-bit twiddle factors
    .AXI_ADDR_WIDTH(32),         // 32-bit AXI address
    .AXI_DATA_WIDTH(64)          // 64-bit AXI data
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
| 0x0018-0x001B | INT_STATUS | R | Interrupt Status Register |
| 0x001C-0x001F | SCALE_FACTOR | R | Output Scale Factor Register |
| 0x0020-0x0023 | RESCALE_CTRL | R/W | Rescaling Control Register |
| 0x0024-0x0027 | OVERFLOW_STATUS | R | Overflow Status Register |
| 0x1000-0x1FFF | Input Buffer A | R/W | Input data buffer A |
| 0x2000-0x2FFF | Input Buffer B | R/W | Input data buffer B |
| 0x3000-0x3FFF | Output Buffer A | R | Output data buffer A |
| 0x4000-0x4FFF | Output Buffer B | R | Output data buffer B |

#### AXI Memory Map

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
// Load input data into buffer A
for (int i = 0; i < FFT_LENGTH; i++) {
    uint32_t addr = INPUT_BUFFER_A_BASE + (i * 4);
    uint32_t data = (input_real[i] << 16) | input_imag[i];
    write_memory(addr, data);
}
```

#### Step 3: Start FFT Computation

```c
// Start FFT computation
write_reg(FFT_CTRL, 0x01);  // Set FFT_START bit

// Wait for completion
while (!(read_reg(FFT_STATUS) & 0x02)) {
    // Wait for FFT_DONE bit
}
```

#### Step 4: Read Results

```c
// Read output data from buffer A
for (int i = 0; i < FFT_LENGTH; i++) {
    uint32_t addr = OUTPUT_BUFFER_A_BASE + (i * 4);
    uint32_t data = read_memory(addr);
    output_real[i] = (int16_t)(data >> 16);
    output_imag[i] = (int16_t)(data & 0xFFFF);
}

// Read scale factor information
read_scale_factor_info();

// Optionally reconstruct original signal magnitude
if (rescaling_enabled) {
    reconstruct_signal(output_data, FFT_LENGTH);
}
```

### 3.2 Double Buffered Operation

#### Step 1: Configure Double Buffering

```c
// Enable double buffering
write_reg(BUFFER_SEL, 0x01);  // Enable buffer switching
write_reg(INT_ENABLE, 0x01);  // Enable completion interrupt
```

#### Step 2: Load Data into Background Buffer

```c
// Load data into buffer B while buffer A is processing
for (int i = 0; i < FFT_LENGTH; i++) {
    uint32_t addr = INPUT_BUFFER_B_BASE + (i * 4);
    uint32_t data = (input_real[i] << 16) | input_imag[i];
    write_memory(addr, data);
}
```

#### Step 3: Start Processing and Switch Buffers

```c
// Start FFT computation
write_reg(FFT_CTRL, 0x01);  // Set FFT_START bit

// Wait for completion interrupt
while (!interrupt_received) {
    // Wait for FFT_DONE interrupt
}

// Switch buffers for next computation
write_reg(FFT_CTRL, 0x04);  // Set BUFFER_SWAP bit
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
    
    // Set rescaling mode (0=divide by 2 each stage, 1=divide by N at end)
    write_reg(FFT_CONFIG, read_reg(FFT_CONFIG) & ~0x10000);  // Mode 0
    
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
    
    printf("Scale Factor: %d (2^%d)\n", 1 << total_scale, total_scale);
    printf("Stages Processed: %d\n", stage_count);
    printf("Overflow Events: %d\n", overflow_count);
}
```

#### Reconstruct Original Signal Magnitude

```c
// Apply inverse scaling to restore original signal magnitude
void reconstruct_signal(uint32_t *output_data, uint32_t length) {
    uint32_t scale_factor_reg = read_reg(SCALE_FACTOR);
    uint8_t total_scale = scale_factor_reg & 0xFF;
    
    // Apply inverse scaling to restore original magnitude
    for (int i = 0; i < length; i++) {
        int16_t real_part = (output_data[i] >> 16) & 0xFFFF;
        int16_t imag_part = output_data[i] & 0xFFFF;
        
        // Scale back by the accumulated scale factor
        real_part = real_part << total_scale;
        imag_part = imag_part << total_scale;
        
        output_data[i] = (real_part << 16) | (imag_part & 0xFFFF);
    }
}
```

### 3.4 Interrupt Handling

#### Interrupt Service Routine

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

| Application | Recommended FFT Length | Throughput (MSPS) |
|-------------|----------------------|-------------------|
| Audio Processing | 1024 | 16.3 |
| Communication | 2048 | 7.4 |
| Radar/Sonar | 4096 | 3.4 |
| Real-time DSP | 512 | 36.2 |

#### Memory Access Optimization

```c
// Burst transfer for improved performance
void burst_load_input_data(uint32_t *input_data, uint32_t length) {
    // Configure burst transfer
    write_reg(BURST_CONFIG, 0x01);
    
    // Perform burst write
    for (int i = 0; i < length; i += 4) {
        burst_write(INPUT_BUFFER_A_BASE + i, &input_data[i], 4);
    }
}
```

### 4.2 Power Management

#### Dynamic Power Control

```c
// Power management functions
void fft_power_down(void) {
    // Disable FFT engine
    write_reg(FFT_CTRL, 0x02);  // Set FFT_RESET bit
    
    // Wait for power down
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

```c
typedef enum {
    FFT_ERROR_NONE = 0,
    FFT_ERROR_INVALID_LENGTH,
    FFT_ERROR_MEMORY_OVERFLOW,
    FFT_ERROR_TIMEOUT,
    FFT_ERROR_DATA_CORRUPTION,
    FFT_ERROR_RESCALING_OVERFLOW,
    FFT_ERROR_SCALE_FACTOR_OVERFLOW
} fft_error_t;

fft_error_t check_fft_error(void) {
    uint32_t status = read_reg(FFT_STATUS);
    
    if (status & 0x04) {
        // FFT error detected
        uint32_t error_code = read_reg(ERROR_CODE);
        
        switch (error_code) {
            case 0x01:
                return FFT_ERROR_INVALID_LENGTH;
            case 0x02:
                return FFT_ERROR_MEMORY_OVERFLOW;
            case 0x03:
                return FFT_ERROR_TIMEOUT;
            case 0x04:
                return FFT_ERROR_DATA_CORRUPTION;
            case 0x08:
                return FFT_ERROR_RESCALING_OVERFLOW;
            case 0x09:
                return FFT_ERROR_SCALE_FACTOR_OVERFLOW;
            default:
                return FFT_ERROR_NONE;
        }
    }
    
    return FFT_ERROR_NONE;
}
```

#### Error Recovery Procedures

```c
void recover_from_fft_error(fft_error_t error) {
    switch (error) {
        case FFT_ERROR_INVALID_LENGTH:
            // Reset FFT length to valid value
            write_reg(FFT_LENGTH, 1024);
            break;
            
        case FFT_ERROR_MEMORY_OVERFLOW:
            // Reset memory pointers
            write_reg(FFT_CTRL, 0x02);  // Reset FFT engine
            break;
            
        case FFT_ERROR_TIMEOUT:
            // Restart FFT computation
            write_reg(FFT_CTRL, 0x01);  // Restart FFT
            break;
            
        case FFT_ERROR_DATA_CORRUPTION:
            // Reload input data and restart
            reload_input_data();
            write_reg(FFT_CTRL, 0x01);  // Restart FFT
            break;
            
        case FFT_ERROR_RESCALING_OVERFLOW:
            // Disable rescaling and retry
            write_reg(FFT_CTRL, read_reg(FFT_CTRL) & ~0x10);  // Clear RESCALE_EN
            write_reg(FFT_CTRL, 0x01);  // Restart FFT
            break;
            
        case FFT_ERROR_SCALE_FACTOR_OVERFLOW:
            // Reset scale factor and retry
            write_reg(FFT_CTRL, 0x02);  // Reset FFT engine
            break;
            
        default:
            break;
    }
}
```

### 5.2 Debug and Diagnostics

#### Performance Monitoring

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
    
    // Load audio samples
    for (int i = 0; i < 1024; i++) {
        uint32_t addr = INPUT_BUFFER_A_BASE + (i * 4);
        uint32_t data = (audio_samples[i] << 16) | 0x0000;  // Real only
        write_memory(addr, data);
    }
    
    // Start FFT computation
    write_reg(FFT_CTRL, 0x01);
    
    // Wait for completion
    while (!(read_reg(FFT_STATUS) & 0x02)) {
        // Wait for completion
    }
    
    // Read frequency domain data
    for (int i = 0; i < 1024; i++) {
        uint32_t addr = OUTPUT_BUFFER_A_BASE + (i * 4);
        uint32_t data = read_memory(addr);
        frequency_magnitude[i] = sqrt((data >> 16) * (data >> 16) + 
                                    (data & 0xFFFF) * (data & 0xFFFF));
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
    
    // Load OFDM symbol data
    for (int i = 0; i < fft_size; i++) {
        uint32_t addr = INPUT_BUFFER_A_BASE + (i * 4);
        uint32_t data = (symbol_data[i].real << 16) | symbol_data[i].imag;
        write_memory(addr, data);
    }
    
    // Start FFT computation
    write_reg(FFT_CTRL, 0x01);
    
    // Wait for completion with timeout
    uint32_t timeout = 0;
    while (!(read_reg(FFT_STATUS) & 0x02) && (timeout < 10000)) {
        timeout++;
    }
    
    if (timeout >= 10000) {
        // Handle timeout error
        handle_fft_timeout();
        return;
    }
    
    // Read frequency domain data
    for (int i = 0; i < fft_size; i++) {
        uint32_t addr = OUTPUT_BUFFER_A_BASE + (i * 4);
        uint32_t data = read_memory(addr);
        frequency_domain[i].real = (int16_t)(data >> 16);
        frequency_domain[i].imag = (int16_t)(data & 0xFFFF);
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
    
    // Enable double buffering and interrupts
    write_reg(BUFFER_SEL, 0x01);
    write_reg(INT_ENABLE, 0x01);
    
    // Register interrupt handler
    register_interrupt_handler(FFT_IRQ_NUM, fft_interrupt_handler);
}

void real_time_dsp_process(int16_t *input_data) {
    uint32_t buffer_base = fft_ctx.buffer_a_active ? 
                          INPUT_BUFFER_A_BASE : INPUT_BUFFER_B_BASE;
    
    // Load data into inactive buffer
    for (int i = 0; i < 512; i++) {
        uint32_t addr = buffer_base + (i * 4);
        uint32_t data = (input_data[i] << 16) | 0x0000;
        write_memory(addr, data);
    }
    
    // Start FFT computation
    write_reg(FFT_CTRL, 0x01);
    
    // Switch buffer for next iteration
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
- Invalid FFT length configuration
- Memory access violation
- Clock frequency too high

**Solutions:**
```c
// Check FFT configuration
uint32_t config = read_reg(FFT_CONFIG);
if ((config & 0xFFF) > 12) {
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
// Verify input data format
for (int i = 0; i < FFT_LENGTH; i++) {
    uint32_t addr = INPUT_BUFFER_A_BASE + (i * 4);
    uint32_t data = read_memory(addr);
    printf("Input[%d]: real=%d, imag=%d\n", 
           i, (int16_t)(data >> 16), (int16_t)(data & 0xFFFF));
}

// Check twiddle factor ROM
uint32_t twiddle_test = read_memory(TWIDDLE_ROM_BASE);
printf("Twiddle factor test: 0x%08X\n", twiddle_test);
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

// Check interrupt status
uint32_t int_status = read_reg(INT_STATUS);
printf("Interrupt status: 0x%08X\n", int_status);
```

### 7.2 Performance Issues

#### Issue: Low Throughput

**Symptoms:** FFT computation takes longer than expected

**Possible Causes:**
- Clock frequency too low
- Memory bandwidth limitation
- Pipeline stalls

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
| | | [3] | MODE_SEL - Mode selection (0=APB, 1=AXI) |
| | | [4] | RESCALE_EN - Enable automatic rescaling |
| | | [5] | SCALE_TRACK_EN - Enable scale factor tracking |
| | | [31:6] | RESERVED - Reserved bits |

#### Status Registers

| Register | Address | Bits | Description |
|----------|---------|------|-------------|
| FFT_STATUS | 0x0004 | [0] | FFT_BUSY - FFT computation in progress |
| | | [1] | FFT_DONE - FFT computation complete |
| | | [2] | FFT_ERROR - FFT computation error |
| | | [3] | BUFFER_ACTIVE - Active buffer indicator |
| | | [4] | RESCALE_ACTIVE - Rescaling in progress |
| | | [5] | OVERFLOW_DETECTED - Overflow detected during computation |
| | | [31:6] | RESERVED - Reserved bits |

### 8.2 Timing Specifications

#### FFT Computation Timing

| FFT Length | Butterfly Count | Total Cycles | Latency (μs @ 1GHz) |
|------------|----------------|--------------|---------------------|
| 256 | 2,048 | 12,288 | 12.3 |
| 512 | 4,608 | 27,648 | 27.6 |
| 1024 | 10,240 | 61,440 | 61.4 |
| 2048 | 22,528 | 135,168 | 135.2 |
| 4096 | 49,152 | 294,912 | 294.9 |

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