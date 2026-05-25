`ifndef FFT_FFT_TOP_SV
`define FFT_FFT_TOP_SV

`include "fft_timescale.vh"
`include "fft_defines.vh"

//=============================================================================
// FFT Hardware Accelerator Top-Level Module
//=============================================================================
// Description: Top-level module for the Fast Fourier Transform (FFT) hardware
//              accelerator with automatic rescaling and scale factor tracking.
//              Supports configurable FFT lengths from 256 to 4096 points.
// Author:      Vyges IP Development Team
// Date:        2025-07-21
// License:     Apache-2.0
//=============================================================================

module fft_top #(
    parameter int FFT_MAX_LENGTH_LOG2 = 12,    // Maximum FFT length (log2)
    parameter int FFT_DATA_WIDTH = 16,         // Input/output data width
    parameter int FFT_TWIDDLE_WIDTH = 16,      // Twiddle factor width
    parameter int FFT_APB_ADDR_WIDTH = 16,     // APB address width
    parameter int FFT_AXI_ADDR_WIDTH = 32,     // AXI address width
    parameter int FFT_AXI_DATA_WIDTH = 64      // AXI data width
) (
    // Clock and Reset
    input  logic        clk_i,                 // System clock
    input  logic        reset_n_i,             // Active-low reset
    
    // APB Interface
    input  logic        pclk_i,                // APB clock
    input  logic        preset_n_i,            // APB reset
    input  logic        psel_i,                // APB select
    input  logic        penable_i,             // APB enable
    input  logic        pwrite_i,              // APB write enable
    input  logic [FFT_APB_ADDR_WIDTH-1:0] paddr_i, // APB address
    input  logic [31:0] pwdata_i,              // APB write data
    output logic [31:0] prdata_o,              // APB read data
    output logic        pready_o,              // APB ready
    
    // AXI Interface
    input  logic        axi_aclk_i,            // AXI clock
    input  logic        axi_areset_n_i,        // AXI reset
    input  logic [FFT_AXI_ADDR_WIDTH-1:0] axi_awaddr_i,   // AXI write address
    input  logic        axi_awvalid_i,         // AXI write address valid
    output logic        axi_awready_o,         // AXI write address ready
    input  logic [FFT_AXI_DATA_WIDTH-1:0] axi_wdata_i,    // AXI write data
    input  logic        axi_wvalid_i,          // AXI write data valid
    output logic        axi_wready_o,          // AXI write data ready
    input  logic [FFT_AXI_ADDR_WIDTH-1:0] axi_araddr_i,   // AXI read address
    input  logic        axi_arvalid_i,         // AXI read address valid
    output logic        axi_arready_o,         // AXI read address ready
    output logic [FFT_AXI_DATA_WIDTH-1:0] axi_rdata_o,    // AXI read data
    output logic        axi_rvalid_o,          // AXI read data valid
    input  logic        axi_rready_i,          // AXI read data ready
    
    // Interrupt Interface
    output logic        fft_done_o,            // FFT completion interrupt
    output logic        fft_error_o,           // FFT error interrupt

    // External SRAM bus (FFT_USE_SRAM_MACRO only) — passthrough to wrapper
    output logic        sram_clk_o,
    output logic [9:0]  sram_addr_o,
    output logic [31:0] sram_wdata_o,
    output logic [31:0] sram_ben_o,
    output logic        sram_rwb_o,
    output logic [1:0]  sram_en_o,
    input  logic [31:0] sram_rdata0_i,
    input  logic [31:0] sram_rdata1_i,

    // Generic bus master (FFT_USE_BUS_MASTER only) — passthrough to wrapper.
    // SoC integrator wraps these with a thin protocol adapter (TL-UL,
    // AXI-Lite, Wishbone, ...). See docs/bus-master-mode-design.md.
`ifdef FFT_USE_BUS_MASTER
    output logic        mem_req_valid_o,
    input  logic        mem_req_ready_i,
    output logic [10:0] mem_req_addr_o,
    output logic        mem_req_we_o,
    output logic [31:0] mem_req_wdata_o,
    output logic [3:0]  mem_req_be_o,
    input  logic        mem_rsp_valid_i,
    input  logic [31:0] mem_rsp_rdata_i,
    input  logic        mem_rsp_err_i,
`endif

    // Streaming bin output (active when FFT_USE_STREAM_OUT is defined;
    // tied off otherwise). See docs/stream-out-mode-design.md for the
    // protocol and the wrapper-scope wiring pattern.
    output logic                              bin_valid_o,
    input  logic                              bin_ready_i,
    output logic [FFT_MAX_LENGTH_LOG2-1:0]    bin_index_o,
    output logic                              bin_last_o,
    output logic signed [FFT_DATA_WIDTH-1:0]  bin_re_o,
    output logic signed [FFT_DATA_WIDTH-1:0]  bin_im_o
);

    // Internal signals
    logic [7:0]  scale_factor_o;
    logic [7:0]  stage_count_o;
    logic        rescaling_active_o;
    logic        overflow_detected_o;
    logic [7:0]  overflow_count_o;
    logic [7:0]  last_overflow_stage_o;
    logic [7:0]  max_overflow_magnitude_o;

    // FFT engine control signals
    logic        fft_start_i;
    logic        fft_reset_i;
    logic        fft_busy_o;
    logic        fft_done_o_internal;
    logic        fft_error_o_internal;
    logic [11:0] fft_length_log2_i;
    logic        rescale_en_i;
    logic        scale_track_en_i;
    logic        rescale_mode_i;
    logic        rounding_mode_i;
    logic        saturation_en_i;
    logic        overflow_detect_i;

    // Memory interface signals (driven by the FFT engine during compute;
    // optionally overridden by the bin streamer post-fft_done — see the
    // FFT_USE_STREAM_OUT block below).
    logic [15:0] mem_addr_i;
    logic [31:0] mem_data_i;
    logic        mem_write_i;
    logic [31:0] mem_data_o;
    logic        mem_ready_o;

    // Pre-mux engine memory outputs (renamed targets for the engine's
    // mem_addr_i / mem_write_i ports so the streamer can override them).
    logic [15:0] engine_mem_addr;
    logic        engine_mem_write;

    // Bin streamer signal declarations — guarded so they exist only in
    // streaming builds. The else-branch below ties off any signals the
    // post-streamer mux assigns to the shared mem ports.
`ifdef FFT_USE_STREAM_OUT
    logic        stream_enable;
    logic        streamer_active;
    logic [15:0] streamer_mem_addr;
    logic        fft_done_pulse;
    logic        fft_done_q;
`endif

    // Buffer control signals
    logic        buffer_swap_i;
    logic        buffer_active_o;
    logic [1:0]  buffer_sel_i;

    // Interrupt control signals
    logic [7:0]  int_enable_i;
    logic [7:0]  int_status_o;

    // Instantiate FFT control unit
    fft_control #(
        .FFT_MAX_LENGTH_LOG2(FFT_MAX_LENGTH_LOG2)
    ) fft_control_inst (
        .clk_i(clk_i),
        .reset_n_i(reset_n_i),
        .fft_start_i(fft_start_i),
        .fft_reset_i(fft_reset_i),
        .fft_busy_o(),  // Remove this connection to avoid MULTIDRIVEN
        .fft_done_i(fft_done_o_internal),
        .fft_error_i(fft_error_o_internal),
        .fft_length_log2_i(fft_length_log2_i),
        .rescale_en_i(rescale_en_i),
        .scale_track_en_i(scale_track_en_i),
        .rescale_mode_i(rescale_mode_i),
        .rounding_mode_i(rounding_mode_i),
        .saturation_en_i(saturation_en_i),
        .overflow_detect_i(overflow_detect_i),
        .buffer_swap_i(buffer_swap_i),
        .buffer_active_o(buffer_active_o),
        .buffer_sel_i(buffer_sel_i),
        .int_enable_i(int_enable_i),
        .int_status_o(int_status_o)
    );

    // Instantiate FFT engine
    fft_engine #(
        .FFT_MAX_LENGTH_LOG2(FFT_MAX_LENGTH_LOG2),
        .FFT_DATA_WIDTH(FFT_DATA_WIDTH),
        .FFT_TWIDDLE_WIDTH(FFT_TWIDDLE_WIDTH)
    ) fft_engine_inst (
        .clk_i(clk_i),
        .reset_n_i(reset_n_i),
        .fft_start_i(fft_start_i),
        .fft_reset_i(fft_reset_i),
        .fft_busy_o(fft_busy_o),
        .fft_done_o(fft_done_o_internal),
        .fft_error_o(fft_error_o_internal),
        .fft_length_log2_i(fft_length_log2_i),
        .rescale_en_i(rescale_en_i),
        .scale_track_en_i(scale_track_en_i),
        .rescale_mode_i(rescale_mode_i),
        .rounding_mode_i(rounding_mode_i),
        .saturation_en_i(saturation_en_i),
        .overflow_detect_i(overflow_detect_i),
        .mem_addr_i(engine_mem_addr),
        .mem_data_i(mem_data_i),
        .mem_write_i(engine_mem_write),
        .mem_data_o(mem_data_o),
        .mem_ready_o(mem_ready_o),
        .scale_factor_o(scale_factor_o),
        .stage_count_o(stage_count_o),
        .rescaling_active_o(rescaling_active_o),
        .overflow_detected_o(overflow_detected_o),
        .overflow_count_o(overflow_count_o),
        .last_overflow_stage_o(last_overflow_stage_o),
        .max_overflow_magnitude_o(max_overflow_magnitude_o)
    );

    // Instantiate memory interface
    memory_interface #(
        .FFT_APB_ADDR_WIDTH(FFT_APB_ADDR_WIDTH),
        .FFT_AXI_ADDR_WIDTH(FFT_AXI_ADDR_WIDTH),
        .FFT_AXI_DATA_WIDTH(FFT_AXI_DATA_WIDTH)
    ) memory_interface_inst (
        .clk_i(clk_i),
        .reset_n_i(reset_n_i),
        .pclk_i(pclk_i),
        .preset_n_i(preset_n_i),
        .psel_i(psel_i),
        .penable_i(penable_i),
        .pwrite_i(pwrite_i),
        .paddr_i(paddr_i),
        .pwdata_i(pwdata_i),
        .prdata_o(prdata_o),
        .pready_o(pready_o),
        .axi_aclk_i(axi_aclk_i),
        .axi_areset_n_i(axi_areset_n_i),
        .axi_awaddr_i(axi_awaddr_i),
        .axi_awvalid_i(axi_awvalid_i),
        .axi_awready_o(axi_awready_o),
        .axi_wdata_i(axi_wdata_i),
        .axi_wvalid_i(axi_wvalid_i),
        .axi_wready_o(axi_wready_o),
        .axi_araddr_i(axi_araddr_i),
        .axi_arvalid_i(axi_arvalid_i),
        .axi_arready_o(axi_arready_o),
        .axi_rdata_o(axi_rdata_o),
        .axi_rvalid_o(axi_rvalid_o),
        .axi_rready_i(axi_rready_i),
        .mem_addr_i(mem_addr_i),
        .mem_data_i(mem_data_i),
        .mem_write_i(mem_write_i),
        .mem_data_o(mem_data_o),
        .mem_ready_o(mem_ready_o),
        .fft_start_o(fft_start_i),
        .fft_reset_o(fft_reset_i),
        .fft_length_log2_o(fft_length_log2_i),
        .rescale_en_o(rescale_en_i),
        .scale_track_en_o(scale_track_en_i),
        .rescale_mode_o(rescale_mode_i),
        .rounding_mode_o(rounding_mode_i),
        .saturation_en_o(saturation_en_i),
        .overflow_detect_o(overflow_detect_i),
        .buffer_swap_o(buffer_swap_i),
        .buffer_sel_o(buffer_sel_i),
        .int_enable_o(int_enable_i),
`ifdef FFT_USE_STREAM_OUT
        .stream_enable_o(stream_enable),
`else
        .stream_enable_o(/* unused: FFT_USE_STREAM_OUT not defined */),
`endif
        .fft_busy_i(fft_busy_o),
        .fft_done_i(fft_done_o_internal),
        .fft_error_i(fft_error_o_internal),
        .buffer_active_i(buffer_active_o),
        .rescaling_active_i(rescaling_active_o),
        .overflow_detected_i(overflow_detected_o),
        .scale_factor_i(scale_factor_o),
        .stage_count_i(stage_count_o),
        .overflow_count_i(overflow_count_o),
        .last_overflow_stage_i(last_overflow_stage_o),
        .max_overflow_magnitude_i(max_overflow_magnitude_o),
        .int_status_i(int_status_o),
        .sram_clk_o(sram_clk_o),
        .sram_addr_o(sram_addr_o),
        .sram_wdata_o(sram_wdata_o),
        .sram_ben_o(sram_ben_o),
        .sram_rwb_o(sram_rwb_o),
        .sram_en_o(sram_en_o),
        .sram_rdata0_i(sram_rdata0_i),
        .sram_rdata1_i(sram_rdata1_i)
`ifdef FFT_USE_BUS_MASTER
        ,
        .mem_req_valid_o(mem_req_valid_o),
        .mem_req_ready_i(mem_req_ready_i),
        .mem_req_addr_o(mem_req_addr_o),
        .mem_req_we_o(mem_req_we_o),
        .mem_req_wdata_o(mem_req_wdata_o),
        .mem_req_be_o(mem_req_be_o),
        .mem_rsp_valid_i(mem_rsp_valid_i),
        .mem_rsp_rdata_i(mem_rsp_rdata_i),
        .mem_rsp_err_i(mem_rsp_err_i)
`endif
    );

    // Generate interrupt outputs
    assign fft_done_o = fft_done_o_internal & int_enable_i[0];
    assign fft_error_o = fft_error_o_internal & int_enable_i[1];

    // ── Bin streamer integration ────────────────────────────────────────
    //
    // Convert the level-held fft_done_o_internal into a single-cycle pulse
    // for the streamer's IDLE → REQ trigger. Mux the engine's memory port
    // address / write strobe against the streamer's address; data and
    // ready paths are shared (the engine is in its done state while the
    // streamer runs, so there is no contention on the response path).

`ifdef FFT_USE_STREAM_OUT
    always_ff @(posedge clk_i or negedge reset_n_i) begin
        if (!reset_n_i) fft_done_q <= 1'b0;
        else            fft_done_q <= fft_done_o_internal;
    end
    assign fft_done_pulse = fft_done_o_internal & ~fft_done_q;

    // Bin streamer instance — guarded so non-streaming builds stay
    // bit-identical to the legacy flow.
    logic [FFT_MAX_LENGTH_LOG2:0] num_bins_for_streamer;
    assign num_bins_for_streamer =
        ({{FFT_MAX_LENGTH_LOG2{1'b0}}, 1'b1}) << fft_length_log2_i[$clog2(FFT_MAX_LENGTH_LOG2+1)-1:0];

    fft_bin_streamer #(
        .MAX_LENGTH_LOG2(FFT_MAX_LENGTH_LOG2),
        .DATA_WIDTH     (FFT_DATA_WIDTH),
        .INDEX_WIDTH    (FFT_MAX_LENGTH_LOG2),
        .MEM_ADDR_WIDTH (16)
    ) u_bin_streamer (
        .clk_i             (clk_i),
        .rst_ni            (reset_n_i),
        .fft_done_pulse_i  (fft_done_pulse),
        .stream_enable_i   (stream_enable),
        .num_bins_i        (num_bins_for_streamer),
        .mem_addr_o        (streamer_mem_addr),
        .mem_read_o        (),  // streamer_active gates the mux directly
        .mem_ready_i       (mem_ready_o),
        .mem_data_i        (mem_data_o),
        .streamer_active_o (streamer_active),
        .bin_valid_o       (bin_valid_o),
        .bin_ready_i       (bin_ready_i),
        .bin_index_o       (bin_index_o),
        .bin_last_o        (bin_last_o),
        .bin_re_o          (bin_re_o),
        .bin_im_o          (bin_im_o)
    );

    // Memory port mux: streamer wins when active.
    assign mem_addr_i  = streamer_active ? streamer_mem_addr : engine_mem_addr;
    assign mem_write_i = streamer_active ? 1'b0              : engine_mem_write;

`else
    // Non-streaming build: legacy flow. Engine drives the memory port
    // directly and the top-level streaming ports are tied off.
    assign mem_addr_i  = engine_mem_addr;
    assign mem_write_i = engine_mem_write;
    assign bin_valid_o = 1'b0;
    assign bin_index_o = '0;
    assign bin_last_o  = 1'b0;
    assign bin_re_o    = '0;
    assign bin_im_o    = '0;
`endif

endmodule

`endif // FFT_FFT_TOP_SV 
