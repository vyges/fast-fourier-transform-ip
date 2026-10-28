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
| Twiddle write | `0x0800 – 0x0FFC` | `paddr[12]=0 && paddr[11]=1` | Firmware loads twiddle factors at boot. Word index `k = paddr[10:2]` (512 words) writes `fft_memory[1024 + k]`. |
| Sample data write | `0x1000 – 0x1FFC` | `paddr[12]=1` (requires `FFT_USE_APB_DATA`) | Firmware loads samples per run. Word index `i = paddr[11:2]` (1024 words) writes `fft_memory[i]`. |

If `FFT_USE_APB_DATA` is not defined the sample window is not present —
samples must reach `fft_memory[0..N-1]` through some other path (DMA,
external SRAM bus, AXI port, etc., see `integration-patterns.md`).

## Register summary (driver-relevant bits)

```
FFT_CTRL (0x0000, RW)
  [0]  start          — a run launches when this is high while the engine is
                        idle. Recommended: pulse (write 1, then write 0); see
                        "Start is level-sensitive" below.
  [1]  reset          — aborts a run; the engine is idle on the next cycle and
                        issues no further memory write.
  [2]  buffer_swap
  [4]  rescale_en     — enable per-stage rescaling. Requires FFT_CONFIG[19]=1
                        AND this bit set, both, for any rescaling to fire.
  [5]  scale_track_en — count the scaled stages into FFT_STATUS[13:6] for
                        postprocessing.
  The run bits [5:4] are latched at launch; writes during a run apply to
  the next run.
  [8]  stream_enable  — gate the post-completion bin streamer. Has no effect
                        unless the IP is compiled with FFT_USE_STREAM_OUT.

FFT_STATUS (0x0004, RO)
  [0]      fft_busy
  [1]      fft_done          — held from the end of a run until the next run starts.
  [2]      fft_error         — held from a rejected launch until the next run starts.
  [3]      buffer_active
  [4]      rescaling_active
  [5]      overflow_detected
  [13:6]   scale_factor      — number of scaled stages; result = true FFT / 2^scale_factor.
  [21:14]  stage_count       — stages completed in the run.
  [29:22]  overflow_count    — butterflies with a component that did not fit
                               16 bits (saturates at 255).

FFT_CONFIG (0x0008, RW)
  [11:0]   fft_length_log2   — log2(N), 1 .. 10 (e.g. 8 for 256-pt, 10 for
                               1024-pt). 0 or a value above the maximum is
                               rejected at launch (FFT_STATUS[2] error).
  [16]     rescale_mode      — 0 = block floating point (a stage is halved only
                               when one of its inputs lies outside
                               [-2^13, 2^13)), 1 = every stage halved (X/N).
  [17]     rounding_mode     — 0 = truncate, 1 = add half an LSB before each shift.
  [18]     saturation_en     — clamp to [-32768, 32767] instead of wrap on overflow.
  [19]     overflow_detect   — required prerequisite for rescaling. See FFT_CTRL[4].
  FFT_CONFIG is latched at launch; writes during a run apply to the next run.

FFT_LENGTH (0x000C, RW)
  [11:0]   N — absolute length (must match 1 << FFT_CONFIG[11:0]).

INT_ENABLE (0x0014, RW)
  [4:0]    enables for rescale, overflow, buffer swap, error, done (bit 0 = done).

INT_STATUS (0x0018, RW1C)
  [0] done  [1] error  [2] buffer swap  [3] overflow  [4] rescale — pending.
  Each bit is set on its event while the matching INT_ENABLE bit is set and
  stays set until software writes 1 to it.
```

## Boot sequence

The engine reads twiddle factor `k` from `fft_memory[1024 + k]` (the
twiddle window). **The twiddle table is not initialised in hardware.** Without firmware
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
   Word layout matches what the engine reads as `W_N^k = e^(-j·2π·k/N)`
   (see the header of `rtl/fft_fft_engine.sv`): cos in the high half,
   `-sin` (already negated) in the low half so the inner multiply is a
   plain `(real, imag) * twiddle` complex product. The table for a
   1024-point FFT (512 words) fills the window; shorter lengths load
   `N/2` words.

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
error over the loop — well under one Q1.15 LSB for N ≤ 1024. The
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
3. Wait for `FFT_STATUS[1]` (`fft_done`), which holds until the next run
   starts, or for `INT_STATUS[0]` / `fft_done_o` with `INT_ENABLE[0]` set.
   The engine performs one memory access per cycle and a butterfly takes
   6 cycles, so a run is about 6·(N/2)·log2(N) cycles for the butterflies
   plus about 3N for the final bit-reverse pass (plus N+2 for the input
   scan in rescale mode 0). Measured from start to the last streamed bin:
   about 7.6k–7.9k cycles for 256 points, 17.3k for 512, 36.8k–37.8k for
   1024. If `FFT_STATUS[2]` (`fft_error`) is set instead, the length in
   `FFT_CONFIG[11:0]` was rejected and nothing was computed.
4. If `INT_STATUS` bits are used, clear them by writing 1 to each bit
   handled (`INT_STATUS` is write-1-to-clear).
5. Read results back through the configured backend, or use the
   streaming bin output (`FFT_USE_STREAM_OUT`) — see
   `stream-out-mode-design.md`. Results are in natural order: bin `k` is
   word `k`, packed `{imag[31:16], real[15:0]}`, and equal the true FFT
   divided by `2^scale_factor`.

## Gotchas

These each cost real bring-up time. Captured here so the next
integrator avoids them.

### Start is level-sensitive

`FFT_CTRL[0]` launches a run whenever it is high while the engine is
idle. If it is left high, the next run starts as soon as the current one
finishes, so the engine keeps re-running on the same memory. A
two-write pulse (write 1, then write 0) is the standard pattern. The
configuration is latched at launch, so changing `FFT_CONFIG` or the run
bits of `FFT_CTRL` mid-run has no effect until the next run.

### Rescale gating

The engine (`rtl/fft_fft_engine.sv`) rescales only when
`rescale_en && overflow_detect` are both set. Setting just `FFT_CTRL[4]`
is not enough — `FFT_CONFIG[19]` must also be high. Symptom of missing
`FFT_CONFIG[19]` with a full-scale input: large output bins clamp at the
16-bit limits (with `saturation_en`) or wrap (without it), and
`FFT_STATUS[13:6]` (scale factor) reads 0.

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

A PicoRV32 SoC at 25 MHz drives an FFT → magnitude/phase → spectrum
chain with exactly the steps above: twiddle load at boot, a 1024-sample
APB load per window, a start pulse, and the results consumed in natural
order through the bin streamer.

## See also

- `integration-patterns.md` — SoC-side memory bus integration.
- `stream-out-mode-design.md` — post-completion bin streaming output.
- `bus-master-mode-design.md` — `FFT_USE_BUS_MASTER` mode.
- `architecture.md` — internal engine structure and sequencing.
