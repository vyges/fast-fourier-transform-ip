#=============================================================================
# OpenLane Configuration for FFT Hardware Accelerator - GF180MCU PDK
#=============================================================================
# Description: Configuration file for ASIC synthesis and place-and-route
#              using OpenLane flow with GF180MCU PDK
# Author:      Vyges IP Development Team
# Date:        2025-01-27
# License:     Apache-2.0
#=============================================================================

# Design configuration
set ::env(DESIGN_NAME) "fft_top"
set ::env(DESIGN_IS_CORE) 1
set ::env(FP_PDN_CORE_RING) 1

# Clock configuration
set ::env(CLOCK_PERIOD) "10.0"  # 100MHz for GF180MCU (more conservative)
set ::env(CLOCK_PORT) "clk_i"
set ::env(CLOCK_NET) "clk_i"

# Synthesis configuration
set ::env(SYNTH_STRATEGY) "AREA 0"
set ::env(SYNTH_MAX_FANOUT) 20
set ::env(SYNTH_BUFFERING) 1
set ::env(SYNTH_SIZING) 0
set ::env(SYNTH_OPT) 0

# Floorplan configuration
set ::env(FP_SIZING) "absolute"
set ::env(DIE_AREA) "0 0 1500 1500"  # Larger die for 180nm
set ::env(PLACE_PINS_ARGS) "-random"
set ::env(FP_PIN_ORDER_CFG) "pin_order.cfg"

# Placement configuration
set ::env(PL_TARGET_DENSITY) 0.60  # Lower density for 180nm
set ::env(PL_TIME_DRIVEN) 1
set ::env(PL_LIB) "gf180mcu_fd_sc_mcu7t5v0__tt_025C_5v00.lib"

# Clock tree synthesis
set ::env(CTS_CLK_BUFFER_LIST) "gf180mcu_fd_sc_mcu7t5v0__clkbuf_8 gf180mcu_fd_sc_mcu7t5v0__clkbuf_4 gf180mcu_fd_sc_mcu7t5v0__clkbuf_2"
set ::env(CTS_ROOT_BUFFER) "gf180mcu_fd_sc_mcu7t5v0__clkbuf_16"
set ::env(CTS_MAX_CAP) 2.0

# Routing configuration
set ::env(ROUTING_STRATEGY) 0
set ::env(GLB_RT_MAXLAYER) 4  # GF180MCU has fewer metal layers
set ::env(GLB_RT_ADJUSTMENT) 0.15
set ::env(GLB_RT_L1_ADJUSTMENT) 0.99
set ::env(GLB_RT_L2_ADJUSTMENT) 0.99

# Power configuration
set ::env(FP_PDN_MACRO_HOOKS) "fft_top vdd vss vdd vss"
set ::env(VDD_NETS) "vdd"
set ::env(GND_NETS) "vss"

# LVS configuration
set ::env(LVS_CONNECT_BY_LABEL) 0
set ::env(LVS_INSERT_POWER_PINS) 1

# DRC configuration
set ::env(QUIT_ON_DRC) 0
set ::env(QUIT_ON_LVS_ERROR) 0
set ::env(QUIT_ON_MAGIC_DRC) 0

# Verification configuration
set ::env(RUN_KLAYOUT) 1
set ::env(RUN_KLAYOUT_DRC) 0
set ::env(KLAYOUT_DRC_KLAYOUT_GDS) 0
set ::env(KLAYOUT_DRC_TECH_SCRIPT) "gf180mcu_mr"

# Reports configuration
set ::env(REPORTS_DIR) "reports"
set ::env(LOG_DIR) "logs"
set ::env(RESULTS_DIR) "results"

# FFT-specific constraints
set ::env(FFT_MAX_LENGTH_LOG2) 12
set ::env(DATA_WIDTH) 16
set ::env(TWIDDLE_WIDTH) 16

# Memory configuration
set ::env(MEMORY_SIZE) 65536
set ::env(MEMORY_WORDS) 16384

# Performance targets (adjusted for 180nm)
set ::env(TARGET_FREQUENCY) 100
set ::env(TARGET_AREA) 75000  # Larger area for 180nm
set ::env(TARGET_POWER) 75    # Higher power for 180nm 