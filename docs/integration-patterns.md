# Integration Patterns

How to integrate the FFT IP into a SoC. Focused on the external memory bus that connects the FFT engine's working buffer to host SRAM macros at the SoC level.

## Memory backend modes

The FFT IP supports two compile-time memory backend selections via Verilog defines on `fft_memory_interface.sv`:

| Define | Backend | Where it fits |
|---|---|---|
| (default — undefined) | FF-array with FPGA `(* ram_style = "block" *)` BRAM-inference attributes | Simulation, FPGA bringup, ASIC sanity hardening |
| `FFT_USE_SRAM_MACRO` | External SRAM bus to host-supplied wrapper | ASIC production hardening |

The two modes share the same module port list above the bus boundary — switching is a one-line define toggle in the integrator's build.

For the default mode see [`memory_optimization.md`](memory_optimization.md). The remainder of this document covers the external SRAM bus mode.

## External SRAM bus contract

When `FFT_USE_SRAM_MACRO` is defined, `memory_interface` exposes eight ports for connection to a SoC-supplied bridge module named `fft_data_sram`:

```
output logic        sram_clk_o    // bridge clock (typically same as clk_i)
output logic [9:0]  sram_addr_o   // intra-bank address; bank is selected upstream
output logic [31:0] sram_wdata_o  // write data
output logic [31:0] sram_ben_o    // byte-enables (1 bit per data bit; '1 = enabled)
output logic        sram_rwb_o    // 0 = write, 1 = read
output logic [1:0]  sram_en_o     // per-bank chip-enable; one-hot active
input  logic [31:0] sram_rdata0_i // bank 0 read data
input  logic [31:0] sram_rdata1_i // bank 1 read data
```

### Address layout

- 11-bit linear address space presented by the FFT engine: `0x000–0x7FF` (2048 words × 32 bits).
- Bridge expectation: `addr[10]` selects bank (0 or 1); `addr[9:0]` is intra-bank.
- Logical regions inside the address space:
  - `0x000–0x3FF` — sample / butterfly working data
  - `0x400–0x5FF` — twiddle factors (loaded by host before `FFT_CTRL[0]=1`)
  - `0x600–0x7FF` — reserved

The bridge does not need to interpret the regions; it just routes accesses by bank-select.

### Write port priority

`memory_interface` muxes two write streams to a single bridge write port: APB-driven twiddle loads and engine-driven butterfly writes. APB twiddle writes take precedence; the two are mutually exclusive by host-firmware protocol (firmware completes twiddle loading before asserting `FFT_CTRL[0]=1` to start the engine).

The bridge sees a single combined write request and does not need to arbitrate.

### Timing

- Synchronous read with **1-cycle latency** — same as the default FF-array mode. The bridge is expected to register the read into `sram_rdata{0,1}_i` on `posedge sram_clk_o` and have it valid one cycle after the address is presented.
- Single outstanding access — engine does not pipeline multiple reads in flight.

### Bank selection muxing

The bridge selects between `sram_rdata0_i` and `sram_rdata1_i` based on the bank that was addressed in the prior cycle. Because the engine presents `sram_en_o[1:0]` one-hot for the current cycle's request and read data returns one cycle later, the bridge must register `sram_en_o` (or equivalently the high bit of address) for one cycle to align selection with the returned data.

## Reference bridge skeleton

A SoC-supplied `fft_data_sram` wrapper. Replace the macro instantiations with whatever SRAM technology your PDK provides (foundry hard macro, OpenRAM-generated module, behavioral model, etc.).

```systemverilog
module fft_data_sram (
    // Host-side ports — match memory_interface external SRAM bus
    input  logic        clk_i,
    input  logic        reset_n_i,
    input  logic [10:0] addr_i,
    input  logic [31:0] wdata_i,
    input  logic        write_en_i,
    output logic [31:0] rdata_o,

    // Pass-through bus signals from memory_interface
    output logic        sram_clk_o,
    output logic [9:0]  sram_addr_o,
    output logic [31:0] sram_wdata_o,
    output logic [31:0] sram_ben_o,
    output logic        sram_rwb_o,
    output logic [1:0]  sram_en_o,
    input  logic [31:0] sram_rdata0_i,
    input  logic [31:0] sram_rdata1_i
);
    // 1. Decode bank from addr[10]; route intra-bank addr[9:0]
    logic       bank_sel;
    logic [9:0] bank_addr;
    assign bank_sel  = addr_i[10];
    assign bank_addr = addr_i[9:0];

    // 2. Drive bus signals
    assign sram_clk_o   = clk_i;
    assign sram_addr_o  = bank_addr;
    assign sram_wdata_o = wdata_i;
    assign sram_ben_o   = {32{1'b1}};       // full-word writes
    assign sram_rwb_o   = ~write_en_i;
    assign sram_en_o    = bank_sel ? 2'b10 : 2'b01;

    // 3. Register bank_sel one cycle to align with 1-cycle read latency
    logic bank_sel_q;
    always_ff @(posedge clk_i or negedge reset_n_i) begin
        if (!reset_n_i) bank_sel_q <= 1'b0;
        else            bank_sel_q <= bank_sel;
    end

    // 4. Mux read data based on the registered bank selection
    assign rdata_o = bank_sel_q ? sram_rdata1_i : sram_rdata0_i;

    // 5. Instantiate two 1024×32 SRAM macros (PDK-specific)
    //    - vendor_sram u_bank0 (...);   // sram_rdata0_i source
    //    - vendor_sram u_bank1 (...);   // sram_rdata1_i source
    //    Wire each macro's clk/addr/wdata/we/ben to the bus signals; mask
    //    chip-enable per bank by ANDing with sram_en_o[i].
endmodule
```

A complete bridge for any specific SRAM technology adds the macro instantiations, power-pin tieoffs (if the macro requires them), and any technology-specific timing trims (output enable delays, read margin shifts).

## Standalone hardenability

The IP can be hardened standalone (without an integrating SoC) using a black-box behavioral model of `fft_data_sram` that mirrors the port list above. This lets DRC/LVS and synthesis sign-off proceed before committing to a specific SRAM macro.

A behavioral skeleton suffices:

```systemverilog
module fft_data_sram (...);  // same port list
    // Implement bus pass-through (no macro instances) for synthesis
    // and LVS-equivalence stubbing.
endmodule
```

## Integration verification recommendations

1. **FPGA bringup first** — exercise the FFT in the default FF-array mode on FPGA against the supplied reference vectors before introducing the external SRAM bus.
2. **Bridge-level cocotb regression** — drive the eight bus ports from a cocotb testbench using the same vectors; compare the FFT output against the FPGA-validated reference.
3. **Single-bank stress** — confirm bank-select muxing handles back-to-back accesses that alternate bank 0 / bank 1 (the address-aligned read-data return is the most common bridge bug).
4. **Twiddle-load + engine-write ordering** — confirm APB twiddle writes complete before the engine asserts its first write; the muxed write port relies on this protocol.

## Future memory backend modes

A bus-master mode is planned where the FFT issues TL-UL transactions to a memory subsystem instead of presenting a direct SRAM bus. This will be a third define (`FFT_USE_TLUL_MASTER`) that coexists with the existing two; integration consequences are similar to the external SRAM bus mode but the bridge becomes a TL-UL slave wrapping the SRAM macros (any standard TL-UL slave that exposes a memory backend will work). This document will gain a section when the mode lands.
