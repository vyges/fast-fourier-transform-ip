// Copyright 2026 Vyges Inc.
// SPDX-License-Identifier: Apache-2.0
//
// fft_ctrl_tlul — TL-UL slave wrapper for the FFT Accelerator
//
// Description:
//   Bridges the TL-UL crossbar to the fast-fourier-transform-ip APB slave port
//   using the tlul-apb-adapter protocol bridge IP.
//
//   IP reuse chain:
//     xbar (TL-UL) → [tlul_apb_adapter] → [fft_top APB port]
//
//   Phase 1 — AXI data port of fft_top is tied off. Sample data is loaded via
//   APB register writes. Full AXI DMA path is Phase 2.
//
//   Interrupts (fft_done_o, fft_error_o) are exported to top-level for PLIC wiring.
//
//   Note: tlul_apb_adapter uses flat TL-UL signals, not tlul_pkg struct types.
//         This wrapper flattens the struct ports from the xbar before passing
//         them to the adapter.

`ifndef FFT_CTRL_TLUL_SV
`define FFT_CTRL_TLUL_SV

module fft_ctrl_tlul
  import tlul_pkg::*;
#(
  parameter int unsigned FFT_MAX_LENGTH_LOG2 = 10,  // 1024-point
  parameter int unsigned FFT_DATA_WIDTH      = 16,
  parameter int unsigned FFT_TWIDDLE_WIDTH   = 16
) (
  input  logic clk_i,
  input  logic rst_ni,

  // TL-UL slave interface (from xbar tl_u_fft_o / tl_u_fft_i)
  input  tlul_pkg::tl_h2d_t tl_i,
  output tlul_pkg::tl_d2h_t tl_o,

  // FFT interrupt outputs (to top-level / PLIC)
  output logic fft_done_o,
  output logic fft_error_o
);

  // -------------------------------------------------------------------------
  // Flatten TL-UL struct → flat signals for tlul_apb_adapter
  // -------------------------------------------------------------------------

  // A channel (host → device)
  logic        tl_a_valid;
  logic [2:0]  tl_a_opcode;
  logic [2:0]  tl_a_param;
  logic [1:0]  tl_a_size;
  logic [7:0]  tl_a_source;
  logic [31:0] tl_a_address;
  logic [3:0]  tl_a_mask;
  logic [31:0] tl_a_data;
  logic        tl_a_ready;

  // D channel (device → host)
  logic        tl_d_valid;
  logic [2:0]  tl_d_opcode;
  logic [1:0]  tl_d_param;
  logic [1:0]  tl_d_size;
  logic [7:0]  tl_d_source;
  logic        tl_d_error;
  logic [31:0] tl_d_data;
  logic        tl_d_ready;

  // Unpack tl_h2d_t
  assign tl_a_valid   = tl_i.a_valid;
  assign tl_a_opcode  = tl_i.a_opcode;
  assign tl_a_param   = tl_i.a_param;
  assign tl_a_size    = tl_i.a_size;
  assign tl_a_source  = tl_i.a_source;
  assign tl_a_address = tl_i.a_address;
  assign tl_a_mask    = tl_i.a_mask;
  assign tl_a_data    = tl_i.a_data;
  assign tl_d_ready   = tl_i.d_ready;

  // Pack tl_d2h_t
  assign tl_o.d_valid  = tl_d_valid;
  assign tl_o.d_opcode = tlul_pkg::tl_d_op_e'(tl_d_opcode);
  assign tl_o.d_param  = tl_d_param;
  assign tl_o.d_size   = tl_d_size;
  assign tl_o.d_source = tl_d_source;
  assign tl_o.d_sink   = '0;
  assign tl_o.d_data   = tl_d_data;
  assign tl_o.d_error  = tl_d_error;
  assign tl_o.d_user   = '0;
  assign tl_o.a_ready  = tl_a_ready;

  // -------------------------------------------------------------------------
  // APB wires (adapter → FFT)
  // -------------------------------------------------------------------------

  logic        apb_psel;
  logic        apb_penable;
  logic        apb_pwrite;
  logic [31:0] apb_paddr;
  logic [31:0] apb_pwdata;
  logic [3:0]  apb_pstrb;
  logic [2:0]  apb_pprot;
  logic [31:0] apb_prdata;
  logic        apb_pready;

  // -------------------------------------------------------------------------
  // tlul_apb_adapter instantiation
  // Converts TL-UL slave port → APB master port
  // -------------------------------------------------------------------------

  tlul_apb_adapter #(
    .AW          (32),
    .DW          (32),
    .SOURCE_WIDTH(8),
    .APB4_EN     (1)
  ) u_adapter (
    .clk_i           (clk_i),
    .rst_ni          (rst_ni),

    // TL-UL A channel (request)
    .tl_a_valid_i    (tl_a_valid),
    .tl_a_opcode_i   (tl_a_opcode),
    .tl_a_param_i    (tl_a_param),
    .tl_a_size_i     (tl_a_size),
    .tl_a_source_i   (tl_a_source),
    .tl_a_address_i  (tl_a_address),
    .tl_a_mask_i     (tl_a_mask),
    .tl_a_data_i     (tl_a_data),
    .tl_a_ready_o    (tl_a_ready),

    // TL-UL D channel (response)
    .tl_d_valid_o    (tl_d_valid),
    .tl_d_opcode_o   (tl_d_opcode),
    .tl_d_param_o    (tl_d_param),
    .tl_d_size_o     (tl_d_size),
    .tl_d_source_o   (tl_d_source),
    .tl_d_error_o    (tl_d_error),
    .tl_d_data_o     (tl_d_data),
    .tl_d_ready_i    (tl_d_ready),

    // APB master
    .apb_psel_o      (apb_psel),
    .apb_penable_o   (apb_penable),
    .apb_pwrite_o    (apb_pwrite),
    .apb_paddr_o     (apb_paddr),
    .apb_pwdata_o    (apb_pwdata),
    .apb_pstrb_o     (apb_pstrb),
    .apb_pprot_o     (apb_pprot),
    .apb_prdata_i    (apb_prdata),
    .apb_pready_i    (apb_pready),
    .apb_pslverr_i   (1'b0)       // fft_top does not expose PSLVERR
  );

  // -------------------------------------------------------------------------
  // fft_top instantiation
  // APB port connected to adapter; AXI port tied off (Phase 1)
  // -------------------------------------------------------------------------

  fft_top #(
    .FFT_MAX_LENGTH_LOG2(FFT_MAX_LENGTH_LOG2),
    .FFT_DATA_WIDTH     (FFT_DATA_WIDTH),
    .FFT_TWIDDLE_WIDTH  (FFT_TWIDDLE_WIDTH),
    .FFT_APB_ADDR_WIDTH (16),
    .FFT_AXI_ADDR_WIDTH (32),
    .FFT_AXI_DATA_WIDTH (64)
  ) u_fft_top (
    .clk_i        (clk_i),
    .reset_n_i    (rst_ni),

    // APB control interface
    .pclk_i       (clk_i),
    .preset_n_i   (rst_ni),
    .psel_i       (apb_psel),
    .penable_i    (apb_penable),
    .pwrite_i     (apb_pwrite),
    .paddr_i      (apb_paddr[15:0]),   // Truncate 32→16; FFT reg space < 64KB
    .pwdata_i     (apb_pwdata),
    .prdata_o     (apb_prdata),
    .pready_o     (apb_pready),

    // AXI data interface — tied off (Phase 1: APB-only sample loading)
    .axi_aclk_i       (clk_i),
    .axi_areset_n_i   (rst_ni),
    .axi_awaddr_i     (32'b0),
    .axi_awvalid_i    (1'b0),
    .axi_awready_o    (),
    .axi_wdata_i      (64'b0),
    .axi_wvalid_i     (1'b0),
    .axi_wready_o     (),
    .axi_araddr_i     (32'b0),
    .axi_arvalid_i    (1'b0),
    .axi_arready_o    (),
    .axi_rdata_o      (),
    .axi_rvalid_o     (),
    .axi_rready_i     (1'b0),

    // Interrupts
    .fft_done_o   (fft_done_o),
    .fft_error_o  (fft_error_o)
  );

endmodule

`endif // FFT_CTRL_TLUL_SV
