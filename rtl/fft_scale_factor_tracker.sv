`ifndef FFT_SCALE_FACTOR_TRACKER_SV
`define FFT_SCALE_FACTOR_TRACKER_SV

`include "fft_timescale.vh"
`include "fft_defines.vh"

//=============================================================================
// Scale Factor Tracker Module
//=============================================================================
// Description: Accumulates and tracks scale factors applied during FFT
//              computation. Provides scale factor information for signal
//              reconstruction and overflow statistics.
// Author:      Vyges IP Development Team
// Date:        2025-07-21
// License:     Apache-2.0
//=============================================================================

module scale_factor_tracker #(
    parameter int SCALE_FACTOR_WIDTH = 8,      // Scale factor width
    parameter int STAGE_COUNT_WIDTH = 8,       // Stage count width
    parameter int OVERFLOW_COUNT_WIDTH = 8     // Overflow count width
) (
    // Clock and Reset
    input  logic        clk_i,
    input  logic        reset_n_i,
    
    // Control Interface
    input  logic        fft_start_i,
    input  logic        scale_track_en_i,
    input  logic        scale_factor_increment_i,
    input  logic        stage_complete_i,
    input  logic        overflow_detected_i,
    input  logic [7:0]  overflow_magnitude_i,
    input  logic [7:0]  overflow_stage_i,
    
    // Scale Factor Outputs
    output logic [SCALE_FACTOR_WIDTH-1:0] total_scale_factor_o,
    output logic [STAGE_COUNT_WIDTH-1:0]  stage_count_o,
    output logic [OVERFLOW_COUNT_WIDTH-1:0] overflow_count_o,
    output logic [7:0]  last_overflow_stage_o,
    output logic [7:0]  max_overflow_magnitude_o,
    
    // Status Interface
    output logic        scale_factor_overflow_o,
    output logic        tracking_active_o
);

    // Internal registers
    logic [SCALE_FACTOR_WIDTH-1:0] scale_factor_reg;
    logic [STAGE_COUNT_WIDTH-1:0]  stage_count_reg;
    logic [OVERFLOW_COUNT_WIDTH-1:0] overflow_count_reg;
    logic [7:0]  last_overflow_stage_reg;
    logic [7:0]  max_overflow_magnitude_reg;
    logic        scale_factor_overflow_reg;
    logic        tracking_active_reg;
    
    // Scale factor accumulator
    always_ff @(posedge clk_i or negedge reset_n_i) begin
        if (!reset_n_i) begin
            scale_factor_reg <= 8'h00;
            stage_count_reg <= 8'h00;
            overflow_count_reg <= 8'h00;
            last_overflow_stage_reg <= 8'h00;
            max_overflow_magnitude_reg <= 8'h00;
            scale_factor_overflow_reg <= 1'b0;
            tracking_active_reg <= 1'b0;
        end else if (fft_start_i) begin
            // Reset counters on FFT start
            scale_factor_reg <= 8'h00;
            stage_count_reg <= 8'h00;
            overflow_count_reg <= 8'h00;
            last_overflow_stage_reg <= 8'h00;
            max_overflow_magnitude_reg <= 8'h00;
            scale_factor_overflow_reg <= 1'b0;
            tracking_active_reg <= scale_track_en_i;
        end else if (scale_track_en_i && tracking_active_reg) begin
            // Increment scale factor when rescaling occurs
            if (scale_factor_increment_i) begin
                if (scale_factor_reg < 8'hFF) begin
                    scale_factor_reg <= scale_factor_reg + 1;
                end else begin
                    scale_factor_overflow_reg <= 1'b1;
                end
                
                // Track overflow statistics
                overflow_count_reg <= overflow_count_reg + 1;
                last_overflow_stage_reg <= overflow_stage_i;
                
                if (overflow_magnitude_i > max_overflow_magnitude_reg) begin
                    max_overflow_magnitude_reg <= overflow_magnitude_i;
                end
            end
            
            // Increment stage count when stage completes
            if (stage_complete_i) begin
                stage_count_reg <= stage_count_reg + 1;
            end
        end
    end
    
    // Output assignments
    assign total_scale_factor_o = scale_factor_reg;
    assign stage_count_o = stage_count_reg;
    assign overflow_count_o = overflow_count_reg;
    assign last_overflow_stage_o = last_overflow_stage_reg;
    assign max_overflow_magnitude_o = max_overflow_magnitude_reg;
    assign scale_factor_overflow_o = scale_factor_overflow_reg;
    assign tracking_active_o = tracking_active_reg;

endmodule

`endif // FFT_SCALE_FACTOR_TRACKER_SV 