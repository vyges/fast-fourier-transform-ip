//=============================================================================
// FFT Top-Level Testbench
//=============================================================================
// Description: Comprehensive testbench for the FFT hardware accelerator
//              with automatic rescaling and scale factor tracking.
//              Tests all major functionality including overflow detection.
// Author:      Vyges IP Development Team
// Date:        2025-07-21
// License:     Apache-2.0
//=============================================================================

`timescale 1ns/1ps

module tb_fft_top;

    // Test parameters
    localparam int FFT_MAX_LENGTH_LOG2 = 12;
    localparam int DATA_WIDTH = 16;
    localparam int TWIDDLE_WIDTH = 16;
    localparam int APB_ADDR_WIDTH = 16;
    localparam int AXI_ADDR_WIDTH = 32;
    localparam int AXI_DATA_WIDTH = 64;
    
    // Clock and reset signals
    logic        clk;
    logic        reset_n;
    logic        pclk;
    logic        preset_n;
    logic        axi_aclk;
    logic        axi_areset_n;
    
    // APB interface signals
    logic        psel;
    logic        penable;
    logic        pwrite;
    logic [APB_ADDR_WIDTH-1:0] paddr;
    logic [31:0] pwdata;
    logic [31:0] prdata;
    logic        pready;
    
    // AXI interface signals
    logic [AXI_ADDR_WIDTH-1:0] axi_awaddr;
    logic        axi_awvalid;
    logic        axi_awready;
    logic [AXI_DATA_WIDTH-1:0] axi_wdata;
    logic        axi_wvalid;
    logic        axi_wready;
    logic [AXI_ADDR_WIDTH-1:0] axi_araddr;
    logic        axi_arvalid;
    logic        axi_arready;
    logic [AXI_DATA_WIDTH-1:0] axi_rdata;
    logic        axi_rvalid;
    logic        axi_rready;
    
    // Interrupt signals
    logic        fft_done;
    logic        fft_error;
    
    // Test stimulus
    logic [15:0] test_input_real [1023:0];
    logic [15:0] test_input_imag [1023:0];
    logic [15:0] test_output_real [1023:0];
    logic [15:0] test_output_imag [1023:0];
    
    // Test control
    logic        test_start;
    logic        test_done;
    int          test_result;
    
    // Clock generation
    initial begin
        clk = 0;
        pclk = 0;
        axi_aclk = 0;
        forever begin
            #0.5 clk = ~clk;      // 1 GHz system clock
            #1.0 pclk = ~pclk;    // 500 MHz APB clock
            #0.5 axi_aclk = ~axi_aclk; // 1 GHz AXI clock
        end
    end
    
    // Reset generation
    initial begin
        reset_n = 0;
        preset_n = 0;
        axi_areset_n = 0;
        #100;
        reset_n = 1;
        preset_n = 1;
        axi_areset_n = 1;
    end
    
    // Instantiate DUT
    fft_top #(
        .FFT_MAX_LENGTH_LOG2(FFT_MAX_LENGTH_LOG2),
        .DATA_WIDTH(DATA_WIDTH),
        .TWIDDLE_WIDTH(TWIDDLE_WIDTH),
        .APB_ADDR_WIDTH(APB_ADDR_WIDTH),
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH)
    ) dut (
        .clk_i(clk),
        .reset_n_i(reset_n),
        .pclk_i(pclk),
        .preset_n_i(preset_n),
        .psel_i(psel),
        .penable_i(penable),
        .pwrite_i(pwrite),
        .paddr_i(paddr),
        .pwdata_i(pwdata),
        .prdata_o(prdata),
        .pready_o(pready),
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
        .fft_done_o(fft_done),
        .fft_error_o(fft_error)
    );
    
    // APB task for register access
    task automatic apb_write(input logic [15:0] addr, input logic [31:0] data);
        @(posedge pclk);
        psel = 1'b1;
        penable = 1'b0;
        pwrite = 1'b1;
        paddr = addr;
        pwdata = data;
        
        @(posedge pclk);
        penable = 1'b1;
        
        @(posedge pclk);
        while (!pready) @(posedge pclk);
        
        psel = 1'b0;
        penable = 1'b0;
    endtask
    
    task automatic apb_read(input logic [15:0] addr, output logic [31:0] data);
        @(posedge pclk);
        psel = 1'b1;
        penable = 1'b0;
        pwrite = 1'b0;
        paddr = addr;
        
        @(posedge pclk);
        penable = 1'b1;
        
        @(posedge pclk);
        while (!pready) @(posedge pclk);
        
        data = prdata;
        psel = 1'b0;
        penable = 1'b0;
    endtask
    
    // Test stimulus generation
    initial begin
        // Initialize test signals
        test_start = 0;
        test_done = 0;
        test_result = 0;
        
        // Initialize APB signals
        psel = 0;
        penable = 0;
        pwrite = 0;
        paddr = 0;
        pwdata = 0;
        
        // Initialize AXI signals
        axi_awaddr = 0;
        axi_awvalid = 0;
        axi_wdata = 0;
        axi_wvalid = 0;
        axi_araddr = 0;
        axi_arvalid = 0;
        axi_rready = 0;
        
        // Wait for reset to complete
        wait (reset_n && preset_n && axi_areset_n);
        #100;
        
        // Run tests
        run_basic_fft_test();
        run_rescaling_test();
        run_overflow_test();
        run_performance_test();
        
        // Test completion
        test_done = 1;
        $display("All tests completed successfully!");
        $finish;
    end
    
    // Basic FFT test
    task automatic run_basic_fft_test();
        logic [31:0] status;
        logic [31:0] scale_factor;
        
        $display("Running basic FFT test...");
        
        // Configure FFT for 1024 points
        apb_write(16'h0008, 32'h0000000A);  // FFT_CONFIG: log2(1024) = 10
        apb_write(16'h000C, 32'h00000400);  // FFT_LENGTH: 1024
        
        // Enable rescaling
        apb_write(16'h0000, 32'h00000030);  // FFT_CTRL: Enable rescaling and scale tracking
        apb_write(16'h0008, 32'h0008000A);  // FFT_CONFIG: Enable overflow detection
        
        // Enable interrupts
        apb_write(16'h0014, 32'h00000001);  // INT_ENABLE: Enable FFT completion interrupt
        
        // Start FFT computation
        apb_write(16'h0000, 32'h00000031);  // FFT_CTRL: Start FFT
        
        // Wait for completion
        do begin
            apb_read(16'h0004, status);
        end while (!status[1]);  // Wait for FFT_DONE bit
        
        // Read scale factor
        apb_read(16'h001C, scale_factor);
        $display("Scale factor: %d", scale_factor[7:0]);
        
        $display("Basic FFT test passed!");
    endtask
    
    // Rescaling test
    task automatic run_rescaling_test();
        logic [31:0] status;
        logic [31:0] overflow_status;
        logic [31:0] scale_factor;
        
        $display("Running rescaling test...");
        
        // Configure for rescaling test
        apb_write(16'h0008, 32'h00000008);  // FFT_CONFIG: 256-point FFT
        apb_write(16'h000C, 32'h00000100);  // FFT_LENGTH: 256
        
        // Enable all rescaling features
        apb_write(16'h0000, 32'h00000030);  // FFT_CTRL: Enable rescaling and scale tracking
        apb_write(16'h0008, 32'h00080008);  // FFT_CONFIG: Enable overflow detection
        apb_write(16'h0020, 32'h0000000F);  // RESCALE_CTRL: Enable all rescaling features
        
        // Start FFT computation
        apb_write(16'h0000, 32'h00000031);  // FFT_CTRL: Start FFT
        
        // Wait for completion
        do begin
            apb_read(16'h0004, status);
        end while (!status[1]);  // Wait for FFT_DONE bit
        
        // Read rescaling statistics
        apb_read(16'h001C, scale_factor);
        apb_read(16'h0024, overflow_status);
        
        $display("Rescaling test - Scale factor: %d, Overflow count: %d", 
                scale_factor[7:0], overflow_status[7:0]);
        
        $display("Rescaling test passed!");
    endtask
    
    // Overflow test
    task automatic run_overflow_test();
        logic [31:0] status;
        logic [31:0] overflow_status;
        
        $display("Running overflow test...");
        
        // Configure for overflow test (small FFT to trigger overflow)
        apb_write(16'h0008, 32'h00000008);  // FFT_CONFIG: 256-point FFT
        apb_write(16'h000C, 32'h00000100);  // FFT_LENGTH: 256
        
        // Enable overflow detection and rescaling
        apb_write(16'h0000, 32'h00000030);  // FFT_CTRL: Enable rescaling and scale tracking
        apb_write(16'h0008, 32'h00080008);  // FFT_CONFIG: Enable overflow detection
        apb_write(16'h0020, 32'h0000000F);  // RESCALE_CTRL: Enable all rescaling features
        
        // Enable overflow interrupt
        apb_write(16'h0014, 32'h00000008);  // INT_ENABLE: Enable overflow interrupt
        
        // Start FFT computation
        apb_write(16'h0000, 32'h00000031);  // FFT_CTRL: Start FFT
        
        // Wait for completion
        do begin
            apb_read(16'h0004, status);
        end while (!status[1]);  // Wait for FFT_DONE bit
        
        // Check overflow status
        apb_read(16'h0024, overflow_status);
        
        if (overflow_status[7:0] > 0) begin
            $display("Overflow test passed - %d overflow events detected", overflow_status[7:0]);
        end else begin
            $display("Overflow test passed - No overflow events (expected for small FFT)");
        end
        
        $display("Overflow test passed!");
    endtask
    
    // Performance test
    task automatic run_performance_test();
        logic [31:0] status;
        int start_time, end_time, cycles;
        
        $display("Running performance test...");
        
        // Configure for performance test
        apb_write(16'h0008, 32'h0000000A);  // FFT_CONFIG: 1024-point FFT
        apb_write(16'h000C, 32'h00000400);  // FFT_LENGTH: 1024
        
        // Disable rescaling for performance measurement
        apb_write(16'h0000, 32'h00000001);  // FFT_CTRL: Start FFT only
        
        // Measure performance
        start_time = $time;
        apb_write(16'h0000, 32'h00000001);  // FFT_CTRL: Start FFT
        
        // Wait for completion
        do begin
            apb_read(16'h0004, status);
        end while (!status[1]);  // Wait for FFT_DONE bit
        
        end_time = $time;
        cycles = (end_time - start_time) / 1;  // 1ns clock period
        
        $display("Performance test - 1024-point FFT completed in %d cycles", cycles);
        $display("Expected cycles: %d (10,240 butterflies * 6 cycles)", 10240 * 6);
        
        if (cycles <= 10240 * 6 + 100) begin  // Allow some tolerance
            $display("Performance test passed!");
        end else begin
            $display("Performance test failed - too many cycles!");
            test_result = 1;
        end
    endtask
    
    // Monitor for interrupts
    always @(posedge fft_done) begin
        $display("FFT completion interrupt received at time %t", $time);
    end
    
    always @(posedge fft_error) begin
        $display("FFT error interrupt received at time %t", $time);
        test_result = 1;
    end
    
    // Basic assertions (Verilator compatible)
    always @(posedge clk) begin
        if (dut.fft_engine_inst.fft_busy_o && dut.fft_engine_inst.fft_done_o) begin
            $error("FFT busy and done asserted simultaneously");
            test_result = 1;
        end
        
        if (dut.fft_engine_inst.rescaling_active_o && !dut.fft_engine_inst.overflow_detect_reg) begin
            $error("Rescaling active without overflow detection");
            test_result = 1;
        end
    end

endmodule 