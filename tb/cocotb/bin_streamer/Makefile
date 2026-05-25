# SPDX-License-Identifier: Apache-2.0
#
# Cocotb makefile for fft_bin_streamer unit test (Verilator).

SIM            ?= verilator
TOPLEVEL_LANG  ?= verilog
TOPLEVEL       ?= fft_bin_streamer

REPO_ROOT      := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))../../..)
RTL            := $(REPO_ROOT)/rtl

VERILOG_SOURCES := $(RTL)/fft_bin_streamer.sv

EXTRA_ARGS += --trace --trace-structs --no-timing
EXTRA_ARGS += -Wno-WIDTHTRUNC -Wno-WIDTHEXPAND

MODULE         ?= test_bin_streamer

# Locate cocotb's makefile share dir without relying on cocotb-config being
# on PATH (it lives under ~/.local/bin in user installs).
COCOTB_MAKEFILES := $(shell python3 -c "import cocotb, os; print(os.path.join(os.path.dirname(cocotb.__file__), 'share', 'makefiles'))")

include $(COCOTB_MAKEFILES)/Makefile.sim
