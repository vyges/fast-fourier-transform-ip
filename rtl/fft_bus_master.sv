// fft_bus_master — generic memory bus master for the FFT memory backend.
//
// Used by fft_memory_interface when compiled with `FFT_USE_BUS_MASTER`.
// Sits between the FFT engine's memory port and the SoC's memory bus,
// presenting a generic request/response interface to the SoC. The SoC
// integrator wraps this module's bus-side ports with a thin protocol
// adapter (TL-UL master, AXI-Lite master, Wishbone master, ...) — see
// docs/bus-master-mode-design.md for the contract.
//
// Behaviour:
//   - Engine accesses go out as bus master requests; responses come
//     back in order (the contract requires in-order response delivery
//     from the SoC-side adapter).
//   - Up to MAX_OUTSTANDING requests in flight at once. After
//     saturating, mem_req_valid_o deasserts until a response arrives.
//   - Engine sees mem_ready_o = 1 only when both (a) the bus accepts
//     the current request AND (b) outstanding < MAX_OUTSTANDING. The
//     engine pipeline must honour mem_ready_o as a stall signal.
//   - Read responses re-emerge on the engine port via mem_rdata_o +
//     a one-cycle mem_rvalid_o pulse.
//   - Bus-level errors (rsp_err_i) latch a sticky err_o flag and
//     stall the engine until reset; rationale is in the design doc.
//
// SCRATCHPAD_DEPTH > 0 reserves the parameter for a future prefetch /
// write-back buffer; the current implementation is depth-0 (per-access
// bus round-trip). The parameter exists so integrators can pin the
// design intent in their build configuration without re-eliding the
// instance when the buffer lands.

`default_nettype none

module fft_bus_master #(
    parameter int unsigned ADDR_WIDTH       = 11,
    parameter int unsigned DATA_WIDTH       = 32,
    parameter int unsigned BE_WIDTH         = 4,
    parameter int unsigned MAX_OUTSTANDING  = 4,
    parameter int unsigned SCRATCHPAD_DEPTH = 0
) (
    input  logic                          clk_i,
    input  logic                          reset_n_i,

    // ── Engine-side memory port (mirrors fft_memory_interface engine signals) ─
    input  logic [ADDR_WIDTH-1:0]         eng_addr_i,
    input  logic [DATA_WIDTH-1:0]         eng_wdata_i,
    input  logic                          eng_we_i,
    input  logic                          eng_req_i,
    output logic [DATA_WIDTH-1:0]         eng_rdata_o,
    output logic                          eng_ready_o,
    output logic                          eng_rvalid_o,
    output logic                          eng_err_o,

    // ── Bus-side master ports (wrapped externally by SoC bus adapter) ────────
    output logic                          mem_req_valid_o,
    input  logic                          mem_req_ready_i,
    output logic [ADDR_WIDTH-1:0]         mem_req_addr_o,
    output logic                          mem_req_we_o,
    output logic [DATA_WIDTH-1:0]         mem_req_wdata_o,
    output logic [BE_WIDTH-1:0]           mem_req_be_o,
    input  logic                          mem_rsp_valid_i,
    input  logic [DATA_WIDTH-1:0]         mem_rsp_rdata_i,
    input  logic                          mem_rsp_err_i
);

    // SCRATCHPAD_DEPTH is reserved; this implementation is depth-0.
    // Reference the parameter to silence unused-parameter warnings.
    localparam int unsigned SCRATCHPAD_DEPTH_USED = SCRATCHPAD_DEPTH;

    // ── Outstanding-request counter ──────────────────────────────────────────
    // Counts in-flight requests (issued but no response yet). Saturates at
    // MAX_OUTSTANDING; engine cannot issue more until a response arrives.
    localparam int unsigned CNT_W = $clog2(MAX_OUTSTANDING + 1);
    logic [CNT_W-1:0] outstanding_q;

    logic req_fire;
    logic rsp_fire;
    assign req_fire = mem_req_valid_o & mem_req_ready_i;
    assign rsp_fire = mem_rsp_valid_i;

    always_ff @(posedge clk_i or negedge reset_n_i) begin
        if (!reset_n_i) begin
            outstanding_q <= '0;
        end else begin
            unique case ({req_fire, rsp_fire})
                2'b10:   outstanding_q <= outstanding_q + 1'b1;
                2'b01:   outstanding_q <= outstanding_q - 1'b1;
                default: outstanding_q <= outstanding_q;  // 00 or 11 (both fire)
            endcase
        end
    end

    logic outstanding_full;
    assign outstanding_full = (outstanding_q == MAX_OUTSTANDING[CNT_W-1:0]);

    // ── Sticky bus-error flag ────────────────────────────────────────────────
    // rsp_err_i latched once seen; engine stays stalled (eng_ready_o low)
    // until reset.
    logic err_q;
    always_ff @(posedge clk_i or negedge reset_n_i) begin
        if (!reset_n_i) begin
            err_q <= 1'b0;
        end else if (mem_rsp_valid_i & mem_rsp_err_i) begin
            err_q <= 1'b1;
        end
    end
    assign eng_err_o = err_q;

    // ── Request issue ────────────────────────────────────────────────────────
    // Issue when:
    //   - engine has a request pending (eng_req_i)
    //   - outstanding budget allows another in-flight request
    //   - no sticky bus error
    // The bus may apply backpressure via mem_req_ready_i; outputs are stable
    // until the request is accepted (req_fire).
    logic can_issue;
    assign can_issue       = eng_req_i & ~outstanding_full & ~err_q;
    assign mem_req_valid_o = can_issue;
    assign mem_req_addr_o  = eng_addr_i;
    assign mem_req_we_o    = eng_we_i;
    assign mem_req_wdata_o = eng_wdata_i;
    // Default: full-word writes. Sub-word writes would set BE per byte; the
    // FFT engine writes whole 32-bit words so all-ones is correct.
    assign mem_req_be_o    = {BE_WIDTH{1'b1}};

    // Engine sees ready when its request can fire on this cycle.
    assign eng_ready_o = req_fire;

    // ── Response forwarding ──────────────────────────────────────────────────
    // In-order delivery: every rsp_valid_i corresponds to the oldest
    // outstanding request. Reads return data; writes return nothing useful
    // to the engine but still consume an outstanding slot (the SoC-side
    // adapter must drive rsp_valid_i for write completions to keep the
    // counter balanced — typically derived from the bus's d_valid).
    assign eng_rdata_o  = mem_rsp_rdata_i;
    assign eng_rvalid_o = mem_rsp_valid_i & ~mem_rsp_err_i;

endmodule

`default_nettype wire
