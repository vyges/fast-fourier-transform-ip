`timescale 1ns/1ps

//=============================================================================
// Simple FFT Testbench
//=============================================================================
// Description: Simple testbench for FFT hardware accelerator
//              Tests basic instantiation and clock generation
// Author:      Vyges IP Development Team
// Date:        2025-07-21
// License:     Apache-2.0
//=============================================================================

module tb_simple;
    // Clock and reset
    logic clk_i = 0;
    logic reset_n_i = 0;
    
    // APB Interface
    logic pclk_i = 0;
    logic preset_n_i = 0;
    logic psel_i = 0;
    logic penable_i = 0;
    logic pwrite_i = 0;
    logic [15:0] paddr_i = 0;
    logic [31:0] pwdata_i = 0;
    logic [31:0] prdata_o;
    logic pready_o;
    
    // AXI Interface
    logic axi_aclk_i = 0;
    logic axi_areset_n_i = 0;
    logic [31:0] axi_awaddr_i = 0;
    logic axi_awvalid_i = 0;
    logic axi_awready_o;
    logic [63:0] axi_wdata_i = 0;
    logic axi_wvalid_i = 0;
    logic axi_wready_o;
    logic [31:0] axi_araddr_i = 0;
    logic axi_arvalid_i = 0;
    logic axi_arready_o;
    logic [63:0] axi_rdata_o;
    logic axi_rvalid_o;
    logic axi_rready_i = 0;
    
    // FFT Outputs
    logic fft_done_o;
    logic fft_error_o;
    
    // Clock generation
    always #0.5 clk_i = ~clk_i;
    always #1.0 pclk_i = ~pclk_i;
    always #0.5 axi_aclk_i = ~axi_aclk_i;
    
    // Instantiate DUT
    fft_top dut (
        .clk_i(clk_i),
        .reset_n_i(reset_n_i),
        .pclk_i(pclk_i),
        .preset_n_i(preset_n_i),
        .psel_i(psel_i),
        .penable_i(penable_i),
        .pwrite_i(pwrite_i),
        .paddr_i(paddr_i),
        .pwdata_i(pwdata_i),
        .prdata_o(prdata_o),
        .pready_o(pready_o),
        .axi_aclk_i(axi_aclk_i),
        .axi_areset_n_i(axi_areset_n_i),
        .axi_awaddr_i(axi_awaddr_i),
        .axi_awvalid_i(axi_awvalid_i),
        .axi_awready_o(axi_awready_o),
        .axi_wdata_i(axi_wdata_i),
        .axi_wvalid_i(axi_wvalid_i),
        .axi_wready_o(axi_wready_o),
        .axi_araddr_i(axi_araddr_i),
        .axi_arvalid_i(axi_arvalid_i),
        .axi_arready_o(axi_arready_o),
        .axi_rdata_o(axi_rdata_o),
        .axi_rvalid_o(axi_rvalid_o),
        .axi_rready_i(axi_rready_i),
        .fft_done_o(fft_done_o),
        .fft_error_o(fft_error_o)
    );
    
    // Test stimulus
    initial begin
        $display("Starting simple FFT test...");
        
        // Initialize
        reset_n_i = 0;
        preset_n_i = 0;
        axi_areset_n_i = 0;
        
        // Wait for reset
        #100;
        
        // Release reset
        reset_n_i = 1;
        preset_n_i = 1;
        axi_areset_n_i = 1;
        
        $display("Reset released at time %t", $time);
        
        // Wait some cycles
        #1000;
        
        $display("Test completed successfully at time %t", $time);
        $display("FFT done: %b, FFT error: %b", fft_done_o, fft_error_o);
        
        $finish;
    end
    
    // Monitor
    always @(posedge clk_i) begin
        if (fft_done_o) begin
            $display("FFT completion detected at time %t", $time);
        end
        if (fft_error_o) begin
            $display("FFT error detected at time %t", $time);
        end
    end

endmodule 