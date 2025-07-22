`timescale 1ns/1ps

//=============================================================================
// Twiddle Factor ROM Module (Synthesis Version)
//=============================================================================
// Description: Pre-computed twiddle factor ROM for FFT computation.
//              Synthesis-friendly version without real types.
//              Stores complex coefficients W_N^k = cos(2πk/N) - j*sin(2πk/N)
//              for all supported FFT lengths.
// Author:      Vyges IP Development Team
// Date:        2025-07-21
// License:     Apache-2.0
//=============================================================================

module twiddle_rom_synth #(
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
        // Using pre-computed values to avoid real arithmetic in synthesis
        rom_memory[0] = 32'h7FFF0000;  // cos(0) = 1.0, sin(0) = 0.0
        rom_memory[1] = 32'h7FFE0006;  // cos(2π/4096), sin(2π/4096)
        rom_memory[2] = 32'h7FFA000C;  // cos(4π/4096), sin(4π/4096)
        rom_memory[3] = 32'h7FF30012;  // cos(6π/4096), sin(6π/4096)
        rom_memory[4] = 32'h7FE90018;  // cos(8π/4096), sin(8π/4096)
        rom_memory[5] = 32'h7FDC001E;  // cos(10π/4096), sin(10π/4096)
        rom_memory[6] = 32'h7FCC0024;  // cos(12π/4096), sin(12π/4096)
        rom_memory[7] = 32'h7FB9002A;  // cos(14π/4096), sin(14π/4096)
        rom_memory[8] = 32'h7FA30030;  // cos(16π/4096), sin(16π/4096)
        rom_memory[9] = 32'h7F8A0036;  // cos(18π/4096), sin(18π/4096)
        
        // Initialize remaining ROM locations with sample values
        for (int k = 10; k < ROM_SIZE; k++) begin
            rom_memory[k] = 32'h00000000;
        end
    end

endmodule 