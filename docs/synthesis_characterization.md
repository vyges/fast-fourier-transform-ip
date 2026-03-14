# FFT IP — Synthesis Characterization

**Last updated:** 2026-03-14
**PDK:** sky130_fd_sc_hd (SkyWater 130 nm)
**Tool:** Yosys 0.33 + OpenSTA 2.7.0
**PDK installation:** [ciel](https://pypi.org/project/ciel/) (open-source PDK manager)
**PDK version hash:** `6d4d11780c40b20ee63cc98e645307a9bf2b2ab8`
**Corner:** TT 25°C 1.8 V
**NAND2 reference area:** 3.75 μm² (sky130_fd_sc_hd__nand2_1)

---

## Architecture: iterative vs pipelined

The `fft_engine` module implements a **radix-2 DIF FFT using an iterative / memory-based architecture**:

- A **single butterfly unit** is shared across all log₂(N) passes
- Each butterfly takes **6 pipeline cycles** (address generation → memory read → addition → subtraction → complex multiply → rescale/write)
- FFT data is stored in external memory; the engine reads, computes, and writes back each butterfly in sequence
- Twiddle factors are fetched from an external twiddle ROM on each butterfly

For a 1024-point FFT: N/2 × log₂(N) = 512 × 10 = **5,120 butterflies × 6 cycles = 30,720 cycles per transform**.
At 50 MHz (edge-sensor-soc target): **~614 μs per transform**.

> **This is very different from a pipelined streaming FFT**, which has log₂(N) concurrent butterfly stages
> all active simultaneously. A pipelined 1024-pt FFT produces one output per clock cycle after an initial
> latency, but requires ~10× more silicon.

### Why gate count is lower than commercial estimates

| Architecture | Butterfly hardware | Gate count (1024-pt) | Throughput |
|---|---|---|---|
| Iterative (this IP) | 1 shared unit | ~10K GE | 1 transform per ~600 μs @ 50 MHz |
| Pipelined streaming | log₂(N) = 10 units | ~40–60K GE | 1 sample/clock after startup |
| Commercial estimate ("50K GE") | typically pipelined | ~50K GE | high throughput |

The `fft_engine` **~10K GE is correct** for this architecture. Gate count scales with the number of
butterfly units, not the FFT length (which only affects counter widths and memory addressing).

---

## Synthesis results

### fft_engine (compute core, twiddle ROM excluded)

Synthesized standalone with `FFT_MAX_LENGTH_LOG2=12` (default params):

| Metric | Value |
|---|---|
| Cells | 4,098 |
| Area | 36,724 μm² |
| Gate equivalents | ~9,793 GE |
| Seq cells (flip-flops) | ~800 |
| Combinational cells | ~3,298 |
| WNS (50 MHz, TT corner) | > 0 ns (passes) |

The core contains: 4× 16-bit multipliers (butterfly complex multiply), 4× adder/subtractor units,
6-stage pipeline registers, address counter, overflow detection, and rescaling logic.

### fft_top with twiddle_rom (DO NOT use as area estimate)

| Metric | Value | Note |
|---|---|---|
| Cells (full) | ~194,587 | Twiddle ROM synthesized as constant gate logic |
| Area | ~690,000 μm² | Inflated — see explanation below |
| Gate equivalents | ~184,000 GE | Not representative of silicon area |

This number is **not meaningful** as an area estimate. See below.

---

## Twiddle ROM and Yosys SRAM inference

`twiddle_rom.sv` has `(* rom_style = "block" *)` synthesis attributes, which are **Xilinx Vivado
attributes** — they are ignored by Yosys. Without an explicit sky130 SRAM macro instantiation,
Yosys synthesizes the 1024-entry × 16-bit ROM as constant combinational logic, producing
~190K cells.

**In production (OpenLane sky130 flow):**
- The twiddle ROM (1024 × 16-bit = 2 KB) maps to a **sky130 OpenRAM SRAM macro**
- SRAM macros are not counted in gate equivalents
- Production logic area is `fft_engine` alone (~10K GE) plus SRAM macro footprint (~0.05 mm²)

**Synthesis flows that correctly handle the ROM:**
- Xilinx Vivado: infers BRAM from `(* rom_style = "block" *)` → ~4 BRAMs
- Intel Quartus: infers M20K blocks → ~2 blocks
- OpenLane sky130: use an explicit `sky130_sram_1kbyte_1rw1r_32x256_8` or equivalent macro
- Yosys generic: does NOT infer SRAM → must use `memory_bram` pass with sky130 tech map

---

## Correct area breakdown for SoC integration

When integrating into a sky130 SoC:

| Component | Area | Source |
|---|---|---|
| `fft_engine` logic | ~36,724 μm² (~10K GE) | Yosys measured |
| Twiddle ROM (2KB SRAM macro) | ~TBD (sky130 SRAM characterization) | OpenRAM macro |
| `fft_control`, `memory_interface` | ~est. 2,000 μm² | Estimate |
| Total (logic only, excl. SRAM) | **~38,700 μm²** | |

---

## Throughput vs. area tradeoff

For the **edge-sensor-soc** use case (vibration monitoring, 10 kHz ADC, 1024-point FFT):

- **Required transform rate:** 1 per 102.4 ms (collect 1024 samples at 10 kHz)
- **Iterative FFT latency:** ~614 μs at 50 MHz
- **CPU utilization:** 614 μs / 102,400 μs ≈ **0.6% of available compute time**
- **Area saved vs pipelined:** ~40K GE (iterative 10K GE vs pipelined ~50K GE)

The iterative architecture is the correct choice for this application. A pipelined streaming FFT
would use ~5× more silicon with no benefit at this sample rate.

---

## PDK installation

The sky130 HD PDK was installed via [ciel](https://pypi.org/project/ciel/):

```bash
pip install ciel
ciel install sky130
```

Version hash used: `6d4d11780c40b20ee63cc98e645307a9bf2b2ab8`
Liberty file: `sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib`

---

## Synthesis invocation

```bash
# On Ubuntu (ovs@ovs-intelsdn-2) with sky130 installed via ciel:
export PDK_LIB=/home/ovs/vyges-test/pdks/volare/sky130/versions/6d4d11780c40b20ee63cc98e645307a9bf2b2ab8/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib

# Convert SV to Verilog (Yosys 0.33 SV support is incomplete for complex packages)
sv2v rtl/fft_fft_engine.sv -w build/fft_engine_conv.v

# Yosys synthesis
yosys -c synth_fft_engine.tcl -l build/synth_fft_engine.log
```

`synth_fft_engine.tcl`:
```tcl
set pdk_lib $::env(PDK_LIB)
yosys "read_liberty -lib $pdk_lib"
yosys "read_verilog build/fft_engine_conv.v"
yosys "hierarchy -check -top fft_engine"
yosys "synth -top fft_engine -flatten"
yosys "dfflibmap -liberty $pdk_lib"
yosys "abc -liberty $pdk_lib"
yosys "clean"
yosys "tee -o build/fft_engine_stats.txt stat -liberty $pdk_lib"
yosys "write_verilog -noattr build/fft_engine_synth.v"
```
