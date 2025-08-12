#=============================================================================
# OpenLane Configuration for FFT Hardware Accelerator
#=============================================================================
# Description: Configuration file for ASIC synthesis and place-and-route
#              using OpenLane flow with sky130B PDK
# Author:      Vyges IP Development Team
# Date:        2025-07-21
# License:     Apache-2.0
#=============================================================================

# Design configuration
set ::env(DESIGN_NAME) "fft_top"
set ::env(DESIGN_IS_CORE) 1
set ::env(FP_PDN_CORE_RING) 1

# Clock configuration
set ::env(CLOCK_PERIOD) "1.0"  # 1GHz for Sky130A and IHP-SG13G2
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
set ::env(DIE_AREA) "0 0 1000 1000"
set ::env(PLACE_PINS_ARGS) "-random"
set ::env(FP_PIN_ORDER_CFG) "pin_order.cfg"

# Placement configuration
set ::env(PL_TARGET_DENSITY) 0.65
set ::env(PL_TIME_DRIVEN) 1
set ::env(PL_LIB) "sky130_fd_sc_hd__tt_025C_1v80.lib"

# Clock tree synthesis
set ::env(CTS_CLK_BUFFER_LIST) "sky130_fd_sc_hd__clkbuf_8 sky130_fd_sc_hd__clkbuf_4 sky130_fd_sc_hd__clkbuf_2"
set ::env(CTS_ROOT_BUFFER) "sky130_fd_sc_hd__clkbuf_16"
set ::env(CTS_MAX_CAP) 1.53169

# Routing configuration
set ::env(ROUTING_STRATEGY) 0
set ::env(GLB_RT_MAXLAYER) 5
set ::env(GLB_RT_ADJUSTMENT) 0.15
set ::env(GLB_RT_L1_ADJUSTMENT) 0.99
set ::env(GLB_RT_L2_ADJUSTMENT) 0.99

# Power configuration
set ::env(FP_PDN_MACRO_HOOKS) "fft_top vccd1 vssd1 vccd1 vssd1"
set ::env(VDD_NETS) "vccd1"
set ::env(GND_NETS) "vssd1"

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
set ::env(KLAYOUT_DRC_TECH_SCRIPT) "sky130A_mr"

# Reports configuration
set ::env(REPORTS_DIR) "reports"
set ::env(LOG_DIR) "logs"
set ::env(RESULTS_DIR) "results"

# Custom scripts
set ::env(PRE_NETLIST_HOOKS) "pre_netlist.tcl"
set ::env(POST_NETLIST_HOOKS) "post_netlist.tcl"
set ::env(PRE_PLACE_HOOKS) "pre_place.tcl"
set ::env(POST_PLACE_HOOKS) "post_place.tcl"
set ::env(PRE_CTS_HOOKS) "pre_cts.tcl"
set ::env(POST_CTS_HOOKS) "post_cts.tcl"
set ::env(PRE_ROUTING_HOOKS) "pre_routing.tcl"
set ::env(POST_ROUTING_HOOKS) "post_routing.tcl"

# FFT-specific constraints
set ::env(FFT_MAX_LENGTH_LOG2) 12
set ::env(DATA_WIDTH) 16
set ::env(TWIDDLE_WIDTH) 16

# Memory configuration
set ::env(MEMORY_SIZE) 65536
set ::env(MEMORY_WORDS) 16384

# Performance targets
set ::env(TARGET_FREQUENCY) 1000
set ::env(TARGET_AREA) 50000
set ::env(TARGET_POWER) 50 