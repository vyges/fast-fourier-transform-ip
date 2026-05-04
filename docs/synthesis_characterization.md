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
At 50 MHz: **~614 μs per transform**.

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

## Memory inference and the wrapper-bus pattern

Yosys does not honour `(* ram_style = "block" *)` or `(* rom_style = "block" *)` synthesis
attributes — those are **Xilinx Vivado** directives. With Yosys alone, the 2048×32-bit data
store and the 1024×16-bit twiddle ROM both synthesize as flop arrays or constant combinational
logic, producing tens to hundreds of thousands of cells.

**FPGA flows handle the inferred storage natively:**
- Xilinx Vivado: infers BRAM from `ram_style`/`rom_style` → ~2 BRAMs for the data array, ~4 BRAMs for the ROM
- Intel Quartus: infers M20K blocks → ~2 blocks for each
- Yosys generic: does **not** infer SRAM — only useful for gate-count sanity, not silicon

**ASIC flows use the wrapper-bus pattern.** When `FFT_USE_SRAM_MACRO` is defined,
`fft_memory_interface.sv` swaps the inferred array for a thin `fft_data_sram` wrapper that
exposes the SRAM bus on the IP's top-level boundary. The SoC integrator places two 1024×32
SRAM banks (any macro matching `bank_depth × data_width`) at the user-project-wrapper level and
connects them to the bus. Pin clustering on the NORTH edge (`flow/openlane/pin_order.cfg`)
keeps the routes short. The IP itself contains no PDK-specific macro instances and hardens
against any PDK with a matching macro.

---

## Area breakdown for SoC integration

When integrating into an ASIC SoC with the wrapper-bus pattern:

| Component | Area | Source |
|---|---|---|
| `fft_engine` logic | ~36,724 μm² (~10K GE) | Yosys measured |
| `fft_control`, `fft_memory_interface` (sans macros) | ~est. 2,000 μm² | Estimate |
| Total (logic only, excludes SRAM) | **~38,700 μm²** | |
| 2× SRAM bank (instantiated by SoC at wrapper level) | per-PDK macro datasheet | external |

The data-array and twiddle-ROM contents share the same 2048×32 store and are both backed by the SoC-supplied SRAM banks; firmware loads twiddle factors into the upper half of the address range via the APB twiddle-write window before asserting `FFT_CTRL[0]=start`.

---

## Throughput vs. area tradeoff

For a representative low-rate sensor use case (vibration monitoring, 10 kHz ADC, 1024-point FFT):

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
