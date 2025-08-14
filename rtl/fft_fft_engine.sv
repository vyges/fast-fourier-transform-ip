`ifndef FFT_FFT_ENGINE_SV
`define FFT_FFT_ENGINE_SV

`include "fft_timescale.vh"
`include "fft_defines.vh"

//=============================================================================
// FFT Engine Module
//=============================================================================
// Description: Main FFT computation engine with 6-stage pipeline and
//              automatic rescaling functionality. Implements radix-2 DIF
//              algorithm with configurable FFT lengths.
// Author:      Vyges IP Development Team
// Date:        2025-07-21
// License:     Apache-2.0
//=============================================================================

module fft_engine #(
    parameter int FFT_MAX_LENGTH_LOG2 = 12,    // Maximum FFT length (log2)
    parameter int FFT_DATA_WIDTH = 16,         // Input/output data width
    parameter int FFT_TWIDDLE_WIDTH = 16       // Twiddle factor width
) (
    // Clock and Reset
    input  logic        clk_i,
    input  logic        reset_n_i,
    
    // Control Interface
    input  logic        fft_start_i,
    input  logic        fft_reset_i,
    output logic        fft_busy_o,
    output logic        fft_done_o,
    output logic        fft_error_o,
    input  logic [11:0] fft_length_log2_i,
    input  logic        rescale_en_i,
    input  logic        scale_track_en_i,
    input  logic        rescale_mode_i,
    input  logic        rounding_mode_i,
    input  logic        saturation_en_i,
    input  logic        overflow_detect_i,
    
    // Memory Interface
    output logic [15:0] mem_addr_i,
    output logic [31:0] mem_data_i,
    output logic        mem_write_i,
    input  logic [31:0] mem_data_o,
    input  logic        mem_ready_o,
    
    // Rescaling Interface
    output logic [7:0]  scale_factor_o,
    output logic [7:0]  stage_count_o,
    output logic        rescaling_active_o,
    output logic        overflow_detected_o,
    output logic [7:0]  overflow_count_o,
    output logic [7:0]  last_overflow_stage_o,
    output logic [7:0]  max_overflow_magnitude_o
);

    // Internal signals
    logic [11:0] fft_length_log2_reg;
    logic        rescale_en_reg;
    logic        scale_track_en_reg;
    logic        rescale_mode_reg;
    logic        rounding_mode_reg;
    logic        saturation_en_reg;
    logic        overflow_detect_reg;
    
    // Pipeline stage signals
    logic [5:0]  pipeline_valid;
    
    // Pipeline address registers (individual instead of arrays)
    logic [15:0] pipeline_addr_a_0, pipeline_addr_a_1, pipeline_addr_a_2, pipeline_addr_a_3, pipeline_addr_a_4, pipeline_addr_a_5;
    logic [15:0] pipeline_addr_b_0, pipeline_addr_b_1, pipeline_addr_b_2, pipeline_addr_b_3, pipeline_addr_b_4, pipeline_addr_b_5;
    
    // Pipeline data registers (individual instead of arrays)
    logic [31:0] pipeline_data_a_0, pipeline_data_a_1, pipeline_data_a_2, pipeline_data_a_3, pipeline_data_a_4, pipeline_data_a_5;
    logic [31:0] pipeline_data_b_0, pipeline_data_b_1, pipeline_data_b_2, pipeline_data_b_3, pipeline_data_b_4, pipeline_data_b_5;
    
    // Pipeline twiddle registers (individual instead of arrays)
    logic [31:0] pipeline_twiddle_0, pipeline_twiddle_1, pipeline_twiddle_2, pipeline_twiddle_3, pipeline_twiddle_4, pipeline_twiddle_5;
    
    // Pipeline result registers (individual instead of arrays)
    logic [31:0] pipeline_result_a_0, pipeline_result_a_1, pipeline_result_a_2, pipeline_result_a_3, pipeline_result_a_4, pipeline_result_a_5;
    logic [31:0] pipeline_result_b_0, pipeline_result_b_1, pipeline_result_b_2, pipeline_result_b_3, pipeline_result_b_4, pipeline_result_b_5;
    
    // Butterfly operation signals
    logic [15:0] butterfly_real_a, butterfly_imag_a;
    logic [15:0] butterfly_real_b, butterfly_imag_b;
    logic [15:0] butterfly_twiddle_real, butterfly_twiddle_imag;
    logic [15:0] butterfly_result_real_a, butterfly_result_imag_a;
    logic [15:0] butterfly_result_real_b, butterfly_result_imag_b;
    logic [15:0] butterfly_temp_real, butterfly_temp_imag;  // Temporary registers for A-B
    logic [15:0] butterfly_final_real_a, butterfly_final_imag_a;  // Final results after rescaling
    logic [15:0] butterfly_final_real_b, butterfly_final_imag_b;  // Final results after rescaling
    logic        butterfly_overflow;
    
    // Rescaling signals
    logic [7:0]  scale_factor_reg;
    logic [7:0]  stage_count_reg;
    logic [7:0]  overflow_count_reg;
    logic [7:0]  last_overflow_stage_reg;
    logic [7:0]  max_overflow_magnitude_reg;
    logic        rescaling_active_reg;
    logic        overflow_detected_reg;
    logic        scale_factor_increment;
    logic        pipeline_rescaling_active;  // New signal for pipeline stage 6
    
    // Address generation signals
    logic [11:0] stage_counter;
    logic [11:0] butterfly_counter;
    logic [11:0] butterfly_spacing;
    logic [15:0] addr_a, addr_b;
    logic [15:0] twiddle_addr;
    
    // State machine
    typedef enum logic [2:0] {
        FFT_IDLE,
        FFT_CONFIG,
        FFT_LOAD,
        FFT_COMPUTE,
        FFT_RESCALE,
        FFT_DONE,
        FFT_ERROR
    } fft_state_t;
    
    fft_state_t fft_state, fft_next_state;
    
    // Configuration registers
    always_ff @(posedge clk_i or negedge reset_n_i) begin
        if (!reset_n_i) begin
            fft_length_log2_reg <= 12'h00A;  // Default 1024 points
            rescale_en_reg <= 1'b0;
            scale_track_en_reg <= 1'b0;
            rescale_mode_reg <= 1'b0;
            rounding_mode_reg <= 1'b0;
            saturation_en_reg <= 1'b0;
            overflow_detect_reg <= 1'b0;
        end else if (fft_start_i) begin
            fft_length_log2_reg <= fft_length_log2_i;
            rescale_en_reg <= rescale_en_i;
            scale_track_en_reg <= scale_track_en_i;
            rescale_mode_reg <= rescale_mode_i;
            rounding_mode_reg <= rounding_mode_i;
            saturation_en_reg <= saturation_en_i;
            overflow_detect_reg <= overflow_detect_i;
        end
    end
    
    // State machine
    always_ff @(posedge clk_i or negedge reset_n_i) begin
        if (!reset_n_i) begin
            fft_state <= FFT_IDLE;
        end else if (fft_reset_i) begin
            fft_state <= FFT_IDLE;
        end else begin
            fft_state <= fft_next_state;
        end
    end
    
    // State machine next state logic
    always_comb begin
        fft_next_state = fft_state;
        
        case (fft_state)
            FFT_IDLE: begin
                if (fft_start_i) begin
                    fft_next_state = FFT_CONFIG;
                end
            end
            
            FFT_CONFIG: begin
                fft_next_state = FFT_LOAD;
            end
            
            FFT_LOAD: begin
                if (mem_ready_o) begin
                    fft_next_state = FFT_COMPUTE;
                end
            end
            
            FFT_COMPUTE: begin
                if (stage_counter >= fft_length_log2_reg) begin
                    if (rescale_en_reg && rescale_mode_reg) begin
                        fft_next_state = FFT_RESCALE;
                    end else begin
                        fft_next_state = FFT_DONE;
                    end
                end else if (fft_error_o) begin
                    fft_next_state = FFT_ERROR;
                end
            end
            
            FFT_RESCALE: begin
                fft_next_state = FFT_DONE;
            end
            
            FFT_DONE: begin
                fft_next_state = FFT_IDLE;
            end
            
            FFT_ERROR: begin
                fft_next_state = FFT_IDLE;
            end
            
            default: begin
                fft_next_state = FFT_IDLE;
            end
        endcase
    end
    
    // Output logic
    always_comb begin
        fft_busy_o = (fft_state != FFT_IDLE);
        fft_done_o = (fft_state == FFT_DONE);
        fft_error_o = (fft_state == FFT_ERROR);
        rescaling_active_o = rescaling_active_reg;
        overflow_detected_o = overflow_detected_reg;
    end
    
    // Rescaling and overflow tracking
    always_ff @(posedge clk_i or negedge reset_n_i) begin
        if (!reset_n_i) begin
            scale_factor_reg <= 8'h00;
            stage_count_reg <= 8'h00;
            overflow_count_reg <= 8'h00;
            last_overflow_stage_reg <= 8'h00;
            max_overflow_magnitude_reg <= 8'h00;
            rescaling_active_reg <= 1'b0;
            overflow_detected_reg <= 1'b0;
        end else if (fft_start_i) begin
            scale_factor_reg <= 8'h00;
            stage_count_reg <= 8'h00;
            overflow_count_reg <= 8'h00;
            last_overflow_stage_reg <= 8'h00;
            max_overflow_magnitude_reg <= 8'h00;
            rescaling_active_reg <= 1'b0;
            overflow_detected_reg <= 1'b0;
        end else if (scale_track_en_reg) begin
            if (scale_factor_increment) begin
                scale_factor_reg <= scale_factor_reg + 1;
                overflow_count_reg <= overflow_count_reg + 1;
                last_overflow_stage_reg <= stage_count_reg;
                overflow_detected_reg <= 1'b1;
            end
            
            if (stage_counter >= fft_length_log2_reg && fft_state == FFT_COMPUTE) begin
                stage_count_reg <= stage_count_reg + 1;
            end
            
            // Update rescaling_active_reg based on pipeline signal
            rescaling_active_reg <= pipeline_rescaling_active;
        end
    end
    
    // Output assignments
    assign scale_factor_o = scale_factor_reg;
    assign stage_count_o = stage_count_reg;
    assign overflow_count_o = overflow_count_reg;
    assign last_overflow_stage_o = last_overflow_stage_reg;
    assign max_overflow_magnitude_o = max_overflow_magnitude_reg;
    
    // Address generation
    always_comb begin
        butterfly_spacing = 1 << stage_counter;
        addr_a = (16'(stage_counter) * 16'(butterfly_spacing)) + 16'(butterfly_counter);
        addr_b = addr_a + 16'(butterfly_spacing);
        // Simplified twiddle address calculation to avoid complex modulo
        twiddle_addr = (16'(stage_counter) * 16'(butterfly_counter)) & ((1 << (fft_length_log2_reg - 1)) - 1);
    end
    
    // Memory address multiplexing (fix driver-driver conflict)
    always_ff @(posedge clk_i) begin
        if (!reset_n_i) begin
            mem_addr_i <= 16'h0000;
        end else if (fft_state == FFT_COMPUTE && mem_ready_o) begin
            // Stage 1: Read first data
            mem_addr_i <= addr_a;
        end else if (pipeline_valid[0]) begin
            // Stage 2: Read second data
            mem_addr_i <= pipeline_addr_b_0;
        end else if (pipeline_valid[1]) begin
            // Stage 3: Read twiddle factors
            mem_addr_i <= pipeline_addr_a_0 + 16'h1000;  // Twiddle ROM base
        end else if (pipeline_valid[4]) begin
            // Stage 6: Write results
            mem_addr_i <= pipeline_addr_a_4;
        end else begin
            mem_addr_i <= 16'h0000;
        end
    end

    // Memory write control
    always_ff @(posedge clk_i) begin
        if (!reset_n_i) begin
            mem_write_i <= 1'b0;
        end else if (pipeline_valid[4]) begin
            // Stage 6: Write results
            mem_write_i <= 1'b1;
        end else begin
            mem_write_i <= 1'b0;
        end
    end

    // Pipeline stage 1: Address generation and memory read
    always_ff @(posedge clk_i) begin
        if (fft_state == FFT_COMPUTE && mem_ready_o) begin
            pipeline_valid[0] <= 1'b1;
            pipeline_addr_a_0 <= addr_a;
            pipeline_addr_b_0 <= addr_b;
        end else begin
            pipeline_valid[0] <= 1'b0;
        end
    end
    
    // Pipeline stage 2: Data alignment and twiddle factor fetch
    always_ff @(posedge clk_i) begin
        if (pipeline_valid[0]) begin
            pipeline_valid[1] <= 1'b1;
            pipeline_data_a_1 <= mem_data_o;
            pipeline_addr_a_1 <= pipeline_addr_a_0;
            pipeline_addr_b_1 <= pipeline_addr_b_0;
        end else begin
            pipeline_valid[1] <= 1'b0;
        end
    end
    
    // Pipeline stage 3: Complex addition
    always_ff @(posedge clk_i) begin
        if (pipeline_valid[1]) begin
            pipeline_valid[2] <= 1'b1;
            pipeline_data_b_2 <= mem_data_o;
            pipeline_addr_a_2 <= pipeline_addr_a_1;
            pipeline_addr_b_2 <= pipeline_addr_b_1;
            
            // Complex addition: A + B (fix width issues)
            butterfly_real_a <= 16'((pipeline_data_a_1 >> 16) & 32'hFFFF);
            butterfly_imag_a <= 16'(pipeline_data_a_1 & 32'hFFFF);
            butterfly_real_b <= 16'((mem_data_o >> 16) & 32'hFFFF);
            butterfly_imag_b <= 16'(mem_data_o & 32'hFFFF);
        end else begin
            pipeline_valid[2] <= 1'b0;
        end
    end
    
    // Pipeline stage 4: Complex subtraction and address propagation
    always_ff @(posedge clk_i) begin
        if (pipeline_valid[2]) begin
            pipeline_valid[3] <= 1'b1;
            pipeline_twiddle_3 <= mem_data_o;
            pipeline_addr_a_3 <= pipeline_addr_a_2;
            pipeline_addr_b_3 <= pipeline_addr_b_2;
            
            // Complex addition result
            butterfly_result_real_a <= butterfly_real_a + butterfly_real_b;
            butterfly_result_imag_a <= butterfly_imag_a + butterfly_imag_b;
            
            // Complex subtraction: A - B (store in temporary registers)
            butterfly_temp_real <= butterfly_real_a - butterfly_real_b;
            butterfly_temp_imag <= butterfly_imag_a - butterfly_imag_b;
        end else begin
            pipeline_valid[3] <= 1'b0;
        end
    end
    
    // Pipeline stage 5: Complex multiplication
    always_ff @(posedge clk_i) begin
        if (pipeline_valid[3]) begin
            pipeline_valid[4] <= 1'b1;
            pipeline_addr_a_4 <= pipeline_addr_a_3;
            pipeline_addr_b_4 <= pipeline_addr_b_3;
            
            // Extract twiddle factors (fix width issues)
            butterfly_twiddle_real <= 16'((pipeline_twiddle_3 >> 16) & 32'hFFFF);
            butterfly_twiddle_imag <= 16'(pipeline_twiddle_3 & 32'hFFFF);
            
            // Complex multiplication: (A-B) * W
            butterfly_result_real_b <= (butterfly_temp_real * butterfly_twiddle_real) - 
                                      (butterfly_temp_imag * butterfly_twiddle_imag);
            butterfly_result_imag_b <= (butterfly_temp_real * butterfly_twiddle_imag) + 
                                      (butterfly_temp_imag * butterfly_twiddle_real);
        end else begin
            pipeline_valid[4] <= 1'b0;
        end
    end
    
    // Pipeline stage 6: Rescaling and memory write
    always_ff @(posedge clk_i) begin
        if (pipeline_valid[4]) begin
            pipeline_valid[5] <= 1'b1;
            
            // Check for overflow and apply rescaling
            if (rescale_en_reg && overflow_detect_reg) begin
                // Overflow detection logic
                logic real_overflow_a, imag_overflow_a;
                logic real_overflow_b, imag_overflow_b;
                
                real_overflow_a = (|butterfly_result_real_a[15:14]) && 
                                 (butterfly_result_real_a[15:14] != 2'b11);
                imag_overflow_a = (|butterfly_result_imag_a[15:14]) && 
                                 (butterfly_result_imag_a[15:14] != 2'b11);
                real_overflow_b = (|butterfly_result_real_b[15:14]) && 
                                 (butterfly_result_real_b[15:14] != 2'b11);
                imag_overflow_b = (|butterfly_result_imag_b[15:14]) && 
                                 (butterfly_result_imag_b[15:14] != 2'b11);
                
                if (real_overflow_a || imag_overflow_a || real_overflow_b || imag_overflow_b) begin
                    // Apply rescaling
                    butterfly_final_real_a <= butterfly_result_real_a >>> 1;
                    butterfly_final_imag_a <= butterfly_result_imag_a >>> 1;
                    butterfly_final_real_b <= butterfly_result_real_b >>> 1;
                    butterfly_final_imag_b <= butterfly_result_imag_b >>> 1;
                    scale_factor_increment <= 1'b1;
                    pipeline_rescaling_active <= 1'b1;
                end else begin
                    // Rescaling disabled - pass through results
                    butterfly_final_real_a <= butterfly_result_real_a;
                    butterfly_final_imag_a <= butterfly_result_imag_a;
                    butterfly_final_real_b <= butterfly_result_real_b;
                    butterfly_final_imag_b <= butterfly_result_imag_b;
                    scale_factor_increment <= 1'b0;
                    pipeline_rescaling_active <= 1'b0;
                end
            end else begin
                // Rescaling disabled - pass through results
                butterfly_final_real_a <= butterfly_result_real_a;
                butterfly_final_imag_a <= butterfly_result_imag_a;
                butterfly_final_real_b <= butterfly_result_real_b;
                butterfly_final_imag_b <= butterfly_result_imag_b;
                scale_factor_increment <= 1'b0;
                pipeline_rescaling_active <= 1'b0;
            end
            
            // Write results to memory (fix width issues)
            mem_data_i <= (32'(butterfly_final_real_a) << 16) | 32'(butterfly_final_imag_a);
        end else begin
            pipeline_valid[5] <= 1'b0;
            pipeline_rescaling_active <= 1'b0;
        end
    end
    
    // Butterfly counter and stage counter
    always_ff @(posedge clk_i or negedge reset_n_i) begin
        if (!reset_n_i) begin
            butterfly_counter <= 12'h000;
            stage_counter <= 12'h000;
        end else if (fft_start_i) begin
            butterfly_counter <= 12'h000;
            stage_counter <= 12'h000;
        end else if (fft_state == FFT_COMPUTE && pipeline_valid[5]) begin
            if (butterfly_counter >= (1 << (fft_length_log2_reg - 1)) - 1) begin
                butterfly_counter <= 12'h000;
                stage_counter <= stage_counter + 1;
            end else begin
                butterfly_counter <= butterfly_counter + 1;
            end
        end
    end

    //=============================================================================
    // Security Assertions - Dual Mode (Yosys + Full SystemVerilog)
    //=============================================================================
    
     // FSM state validity - ensure stable state transitions
     // Yosys-compatible security checks (synthesis-safe)
    `ifdef YOSYS_SYNTHESIS
    // Note: Yosys doesn't support $error or SystemVerilog assertions
    // These are implemented as synthesis-safe logic that can be optimized out
    logic security_violation_fsm;
    logic security_violation_stage_count;
    logic security_violation_buffer_access;
    
    // FSM state validity - synthesis-safe implementation
    assign security_violation_fsm = !(fft_state == FFT_IDLE || fft_state == FFT_LOAD || fft_state == FFT_COMPUTE || 
                                     fft_state == FFT_RESCALE || fft_state == FFT_DONE || fft_state == FFT_ERROR);
    
    // Stage count validation - synthesis-safe implementation
    assign security_violation_stage_count = stage_counter > fft_length_log2_reg;
    
    // Buffer access validation - synthesis-safe implementation
    assign security_violation_buffer_access = mem_addr_i >= 16'h1000;
    
    // These signals can be used for formal verification or external monitoring
    // In synthesis, they will be optimized out if not used
    `endif
    
    // Full SystemVerilog security assertions (for simulation and formal verification)
    `ifdef SECURITY_ASSERTIONS
    property fsm_state_validity;
        @(posedge clk_i) disable iff (!reset_n_i)
        (fft_state == FFT_IDLE || fft_state == FFT_LOAD || fft_state == FFT_COMPUTE || 
         fft_state == FFT_RESCALE || fft_state == FFT_DONE || fft_state == FFT_ERROR);
    endproperty
    
    // Reset synchronization - ensure proper reset behavior
    property reset_synchronization;
        @(posedge clk_i)
        !reset_n_i |-> (fft_state == FFT_IDLE && stage_counter == 0);
    endproperty
    
    // Overflow protection - ensure scale factor tracking prevents overflow
    property overflow_protection;
        @(posedge clk_i) disable iff (!reset_n_i)
        (overflow_detected_o) |-> (scale_factor_reg < 8'hFF); // Assuming MAX_SCALE_FACTOR is 8'hFF
    endproperty
    
    // Stage count validation - ensure stage count stays within bounds
    property stage_count_validation;
        @(posedge clk_i) disable iff (!reset_n_i)
        (stage_counter <= fft_length_log2_reg);
    endproperty
    
    // Buffer access validation - prevent illegal buffer access
    property buffer_access_validation;
        @(posedge clk_i) disable iff (!reset_n_i)
        (mem_addr_i < 16'h1000); // Only 4KB (1024 points * 4 bytes) for twiddle factors
    endproperty
    
    // Assert the security properties
    assert property (fsm_state_validity) else
        $error("Security violation: Invalid FSM state detected in FFT engine");
    
    assert property (reset_synchronization) else
        $error("Security violation: Improper reset behavior detected in FFT engine");
    
    assert property (overflow_protection) else
        $error("Security violation: Overflow detected without proper scale factor tracking");
    
    assert property (stage_count_validation) else
        $error("Security violation: Stage count exceeds maximum allowed value");
    
    assert property (buffer_access_validation) else
        $error("Security violation: Illegal buffer selection detected");
    `endif
    
    //=============================================================================
    // End Security Assertions
    //=============================================================================

endmodule

`endif // FFT_FFT_ENGINE_SV 