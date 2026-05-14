# `FFT_USE_BUS_MASTER` Memory Backend — Design

**Status:** design draft, not yet implemented.

A third memory backend mode for `fft_memory_interface.sv`, alongside the default FF/BRAM mode and the existing `FFT_USE_SRAM_MACRO` external SRAM bus mode. In this mode the FFT's working memory lives behind a SoC-supplied bus slave anywhere in the SoC's address space, and the FFT engine accesses it through a **generic, bus-protocol-agnostic master request/response interface** that the SoC integrator wraps with a thin adapter for the target bus protocol (TL-UL, AXI-Lite, Wishbone, OBI, custom).

This document defines the contract; companion `integration-patterns.md` covers the existing modes.

## Motivation

`FFT_USE_SRAM_MACRO` is correct when the SoC dedicates SRAM macros directly to the FFT (point-to-point bus). It does not fit SoCs with a **unified memory subsystem** — a memory-controller bus where ROM, RAM, and accelerator working memory are peers, and any master (CPU, debug, DMA, accelerator) can access any memory through a single arbitration point.

In that topology, the FFT becomes a master on the memory-controller bus. Its working memory is a slave on the same bus, addressable by the host CPU as well — enabling concurrent CPU readout of completed-window results while the engine processes the next window.

Three things this mode unlocks vs `FFT_USE_SRAM_MACRO`:

1. **Concurrent host access** to FFT working memory without going through APB control-register proxies.
2. **Unified memory arbitration** — one bus, one address map, one set of timing closure constraints across all memory IPs.
3. **Forward path to DMA / multi-master / cache-coherent** topologies. The FFT becomes one of N masters; nothing in the IP changes when adding more.

## Why bus-protocol-agnostic

The IP today has zero external dependencies and is bus-protocol-neutral. Adding a TL-UL-specific (or AXI-specific) master would couple the IP to one bus protocol's package types and reduce its reusability. Instead, this mode exposes a minimal request/response port set — the same shape used internally by the existing modes — and lets the SoC integrator wrap it with the appropriate bus-master adapter.

A typical adapter is small (50–150 lines) and is a one-time per-protocol cost the integrator absorbs. It also lives on the SoC side, where the bus protocol decision is made.

## Topology

```
  ┌──────────────────────┐                ┌──────────────────────┐
  │   FFT compute        │                │   memory             │
  │   (butterflies,      │                │   (any bus slave +   │
  │   twiddle, scaling)  │                │   storage backing)   │
  │                      │                │                      │
  │   ┌──────────────┐   │                │                      │
  │   │ scratchpad   │◄──┤                │                      │
  │   │ (FF, ~64-    │   │                │                      │
  │   │  256 words)  │   │                │                      │
  │   └──────────────┘   │                │                      │
  │           │          │                │                      │
  │           ▼          │                │                      │
  │   ┌──────────────┐   │ generic bus    │                      │
  │   │ bus master   ├───┼───────────────►│ ───►  SoC-side bus   │
  │   │ (req/rsp,    │   │ master ports   │       master adapter │
  │   │  outstanding │◄──┼────────────────┤ ◄───  (TL-UL, AXI,   │
  │   │  N requests) │   │                │       Wishbone, …)   │
  │   └──────────────┘   │                │                      │
  └──────────────────────┘                └──────────────────────┘
```

The SoC-side bus-master adapter and the memory slave are not part of this IP. The integrator supplies both.

## Memory layout (preserved from existing modes)

The FFT's logical memory image is identical to the FF/SRAM-bus modes:

- 2048 × 32-bit = 8 KB total
- `0x000–0x3FF` — sample / butterfly working data
- `0x400–0x5FF` — twiddle factors
- `0x600–0x7FF` — reserved

The IP exposes a **`MEM_BASE_ADDR`** parameter that the integrator sets to the base address at which this 8 KB image lives in the SoC's address space. The IP itself emits word-aligned offsets (11-bit) on the master interface; the SoC-side adapter (or the slave) adds `MEM_BASE_ADDR` if the bus protocol expects byte-addressed transactions or a SoC-wide address space.

## Port interface (added to `memory_interface` module under `FFT_USE_BUS_MASTER`)

```systemverilog
module memory_interface #(
    // ... existing parameters ...
    parameter logic [31:0] MEM_BASE_ADDR        = 32'h0000_0000,
    parameter int unsigned MEM_OUTSTANDING_MAX  = 4,    // max in-flight requests
    parameter int unsigned MEM_SCRATCHPAD_DEPTH = 64    // local scratchpad words; 0 disables
) (
    // ... existing APB / AXI / control / status / engine ports ...

    // Generic bus master (FFT_USE_BUS_MASTER only)
    output logic                          mem_req_valid_o,
    input  logic                          mem_req_ready_i,
    output logic [10:0]                   mem_req_addr_o,    // word address
    output logic                          mem_req_we_o,      // 0 = read, 1 = write
    output logic [31:0]                   mem_req_wdata_o,
    output logic [3:0]                    mem_req_be_o,      // byte-enable (writes)
    input  logic                          mem_rsp_valid_i,
    input  logic [31:0]                   mem_rsp_rdata_i,
    input  logic                          mem_rsp_err_i
);
```

When `FFT_USE_BUS_MASTER` is undefined, `mem_req_valid_o` and the other outputs are tied off (`'0`) so the ports remain present but inert. Same convention as the `sram_*_o` ports in the SRAM-bus mode.

## Request / response semantics

1. **Handshake** — request fires when both `mem_req_valid_o` and `mem_req_ready_i` are high on the same clock edge. The IP holds the request stable until accepted.
2. **In-order responses** — the IP relies on response ordering matching request ordering. SoC-side adapters that don't preserve order must reorder on the response side before driving `mem_rsp_valid_i`. (TL-UL preserves order per source; AXI-Lite does too; Wishbone is naturally in-order.)
3. **Outstanding** — the IP issues up to `MEM_OUTSTANDING_MAX` requests without seeing responses. After saturating, `mem_req_valid_o` deasserts until a response is received.
4. **Read response** — exactly one cycle of `mem_rsp_valid_i` per outstanding read. `mem_rsp_rdata_i` is sampled on that cycle.
5. **Write response** — none required; writes are fire-and-forget. (If the SoC bus has write acks, the adapter sinks them.)
6. **Errors** — if `mem_rsp_err_i` asserts on any response cycle, the IP raises a status bit (`fft_error_o`) and stalls further engine operation until reset. The IP does not retry — bus-level errors are SoC-integration bugs that should fail loud.

## Local scratchpad (`MEM_SCRATCHPAD_DEPTH`)

Set to 0 to disable; non-zero enables a small FF-based working buffer between the engine and the bus master.

The scratchpad is a **prefetch + write-back amortizer**, not a cache. It holds the operands for the current butterfly stage and the incoming operands for the next. Pre-fetch fills the scratchpad with the next butterfly's operands while the current butterfly computes; write-back coalesces the current butterfly's outputs and issues them as a burst when compute is done.

Sizing guidance:

| Depth | Use case |
|---|---|
| 0 | Per-access bus round-trip; simplest, lowest area, throughput limited by bus latency |
| 64 | Single-stage prefetch; hides ~bus-latency × outstanding-N round-trips |
| 256 | Multi-butterfly buffer; bus traffic in bursts; best throughput on long FFTs |

Default is 64 — covers the usual `MEM_OUTSTANDING_MAX = 4` × 4-cycle bus round-trip case with margin.

## Twiddle / engine write priority (preserved)

Same protocol as the FF and external-SRAM-bus modes: APB twiddle writes take priority over engine writes; the two are mutually exclusive by host-firmware protocol (firmware completes twiddle loading before asserting `FFT_CTRL[0]=1`). Both write streams flow through the same bus master interface — no separate write port is needed.

## Reset behaviour

On `reset_n_i` deassertion:

- All outstanding-transaction tracking state clears.
- Scratchpad is invalidated (no held data is reused after reset).
- `mem_req_valid_o` is forced low for at least one cycle to flush any in-flight request that was being formed.
- Engine sees `mem_ready_o = 0` until the IP completes its post-reset initialization.

## Standalone hardenability

Same as the existing modes: the IP can be hardened without an integrating SoC by stubbing the bus master ports with a behavioural always-ready slave that returns valid responses for any address. Synthesis and DRC/LVS sign-off proceed without a real bus or memory.

A behavioural slave skeleton:

```systemverilog
module fft_bus_slave_stub (
    input  logic        clk_i,
    input  logic        reset_n_i,
    // Mirror of the IP's master ports
    input  logic        req_valid_i,
    output logic        req_ready_o,
    input  logic [10:0] req_addr_i,
    input  logic        req_we_i,
    input  logic [31:0] req_wdata_i,
    input  logic [3:0]  req_be_i,
    output logic        rsp_valid_o,
    output logic [31:0] rsp_rdata_o,
    output logic        rsp_err_o
);
    // Always-ready; one-cycle response with zero data (for sim / lint /
    // standalone harden — not for any functional run).
endmodule
```

## Reference TL-UL master adapter (SoC-side example)

For SoCs on TL-UL, the integrator wraps the IP's generic master ports with an adapter that translates request / response handshakes to TL-UL `tl_h2d_t` / `tl_d2h_t` channels. The adapter is small (~150 lines) and has well-known patterns (OpenTitan's `tlul_adapter_master` is one reference).

The adapter contract:

| IP-side signal | TL-UL channel side |
|---|---|
| `req_valid_o`, `req_ready_i` | `a_valid` / `a_ready` |
| `req_addr_o + MEM_BASE_ADDR` | `a_address` |
| `req_we_o` | `a_opcode` (`PutFullData` or `PutPartialData` if writing, `Get` if reading) |
| `req_wdata_o` | `a_data` |
| `req_be_o` | `a_mask` |
| `rsp_valid_i` | `d_valid` (TL-UL `d_ready` always high in this direction) |
| `rsp_rdata_i` | `d_data` |
| `rsp_err_i` | `d_error` |
| (unique source ID per outstanding) | `a_source` / `d_source` matching |

For AXI-Lite or Wishbone the analogous mappings apply.

## Implementation outline

Files to add:

- `rtl/fft_bus_master.sv` — request issuer + outstanding-N tracking + response ordering check + scratchpad. ~200 lines self-contained, no external imports.

Files to modify:

- `rtl/fft_memory_interface.sv` — add the master ports under `FFT_USE_BUS_MASTER`; in the third arm of the `ifndef / else` chain, instantiate `fft_bus_master` and wire its scratchpad-side to the existing engine memory interface (`mem_addr_i` / `mem_data_i` / `mem_write_i` / `mem_data_o` / `mem_ready_o`).

Files for verification:

- `tb/cocotb/bus_master_mode/` — cocotb regression directory mirroring the existing test layout. Drives the bus-master ports from a simple in-order memory model and runs the FFT against the same vectors used by the FF/SRAM-bus modes; outputs must be bit-exact.

## Verification plan

1. **Unit-level — `fft_bus_master`**: cocotb testbench drives the engine-side and checks the bus-side request issuance. Exercises outstanding-N saturation, error injection, ordering invariants.
2. **Unit-level — scratchpad**: prefetch / write-back patterns vs FF-array reference.
3. **Integration — FFT engine on bus-slave model**: drive the same FFT input vectors used for the FF/SRAM-bus modes; output samples must match within bit-exactness. Use a behavioural slave with adjustable read latency to characterize throughput sensitivity.
4. **FPGA bringup**: inferred BRAM behind a stub bus slave — exercise on the standard FPGA target board with the existing reference vectors.
5. **Throughput characterization**: measure butterflies-per-cycle vs `MEM_OUTSTANDING_MAX` and `MEM_SCRATCHPAD_DEPTH`. Document the operating curve so integrators can size for their workload.

## Coexistence with existing modes

| Define | Effect |
|---|---|
| (none) | Default FF/BRAM mode (existing) |
| `FFT_USE_SRAM_MACRO` | External SRAM bus mode (existing) |
| `FFT_USE_BUS_MASTER` | Generic bus-master mode (this design) |

The defines are mutually exclusive at compile time. If the integrator defines more than one, synthesis errors with a clear `$fatal` message at the top of `memory_interface`.

## What this design does NOT include

- **Cache** — the scratchpad is a prefetch buffer, not a cache. No tag matching, no eviction policy. If the integrator needs caching they put it on the SoC side, behind the bus slave.
- **Multi-master arbitration** — the FFT is a single master in this IP. SoC-side arbitration handles contention with other masters.
- **Coherency protocols** — the FFT memory image is logically owned by the FFT during compute. Software is expected to wait on `FFT_STATUS.done` before reading results, same as in existing modes.
- **Out-of-order response handling** — the IP relies on in-order response delivery. Adapters for buses that allow reordering must reorder on the response side.
- **Bus-protocol-specific RTL** — no `tlul_pkg`, no `axi_pkg`, no Wishbone types inside the IP. The generic request/response interface stays bus-neutral.

## Open questions

1. **`MEM_SCRATCHPAD_DEPTH` default of 64** — chosen for the usual 4-cycle bus latency × `MEM_OUTSTANDING_MAX = 4` case. Revisit after the throughput characterization in step 5 of the verification plan.
2. **Byte enable width** — `mem_req_be_o` is sized for the FFT's 32-bit data width (4 bits, byte granularity). Larger bus widths would need width-conversion in the SoC-side adapter; documented but not handled inside the IP.
