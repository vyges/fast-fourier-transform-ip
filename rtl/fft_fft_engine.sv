`ifndef FFT_FFT_ENGINE_SV
`define FFT_FFT_ENGINE_SV

`include "fft_timescale.vh"
`include "fft_defines.vh"

//=============================================================================
// FFT Engine Module
//=============================================================================
// Description: In-place radix-2 decimation-in-frequency FFT over the shared
//              working memory, with per-stage rescaling and a final
//              bit-reverse pass so results land in natural order.
//
//              Memory contract (see fft_memory_interface.sv): one port, one
//              access per cycle. The engine registers mem_addr_i /
//              mem_write_i / mem_data_i; read data for an address issued on
//              cycle t is on mem_data_o on cycle t+2.
//                data    0x0000 + i   word i = {imag[31:16], real[15:0]}
//                twiddle 0x1000 + k   word k = {cos[31:16], -sin[15:0]} of
//                                     W_N^k = e^(-j*2*pi*k/N), k < N/2
//
//              One run, launched by START in IDLE:
//                CONFIG   latch the configuration; an illegal length is an
//                         error (log2(N) must be 1..min(FFT_MAX_LENGTH_LOG2,10))
//                LOAD     wait for the memory to be ready
//                SCAN     (rescale_mode 0 only) read the input once to decide
//                         whether stage 0 needs scaling
//                COMPUTE  log2(N) stages of N/2 butterflies, 6 cycles each:
//                           read A, read B, read W, (wait), write A', write B'
//                           A' = (A + B) >> sh
//                           B' = ((A - B) * W) >> (15 + sh)
//                         sh = 1 when the stage is scaled, else 0
//                REORDER  swap word i with word bitrev(i) for every i < bitrev(i)
//                DONE     one cycle (fft_done_o), then IDLE
//
//              Rescaling (rescale_en_i and overflow_detect_i both set):
//                rescale_mode 1: every stage is scaled; the result is X/N.
//                rescale_mode 0: a stage is scaled only when one of its input
//                         components lies outside [-2^13, 2^13), the range
//                         that cannot grow past 16 bits in one stage.
//              scale_factor_o counts the scaled stages (when scale tracking is
//              on), so it never exceeds log2(N); the result is X / 2^scale.
//
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

    // The data window holds 1024 words and the twiddle window 512, so 1024
    // points is the largest length the memory supports whatever the parameter.
    localparam int FFT_MEM_LENGTH_LOG2 = 10;
    localparam int FFT_LEGAL_MAX_LOG2  = (FFT_MAX_LENGTH_LOG2 < FFT_MEM_LENGTH_LOG2)
                                         ? FFT_MAX_LENGTH_LOG2 : FFT_MEM_LENGTH_LOG2;
    localparam logic [15:0] FFT_TWIDDLE_BASE = 16'h1000;

    typedef enum logic [2:0] {
        FFT_IDLE,
        FFT_CONFIG,
        FFT_LOAD,
        FFT_SCAN,
        FFT_COMPUTE,
        FFT_REORDER,
        FFT_DONE,
        FFT_ERROR
    } fft_state_t;

    fft_state_t fft_state;

    // Configuration, latched once per run at launch
    logic [11:0] fft_length_log2_reg;
    logic        rescale_en_reg;
    logic        scale_track_en_reg;
    logic        rescale_mode_reg;
    logic        rounding_mode_reg;
    logic        saturation_en_reg;
    logic        overflow_detect_reg;

    // Sequencing
    logic [3:0]  stage_counter;      // current stage, 0 .. log2(N)-1
    logic [9:0]  butterfly_counter;  // butterfly in the stage, 0 .. N/2-1
    logic [10:0] index_counter;      // SCAN and REORDER word index, 0 .. N+1
    logic [2:0]  phase;              // step within a butterfly or a swap
    logic        stage_scaled;       // current stage divides by 2
    logic        guard;              // a value seen so far is outside [-2^13, 2^13)

    // Operands and results
    logic [31:0] data_a, data_b;
    logic [31:0] result_b;

    // Status
    logic [7:0]  scale_factor_reg;
    logic [7:0]  stage_count_reg;
    logic [7:0]  overflow_count_reg;
    logic [7:0]  last_overflow_stage_reg;
    logic        overflow_detected_reg;

    logic launch;
    assign launch = (fft_state == FFT_IDLE) && fft_start_i;

    //-------------------------------------------------------------------------
    // Addresses
    //-------------------------------------------------------------------------
    logic [3:0]  length_log2;        // log2(N), legal once past CONFIG
    logic [3:0]  half_log2;          // log2 of the butterfly span in this stage
    logic [9:0]  span_mask;
    logic [9:0]  addr_a, addr_b, twiddle_index;
    logic [10:0] last_index;         // N - 1
    logic [9:0]  last_butterfly;     // N/2 - 1
    logic [9:0]  reversed_index;

    assign length_log2    = fft_length_log2_reg[3:0];
    assign half_log2      = length_log2 - 4'd1 - stage_counter;
    assign span_mask      = (10'd1 << half_log2) - 10'd1;
    // A sits at the butterfly index with a 0 inserted at bit half_log2; B is
    // one span above it. The twiddle exponent is j * 2^stage for j = b mod span.
    assign addr_a         = ((butterfly_counter & ~span_mask) << 1) | (butterfly_counter & span_mask);
    assign addr_b         = addr_a | (10'd1 << half_log2);
    assign twiddle_index  = (butterfly_counter & span_mask) << stage_counter;
    assign last_index     = (11'd1 << length_log2) - 11'd1;
    assign last_butterfly = 10'((11'd1 << length_log2) >> 1) - 10'd1;

    always_comb begin
        reversed_index = '0;
        for (int i = 0; i < FFT_MEM_LENGTH_LOG2; i++) begin
            if (i < int'(length_log2))
                reversed_index[i] = index_counter[int'(length_log2) - 1 - i];
        end
    end

    //-------------------------------------------------------------------------
    // Butterfly arithmetic (Q1.15), evaluated while the twiddle word is on
    // mem_data_o
    //-------------------------------------------------------------------------
    logic signed [15:0] a_re, a_im, b_re, b_im, w_re, w_im;
    logic signed [16:0] sum_re, sum_im, dif_re, dif_im;
    logic signed [34:0] prod_re, prod_im;
    logic signed [34:0] val_a_re, val_a_im, val_b_re, val_b_im;
    logic [15:0]        out_a_re, out_a_im, out_b_re, out_b_im;
    logic               ovf_a_re, ovf_a_im, ovf_b_re, ovf_b_im;
    logic               butterfly_overflow;

    assign a_re = data_a[15:0];
    assign a_im = data_a[31:16];
    assign b_re = data_b[15:0];
    assign b_im = data_b[31:16];
    assign w_re = mem_data_o[31:16];
    assign w_im = mem_data_o[15:0];

    assign sum_re  = a_re + b_re;
    assign sum_im  = a_im + b_im;
    assign dif_re  = a_re - b_re;
    assign dif_im  = a_im - b_im;
    assign prod_re = dif_re * w_re - dif_im * w_im;
    assign prod_im = dif_re * w_im + dif_im * w_re;

    // A' = (A + B) >> sh, adding half an LSB first when rounding.
    function automatic logic signed [34:0] fft_shift_sum(input logic signed [34:0] v,
                                                         input logic scaled,
                                                         input logic round);
        if (scaled)
            fft_shift_sum = (v + (round ? 35'sd1 : 35'sd0)) >>> 1;
        else
            fft_shift_sum = v;
    endfunction

    // B' = ((A - B) * W) >> (15 + sh), adding half an LSB first when rounding.
    function automatic logic signed [34:0] fft_shift_prod(input logic signed [34:0] v,
                                                          input logic scaled,
                                                          input logic round);
        if (scaled)
            fft_shift_prod = (v + (round ? 35'sd32768 : 35'sd0)) >>> 16;
        else
            fft_shift_prod = (v + (round ? 35'sd16384 : 35'sd0)) >>> 15;
    endfunction

    // Narrow to 16 bits: clamp when saturating, otherwise keep the low bits.
    // Bit 16 of the result flags a value that did not fit.
    function automatic logic [16:0] fft_fit(input logic signed [34:0] v, input logic saturate);
        logic over, under;
        over  = v > 35'sd32767;
        under = v < -35'sd32768;
        if (saturate && over)
            fft_fit = {1'b1, 16'h7FFF};
        else if (saturate && under)
            fft_fit = {1'b1, 16'h8000};
        else
            fft_fit = {over | under, v[15:0]};
    endfunction

    // Outside [-2^13, 2^13): the top three bits are not all equal.
    function automatic logic fft_near_full(input logic [15:0] v);
        fft_near_full = !(v[15:13] == 3'b000 || v[15:13] == 3'b111);
    endfunction

    always_comb begin
        val_a_re = fft_shift_sum(35'(sum_re), stage_scaled, rounding_mode_reg);
        val_a_im = fft_shift_sum(35'(sum_im), stage_scaled, rounding_mode_reg);
        val_b_re = fft_shift_prod(prod_re, stage_scaled, rounding_mode_reg);
        val_b_im = fft_shift_prod(prod_im, stage_scaled, rounding_mode_reg);
        {ovf_a_re, out_a_re} = fft_fit(val_a_re, saturation_en_reg);
        {ovf_a_im, out_a_im} = fft_fit(val_a_im, saturation_en_reg);
        {ovf_b_re, out_b_re} = fft_fit(val_b_re, saturation_en_reg);
        {ovf_b_im, out_b_im} = fft_fit(val_b_im, saturation_en_reg);
        butterfly_overflow = ovf_a_re | ovf_a_im | ovf_b_re | ovf_b_im;
    end

    //-------------------------------------------------------------------------
    // Sequencer
    //-------------------------------------------------------------------------
    logic rescale_on;
    logic last_stage, last_in_stage;
    logic stage_guard;  // guard including the butterfly being written now
    assign rescale_on    = rescale_en_reg && overflow_detect_reg;
    assign last_stage    = (stage_counter == length_log2 - 4'd1);
    assign last_in_stage = (butterfly_counter == last_butterfly);
    assign stage_guard   = guard | fft_near_full(out_a_re) | fft_near_full(out_a_im)
                                 | fft_near_full(out_b_re) | fft_near_full(out_b_im);

    always_ff @(posedge clk_i or negedge reset_n_i) begin
        if (!reset_n_i) begin
            fft_state               <= FFT_IDLE;
            fft_length_log2_reg     <= 12'h00A;  // Default 1024 points
            rescale_en_reg          <= 1'b0;
            scale_track_en_reg      <= 1'b0;
            rescale_mode_reg        <= 1'b0;
            rounding_mode_reg       <= 1'b0;
            saturation_en_reg       <= 1'b0;
            overflow_detect_reg     <= 1'b0;
            stage_counter           <= '0;
            butterfly_counter       <= '0;
            index_counter           <= '0;
            phase                   <= '0;
            stage_scaled            <= 1'b0;
            guard                   <= 1'b0;
            data_a                  <= '0;
            data_b                  <= '0;
            result_b                <= '0;
            mem_addr_i              <= '0;
            mem_data_i              <= '0;
            mem_write_i             <= 1'b0;
            scale_factor_reg        <= '0;
            stage_count_reg         <= '0;
            overflow_count_reg      <= '0;
            last_overflow_stage_reg <= '0;
            overflow_detected_reg   <= 1'b0;
        end else if (fft_reset_i) begin
            // Abort: nothing in flight survives, no write goes out afterwards.
            fft_state   <= FFT_IDLE;
            phase       <= '0;
            mem_addr_i  <= '0;
            mem_write_i <= 1'b0;
        end else begin
            mem_write_i <= 1'b0;

            case (fft_state)
                FFT_IDLE: begin
                    mem_addr_i <= '0;
                    if (launch) begin
                        fft_length_log2_reg     <= fft_length_log2_i;
                        rescale_en_reg          <= rescale_en_i;
                        scale_track_en_reg      <= scale_track_en_i;
                        rescale_mode_reg        <= rescale_mode_i;
                        rounding_mode_reg       <= rounding_mode_i;
                        saturation_en_reg       <= saturation_en_i;
                        overflow_detect_reg     <= overflow_detect_i;
                        stage_counter           <= '0;
                        butterfly_counter       <= '0;
                        index_counter           <= '0;
                        phase                   <= '0;
                        guard                   <= 1'b0;
                        scale_factor_reg        <= '0;
                        stage_count_reg         <= '0;
                        overflow_count_reg      <= '0;
                        last_overflow_stage_reg <= '0;
                        overflow_detected_reg   <= 1'b0;
                        fft_state               <= FFT_CONFIG;
                    end
                end

                FFT_CONFIG: begin
                    if (fft_length_log2_reg == 12'd0 || fft_length_log2_reg > 12'(FFT_LEGAL_MAX_LOG2))
                        fft_state <= FFT_ERROR;
                    else
                        fft_state <= FFT_LOAD;
                end

                FFT_LOAD: begin
                    if (mem_ready_o) begin
                        if (rescale_on && !rescale_mode_reg) begin
                            fft_state <= FFT_SCAN;
                        end else begin
                            stage_scaled <= rescale_on;
                            fft_state    <= FFT_COMPUTE;
                        end
                    end
                end

                // Issue word i on cycle i; its data is checked two cycles later.
                FFT_SCAN: begin
                    if (index_counter <= last_index)
                        mem_addr_i <= 16'(index_counter);
                    if (index_counter >= 11'd2) begin
                        if (fft_near_full(mem_data_o[15:0]) || fft_near_full(mem_data_o[31:16]))
                            guard <= 1'b1;
                    end
                    if (index_counter == last_index + 11'd2) begin
                        stage_scaled  <= guard | fft_near_full(mem_data_o[15:0])
                                               | fft_near_full(mem_data_o[31:16]);
                        guard         <= 1'b0;
                        index_counter <= '0;
                        fft_state     <= FFT_COMPUTE;
                    end else begin
                        index_counter <= index_counter + 11'd1;
                    end
                end

                FFT_COMPUTE: begin
                    case (phase)
                        3'd0: mem_addr_i <= 16'(addr_a);
                        3'd1: mem_addr_i <= 16'(addr_b);
                        3'd2: begin
                            data_a     <= mem_data_o;
                            mem_addr_i <= FFT_TWIDDLE_BASE + 16'(twiddle_index);
                        end
                        3'd3: data_b <= mem_data_o;
                        3'd4: begin
                            mem_addr_i  <= 16'(addr_a);
                            mem_data_i  <= {out_a_im, out_a_re};
                            mem_write_i <= 1'b1;
                            result_b    <= {out_b_im, out_b_re};
                            guard       <= stage_guard;
                            if (butterfly_overflow && overflow_detect_reg) begin
                                overflow_detected_reg   <= 1'b1;
                                last_overflow_stage_reg <= 8'(stage_counter);
                                if (overflow_count_reg != 8'hFF)
                                    overflow_count_reg <= overflow_count_reg + 8'd1;
                            end
                        end
                        default: begin  // 3'd5
                            mem_addr_i  <= 16'(addr_b);
                            mem_data_i  <= result_b;
                            mem_write_i <= 1'b1;
                            if (last_in_stage) begin
                                butterfly_counter <= '0;
                                stage_count_reg   <= stage_count_reg + 8'd1;
                                if (stage_scaled && scale_track_en_reg)
                                    scale_factor_reg <= scale_factor_reg + 8'd1;
                                // The next stage is scaled when this stage's
                                // outputs could grow past 16 bits in it.
                                stage_scaled <= rescale_on && (rescale_mode_reg || guard);
                                guard        <= 1'b0;
                                if (last_stage) begin
                                    index_counter <= '0;
                                    fft_state     <= FFT_REORDER;
                                end else begin
                                    stage_counter <= stage_counter + 4'd1;
                                end
                            end else begin
                                butterfly_counter <= butterfly_counter + 10'd1;
                            end
                        end
                    endcase
                    phase <= (phase == 3'd5) ? 3'd0 : phase + 3'd1;
                end

                // Swap word i and word bitrev(i), once per pair.
                FFT_REORDER: begin
                    case (phase)
                        3'd0: begin
                            if (index_counter == last_index) begin
                                fft_state <= FFT_DONE;
                            end else if (10'(index_counter) < reversed_index) begin
                                mem_addr_i <= 16'(index_counter);
                                phase      <= 3'd1;
                            end else begin
                                index_counter <= index_counter + 11'd1;
                            end
                        end
                        3'd1: begin
                            mem_addr_i <= 16'(reversed_index);
                            phase      <= 3'd2;
                        end
                        3'd2: begin
                            data_a <= mem_data_o;  // word i
                            phase  <= 3'd3;
                        end
                        3'd3: begin
                            mem_addr_i  <= 16'(index_counter);
                            mem_data_i  <= mem_data_o;  // word bitrev(i)
                            mem_write_i <= 1'b1;
                            phase       <= 3'd4;
                        end
                        default: begin  // 3'd4
                            mem_addr_i    <= 16'(reversed_index);
                            mem_data_i    <= data_a;
                            mem_write_i   <= 1'b1;
                            index_counter <= index_counter + 11'd1;
                            phase         <= 3'd0;
                        end
                    endcase
                end

                FFT_DONE: begin
                    stage_scaled <= 1'b0;
                    fft_state    <= FFT_IDLE;
                end

                default: begin  // FFT_ERROR
                    fft_state <= FFT_IDLE;
                end
            endcase
        end
    end

    //-------------------------------------------------------------------------
    // Outputs
    //-------------------------------------------------------------------------
    assign fft_busy_o               = (fft_state != FFT_IDLE);
    assign fft_done_o               = (fft_state == FFT_DONE);
    assign fft_error_o              = (fft_state == FFT_ERROR);
    assign rescaling_active_o       = (fft_state == FFT_COMPUTE) && stage_scaled;
    assign overflow_detected_o      = overflow_detected_reg;
    assign scale_factor_o           = scale_factor_reg;
    assign stage_count_o            = stage_count_reg;
    assign overflow_count_o         = overflow_count_reg;
    assign last_overflow_stage_o    = last_overflow_stage_reg;
    assign max_overflow_magnitude_o = 8'h00;  // not measured; reads 0

    //=============================================================================
    // Security Assertions - Dual Mode (Yosys + Full SystemVerilog)
    //=============================================================================

    // Valid engine addresses: data 0x0000-0x03FF, twiddle 0x1000-0x11FF.
    `ifdef YOSYS_SYNTHESIS
    // Synthesis-safe checks: plain logic that can be optimized out or probed.
    logic security_violation_stage_count;
    logic security_violation_buffer_access;

    assign security_violation_stage_count  = stage_counter >= length_log2 && fft_state == FFT_COMPUTE;
    assign security_violation_buffer_access = mem_write_i && (mem_addr_i >= 16'h0400);
    `endif

    // Full SystemVerilog security assertions (for simulation and formal verification)
    `ifdef SECURITY_ASSERTIONS
    property reset_synchronization;
        @(posedge clk_i)
        !reset_n_i |-> (fft_state == FFT_IDLE && stage_counter == 0);
    endproperty

    property scale_factor_bounded;
        @(posedge clk_i) disable iff (!reset_n_i)
        (scale_factor_reg <= 8'(FFT_LEGAL_MAX_LOG2));
    endproperty

    property stage_count_validation;
        @(posedge clk_i) disable iff (!reset_n_i)
        (fft_state == FFT_COMPUTE) |-> (stage_counter < length_log2);
    endproperty

    property write_inside_data_window;
        @(posedge clk_i) disable iff (!reset_n_i)
        mem_write_i |-> (mem_addr_i <= 16'(last_index));
    endproperty

    assert property (reset_synchronization) else
        $error("Security violation: Improper reset behavior detected in FFT engine");

    assert property (scale_factor_bounded) else
        $error("Security violation: Scale factor exceeds log2 of the maximum length");

    assert property (stage_count_validation) else
        $error("Security violation: Stage count exceeds maximum allowed value");

    assert property (write_inside_data_window) else
        $error("Security violation: Engine write outside the configured data buffer");
    `endif

    //=============================================================================
    // End Security Assertions
    //=============================================================================

endmodule

`endif // FFT_FFT_ENGINE_SV
