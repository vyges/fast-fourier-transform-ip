# `FFT_USE_TLUL_MASTER` Memory Backend — Design

**Status:** design draft, not yet implemented.

A third memory backend mode for `fft_memory_interface.sv`, alongside the default FF/BRAM mode and the existing `FFT_USE_SRAM_MACRO` external SRAM bus mode. In this mode the FFT's working memory lives behind a TL-UL slave anywhere in the consumer SoC's address space, and the FFT engine accesses it as a TL-UL bus master.

This document defines the contract; companion `integration-patterns.md` covers the existing modes.

## Motivation

`FFT_USE_SRAM_MACRO` is correct when the SoC dedicates SRAM macros directly to the FFT (point-to-point bus). It does not fit SoCs with a **unified memory subsystem** — a memory-controller bus where ROM, RAM, and accelerator working memory are peers, and any master (CPU, debug, DMA, accelerator) can access any memory through a single arbitration point.

In that topology, the FFT becomes a master on the memory-controller bus. Its working memory is a slave on the same bus, addressable by the host CPU as well — enabling concurrent CPU readout of completed-window results while the engine processes the next window.

Three things this mode unlocks vs `FFT_USE_SRAM_MACRO`:

1. **Concurrent host access** to FFT working memory without going through APB control-register proxies.
2. **Unified memory arbitration** — one bus, one address map, one set of timing closure constraints across all memory IPs.
3. **Forward path to DMA / multi-master / cache-coherent** topologies. The FFT becomes one of N masters; nothing in the IP changes when adding more.

## Topology

```
  ┌──────────────────────┐                ┌──────────────────────┐
  │   FFT compute        │                │   memory             │
  │   (butterflies,      │                │   (TL-UL slave +     │
  │   twiddle, scaling)  │                │   storage backing)   │
  │                      │                │                      │
  │   ┌──────────────┐   │                │                      │
  │   │ scratchpad   │◄──┤                │                      │
  │   │ (FF, ~64-    │   │                │                      │
  │   │  256 words)  │   │                │                      │
  │   └──────────────┘   │                │                      │
  │           │          │                │                      │
  │           ▼          │                │                      │
  │   ┌──────────────┐   │ tl_o (h2d)     │                      │
  │   │ TL-UL master ├───┼───────────────►│ a_valid / a_address  │
  │   │ adapter      │◄──┼────────────────┤ d_valid / d_data     │
  │   │ (outstanding ├───┼─── tl_i (d2h)──┤                      │
  │   │  N requests) │   │                │                      │
  │   └──────────────┘   │                │                      │
  └──────────────────────┘                └──────────────────────┘
```

The memory slave is **not part of this IP**. The integrating SoC provides a TL-UL slave (any standard implementation that exposes a memory backend works — for example a generic `tlul_adapter_sram` wrapping vendor SRAM macros, OpenRAM-generated modules, or behavioural models for sim).

## Memory layout (preserved from existing modes)

The FFT's logical memory image is identical to the FF/SRAM-bus modes:

- 2048 × 32-bit = 8 KB total
- `0x000–0x3FF` — sample / butterfly working data
- `0x400–0x5FF` — twiddle factors
- `0x600–0x7FF` — reserved

The IP exposes a **`MEM_BASE_ADDR`** parameter that the integrator sets to the base address at which this 8 KB image lives in the SoC's address space. All TL-UL master transactions issued by the IP add `MEM_BASE_ADDR` to the logical address.

## Port interface (added to `memory_interface` module under `FFT_USE_TLUL_MASTER`)

```systemverilog
module memory_interface #(
    // ... existing parameters ...
    parameter logic [31:0] MEM_BASE_ADDR        = 32'h0000_0000,
    parameter int unsigned MEM_OUTSTANDING_MAX  = 4,    // max in-flight TL-UL requests
    parameter int unsigned MEM_SCRATCHPAD_DEPTH = 64    // local scratchpad words; 0 disables
) (
    // ... existing APB / AXI / control / status / engine ports ...

    // TL-UL master (FFT_USE_TLUL_MASTER only)
    output tlul_pkg::tl_h2d_t  tl_o,
    input  tlul_pkg::tl_d2h_t  tl_i
);
```

When `FFT_USE_TLUL_MASTER` is undefined, `tl_o` is tied off (`'0`) so the ports remain present but inert. Same convention as the `sram_*_o` ports in the SRAM-bus mode.

## TL-UL master adapter requirements

The master adapter inside `memory_interface` must:

1. **Issue read and write requests** corresponding to the engine's `mem_addr_i` / `mem_data_i` / `mem_write_i` interface (and APB twiddle writes — same priority muxing as today).
2. **Track outstanding transactions** up to `MEM_OUTSTANDING_MAX`. Each outstanding request gets a unique `a_source` ID; responses are matched back by `d_source`.
3. **Backpressure the engine** when the outstanding-request budget is exhausted (`mem_ready_o` deasserts).
4. **Surface read responses** to the engine via `mem_data_o`, with `mem_ready_o` asserting on the cycle valid data is available.
5. **Trap response errors** (`d_error == 1`) by raising a status bit (`fft_error_o`) and stalling further engine operation until reset. The IP does not retry — bus-level errors are SoC-integration bugs that should fail loud.

A reference adapter (e.g. OpenTitan's `tlul_adapter_master`) can be vendored or written from scratch; the contract above is what the FFT depends on, not any specific adapter source.

## Local scratchpad (`MEM_SCRATCHPAD_DEPTH`)

Set to 0 to disable; non-zero enables a small FF-based working buffer between the engine and the TL-UL master.

The scratchpad is a **prefetch + write-back amortizer**, not a cache. It holds the operands for the current butterfly stage and the incoming operands for the next. Pre-fetch fills the scratchpad with the next butterfly's operands while the current butterfly computes; write-back coalesces the current butterfly's outputs and issues them as a burst when compute is done.

Sizing guidance:

| Depth | Use case |
|---|---|
| 0 | Per-access bus round-trip; simplest, lowest area, throughput limited by bus latency |
| 64 | Single-stage prefetch; hides ~bus-latency × outstanding-N round-trips |
| 256 | Multi-butterfly buffer; bus traffic in bursts; best throughput on long FFTs |

Default is 64 — covers the usual `MEM_OUTSTANDING_MAX = 4` × 4-cycle bus round-trip case with margin.

## Twiddle / engine write priority (preserved)

Same protocol as the FF and external-SRAM-bus modes: APB twiddle writes take priority over engine writes; the two are mutually exclusive by host-firmware protocol (firmware completes twiddle loading before asserting `FFT_CTRL[0]=1`). Both write streams flow through the same TL-UL master adapter — no separate write port is needed.

## Reset behaviour

On `reset_n_i` deassertion:

- All outstanding-transaction tracking state clears.
- Scratchpad is invalidated (no held data is reused after reset).
- `tl_o.a_valid` is forced low for at least one cycle to flush any in-flight request that was being formed.
- Engine sees `mem_ready_o = 0` until the IP completes its post-reset initialization.

## Standalone hardenability

Same as the existing modes: the IP can be hardened without an integrating SoC by stubbing the TL-UL slave with a behavioural model that returns valid responses for any address. Synthesis and DRC/LVS sign-off proceed without a real bus or memory.

A behavioural slave skeleton:

```systemverilog
module tlul_dummy_mem_slave (
    input  logic clk_i, rst_ni,
    input  tlul_pkg::tl_h2d_t tl_i,
    output tlul_pkg::tl_d2h_t tl_o
);
    // Always-ready slave returning zero data for reads, accepting all writes.
    // Suitable for sim / lint / standalone harden — not for any functional run.
endmodule
```

## Implementation outline

Files to modify:

- `rtl/fft_memory_interface.sv` — add `tl_o` / `tl_i` ports under `FFT_USE_TLUL_MASTER`; replace the FF-array / external-SRAM-bus block with the TL-UL master adapter + scratchpad in the third arm of the existing `ifndef / else` chain.

Files to add:

- `rtl/fft_tlul_master_adapter.sv` — the TL-UL master with outstanding-N tracking, source-ID assignment, response demux. Keeps the master logic out of the main `memory_interface` for testability.
- `rtl/fft_scratchpad.sv` — the FF-array scratchpad with prefetch / write-back logic.
- `tb/cocotb/tlul_master_mode/` — cocotb regression directory mirroring the existing `tb/cocotb/sram_macro_mode/` layout (assumed pattern).

## Verification plan

1. **Unit-level — TL-UL master adapter**: cocotb testbench drives the engine-side request stream and checks bus-side request issuance. Exercises outstanding-N saturation, response reordering, error injection.
2. **Unit-level — scratchpad**: prefetch / write-back patterns vs FF-array reference.
3. **Integration — FFT engine on TL-UL slave model**: drive the same FFT input vectors used for the FF/SRAM-bus modes; output samples must match within bit-exactness. Use a behavioural TL-UL slave with adjustable read latency to characterize throughput sensitivity.
4. **FPGA bringup**: inferred BRAM behind a generated TL-UL slave — exercise on the standard FPGA target board with the existing reference vectors.
5. **Throughput characterization**: measure butterflies-per-cycle vs `MEM_OUTSTANDING_MAX` and `MEM_SCRATCHPAD_DEPTH`. Document the operating curve so integrators can size for their workload.

## Coexistence with existing modes

| Define | Effect |
|---|---|
| (none) | Default FF/BRAM mode (existing) |
| `FFT_USE_SRAM_MACRO` | External SRAM bus mode (existing) |
| `FFT_USE_TLUL_MASTER` | TL-UL master mode (this design) |

The defines are mutually exclusive at compile time. If the integrator defines more than one, synthesis errors with a clear `$fatal` message at the top of `memory_interface`.

## What this design does NOT include

- **Cache** — the scratchpad is a prefetch buffer, not a cache. No tag matching, no eviction policy. If the integrator needs caching they put it on the SoC side, behind the TL-UL slave.
- **Multi-master arbitration** — the FFT is a single master in this IP. SoC-side arbitration handles contention with other masters.
- **Coherency protocols** — the FFT memory image is logically owned by the FFT during compute. Software is expected to wait on `FFT_STATUS.done` before reading results, same as in existing modes.

## Open questions

1. **`MEM_SCRATCHPAD_DEPTH` default of 64** — chosen for the usual 4-cycle bus latency × `MEM_OUTSTANDING_MAX = 4` case. May want to revisit after the throughput characterization in step 5 of the verification plan.
2. **Source-ID width** — `tl_h2d_t.a_source` is 8 bits in standard TL-UL packages. With `MEM_OUTSTANDING_MAX = 4` only 2 bits are needed; the upper 6 are reserved (0). Document the convention so SoC integrators don't attempt to mux multiple master IDs into a single TL-UL channel without remapping.
3. **Vendored vs from-scratch master adapter** — vendoring an existing well-tested master adapter (such as OpenTitan's `tlul_adapter_master`) saves DV time but couples the IP to that adapter's update cadence. Writing from scratch is small (~200 lines) and self-contained; preferred unless the throughput characterization reveals a need for a more sophisticated adapter.
