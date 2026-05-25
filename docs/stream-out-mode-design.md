# `FFT_USE_STREAM_OUT` Output Streaming Mode — Design

**Status:** module landed (`fft_bin_streamer`), top-level mux pending.

A post-completion output streaming mode for `fft_top.sv` that, after
the engine asserts `fft_done`, walks the scratchpad bin-by-bin and
emits each `(index, real, imaginary)` triplet on a generic streaming
output port set. Consumers downstream (a magnitude/phase converter, a
peak detector, a DMA, a FIFO, an external bus adapter, …) plug in
through a thin profile of AXI-Stream rather than going through APB
control-register proxies or sharing the engine's working-memory bus.

This document defines the contract; companion
`docs/bus-master-mode-design.md` covers the unrelated working-memory
backend modes.

## Motivation

The existing `FFT_USE_SRAM_MACRO` and the design-stage
`FFT_USE_BUS_MASTER` modes both keep output bins resident in the
engine's working memory. A host (or downstream accelerator) that
wants the bins has to either:

1. Read them from external SRAM (`FFT_USE_SRAM_MACRO`) — only
   possible if the SoC integrator has wired a separate read port to
   that SRAM, which most SoCs do not, or
2. Wait for the engine to write its output to a system bus
   (`FFT_USE_BUS_MASTER`), then read it back from that bus — adds a
   round trip and ties the consumer to the bus protocol.

For a hardware-only DSP chain (e.g. FFT → CORDIC → peak detector),
neither path is ideal: chaining accelerators through a system bus
puts the CPU in the loop, and even a DMA path adds a memory copy.
This mode provides a third option — emit bins on a dedicated output
stream the instant the engine finishes, with zero round-trip through
memory or CPU.

Three things this mode unlocks vs the existing backends:

1. **Hardware-to-hardware chaining** — feed FFT output directly into
   a downstream accelerator with no CPU mediation.
2. **Bus-protocol independence on the consumer side** — the same
   stream port set works for any consumer protocol; only the
   wrapper-level wiring changes.
3. **Concurrent CPU readout via the existing memory backend** — the
   stream is *additive*: a SoC can simultaneously stream out to an
   accelerator AND read bins back via the regular memory backend if
   it wants to log the spectrum.

## Topology

```
   FFT engine
   (in-place butterflies, scaling)
        │
        ▼
   working memory  (single port — engine's scratchpad)
        │  reads bin 0, 1, 2, …, N-1 after fft_done
        ▼
   fft_bin_streamer    ──►   bin_valid_o / bin_ready_i / bin_index_o /
                              bin_last_o  / bin_re_o    / bin_im_o
                              (vyges-dsp-stream-v1)
```

The streamer borrows the engine-facing memory port during the
streaming window. Because the engine is in its done state at that
point, it has released the port and there is no contention. The
top-level instantiation muxes between the engine's address driver and
the streamer's based on `streamer_active_o`.

## Stream protocol — `vyges-dsp-stream-v1`

A thin profile of AXI-Stream with sideband index + last signals.

| Port              | Width            | Description |
|-------------------|------------------|-------------|
| `bin_valid_o`     | 1                | Producer asserts when a beat is present. |
| `bin_ready_i`     | 1                | Consumer ready. Held high under no backpressure. |
| `bin_index_o`     | `INDEX_WIDTH`    | Bin index. Increases monotonically 0…N-1 within a stream. |
| `bin_last_o`      | 1                | Asserted on the final beat of the spectrum. |
| `bin_re_o`        | `DATA_WIDTH`     | Signed real component of the bin. |
| `bin_im_o`        | `DATA_WIDTH`     | Signed imaginary component of the bin. |

Handshake rules follow AXI-Stream conventions: a beat is accepted on
any rising clock edge where both `valid_o` and `ready_i` are high.
Producer must not retract `valid_o` until the beat is accepted.
`bin_last_o` is asserted on the final beat together with
`bin_valid_o`.

## State machine

`fft_bin_streamer.sv` is a four-state FSM:

```
S_IDLE   wait for fft_done_pulse_i & stream_enable_i
S_REQ    drive mem_read_o + mem_addr_o for the current bin index
S_WAIT   hold the address; wait for mem_ready_i; latch (re, im)
S_EMIT   drive valid_o + (index, re, im, last); advance on ready_i
```

Transitions:

```
S_IDLE  → S_REQ   when fft_done_pulse_i & stream_enable_i
S_REQ   → S_WAIT  unconditional (1-cycle pulse on mem_read_o)
S_WAIT  → S_EMIT  when mem_ready_i = 1
S_EMIT  → S_IDLE  when bin_ready_i & is_last
S_EMIT  → S_REQ   when bin_ready_i & !is_last
```

`streamer_active_o` is high in every state except `S_IDLE`; the
top-level memory port mux uses this signal to decide whether the
engine or the streamer drives `mem_addr` and `mem_write`.

## Memory data layout assumption

The streamer assumes 32-bit memory words with the standard packing:

| Bits   | Field              |
|--------|--------------------|
| `[15:0]`  | signed real part |
| `[31:16]` | signed imaginary part |

Output bins reside at memory addresses `0..N-1` in natural order.
Engines that produce bit-reversed output should run a bit-reverse
pass before raising `fft_done`, or wrap this module with a small
address-mapping shim that translates the streamer's
`mem_addr_o[INDEX_WIDTH-1:0]` through a bit-reverse before
forwarding to memory.

## Parameters

| Parameter         | Default | Description |
|-------------------|---------|-------------|
| `MAX_LENGTH_LOG2` | 12      | Max log2(N). Defines the width of `num_bins_i`. |
| `DATA_WIDTH`      | 16      | Width of real / imaginary fields. |
| `INDEX_WIDTH`     | 12      | Width of `bin_index_o`. Typically equals `MAX_LENGTH_LOG2`. |
| `MEM_ADDR_WIDTH`  | 16      | Width of `mem_addr_o`. Sized to match the engine's port. |

## Integration with `fft_top.sv` (pending)

The top-level mux that hooks the streamer into the engine's memory
port is the remaining piece of the integration. It will be guarded
by `\`ifdef FFT_USE_STREAM_OUT` so non-streaming builds are
bit-identical to the existing flow. Sketch:

```
`ifdef FFT_USE_STREAM_OUT
    fft_bin_streamer #(...) u_bin_streamer (
        .clk_i                (clk_i),
        .rst_ni               (reset_n_i),
        .fft_done_pulse_i     (fft_done_o_internal),
        .stream_enable_i      (stream_enable_from_ctrl),
        .num_bins_i           (1 << fft_length_log2_i),
        .mem_addr_o           (streamer_mem_addr),
        .mem_read_o           (streamer_mem_read),
        .mem_ready_i          (mem_ready_o),
        .mem_data_i           (mem_data_o),
        .streamer_active_o    (streamer_active),
        .bin_valid_o          (bin_valid_o),
        .bin_ready_i          (bin_ready_i),
        .bin_index_o          (bin_index_o),
        .bin_last_o           (bin_last_o),
        .bin_re_o             (bin_re_o),
        .bin_im_o             (bin_im_o)
    );

    // Mux engine and streamer onto the shared memory port
    assign mem_addr_i  = streamer_active ? streamer_mem_addr : engine_mem_addr;
    assign mem_write_i = streamer_active ? 1'b0              : engine_mem_write;
`else
    // Legacy: engine drives the memory port directly.
`endif
```

A `stream_enable` bit in the `FFT_CTRL` register controls whether
the post-done walker auto-fires. When zero, the engine behaves
exactly as today.

## Connecting downstream consumers

The streaming output port set is bus-protocol-agnostic. Any consumer IP
that exposes a matching `vyges-dsp-stream-v1` input port set can be
wired directly at SoC wrapper scope without intermediate adapters.

Typical wrapper-scope wiring, where `u_consumer` is any downstream IP
(e.g. a magnitude/phase converter, peak detector, DMA, FIFO, or
external bus adapter):

```sv
fft_top #(
    .FFT_MAX_LENGTH_LOG2(12)
) u_fft (
    // ... clk / reset / APB / working-memory ports ...

    // Streaming output
    .bin_valid_o (fft_to_consumer_valid),
    .bin_ready_i (fft_to_consumer_ready),
    .bin_index_o (fft_to_consumer_index),
    .bin_last_o  (fft_to_consumer_last),
    .bin_re_o    (fft_to_consumer_re),
    .bin_im_o    (fft_to_consumer_im)
);

downstream_consumer_ip #(
    .DATA_WIDTH (16),
    .INDEX_WIDTH(12)
) u_consumer (
    .stream_in_valid_i (fft_to_consumer_valid),
    .stream_in_ready_o (fft_to_consumer_ready),
    .stream_in_index_i (fft_to_consumer_index),
    .stream_in_last_i  (fft_to_consumer_last),
    .stream_in_re_i    (fft_to_consumer_re),
    .stream_in_im_i    (fft_to_consumer_im)
    // ... other consumer-specific ports ...
);
```

Rules of thumb for the SoC integrator:

- **Index width.** `INDEX_WIDTH` on every IP in the chain must equal
  the producer's `INDEX_WIDTH` (default 12 here — fits N = 4096). A
  chain that runs at a smaller fixed N can save flops by setting all
  IPs to the matching narrower width.
- **Backpressure.** The consumer's `stream_in_ready_o` drives the
  producer's `bin_ready_i`. The streamer parks `valid + payload`
  whenever `ready_i` is low, so a consumer that needs an extra cycle
  to digest each beat can simply lower its ready line. If the
  consumer cannot stall at all (a fixed-latency pipeline like a
  CORDIC engine), tie its `stream_in_ready_o` to `1'b1` and ensure no
  upstream stage that feeds it can stall the stream either.
- **Multi-stage chains.** Cascading two consumers (`producer →
  stage_A → stage_B`) is direct wiring — `stage_A.stream_out_*`
  connects to `stage_B.stream_in_*`. The producer's `bin_last_o`
  propagates through every stage; the final stage's `last` is the
  spectrum-complete signal a capture or interrupt block can latch.
- **N at runtime.** The streamer's `num_bins_i` is a runtime input
  (driven from the FFT length register), so the same synthesized
  chain handles every supported N (256 / 512 / 1024 / 2048 / 4096)
  without re-build. Consumers that maintain per-bin state across a
  spectrum should reset that state on the `last` beat, not on a
  fixed bin count.

## Verification

`tb/cocotb/bin_streamer/test_bin_streamer.py` exercises the streamer
in isolation against a synthetic 1-cycle-latency memory model. Four
cases:

1. Idle state emits nothing across 50 cycles.
2. `fft_done` with `stream_enable = 0` does not start a walk.
3. 8-bin walk with an always-ready consumer produces the expected
   sequence and `last` placement.
4. Consumer-stall: with `bin_ready_i = 0` parked before the first
   beat, the streamer holds valid + payload steady until the consumer
   accepts; on release the stream drains to last.

All four pass on Verilator with cocotb 1.9.

The integration-level test (driving real samples through the FFT
engine and checking the output stream against a Python reference)
lands together with the `fft_top.sv` mux.
