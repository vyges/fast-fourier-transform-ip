# Copyright 2026 Vyges Inc.
# SPDX-License-Identifier: Apache-2.0
#
# Cocotb test for fft_bin_streamer.
#
# Drives a synthetic 1-cycle-latency memory model and verifies that the
# bin walker reads N bins in increasing address order and presents them
# on the vyges-dsp-stream-v1 output port set. Covers:
#
#   * idle pre-fft (no spurious memory reads)
#   * gating: fft_done with stream_enable=0 should NOT walk
#   * single 8-bin walk with always-ready consumer
#   * consumer stall handling (bin_ready_i de-asserted mid-stream)
#   * index propagation and last-flag placement

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge


def pack_bin(re: int, im: int) -> int:
    """Pack signed 16-bit (re, im) into a 32-bit memory word: [31:16]=im, [15:0]=re."""
    return ((im & 0xFFFF) << 16) | (re & 0xFFFF)


def _signed16(v: int) -> int:
    return v - 0x10000 if v & 0x8000 else v


async def reset(dut):
    dut.rst_ni.value            = 0
    dut.fft_done_pulse_i.value  = 0
    dut.stream_enable_i.value   = 0
    dut.num_bins_i.value        = 0
    dut.mem_ready_i.value       = 0
    dut.mem_data_i.value        = 0
    dut.bin_ready_i.value       = 1   # always-ready by default
    for _ in range(4):
        await RisingEdge(dut.clk_i)
    dut.rst_ni.value = 1
    for _ in range(2):
        await RisingEdge(dut.clk_i)


async def synthetic_memory(dut, bins, latency_cycles: int = 1):
    """Background task: respond to mem_read_o with packed bin data."""
    while True:
        await RisingEdge(dut.clk_i)
        if dut.mem_read_o.value == 1:
            addr = int(dut.mem_addr_o.value)
            for _ in range(latency_cycles):
                await RisingEdge(dut.clk_i)
            await FallingEdge(dut.clk_i)
            dut.mem_ready_i.value = 1
            dut.mem_data_i.value  = pack_bin(*bins[addr])
            await RisingEdge(dut.clk_i)
            await FallingEdge(dut.clk_i)
            dut.mem_ready_i.value = 0
            dut.mem_data_i.value  = 0


@cocotb.test()
async def idle_state_emits_nothing(dut):
    cocotb.start_soon(Clock(dut.clk_i, 10, units="ns").start())
    await reset(dut)
    dut.num_bins_i.value = 8
    # Run 50 cycles with no fft_done — no stream activity expected.
    for _ in range(50):
        await RisingEdge(dut.clk_i)
        assert dut.bin_valid_o.value  == 0
        assert dut.mem_read_o.value   == 0
        assert dut.streamer_active_o.value == 0


@cocotb.test()
async def fft_done_without_enable_is_ignored(dut):
    cocotb.start_soon(Clock(dut.clk_i, 10, units="ns").start())
    await reset(dut)
    dut.num_bins_i.value = 8
    # Pulse fft_done while stream_enable_i is still 0 — no walk.
    await FallingEdge(dut.clk_i)
    dut.fft_done_pulse_i.value = 1
    await RisingEdge(dut.clk_i)
    await FallingEdge(dut.clk_i)
    dut.fft_done_pulse_i.value = 0
    for _ in range(20):
        await RisingEdge(dut.clk_i)
        assert dut.bin_valid_o.value == 0
        assert dut.mem_read_o.value  == 0


@cocotb.test()
async def eight_bin_walk_always_ready(dut):
    cocotb.start_soon(Clock(dut.clk_i, 10, units="ns").start())
    await reset(dut)

    bins = [(re, 2 * re + 3) for re in range(8)]
    cocotb.start_soon(synthetic_memory(dut, bins))

    dut.num_bins_i.value      = 8
    dut.stream_enable_i.value = 1

    await FallingEdge(dut.clk_i)
    dut.fft_done_pulse_i.value = 1
    await RisingEdge(dut.clk_i)
    await FallingEdge(dut.clk_i)
    dut.fft_done_pulse_i.value = 0

    collected = []
    cycle_budget = 200
    while len(collected) < len(bins) and cycle_budget > 0:
        await RisingEdge(dut.clk_i)
        if dut.bin_valid_o.value == 1:
            collected.append({
                "index": int(dut.bin_index_o.value),
                "last":  int(dut.bin_last_o.value),
                "re":    _signed16(int(dut.bin_re_o.value)),
                "im":    _signed16(int(dut.bin_im_o.value)),
            })
        cycle_budget -= 1

    assert len(collected) == len(bins), f"only saw {len(collected)} beats: {collected}"
    for c, (re, im) in zip(collected, bins):
        assert c["re"] == re,    f"expected re={re}, got {c['re']}"
        assert c["im"] == im,    f"expected im={im}, got {c['im']}"
    indices = [c["index"] for c in collected]
    assert indices == list(range(len(bins))), f"indices out of order: {indices}"
    lasts = [c["last"] for c in collected]
    assert lasts == [0]*7 + [1], f"last flag misplaced: {lasts}"

    # After last beat, the streamer must return to idle.
    for _ in range(8):
        await RisingEdge(dut.clk_i)
    assert dut.streamer_active_o.value == 0


@cocotb.test()
async def consumer_stall_holds_data(dut):
    """De-assert bin_ready_i pre-stream; first beat must stay parked
    until the consumer accepts it. Then drain to last."""
    cocotb.start_soon(Clock(dut.clk_i, 10, units="ns").start())
    await reset(dut)

    bins = [(re * 7, re * 11) for re in range(4)]
    cocotb.start_soon(synthetic_memory(dut, bins))

    dut.num_bins_i.value      = 4
    dut.stream_enable_i.value = 1

    # Stall the consumer BEFORE the first beat appears, so the streamer
    # has to park its valid + payload on the first beat.
    await FallingEdge(dut.clk_i)
    dut.bin_ready_i.value      = 0
    dut.fft_done_pulse_i.value = 1
    await RisingEdge(dut.clk_i)
    await FallingEdge(dut.clk_i)
    dut.fft_done_pulse_i.value = 0

    # Wait for the first beat to appear.
    while dut.bin_valid_o.value == 0:
        await RisingEdge(dut.clk_i)

    # Sample the parked beat and verify it stays put across 10 stall cycles.
    held_index = int(dut.bin_index_o.value)
    held_re    = int(dut.bin_re_o.value)
    held_im    = int(dut.bin_im_o.value)
    for _ in range(10):
        await RisingEdge(dut.clk_i)
        assert dut.bin_valid_o.value  == 1, "valid dropped during stall"
        assert int(dut.bin_index_o.value) == held_index
        assert int(dut.bin_re_o.value)    == held_re
        assert int(dut.bin_im_o.value)    == held_im

    # Release the consumer; stream must drain to last.
    await FallingEdge(dut.clk_i)
    dut.bin_ready_i.value = 1
    cycle_budget = 200
    saw_last = 0
    while cycle_budget > 0 and saw_last == 0:
        await RisingEdge(dut.clk_i)
        if dut.bin_valid_o.value == 1 and dut.bin_last_o.value == 1:
            saw_last = 1
        cycle_budget -= 1
    assert saw_last == 1, "stream never reached last after stall release"
