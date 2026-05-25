# Firmware Integration Guide

How to drive the FFT engine from a host CPU. Covers the boot-time setup
(twiddle table load + register configuration), the per-run trigger /
wait / read sequence, and the gotchas that every SoC integrator hits
during bring-up.

This document is the consumer-side companion to
`integration-patterns.md` (which covers the SoC-side bus integration of
the memory backend).

## APB address map at a glance

The FFT presents a single APB slave with three logical windows decoded
on `paddr_i`:

| Window | Range (offset from FFT base) | Decode | Use |
|---|---|---|---|
| Registers | `0x0000 – 0x07FC` | `paddr[12]=0 && paddr[11]=0` | `FFT_CTRL`, `FFT_STATUS`, `FFT_CONFIG`, `FFT_LENGTH`, etc. |
| Twiddle write | `0x0800 – 0x0BFC` | `paddr[11]=1` | Firmware loads twiddle factors at boot. Word index `k = paddr[10:2]` writes `fft_memory[1024 + k]`. |
| Sample data write | `0x1000 – 0x1FFC` | `paddr[12]=1 && paddr[11]=0` (requires `FFT_USE_APB_DATA`) | Firmware loads samples per run. Word index `i = paddr[11:2]` writes `fft_memory[i]`. |

If `FFT_USE_APB_DATA` is not defined the sample window is not present —
samples must reach `fft_memory[0..N-1]` through some other path (DMA,
external SRAM bus, AXI port, etc., see `integration-patterns.md`).

## Register summary (driver-relevant bits)

```
FFT_CTRL (0x0000, RW)
  [0]  start          — pulse: write 1, then write 0 (see "Sticky-start" below).
  [1]  reset
  [2]  buffer_swap
  [4]  rescale_en     — enable per-butterfly auto-rescale. Requires FFT_CONFIG[19]=1
                        AND this bit set, both, for any rescaling to fire.
  [5]  scale_track_en — accumulate the per-window rescale shift count into
                        FFT_STATUS[13:6] for postprocessing.
  [8]  stream_enable  — gate the post-completion bin streamer. Has no effect
                        unless the IP is compiled with FFT_USE_STREAM_OUT.

FFT_STATUS (0x0004, RO)
  [0]      fft_busy
  [1]      fft_done
  [2]      fft_error
  [3]      buffer_active
  [4]      rescaling_active
  [5]      overflow_detected
  [13:6]   scale_factor      — accumulated >>1 shifts (informational).
  [21:14]  stage_count
  [29:22]  overflow_count

FFT_CONFIG (0x0008, RW)
  [11:0]   fft_length_log2   — log2(N), e.g. 8 for 256-pt, 10 for 1024-pt.
  [16]     rescale_mode      — 0 = divide-by-2 per overflow, 1 = divide-by-N.
  [17]     rounding_mode     — 0 = truncate, 1 = round-to-nearest.
  [18]     saturation_en     — clamp instead of wrap on overflow.
  [19]     overflow_detect   — required prerequisite for rescaling. See FFT_CTRL[4].

FFT_LENGTH (0x000C, RW)
  [11:0]   N — absolute length (must match 1 << FFT_CONFIG[11:0]).
```

## Boot sequence

The engine reads twiddle factors from `fft_memory[N/2 .. N-1]`. **The
twiddle table is not initialised in hardware.** Without firmware
loading it, every FFT output is zero. The deprecated `twiddle_rom.sv`
module that simulates with `$sin()` is not instantiated in any current
build — see its own deprecation notice for history.

A correct boot sequence:

1. Configure the engine:
   ```c
   REG32(FFT_FFT_CONFIG) = (1U << 18)        // saturation_en
                         | (1U << 19)        // overflow_detect
                         | LOG2_N;
   REG32(FFT_FFT_LENGTH) = N;
   ```
2. Load `N/2` twiddle words to the paddr[11]=1 window:
   ```
   for k in [0 .. N/2-1]:
       cos_q = (Q1.15)  cos(2π·k/N)
       sin_q = (Q1.15)  sin(2π·k/N)
       word  = (cos_q[15:0] << 16) | ((-sin_q)[15:0])
       REG32(FFT_BASE + 0x0800 + 4*k) = word
   ```
   Word layout matches what the butterfly stage captures (see
   `fft_fft_engine.sv:372-373`): cos in the high half, `-sin` (already
   negated) in the low half so the inner multiply is a plain
   `(real, imag) * twiddle` complex product.

A reference iterative generator in Q1.15 fixed point (~30 lines of C,
no FPU needed):

```c
int c  = 0x7FFF;                 // cos(0)
int s  = 0x0000;                 // sin(0)
int cd = (int)round(cos(2*M_PI/N) * 32767.0);  // cos(Δθ)
int sd = (int)round(sin(2*M_PI/N) * 32767.0);  // sin(Δθ)
for (unsigned k = 0; k < N/2; k++) {
    unsigned neg_s = ((unsigned)(-s)) & 0xFFFFu;
    unsigned cos_w = ((unsigned)c)    & 0xFFFFu;
    REG32(FFT_BASE + 0x0800 + (k << 2)) = (cos_w << 16) | neg_s;
    int cn = (c * cd - s * sd) >> 15;
    int sn = (s * cd + c * sd) >> 15;
    c = cn;
    s = sn;
}
```

Iterative rotation accumulates O(√(N/2) · 2⁻¹⁵) Q1.15 quantisation
error over the loop — well under one Q1.15 LSB for N ≤ 4096. The
trade-off vs a pre-baked table is no ROM cost.

## Per-run sequence

Each FFT run:

1. Load N samples (real-valued is fine — drive `imag = 0`) to the
   sample window. With `FFT_USE_APB_DATA`:
   ```c
   for (i = 0; i < N; i++) {
       REG32(FFT_BASE + 0x1000 + 4*i) = sample_q15[i] & 0xFFFFu;
   }
   ```
   Without `FFT_USE_APB_DATA`, the sample buffer must reach
   `fft_memory[0..N-1]` through the configured backend.
2. Pulse start with rescale bits set:
   ```c
   unsigned hold = (1U << 4) | (1U << 5);  // rescale_en + scale_track_en
   REG32(FFT_FFT_CTRL) = hold | 0x1u;      // start=1
   REG32(FFT_FFT_CTRL) = hold;             // start=0 (deassert)
   ```
3. Wait for `FFT_STATUS[1]` (`fft_done`) — typical wallclock is N·log2(N)
   cycles at the engine clock plus a few-cycle pipeline drain.
4. Read results back through the configured backend, or use the
   streaming bin output (`FFT_USE_STREAM_OUT`) — see
   `stream-out-mode-design.md`.

## Gotchas

These each cost real bring-up time. Captured here so the next
integrator avoids them.

### Sticky-start

`FFT_CTRL[0]` is **level-sensitive AND sticky**. The engine's
`stage_counter` reset condition is `if (fft_start_i) stage_counter <= 0`
(`fft_fft_engine.sv:445-447`). Setting start once and leaving it high
holds the counter at zero forever — the engine sits in COMPUTE with
`FFT_STATUS[0]=1` (busy) indefinitely.

**Always** deassert start within a few cycles of asserting it. A
two-write pulse (write 1, then write 0) is the standard pattern.

### Rescale gating

`fft_rescale_unit.sv:93` gates the rescaling logic on
`rescale_en_i && overflow_detect_i`. Setting just `FFT_CTRL[4]` is not
enough — `FFT_CONFIG[19]` must also be high. Symptom of missing
`FFT_CONFIG[19]`: every FFT output bin saturates at the 16-bit ceiling
(`peak_mag ≈ 65500` if you're feeding a magnitude detector
downstream).

### Twiddles are not in hardware

There is no ROM, no `$readmemh`, no built-in initialisation. The
`twiddle_rom.sv` file in the repo is dead code, retained only for
historical reference (see its in-file deprecation notice). Firmware
must load the table at boot before the first `FFT_CTRL[0]=1`.

### Buffer initial state on FPGA

When the working memory is FF-array / inferred BRAM (default mode), the
initial state on Xilinx is all-zero. On Intel and most ASIC SRAMs it is
unknown / X. If you depend on running an FFT immediately at reset, load
samples + twiddles explicitly — do not rely on a zeroed buffer.

### Single-port BRAM mux precedence

`fft_memory_interface.sv` muxes three write streams into one BRAM port,
in priority order: `apb_data_wr` > `apb_twiddle_wr` > engine write.
The host firmware is expected to load samples and twiddles BEFORE
asserting start; the protocol is "host finishes its writes, then the
engine runs". If you interleave APB writes with a running FFT, the APB
write wins for that cycle and the engine loses a butterfly result.

## Worked example

The `vyges/edge-sensor-pico-openframe` SoC drives a chain
`u_fft → u_mag_phase → u_spectrum` on a 25 MHz PicoRV32 via the steps
above. Its firmware emission template
(`vyges/soc-generator/src/soc_generator/templates/firmware_main.c.j2`,
the `dsp_chain_*` block) is a complete reference implementation in C.

## See also

- `integration-patterns.md` — SoC-side memory bus integration.
- `stream-out-mode-design.md` — post-completion bin streaming output.
- `bus-master-mode-design.md` — `FFT_USE_BUS_MASTER` mode.
- `architecture.md` — internal engine pipeline.
