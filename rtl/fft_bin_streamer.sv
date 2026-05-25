// SPDX-License-Identifier: Apache-2.0
//
// fft_bin_streamer — post-completion output streamer for the FFT
// scratchpad. After the engine asserts `fft_done` and streaming is
// enabled, walks the scratchpad bin-by-bin and emits each
// (re, im, index) triplet on a generic streaming output port set.
//
// The streamer borrows the engine-facing memory port during the
// streaming window — when the engine is in its done state it has
// released the port, so there is no contention. The top-level
// instantiation muxes between the engine's address driver and this
// module's address driver based on streamer_active_o.
//
// Memory packing assumption: 32-bit memory word per complex bin,
// [15:0] = signed real, [31:16] = signed imaginary. Bins reside at
// addresses 0..N-1 in natural order. (Engines that produce
// bit-reversed output should run a bit-reverse pass before raising
// fft_done, or wrap this module with an address-mapping shim.)

`ifndef FFT_BIN_STREAMER_SV
`define FFT_BIN_STREAMER_SV

module fft_bin_streamer #(
  parameter int unsigned MAX_LENGTH_LOG2 = 12,
  parameter int unsigned DATA_WIDTH      = 16,
  parameter int unsigned INDEX_WIDTH     = 12,
  parameter int unsigned MEM_ADDR_WIDTH  = 16
) (
  input  logic                              clk_i,
  input  logic                              rst_ni,

  // Engine completion + configuration
  input  logic                              fft_done_pulse_i,    // single-cycle when engine finishes
  input  logic                              stream_enable_i,     // gate from CTRL register
  input  logic [MAX_LENGTH_LOG2:0]          num_bins_i,           // 2^fft_length_log2

  // Memory read port (multiplexed with the engine port at the top level)
  output logic [MEM_ADDR_WIDTH-1:0]         mem_addr_o,
  output logic                              mem_read_o,           // 1 = bin streamer is reading
  input  logic                              mem_ready_i,          // 1-cycle ready pulse from memory
  input  logic [31:0]                       mem_data_i,           // {imag[15:0], real[15:0]}

  // Top-level mux control (high while the streamer owns the memory port)
  output logic                              streamer_active_o,

  // vyges-dsp-stream-v1 output
  output logic                              bin_valid_o,
  input  logic                              bin_ready_i,
  output logic [INDEX_WIDTH-1:0]            bin_index_o,
  output logic                              bin_last_o,
  output logic signed [DATA_WIDTH-1:0]      bin_re_o,
  output logic signed [DATA_WIDTH-1:0]      bin_im_o
);

  // ── State machine ─────────────────────────────────────────────────────
  //
  // S_IDLE  : waiting for fft_done_pulse_i + stream_enable_i.
  // S_REQ   : asserting mem_read_o with the current bin address.
  // S_WAIT  : holding the address, waiting for the memory's 1-cycle
  //           ready pulse. Latch (re, im) when it arrives.
  // S_EMIT  : present (index, re, im, last) on the output stream.
  //           Advance when bin_ready_i is asserted.

  typedef enum logic [1:0] {
    S_IDLE,
    S_REQ,
    S_WAIT,
    S_EMIT
  } state_e;

  state_e                       state_q, state_n;
  logic [INDEX_WIDTH-1:0]       bin_idx_q;
  logic signed [DATA_WIDTH-1:0] re_q;
  logic signed [DATA_WIDTH-1:0] im_q;
  logic                         is_last;

  // Widen bin_idx_q to the num_bins port width for the bounds check so
  // the comparison is unambiguous on the wide side (num_bins_i is one
  // bit wider than INDEX_WIDTH to be able to express N = 2^INDEX_WIDTH).
  logic [MAX_LENGTH_LOG2:0]     bin_idx_extended;
  assign bin_idx_extended = {{(MAX_LENGTH_LOG2+1-INDEX_WIDTH){1'b0}}, bin_idx_q};
  assign is_last = (bin_idx_extended == (num_bins_i - 1'b1)) & (num_bins_i != '0);

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q   <= S_IDLE;
      bin_idx_q <= '0;
      re_q      <= '0;
      im_q      <= '0;
    end else begin
      state_q <= state_n;

      case (state_q)
        S_IDLE: begin
          if (fft_done_pulse_i && stream_enable_i)
            bin_idx_q <= '0;
        end
        S_WAIT: begin
          if (mem_ready_i) begin
            re_q <= mem_data_i[DATA_WIDTH-1:0];
            im_q <= mem_data_i[DATA_WIDTH+15:16];
          end
        end
        S_EMIT: begin
          if (bin_ready_i) begin
            if (is_last)
              bin_idx_q <= '0;
            else
              bin_idx_q <= bin_idx_q + 1'b1;
          end
        end
        default: ;
      endcase
    end
  end

  always_comb begin
    state_n = state_q;
    unique case (state_q)
      S_IDLE: if (fft_done_pulse_i && stream_enable_i) state_n = S_REQ;
      S_REQ:  state_n = S_WAIT;
      S_WAIT: if (mem_ready_i) state_n = S_EMIT;
      S_EMIT: if (bin_ready_i) state_n = is_last ? S_IDLE : S_REQ;
      default: state_n = S_IDLE;
    endcase
  end

  // ── Memory port ─────────────────────────────────────────────────────
  assign streamer_active_o = (state_q != S_IDLE);
  assign mem_read_o        = (state_q == S_REQ);
  assign mem_addr_o        = {{(MEM_ADDR_WIDTH-INDEX_WIDTH){1'b0}}, bin_idx_q};

  // ── Stream output ────────────────────────────────────────────────────
  assign bin_valid_o = (state_q == S_EMIT);
  assign bin_index_o = bin_idx_q;
  assign bin_last_o  = (state_q == S_EMIT) && is_last;
  assign bin_re_o    = re_q;
  assign bin_im_o    = im_q;

endmodule

`endif // FFT_BIN_STREAMER_SV
