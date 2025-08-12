`ifndef FFT_TWIDDLE_ROM_SV
`define FFT_TWIDDLE_ROM_SV

`include "fft_timescale.vh"
`include "fft_defines.vh"

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
    typedef int int_t;
    
    // ROM size calculation with symmetry optimization
    // Using cos(w) = sin(w + π/2) and sin(w + π/2) = sin(w - π/2)
    // This reduces ROM from 16K bits to 4K bits + extra logic
    localparam int ROM_SIZE = 1 << (MAX_FFT_LENGTH_LOG2 - 2);  // Reduced by factor of 4
    localparam int ADDR_WIDTH = $clog2(ROM_SIZE);
    
    // ROM memory array with synthesis attributes
    (* rom_style = "block" *)  // Force ROM synthesis
    (* rom_init_file = "" *)    // No initialization file needed
    logic [15:0] rom_memory [ROM_SIZE-1:0];  // Only store sin values (16-bit each)
    logic [ADDR_WIDTH-1:0] rom_addr;
    logic [31:0] rom_data;
    
    // Address validation and symmetry logic
    logic [1:0] quadrant;
    logic [ADDR_WIDTH-1:0] base_addr;
    logic [15:0] sin_value, cos_value;
    
    // Determine quadrant and base address
    assign quadrant = addr_i[1:0];  // 2 bits for quadrant
    assign base_addr = addr_i[15:2];  // Remaining bits for base address
    
    // ROM read with symmetry optimization
    always_ff @(posedge clk_i) begin
        if (addr_valid_i) begin
            // Read base sin value from ROM
            sin_value <= rom_memory[base_addr];
            
            // Apply symmetry transformations
            case (quadrant)
                2'b00: begin  // 0 to π/2: cos = cos, sin = sin
                    cos_value <= rom_memory[base_addr];
                end
                2'b01: begin  // π/2 to π: cos = -sin, sin = cos
                    cos_value <= -rom_memory[base_addr];
                end
                2'b10: begin  // π to 3π/2: cos = -cos, sin = -sin
                    cos_value <= -rom_memory[base_addr];
                end
                2'b11: begin  // 3π/2 to 2π: cos = sin, sin = -cos
                    cos_value <= rom_memory[base_addr];
                end
            endcase
        end
        data_valid_o <= addr_valid_i;
    end
    
    // Pack into 32-bit output (real:imag)
    assign data_o = {cos_value, sin_value};
    
    // ROM initialization with pre-computed sin values only
    initial begin
        // Initialize ROM with sin values for 4096-point FFT (using symmetry optimization)
        // Only need 0 to π/2 range due to symmetry (1024 entries for 4096-point FFT)
        for (int k = 0; k < 1024; k++) begin
            int_t sin_int;
            
            // Calculate sin values for 0 to π/2 range (using more compatible syntax)
            sin_int = $rtoi($sin(2.0 * 3.14159265359 * k / 4096.0) * 32767.0);
            
            // Store only sin values (16-bit each)
            rom_memory[k] = sin_int[15:0];
        end
        
        // Initialize remaining ROM locations to zero
        for (int k = 1024; k < ROM_SIZE; k++) begin
            rom_memory[k] = 16'h0000;
        end
    end

endmodule

`endif // FFT_TWIDDLE_ROM_SV 