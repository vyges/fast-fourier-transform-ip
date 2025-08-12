`ifndef FFT_FFT_CONTROL_SV
`define FFT_FFT_CONTROL_SV

`include "fft_timescale.vh"
`include "fft_defines.vh"

//=============================================================================
// FFT Control Module
//=============================================================================
// Description: Control unit for the FFT accelerator managing state transitions,
//              buffer switching, and interrupt generation.
// Author:      Vyges IP Development Team
// Date:        2025-07-21
// License:     Apache-2.0
//=============================================================================

module fft_control #(
    parameter int FFT_MAX_LENGTH_LOG2 = 12    // Maximum FFT length (log2)
) (
    // Clock and Reset
    input  logic        clk_i,
    input  logic        reset_n_i,
    
    // FFT Engine Interface
    input  logic        fft_start_i,
    input  logic        fft_reset_i,
    output logic        fft_busy_o,
    input  logic        fft_done_i,
    input  logic        fft_error_i,
    input  logic [11:0] fft_length_log2_i,
    input  logic        rescale_en_i,
    input  logic        scale_track_en_i,
    input  logic        rescale_mode_i,
    input  logic        rounding_mode_i,
    input  logic        saturation_en_i,
    input  logic        overflow_detect_i,
    
    // Buffer Control Interface
    input  logic        buffer_swap_i,
    output logic        buffer_active_o,
    input  logic [1:0]  buffer_sel_i,
    
    // Interrupt Interface
    input  logic [7:0]  int_enable_i,
    output logic [7:0]  int_status_o
);

    // Internal signals
    logic [1:0]  buffer_active_reg;
    logic [7:0]  int_status_reg;
    logic        fft_busy_reg;
    logic        fft_done_pending;
    logic        fft_error_pending;
    logic        buffer_swap_pending;
    logic        overflow_pending;
    logic        rescale_pending;
    
    // State machine
    typedef enum logic [2:0] {
        CTRL_IDLE,
        CTRL_CONFIG,
        CTRL_LOAD,
        CTRL_COMPUTE,
        CTRL_RESCALE,
        CTRL_DONE,
        CTRL_ERROR
    } ctrl_state_t;
    
    ctrl_state_t ctrl_state, ctrl_next_state;
    
    // State machine
    always_ff @(posedge clk_i or negedge reset_n_i) begin
        if (!reset_n_i) begin
            ctrl_state <= CTRL_IDLE;
        end else if (fft_reset_i) begin
            ctrl_state <= CTRL_IDLE;
        end else begin
            ctrl_state <= ctrl_next_state;
        end
    end
    
    // Next state logic
    always_comb begin
        ctrl_next_state = ctrl_state;
        
        case (ctrl_state)
            CTRL_IDLE: begin
                if (fft_start_i) begin
                    ctrl_next_state = CTRL_CONFIG;
                end
            end
            
            CTRL_CONFIG: begin
                ctrl_next_state = CTRL_LOAD;
            end
            
            CTRL_LOAD: begin
                ctrl_next_state = CTRL_COMPUTE;
            end
            
            CTRL_COMPUTE: begin
                if (fft_error_i) begin
                    ctrl_next_state = CTRL_ERROR;
                end else if (fft_done_i) begin
                    if (rescale_en_i && rescale_mode_i) begin
                        ctrl_next_state = CTRL_RESCALE;
                    end else begin
                        ctrl_next_state = CTRL_DONE;
                    end
                end
            end
            
            CTRL_RESCALE: begin
                ctrl_next_state = CTRL_DONE;
            end
            
            CTRL_DONE: begin
                ctrl_next_state = CTRL_IDLE;
            end
            
            CTRL_ERROR: begin
                ctrl_next_state = CTRL_IDLE;
            end
            
            default: begin
                ctrl_next_state = CTRL_IDLE;
            end
        endcase
    end
    
    // Buffer control
    always_ff @(posedge clk_i or negedge reset_n_i) begin
        if (!reset_n_i) begin
            buffer_active_reg <= 2'b00;
        end else if (fft_reset_i) begin
            buffer_active_reg <= 2'b00;
        end else if (buffer_swap_i) begin
            buffer_active_reg <= ~buffer_active_reg;
        end else if (buffer_sel_i[1]) begin
            buffer_active_reg <= 2'b10;  // Force buffer B
        end else if (buffer_sel_i[0]) begin
            buffer_active_reg <= 2'b01;  // Force buffer A
        end
    end
    
    // Interrupt generation
    always_ff @(posedge clk_i or negedge reset_n_i) begin
        if (!reset_n_i) begin
            fft_done_pending <= 1'b0;
            fft_error_pending <= 1'b0;
            buffer_swap_pending <= 1'b0;
            overflow_pending <= 1'b0;
            rescale_pending <= 1'b0;
        end else begin
            // FFT completion interrupt
            if (fft_done_i && int_enable_i[0]) begin
                fft_done_pending <= 1'b1;
            end else if (int_status_reg[0]) begin
                fft_done_pending <= 1'b0;
            end
            
            // FFT error interrupt
            if (fft_error_i && int_enable_i[1]) begin
                fft_error_pending <= 1'b1;
            end else if (int_status_reg[1]) begin
                fft_error_pending <= 1'b0;
            end
            
            // Buffer swap interrupt
            if (buffer_swap_i && int_enable_i[2]) begin
                buffer_swap_pending <= 1'b1;
            end else if (int_status_reg[2]) begin
                buffer_swap_pending <= 1'b0;
            end
            
            // Overflow interrupt
            if (overflow_detect_i && int_enable_i[3]) begin
                overflow_pending <= 1'b1;
            end else if (int_status_reg[3]) begin
                overflow_pending <= 1'b0;
            end
            
            // Rescaling interrupt
            if (rescale_en_i && int_enable_i[4]) begin
                rescale_pending <= 1'b1;
            end else if (int_status_reg[4]) begin
                rescale_pending <= 1'b0;
            end
        end
    end
    
    // Interrupt status register
    always_comb begin
        int_status_reg = {
            3'b000,                     // Reserved
            rescale_pending,            // Rescaling interrupt pending
            overflow_pending,           // Overflow interrupt pending
            buffer_swap_pending,        // Buffer swap interrupt pending
            fft_error_pending,          // FFT error interrupt pending
            fft_done_pending            // FFT completion interrupt pending
        };
    end
    
    // Busy signal
    always_ff @(posedge clk_i or negedge reset_n_i) begin
        if (!reset_n_i) begin
            fft_busy_reg <= 1'b0;
        end else begin
            fft_busy_reg <= (ctrl_state != CTRL_IDLE);
        end
    end
    
    // Output assignments
    assign fft_busy_o = fft_busy_reg;
    assign buffer_active_o = buffer_active_reg[0];
    assign int_status_o = int_status_reg;

endmodule

`endif // FFT_FFT_CONTROL_SV 