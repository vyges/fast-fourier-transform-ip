`ifndef FFT_RESCALE_UNIT_SV
`define FFT_RESCALE_UNIT_SV

`include "fft_timescale.vh"
`include "fft_defines.vh"

//=============================================================================
// Rescale Unit Module
//=============================================================================
// Description: Dedicated rescaling logic for FFT computation with overflow
//              detection and scale factor tracking. Supports configurable
//              rescaling modes and thresholds.
// Author:      Vyges IP Development Team
// Date:        2025-07-21
// License:     Apache-2.0
//=============================================================================

module rescale_unit #(
    parameter int DATA_WIDTH = 16,             // Data width
    parameter int SCALE_FACTOR_WIDTH = 8       // Scale factor width
) (
    // Clock and Reset
    input  logic        clk_i,
    input  logic        reset_n_i,
    
    // Control Interface
    input  logic        rescale_en_i,
    input  logic        scale_track_en_i,
    input  logic        rescale_mode_i,        // 0=divide by 2, 1=divide by N
    input  logic        rounding_mode_i,       // 0=truncate, 1=round
    input  logic        saturation_en_i,
    input  logic        overflow_detect_i,
    input  logic [7:0]  rescale_threshold_i,   // Rescaling threshold
    
    // Data Interface
    input  logic [DATA_WIDTH-1:0] data_real_i,
    input  logic [DATA_WIDTH-1:0] data_imag_i,
    input  logic                   data_valid_i,
    output logic [DATA_WIDTH-1:0] data_real_o,
    output logic [DATA_WIDTH-1:0] data_imag_o,
    output logic                   data_valid_o,
    
    // Overflow Detection
    output logic                   overflow_detected_o,
    output logic [7:0]            overflow_magnitude_o,
    
    // Scale Factor Interface
    output logic [SCALE_FACTOR_WIDTH-1:0] scale_factor_o,
    output logic                   scale_factor_increment_o,
    
    // Status Interface
    output logic                   rescaling_active_o,
    output logic [7:0]            rescale_count_o
);

    // Internal signals
    logic [DATA_WIDTH-1:0] data_real_reg, data_imag_reg;
    logic [DATA_WIDTH-1:0] rescaled_real, rescaled_imag;
    logic [7:0]            scale_factor_reg;
    logic [7:0]            rescale_count_reg;
    logic                  rescaling_active_reg;
    logic                  overflow_detected_reg;
    logic [7:0]            overflow_magnitude_reg;
    logic                  scale_factor_increment_reg;
    
    // Overflow detection signals
    logic                  real_overflow, imag_overflow;
    logic [7:0]            overflow_magnitude_real, overflow_magnitude_imag;
    
    // Rescaling logic
    always_comb begin
        // Local variables for overflow detection
        logic [1:0] real_msb, imag_msb;
        logic [7:0] real_overflow_bits, imag_overflow_bits;
        
        // Default outputs
        rescaled_real = data_real_reg;
        rescaled_imag = data_imag_reg;
        scale_factor_increment_reg = 1'b0;
        
        // Default overflow detection values
        real_overflow = 1'b0;
        imag_overflow = 1'b0;
        overflow_magnitude_real = 8'h00;
        overflow_magnitude_imag = 8'h00;
        
        // Default bit extraction values
        real_msb = 2'b00;
        real_overflow_bits = 8'h00;
        imag_msb = 2'b00;
        imag_overflow_bits = 8'h00;
        
        if (rescale_en_i && overflow_detect_i) begin
            // Extract bits for overflow detection (using fixed widths for Icarus compatibility)
            real_msb = data_real_reg[15:14];  // Fixed for 16-bit data
            real_overflow_bits = data_real_reg[15:8];  // Fixed for 16-bit data
            imag_msb = data_imag_reg[15:14];  // Fixed for 16-bit data
            imag_overflow_bits = data_imag_reg[15:8];  // Fixed for 16-bit data
            
            // Check for overflow in real component
            if (real_msb != 2'b00 && real_msb != 2'b11) begin
                real_overflow = 1'b1;
                overflow_magnitude_real = real_overflow_bits;
            end
            
            // Check for overflow in imaginary component
            if (imag_msb != 2'b00 && imag_msb != 2'b11) begin
                imag_overflow = 1'b1;
                overflow_magnitude_imag = imag_overflow_bits;
            end
            
            // Apply rescaling if overflow detected
            if (real_overflow || imag_overflow) begin
                if (rounding_mode_i) begin
                    // Round to nearest
                    rescaled_real = (data_real_reg >>> 1) + (data_real_reg[0] ? 1 : 0);
                    rescaled_imag = (data_imag_reg >>> 1) + (data_imag_reg[0] ? 1 : 0);
                end else begin
                    // Truncate
                    rescaled_real = data_real_reg >>> 1;
                    rescaled_imag = data_imag_reg >>> 1;
                end
                
                scale_factor_increment_reg = 1'b1;
            end
        end
    end
    
    // Saturation logic
    always_comb begin
        if (saturation_en_i) begin
            // Apply saturation to prevent overflow
            if (rescaled_real > {1'b0, {(DATA_WIDTH-1){1'b1}}}) begin
                data_real_o = {1'b0, {(DATA_WIDTH-1){1'b1}}};
            end else if (rescaled_real < {1'b1, {(DATA_WIDTH-1){1'b0}}}) begin
                data_real_o = {1'b1, {(DATA_WIDTH-1){1'b0}}};
            end else begin
                data_real_o = rescaled_real;
            end
            
            if (rescaled_imag > {1'b0, {(DATA_WIDTH-1){1'b1}}}) begin
                data_imag_o = {1'b0, {(DATA_WIDTH-1){1'b1}}};
            end else if (rescaled_imag < {1'b1, {(DATA_WIDTH-1){1'b0}}}) begin
                data_imag_o = {1'b1, {(DATA_WIDTH-1){1'b0}}};
            end else begin
                data_imag_o = rescaled_imag;
            end
        end else begin
            data_real_o = rescaled_real;
            data_imag_o = rescaled_imag;
        end
    end
    
    // Scale factor tracking
    always_ff @(posedge clk_i or negedge reset_n_i) begin
        if (!reset_n_i) begin
            scale_factor_reg <= 8'h00;
            rescale_count_reg <= 8'h00;
            overflow_magnitude_reg <= 8'h00;
        end else if (scale_track_en_i) begin
            if (scale_factor_increment_reg) begin
                scale_factor_reg <= scale_factor_reg + 1;
                rescale_count_reg <= rescale_count_reg + 1;
                
                // Track maximum overflow magnitude
                if (overflow_magnitude_real > overflow_magnitude_reg) begin
                    overflow_magnitude_reg <= overflow_magnitude_real;
                end
                if (overflow_magnitude_imag > overflow_magnitude_reg) begin
                    overflow_magnitude_reg <= overflow_magnitude_imag;
                end
            end
        end
    end
    
    // Data pipeline
    always_ff @(posedge clk_i) begin
        if (data_valid_i) begin
            data_real_reg <= data_real_i;
            data_imag_reg <= data_imag_i;
        end
        data_valid_o <= data_valid_i;
    end
    
    // Overflow detection pipeline
    always_ff @(posedge clk_i) begin
        overflow_detected_reg <= real_overflow || imag_overflow;
        rescaling_active_reg <= scale_factor_increment_reg;
    end
    
    // Output assignments
    assign overflow_detected_o = overflow_detected_reg;
    assign overflow_magnitude_o = overflow_magnitude_reg;
    assign scale_factor_o = scale_factor_reg;
    assign scale_factor_increment_o = scale_factor_increment_reg;
    assign rescaling_active_o = rescaling_active_reg;
    assign rescale_count_o = rescale_count_reg;

endmodule

`endif // FFT_RESCALE_UNIT_SV 