`timescale 1ns/1ps

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
    parameter int DATA_WIDTH = 16,             // Input/output data width
    parameter int TWIDDLE_WIDTH = 16,          // Twiddle factor width
    parameter int APB_ADDR_WIDTH = 16,         // APB address width
    parameter int AXI_ADDR_WIDTH = 32,         // AXI address width
    parameter int AXI_DATA_WIDTH = 64          // AXI data width
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
    input  logic [APB_ADDR_WIDTH-1:0] paddr_i, // APB address
    input  logic [31:0] pwdata_i,              // APB write data
    output logic [31:0] prdata_o,              // APB read data
    output logic        pready_o,              // APB ready
    
    // AXI Interface
    input  logic        axi_aclk_i,            // AXI clock
    input  logic        axi_areset_n_i,        // AXI reset
    input  logic [AXI_ADDR_WIDTH-1:0] axi_awaddr_i,   // AXI write address
    input  logic        axi_awvalid_i,         // AXI write address valid
    output logic        axi_awready_o,         // AXI write address ready
    input  logic [AXI_DATA_WIDTH-1:0] axi_wdata_i,    // AXI write data
    input  logic        axi_wvalid_i,          // AXI write data valid
    output logic        axi_wready_o,          // AXI write data ready
    input  logic [AXI_ADDR_WIDTH-1:0] axi_araddr_i,   // AXI read address
    input  logic        axi_arvalid_i,         // AXI read address valid
    output logic        axi_arready_o,         // AXI read address ready
    output logic [AXI_DATA_WIDTH-1:0] axi_rdata_o,    // AXI read data
    output logic        axi_rvalid_o,          // AXI read data valid
    input  logic        axi_rready_i,          // AXI read data ready
    
    // Interrupt Interface
    output logic        fft_done_o,            // FFT completion interrupt
    output logic        fft_error_o            // FFT error interrupt
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

    // Memory interface signals
    logic [15:0] mem_addr_i;
    logic [31:0] mem_data_i;
    logic        mem_write_i;
    logic [31:0] mem_data_o;
    logic        mem_ready_o;

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
        .DATA_WIDTH(DATA_WIDTH),
        .TWIDDLE_WIDTH(TWIDDLE_WIDTH)
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
        .mem_addr_i(mem_addr_i),
        .mem_data_i(mem_data_i),
        .mem_write_i(mem_write_i),
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
        .APB_ADDR_WIDTH(APB_ADDR_WIDTH),
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH)
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
        .int_status_i(int_status_o)
    );

    // Generate interrupt outputs
    assign fft_done_o = fft_done_o_internal & int_enable_i[0];
    assign fft_error_o = fft_error_o_internal & int_enable_i[1];

endmodule 