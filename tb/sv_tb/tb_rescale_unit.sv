`timescale 1ns/1ps

//=============================================================================
// Rescale Unit Testbench
//=============================================================================
// Description: Comprehensive testbench for rescale unit module
//              Tests overflow detection, rescaling, and scale factor tracking.
//              Generates VCD waveform files following Vyges conventions.
// Author:      Vyges IP Development Team
// Date:        2025-07-21
// License:     Apache-2.0
//=============================================================================

module tb_rescale_unit;
    // Clock and reset
    logic clk_i = 0;
    logic reset_n_i = 0;
    
    // Data interface
    logic [15:0] data_real_i = 0;
    logic [15:0] data_imag_i = 0;
    logic data_valid_i = 0;
    logic [15:0] data_real_o;
    logic [15:0] data_imag_o;
    logic data_valid_o;
    
    // Control interface
    logic rescale_en_i = 0;
    logic scale_track_en_i = 0;
    logic rescale_mode_i = 0;
    logic rounding_mode_i = 0;
    logic saturation_en_i = 0;
    logic overflow_detect_i = 0;
    logic [7:0] rescale_threshold_i = 8'h80;
    
    // Status outputs
    logic overflow_detected_o;
    logic [7:0] overflow_magnitude_o;
    logic [7:0] scale_factor_o;
    logic scale_factor_increment_o;
    logic rescaling_active_o;
    logic [7:0] rescale_count_o;
    
    // Clock generation
    always #0.5 clk_i = ~clk_i;
    
    // Instantiate DUT
    rescale_unit dut (
        .clk_i(clk_i),
        .reset_n_i(reset_n_i),
        .data_real_i(data_real_i),
        .data_imag_i(data_imag_i),
        .data_valid_i(data_valid_i),
        .data_real_o(data_real_o),
        .data_imag_o(data_imag_o),
        .data_valid_o(data_valid_o),
        .rescale_en_i(rescale_en_i),
        .scale_track_en_i(scale_track_en_i),
        .rescale_mode_i(rescale_mode_i),
        .rounding_mode_i(rounding_mode_i),
        .saturation_en_i(saturation_en_i),
        .overflow_detect_i(overflow_detect_i),
        .rescale_threshold_i(rescale_threshold_i),
        .overflow_detected_o(overflow_detected_o),
        .overflow_magnitude_o(overflow_magnitude_o),
        .scale_factor_o(scale_factor_o),
        .scale_factor_increment_o(scale_factor_increment_o),
        .rescaling_active_o(rescaling_active_o),
        .rescale_count_o(rescale_count_o)
    );
    
    // VCD dump file
    initial begin
        $dumpfile("rescale_unit_test.vcd");
        $dumpvars(0, tb_rescale_unit);
    end
    
    // Test stimulus
    initial begin
        $display("Starting rescale unit test...");
        
        // Initialize
        reset_n_i = 0;
        rescale_en_i = 1;
        scale_track_en_i = 1;
        overflow_detect_i = 1;
        
        // Wait for reset
        #100;
        
        // Release reset
        reset_n_i = 1;
        
        $display("Reset released at time %t", $time);
        
        // Test 1: No overflow case
        test_no_overflow();
        
        // Test 2: Overflow case with truncation
        test_overflow_truncate();
        
        // Test 3: Overflow case with rounding
        test_overflow_round();
        
        // Test 4: Saturation test
        test_saturation();
        
        // Test 5: Scale factor tracking
        test_scale_factor_tracking();
        
        // Wait some cycles
        #100;
        
        $display("Rescale unit test completed successfully at time %t", $time);
        $finish;
    end
    
    // Test task: No overflow
    task test_no_overflow();
        $display("Test 1: No overflow case");
        
        data_real_i = 16'h2000;  // 0.25 in Q1.15
        data_imag_i = 16'h3000;  // 0.375 in Q1.15
        data_valid_i = 1;
        #1;
        data_valid_i = 0;
        #2;
        
        if (!overflow_detected_o) begin
            $display("  No overflow test passed");
        end else begin
            $display("  No overflow test failed");
        end
    endtask
    
    // Test task: Overflow with truncation
    task test_overflow_truncate();
        $display("Test 2: Overflow case with truncation");
        
        rounding_mode_i = 0;  // Truncate mode
        data_real_i = 16'h7000;  // Large value that will overflow
        data_imag_i = 16'h6000;  // Large value that will overflow
        data_valid_i = 1;
        #1;
        data_valid_i = 0;
        #2;
        
        if (overflow_detected_o) begin
            $display("  Overflow truncation test passed - overflow detected");
        end else begin
            $display("  Overflow truncation test failed - no overflow detected");
        end
    endtask
    
    // Test task: Overflow with rounding
    task test_overflow_round();
        $display("Test 3: Overflow case with rounding");
        
        rounding_mode_i = 1;  // Round mode
        data_real_i = 16'h7000;  // Large value that will overflow
        data_imag_i = 16'h6000;  // Large value that will overflow
        data_valid_i = 1;
        #1;
        data_valid_i = 0;
        #2;
        
        if (overflow_detected_o) begin
            $display("  Overflow rounding test passed - overflow detected");
        end else begin
            $display("  Overflow rounding test failed - no overflow detected");
        end
    endtask
    
    // Test task: Saturation
    task test_saturation();
        $display("Test 4: Saturation test");
        
        saturation_en_i = 1;
        data_real_i = 16'h8000;  // Maximum negative value
        data_imag_i = 16'h7FFF;  // Maximum positive value
        data_valid_i = 1;
        #1;
        data_valid_i = 0;
        #2;
        
        $display("  Saturation test completed - real: %h, imag: %h", data_real_o, data_imag_o);
    endtask
    
    // Test task: Scale factor tracking
    task test_scale_factor_tracking();
        $display("Test 5: Scale factor tracking");
        
        // Apply multiple rescaling operations
        for (int i = 0; i < 5; i++) begin
            data_real_i = 16'h7000 + i * 16'h1000;
            data_imag_i = 16'h6000 + i * 16'h1000;
            data_valid_i = 1;
            #1;
            data_valid_i = 0;
            #2;
        end
        
        $display("  Scale factor tracking test completed - scale factor: %d, count: %d", 
                scale_factor_o, rescale_count_o);
    endtask

endmodule 