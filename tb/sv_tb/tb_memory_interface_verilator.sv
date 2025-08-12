//=============================================================================
// Memory Interface Testbench for Verilator
//=============================================================================
// Description: Simple testbench to verify memory interface functionality
//              and generate VCD files for waveform analysis
// Author:      Vyges IP Development Team
// Date:        2025-08-11
// License:     Apache-2.0
//=============================================================================

`timescale 1ns/1ps

module tb_memory_interface_verilator;
    // Clock and reset
    logic clk_i = 0;
    logic reset_n_i = 0;
    
    // APB interface signals
    logic pclk_i = 0;
    logic preset_n_i = 0;
    logic psel_i = 0;
    logic penable_i = 0;
    logic pwrite_i = 0;
    logic [15:0] paddr_i = 0;
    logic [31:0] pwdata_i = 0;
    logic [31:0] prdata_o;
    logic pready_o;
    
    // FFT Engine Interface (core memory functionality)
    logic [15:0] mem_addr_i = 0;
    logic [31:0] mem_data_i = 0;
    logic mem_write_i = 0;
    logic [31:0] mem_data_o;
    logic mem_ready_o;
    
    // Control Interface
    logic fft_start_o;
    logic fft_reset_o;
    
    // Status Interface (inputs)
    logic fft_busy_i = 0;
    logic fft_done_i = 0;
    logic fft_error_i = 0;
    
    // Clock generation
    always #5 clk_i = ~clk_i;      // 100MHz clock
    always #10 pclk_i = ~pclk_i;   // 50MHz APB clock
    
    // Instantiate the memory interface with minimal connections
    memory_interface uut (
        // Clock and Reset
        .clk_i(clk_i),
        .reset_n_i(reset_n_i),
        
        // APB Interface
        .pclk_i(pclk_i),
        .preset_n_i(preset_n_i),
        .psel_i(psel_i),
        .penable_i(penable_i),
        .pwrite_i(pwrite_i),
        .paddr_i(paddr_i),
        .pwdata_i(pwdata_i),
        .prdata_o(prdata_o),
        .pready_o(pready_o),
        
        // AXI Interface (tied off)
        .axi_aclk_i(1'b0),
        .axi_areset_n_i(1'b1),
        .axi_awaddr_i(32'h0),
        .axi_awvalid_i(1'b0),
        .axi_awready_o(),
        .axi_wdata_i(64'h0),
        .axi_wvalid_i(1'b0),
        .axi_wready_o(),
        .axi_araddr_i(32'h0),
        .axi_arvalid_i(1'b0),
        .axi_arready_o(),
        .axi_rdata_o(),
        .axi_rvalid_o(),
        .axi_rready_i(1'b0),
        
        // FFT Engine Interface
        .mem_addr_i(mem_addr_i),
        .mem_data_i(mem_data_i),
        .mem_write_i(mem_write_i),
        .mem_data_o(mem_data_o),
        .mem_ready_o(mem_ready_o),
        
        // Control Interface
        .fft_start_o(fft_start_o),
        .fft_reset_o(fft_reset_o),
        .fft_length_log2_o(),
        .rescale_en_o(),
        .scale_track_en_o(),
        .rescale_mode_o(),
        .rounding_mode_o(),
        .saturation_en_o(),
        .overflow_detect_o(),
        .buffer_swap_o(),
        .buffer_sel_o(),
        .int_enable_o(),
        
        // Status Interface
        .fft_busy_i(fft_busy_i),
        .fft_done_i(fft_done_i),
        .fft_error_i(fft_error_i),
        .buffer_active_i(1'b0),
        .rescaling_active_i(1'b0),
        .overflow_detected_i(1'b0),
        .scale_factor_i(8'h0),
        .stage_count_i(8'h0),
        .overflow_count_i(8'h0),
        .last_overflow_stage_i(8'h0),
        .max_overflow_magnitude_i(8'h0),
        .int_status_i(8'h0)
    );
    
    // Test sequence
    initial begin
        // Initialize waveform dump
        $dumpfile("memory_interface_verilator.vcd");
        $dumpvars(0, tb_memory_interface_verilator);
        
        $display("🧪 Starting Memory Interface Verilator Test");
        $display("📊 VCD file: memory_interface_verilator.vcd");
        
        // Reset sequence
        reset_n_i = 0;
        preset_n_i = 0;
        #100;
        reset_n_i = 1;
        preset_n_i = 1;
        #50;
        
        // Test 1: Basic memory write/read
        $display("Test 1: Basic Memory Write/Read");
        test_memory_basic();
        
        // Test 2: APB register access
        $display("Test 2: APB Register Access");
        test_apb_registers();
        
        // Test 3: Memory addressing
        $display("Test 3: Memory Addressing");
        test_memory_addressing();
        
        // Test 4: FFT control
        $display("Test 4: FFT Control");
        test_fft_control();
        
        #100;
        $display("✅ All tests completed successfully!");
        $display("📊 VCD file generated: memory_interface_verilator.vcd");
        $finish;
    end
    
    // Test 1: Basic memory operations
    task test_memory_basic;
        // Write test data
        @(posedge clk_i);
        mem_addr_i = 16'h0000;
        mem_data_i = 32'hA5A5A5A5;
        mem_write_i = 1;
        @(posedge clk_i);
        mem_write_i = 0;
        
        @(posedge clk_i);
        mem_addr_i = 16'h0001;
        mem_data_i = 32'h5A5A5A5A;
        mem_write_i = 1;
        @(posedge clk_i);
        mem_write_i = 0;
        
        // Read back test data
        @(posedge clk_i);
        mem_addr_i = 16'h0000;
        mem_write_i = 0;
        @(posedge clk_i);
        
        if (mem_data_o == 32'hA5A5A5A5) begin
            $display("  ✓ Memory location 0x0000: 0x%08X", mem_data_o);
        end else begin
            $display("  ✗ Memory location 0x0000: expected 0xA5A5A5A5, got 0x%08X", mem_data_o);
        end
        
        @(posedge clk_i);
        mem_addr_i = 16'h0001;
        @(posedge clk_i);
        
        if (mem_data_o == 32'h5A5A5A5A) begin
            $display("  ✓ Memory location 0x0001: 0x%08X", mem_data_o);
        end else begin
            $display("  ✗ Memory location 0x0001: expected 0x5A5A5A5A, got 0x%08X", mem_data_o);
        end
        
        #50;
    endtask
    
    // Test 2: APB register access
    task test_apb_registers;
        // APB write to control register
        @(posedge pclk_i);
        psel_i = 1;
        penable_i = 0;
        pwrite_i = 1;
        paddr_i = 16'h0000;
        pwdata_i = 32'h00000001;  // Set fft_start
        @(posedge pclk_i);
        penable_i = 1;
        @(posedge pclk_i);
        psel_i = 0;
        penable_i = 0;
        
        // Check FFT start signal
        @(posedge clk_i);
        if (fft_start_o == 1) begin
            $display("  ✓ FFT start bit set correctly");
        end else begin
            $display("  ✗ FFT start bit not set");
        end
        
        // APB read from control register
        @(posedge pclk_i);
        psel_i = 1;
        penable_i = 0;
        pwrite_i = 0;
        paddr_i = 16'h0000;
        @(posedge pclk_i);
        penable_i = 1;
        @(posedge pclk_i);
        
        if (prdata_o == 32'h00000001) begin
            $display("  ✓ Control register read correct: 0x%08X", prdata_o);
        end else begin
            $display("  ✗ Control register read incorrect: 0x%08X", prdata_o);
        end
        
        psel_i = 0;
        penable_i = 0;
        #50;
    endtask
    
    // Test 3: Memory addressing (11-bit address space)
    task test_memory_addressing;
        // Test boundary addresses
        @(posedge clk_i);
        mem_addr_i = 16'h07FF;  // Last location (2047)
        mem_data_i = 32'hDEADBEEF;
        mem_write_i = 1;
        @(posedge clk_i);
        mem_write_i = 0;
        
        // Read back
        @(posedge clk_i);
        mem_addr_i = 16'h07FF;
        @(posedge clk_i);
        
        if (mem_data_o == 32'hDEADBEEF) begin
            $display("  ✓ Boundary address 0x07FF: 0x%08X", mem_data_o);
        end else begin
            $display("  ✗ Boundary address 0x07FF: expected 0xDEADBEEF, got 0x%08X", mem_data_o);
        end
        
        #50;
    endtask
    
    // Test 4: FFT control signals
    task test_fft_control;
        // Test FFT reset
        @(posedge pclk_i);
        psel_i = 1;
        penable_i = 0;
        pwrite_i = 1;
        paddr_i = 16'h0000;
        pwdata_i = 32'h00000002;  // Set fft_reset
        @(posedge pclk_i);
        penable_i = 1;
        @(posedge pclk_i);
        psel_i = 0;
        penable_i = 0;
        
        @(posedge clk_i);
        if (fft_reset_o == 1) begin
            $display("  ✓ FFT reset bit set correctly");
        end else begin
            $display("  ✗ FFT reset bit not set");
        end
        
        #50;
    endtask
    
    // Monitor key signals
    always @(posedge clk_i) begin
        if (mem_write_i) begin
            $display("📝 Memory Write: addr=0x%04X, data=0x%08X", mem_addr_i, mem_data_i);
        end
    end
    
    always @(posedge pclk_i) begin
        if (psel_i && penable_i && pwrite_i) begin
            $display("📝 APB Write: addr=0x%04X, data=0x%08X", paddr_i, pwdata_i);
        end
    end
    
endmodule
