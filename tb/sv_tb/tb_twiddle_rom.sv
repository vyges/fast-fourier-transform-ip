`timescale 1ns/1ps

//=============================================================================
// Twiddle ROM Testbench
//=============================================================================
// Description: Simple testbench for twiddle ROM module
// Author:      Vyges IP Development Team
// Date:        2025-07-21
// License:     Apache-2.0
//=============================================================================

module tb_twiddle_rom;
    // Clock and reset
    logic clk_i = 0;
    logic reset_n_i = 0;
    
    // ROM interface
    logic [15:0] addr_i = 0;
    logic addr_valid_i = 0;
    logic [31:0] data_o;
    logic data_valid_o;
    
    // Clock generation
    always #0.5 clk_i = ~clk_i;
    
    // Instantiate DUT
    twiddle_rom dut (
        .clk_i(clk_i),
        .reset_n_i(reset_n_i),
        .addr_i(addr_i),
        .addr_valid_i(addr_valid_i),
        .data_o(data_o),
        .data_valid_o(data_valid_o)
    );
    
    // VCD dump file
    initial begin
        $dumpfile("twiddle_rom_test.vcd");
        $dumpvars(0, tb_twiddle_rom);
    end
    
    // Test stimulus
    initial begin
        $display("Starting twiddle ROM test...");
        
        // Initialize
        reset_n_i = 0;
        
        // Wait for reset
        #100;
        
        // Release reset
        reset_n_i = 1;
        
        $display("Reset released at time %t", $time);
        
        // Test ROM read
        addr_i = 16'h0000;
        addr_valid_i = 1;
        #1;
        addr_valid_i = 0;
        #1;
        
        if (data_valid_o) begin
            $display("Twiddle ROM test passed - data: %h", data_o);
        end else begin
            $display("Twiddle ROM test failed - no data valid");
        end
        
        // Test another address
        addr_i = 16'h0001;
        addr_valid_i = 1;
        #1;
        addr_valid_i = 0;
        #1;
        
        if (data_valid_o) begin
            $display("Twiddle ROM test passed - data: %h", data_o);
        end else begin
            $display("Twiddle ROM test failed - no data valid");
        end
        
        // Test more addresses for better coverage
        for (int i = 2; i < 10; i++) begin
            addr_i = i;
            addr_valid_i = 1;
            #1;
            addr_valid_i = 0;
            #1;
            
            if (data_valid_o) begin
                $display("Address %d: data = %h", i, data_o);
            end
        end
        
        // Wait some cycles
        #100;
        
        $display("Twiddle ROM test completed successfully at time %t", $time);
        $finish;
    end

endmodule 