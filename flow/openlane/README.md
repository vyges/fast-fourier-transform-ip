# LibreLane ASIC Flow

LibreLane configuration for hardening the FFT IP standalone in sky130A.

## Files

- `config.json` — main configuration. Targets `fft_top` with `+define+FFT_USE_SRAM_MACRO`, `DIE_AREA = 0 0 1500 1500`, `RT_MAX_LAYER = met5`. PDK section is `pdk::sky130A`.
- `pin_order.cfg` — `#BUS_SORT` pin placement. SRAM bus on NORTH, APB on WEST, AXI on EAST, clocks/resets/interrupts on SOUTH.
- `config.template.json` — generic LibreLane config template (untracked starter).

## Running

The IP top is `fft_top` and exposes an external SRAM bus (see project `README.md` "Memory Topology"). Standalone hardening uses a black-box `fft_data_sram` model — supply one in your SoC repository, or override `VERILOG_FILES` to add a stub before invoking LibreLane.

```bash
librelane flow/openlane/config.json
```
