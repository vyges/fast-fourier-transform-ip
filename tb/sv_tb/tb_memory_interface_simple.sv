//=============================================================================
// Simple Memory Interface Testbench for VCD Generation
//=============================================================================
// Description: Minimal testbench to generate VCD files for waveform analysis
// Author:      Vyges IP Development Team
// Date:        2025-08-11
// License:     Apache-2.0
//=============================================================================

`timescale 1ns/1ps

module tb_memory_interface_simple;
    // Clock and reset
    logic clk_i = 0;
    logic reset_n_i = 0;
    
    // Memory interface signals
    logic [15:0] mem_addr_i = 0;
    logic [31:0] mem_data_i = 0;
    logic mem_write_i = 0;
    logic [31:0] mem_data_o;
    logic mem_ready_o;
    
    // Clock generation
    always #5 clk_i = ~clk_i;  // 100MHz clock
    
    // Instantiate the memory interface (only core memory part)
    memory_interface uut (
        .clk_i(clk_i),
        .reset_n_i(reset_n_i),
        .pclk_i(clk_i),
        .preset_n_i(reset_n_i),
        .psel_i(1'b0),
        .penable_i(1'b0),
        .pwrite_i(1'b0),
        .paddr_i(16'h0),
        .pwdata_i(32'h0),
        .prdata_o(),
        .pready_o(),
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
        .mem_addr_i(mem_addr_i),
        .mem_data_i(mem_data_i),
        .mem_write_i(mem_write_i),
        .mem_data_o(mem_data_o),
        .mem_ready_o(mem_ready_o),
        .fft_start_o(),
        .fft_reset_o(),
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
        .fft_busy_i(1'b0),
        .fft_done_i(1'b0),
        .fft_error_i(1'b0),
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
        $dumpfile("memory_interface_simple.vcd");
        $dumpvars(0, tb_memory_interface_simple);
        
        $display("🧪 Starting Simple Memory Interface Test");
        $display("📊 VCD file: memory_interface_simple.vcd");
        
        // Reset sequence
        reset_n_i = 0;
        #100;
        reset_n_i = 1;
        #50;
        
        // Simple memory test
        $display("Test: Basic Memory Operations");
        
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
        
        $display("Memory location 0x0000: 0x%08X", mem_data_o);
        
        @(posedge clk_i);
        mem_addr_i = 16'h0001;
        @(posedge clk_i);
        
        $display("Memory location 0x0001: 0x%08X", mem_data_o);
        
        #100;
        $display("✅ Test completed successfully!");
        $display("📊 VCD file generated: memory_interface_simple.vcd");
        $finish;
    end
    
    // Monitor key signals
    always @(posedge clk_i) begin
        if (mem_write_i) begin
            $display("📝 Memory Write: addr=0x%04X, data=0x%08X", mem_addr_i, mem_data_i);
        end
    end
    
endmodule
