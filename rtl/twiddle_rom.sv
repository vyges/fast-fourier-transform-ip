`timescale 1ns/1ps

//=============================================================================
// Twiddle Factor ROM Module
//=============================================================================
// Description: Pre-computed twiddle factor ROM for FFT computation.
//              Stores complex coefficients W_N^k = cos(2πk/N) - j*sin(2πk/N)
//              for all supported FFT lengths.
// Author:      Vyges IP Development Team
// Date:        2025-07-21
// License:     Apache-2.0
//=============================================================================

module twiddle_rom #(
    parameter int TWIDDLE_WIDTH = 16,         // Twiddle factor width
    parameter int MAX_FFT_LENGTH_LOG2 = 12    // Maximum FFT length (log2)
) (
    // Clock and Reset
    input  logic        clk_i,
    input  logic        reset_n_i,
    
    // Address Interface
    input  logic [15:0] addr_i,
    input  logic        addr_valid_i,
    output logic [31:0] data_o,
    output logic        data_valid_o
);

    // Type definitions
    typedef real real_t;
    typedef int int_t;
    
    // ROM size calculation
    localparam int ROM_SIZE = 1 << (MAX_FFT_LENGTH_LOG2 - 1);
    localparam int ADDR_WIDTH = $clog2(ROM_SIZE);
    
    // ROM memory array
    logic [31:0] rom_memory [ROM_SIZE-1:0];
    logic [ADDR_WIDTH-1:0] rom_addr;
    logic [31:0] rom_data;
    
    // Address validation
    assign rom_addr = (32'(addr_i) < ROM_SIZE) ? addr_i[ADDR_WIDTH-1:0] : '0;
    
    // ROM read
    always_ff @(posedge clk_i) begin
        if (addr_valid_i) begin
            rom_data <= rom_memory[rom_addr];
        end
        data_valid_o <= addr_valid_i;
    end
    
    assign data_o = rom_data;
    
    // ROM initialization with pre-computed twiddle factors
    initial begin
        // Initialize ROM with twiddle factors for 4096-point FFT
        // W_N^k = cos(2πk/N) - j*sin(2πk/N) in Q1.15 format
        
        // For 4096-point FFT (N=4096), we need 2048 twiddle factors
        for (int k = 0; k < 2048; k++) begin
            real_t cos_val, sin_val;
            int_t cos_int, sin_int;
            
            // Calculate trigonometric values
            cos_val = $cos(2.0 * 3.14159265359 * k / 4096.0);
            sin_val = $sin(2.0 * 3.14159265359 * k / 4096.0);
            
            // Convert to Q1.15 fixed-point format
            cos_int = int'(cos_val * 32767.0);
            sin_int = int'(sin_val * 32767.0);
            
            // Pack into 32-bit word (real:imag)
            rom_memory[k] = {cos_int[15:0], sin_int[15:0]};
        end
        
        // Initialize remaining ROM locations to zero
        for (int k = 2048; k < ROM_SIZE; k++) begin
            rom_memory[k] = 32'h00000000;
        end
    end

endmodule 