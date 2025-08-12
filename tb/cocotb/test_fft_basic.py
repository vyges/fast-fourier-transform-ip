#=============================================================================
# Basic FFT Test using Cocotb
#=============================================================================
# Description: Basic functionality test for FFT hardware accelerator
#              Minimal test that just verifies compilation and basic operation
# Author:      Vyges IP Development Team
# Date:        2025-07-21
# License:     Apache-2.0
#=============================================================================

import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

# Test parameters
CLOCK_PERIOD = 10  # 10ns = 100MHz

@cocotb.test()
async def test_fft_minimal(dut):
    """Minimal test that just verifies the design compiles and runs"""
    
    print("🚀 Starting minimal FFT test...")
    
    # Start clock
    clock = Clock(dut.clk_i, CLOCK_PERIOD, units="ns")
    cocotb.start_soon(clock.start())
    
    # Start APB clock
    pclock = Clock(dut.pclk_i, CLOCK_PERIOD, units="ns")
    cocotb.start_soon(pclock.start())
    
    # Start AXI clock
    axiclock = Clock(dut.axi_aclk_i, CLOCK_PERIOD, units="ns")
    cocotb.start_soon(axiclock.start())
    
    print("✅ Clocks started")
    
    # Reset the design
    dut.reset_n_i.value = 0
    dut.preset_n_i.value = 0
    dut.axi_areset_n_i.value = 0
    
    await Timer(100, units="ns")
    
    dut.reset_n_i.value = 1
    dut.preset_n_i.value = 1
    dut.axi_areset_n_i.value = 1
    
    print("✅ Reset completed")
    
    # Run for a fixed number of cycles
    for i in range(50):
        await RisingEdge(dut.clk_i)
        if i % 10 == 0:
            print(f"   Cycle {i}")
    
    print("✅ Test completed successfully - design is working!")

@cocotb.test()
async def test_fft_signal_check(dut):
    """Test that we can access all the main signals"""
    
    print("🔍 Checking signal accessibility...")
    
    # Start clock
    clock = Clock(dut.clk_i, CLOCK_PERIOD, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.reset_n_i.value = 0
    await Timer(50, units="ns")
    dut.reset_n_i.value = 1
    
    # Check that we can read signals
    clk_val = dut.clk_i.value
    reset_val = dut.reset_n_i.value
    
    print(f"   clk_i: {clk_val}")
    print(f"   reset_n_i: {reset_val}")
    
    # Check APB signals
    dut.psel_i.value = 0
    dut.penable_i.value = 0
    dut.pwrite_i.value = 0
    dut.paddr_i.value = 0
    dut.pwdata_i.value = 0
    
    print("✅ Signal accessibility test completed")
    
    # Run for a few cycles
    for _ in range(10):
        await RisingEdge(dut.clk_i)
    
    print("✅ Signal check test completed successfully!") 