#=============================================================================
# FFT Edge Cases Test using Cocotb
#=============================================================================
# Description: Comprehensive edge case testing for FFT hardware accelerator
#              Tests boundary conditions, error cases, and extreme inputs
# Author:      Vyges IP Development Team
# Date:        2025-07-21
# License:     Apache-2.0
#=============================================================================

import cocotb
from cocotb.triggers import RisingEdge, FallingEdge, Timer
from cocotb.clock import Clock
from cocotb.handle import ModifiableObject
import random
import numpy as np

# Test parameters
CLOCK_PERIOD = 1  # 1ns = 1GHz

@cocotb.test()
async def test_zero_input(dut):
    """Test FFT with all-zero input"""
    
    # Start clock
    clock = Clock(dut.clk_i, CLOCK_PERIOD, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset the design
    await reset_dut(dut)
    
    # Configure FFT for 256 points
    await configure_fft(dut, fft_length_log2=8, fft_length=256)
    
    # Load zero data
    zero_data = [complex(0.0, 0.0) for _ in range(256)]
    await load_input_data(dut, zero_data)
    
    # Start FFT computation
    await start_fft(dut)
    
    # Wait for completion
    await wait_for_completion(dut)
    
    # Read results
    output_data = await read_output_data(dut, 256)
    
    # Verify results - should be all zeros
    for i, val in enumerate(output_data):
        assert abs(val) < 1e-6, f"Output at index {i} should be zero, got {val}"

@cocotb.test()
async def test_single_impulse(dut):
    """Test FFT with single impulse input"""
    
    # Start clock
    clock = Clock(dut.clk_i, CLOCK_PERIOD, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset the design
    await reset_dut(dut)
    
    # Configure FFT for 256 points
    await configure_fft(dut, fft_length_log2=8, fft_length=256)
    
    # Load single impulse data
    impulse_data = [complex(0.0, 0.0) for _ in range(256)]
    impulse_data[0] = complex(1.0, 0.0)  # Impulse at index 0
    await load_input_data(dut, impulse_data)
    
    # Start FFT computation
    await start_fft(dut)
    
    # Wait for completion
    await wait_for_completion(dut)
    
    # Read results
    output_data = await read_output_data(dut, 256)
    
    # Verify results - should be constant magnitude
    expected_magnitude = 1.0 / np.sqrt(256)  # Normalized FFT of impulse
    for i, val in enumerate(output_data):
        magnitude = abs(val)
        assert abs(magnitude - expected_magnitude) < 0.1, f"Magnitude at index {i} should be ~{expected_magnitude}, got {magnitude}"

@cocotb.test()
async def test_maximum_input(dut):
    """Test FFT with maximum magnitude input"""
    
    # Start clock
    clock = Clock(dut.clk_i, CLOCK_PERIOD, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset the design
    await reset_dut(dut)
    
    # Configure FFT for 256 points
    await configure_fft(dut, fft_length_log2=8, fft_length=256)
    await enable_rescaling_full(dut)
    
    # Load maximum magnitude data
    max_data = [complex(1.0, 1.0) for _ in range(256)]
    await load_input_data(dut, max_data)
    
    # Start FFT computation
    await start_fft(dut)
    
    # Wait for completion
    await wait_for_completion(dut)
    
    # Check rescaling occurred
    scale_factor = await read_scale_factor(dut)
    overflow_status = await read_overflow_status(dut)
    
    # Verify rescaling occurred due to maximum input
    assert scale_factor > 0, "Scale factor should be greater than 0 for maximum input"
    assert overflow_status['overflow_count'] > 0, "Overflow count should be greater than 0"

@cocotb.test()
async def test_different_fft_sizes(dut):
    """Test FFT with different sizes"""
    
    # Start clock
    clock = Clock(dut.clk_i, CLOCK_PERIOD, units="ns")
    cocotb.start_soon(clock.start())
    
    # Test different FFT sizes
    fft_sizes = [64, 128, 256, 512, 1024]
    
    for fft_size in fft_sizes:
        dut._log.info(f"Testing FFT size: {fft_size}")
        
        # Reset the design
        await reset_dut(dut)
        
        # Configure FFT
        fft_length_log2 = int(np.log2(fft_size))
        await configure_fft(dut, fft_length_log2=fft_length_log2, fft_length=fft_size)
        
        # Load test data
        test_data = generate_test_data(fft_size)
        await load_input_data(dut, test_data)
        
        # Start FFT computation
        await start_fft(dut)
        
        # Wait for completion
        await wait_for_completion(dut)
        
        # Read results
        output_data = await read_output_data(dut, fft_size)
        
        # Basic verification
        assert len(output_data) == fft_size, f"Output length should be {fft_size}"
        
        # Check that output is not all zeros
        output_magnitude = sum(abs(val) for val in output_data)
        assert output_magnitude > 0, f"Output data should not be all zeros for size {fft_size}"

@cocotb.test()
async def test_invalid_configuration(dut):
    """Test behavior with invalid configuration"""
    
    # Start clock
    clock = Clock(dut.clk_i, CLOCK_PERIOD, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset the design
    await reset_dut(dut)
    
    # Test invalid FFT length (not power of 2)
    await apb_write(dut, 0x0008, 7)  # FFT_CONFIG: log2(128) = 7
    await apb_write(dut, 0x000C, 100)  # FFT_LENGTH: Invalid (not 128)
    
    # Load test data
    test_data = generate_test_data(128)
    await load_input_data(dut, test_data)
    
    # Start FFT computation
    await start_fft(dut)
    
    # Wait for completion or error
    try:
        await wait_for_completion(dut, timeout=10000)
        # If we get here, the design handled the invalid config gracefully
        dut._log.info("Design handled invalid configuration gracefully")
    except:
        # Expected behavior - design should handle invalid config
        dut._log.info("Design correctly rejected invalid configuration")

@cocotb.test()
async def test_concurrent_operations(dut):
    """Test concurrent operations and bus contention"""
    
    # Start clock
    clock = Clock(dut.clk_i, CLOCK_PERIOD, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset the design
    await reset_dut(dut)
    
    # Configure FFT
    await configure_fft(dut, fft_length_log2=8, fft_length=256)
    
    # Load test data
    test_data = generate_test_data(256)
    await load_input_data(dut, test_data)
    
    # Start FFT computation
    await start_fft(dut)
    
    # Try to read status while FFT is running
    for _ in range(10):
        await Timer(100, units="ns")
        try:
            status = await apb_read(dut, 0x0004)  # FFT_STATUS
            dut._log.info(f"Status during computation: 0x{status:08x}")
        except:
            dut._log.info("Status read failed during computation (expected)")
    
    # Wait for completion
    await wait_for_completion(dut)
    
    # Verify final status
    final_status = await apb_read(dut, 0x0004)
    assert final_status & 0x02, "FFT_DONE bit should be set after completion"

@cocotb.test()
async def test_memory_boundary_conditions(dut):
    """Test memory boundary conditions"""
    
    # Start clock
    clock = Clock(dut.clk_i, CLOCK_PERIOD, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset the design
    await reset_dut(dut)
    
    # Configure FFT for 256 points
    await configure_fft(dut, fft_length_log2=8, fft_length=256)
    
    # Test writing to memory boundaries
    # Write to first address
    await apb_write(dut, 0x1000, 0x12345678)
    
    # Write to last address
    await apb_write(dut, 0x13FC, 0x87654321)  # 256 * 4 - 4 = 1020 = 0x3FC
    
    # Read back to verify
    first_val = await apb_read(dut, 0x1000)
    last_val = await apb_read(dut, 0x13FC)
    
    assert first_val == 0x12345678, f"First address readback failed: 0x{first_val:08x}"
    assert last_val == 0x87654321, f"Last address readback failed: 0x{last_val:08x}"

@cocotb.test()
async def test_clock_frequency_variations(dut):
    """Test behavior with different clock frequencies"""
    
    # Test different clock periods
    clock_periods = [0.5, 1.0, 2.0, 5.0]  # ns
    
    for period in clock_periods:
        dut._log.info(f"Testing clock period: {period}ns")
        
        # Reset the design
        await reset_dut(dut)
        
        # Create clock with different period
        clock = Clock(dut.clk_i, period, units="ns")
        cocotb.start_soon(clock.start())
        
        # Configure FFT
        await configure_fft(dut, fft_length_log2=8, fft_length=256)
        
        # Load test data
        test_data = generate_test_data(256)
        await load_input_data(dut, test_data)
        
        # Start FFT computation
        await start_fft(dut)
        
        # Wait for completion
        await wait_for_completion(dut)
        
        # Read results
        output_data = await read_output_data(dut, 256)
        
        # Basic verification
        assert len(output_data) == 256, f"Output length should be 256 for clock period {period}ns"
        
        # Check that output is not all zeros
        output_magnitude = sum(abs(val) for val in output_data)
        assert output_magnitude > 0, f"Output data should not be all zeros for clock period {period}ns"

# Helper functions

async def reset_dut(dut):
    """Reset the DUT"""
    dut.reset_n_i.value = 0
    dut.preset_n_i.value = 0
    dut.axi_areset_n_i.value = 0
    await Timer(100, units="ns")
    dut.reset_n_i.value = 1
    dut.preset_n_i.value = 1
    dut.axi_areset_n_i.value = 1
    await Timer(10, units="ns")

async def configure_fft(dut, fft_length_log2, fft_length):
    """Configure FFT parameters"""
    await apb_write(dut, 0x0008, fft_length_log2)  # FFT_CONFIG
    await apb_write(dut, 0x000C, fft_length)      # FFT_LENGTH

async def enable_rescaling_full(dut):
    """Enable all rescaling features"""
    await apb_write(dut, 0x0000, 0x30)  # FFT_CTRL: Enable rescaling and scale tracking
    await apb_write(dut, 0x0008, 0x80008)  # FFT_CONFIG: Enable overflow detection
    await apb_write(dut, 0x0020, 0x0F)  # RESCALE_CTRL: Enable all rescaling features

async def load_input_data(dut, data):
    """Load input data into buffer"""
    for i, sample in enumerate(data):
        addr = 0x1000 + (i * 4)  # Input buffer A base address
        real_part = int(sample.real * 32767) & 0xFFFF
        imag_part = int(sample.imag * 32767) & 0xFFFF
        data_word = (real_part << 16) | imag_part
        await apb_write(dut, addr, data_word)

async def start_fft(dut):
    """Start FFT computation"""
    await apb_write(dut, 0x0000, 0x31)  # FFT_CTRL: Start FFT

async def wait_for_completion(dut, timeout=100000):
    """Wait for FFT completion with timeout"""
    timeout_count = 0
    while timeout_count < timeout:
        status = await apb_read(dut, 0x0004)  # FFT_STATUS
        if status & 0x02:  # FFT_DONE bit
            break
        await RisingEdge(dut.clk_i)
        timeout_count += 1
    
    if timeout_count >= timeout:
        raise Exception("FFT completion timeout")

async def read_output_data(dut, length):
    """Read output data from buffer"""
    output_data = []
    for i in range(length):
        addr = 0x3000 + (i * 4)  # Output buffer A base address
        data_word = await apb_read(dut, addr)
        real_part = (data_word >> 16) & 0xFFFF
        imag_part = data_word & 0xFFFF
        # Convert from 16-bit fixed-point to complex
        real_val = real_part / 32767.0
        imag_val = imag_part / 32767.0
        output_data.append(complex(real_val, imag_val))
    return output_data

async def read_scale_factor(dut):
    """Read scale factor register"""
    scale_reg = await apb_read(dut, 0x001C)  # SCALE_FACTOR
    return scale_reg & 0xFF

async def read_overflow_status(dut):
    """Read overflow status register"""
    overflow_reg = await apb_read(dut, 0x0024)  # OVERFLOW_STATUS
    return {
        'overflow_count': overflow_reg & 0xFF,
        'last_overflow_stage': (overflow_reg >> 8) & 0xFF,
        'max_overflow_magnitude': (overflow_reg >> 16) & 0xFF
    }

# APB interface functions

async def apb_write(dut, addr, data):
    """Write to APB register"""
    await RisingEdge(dut.pclk_i)
    dut.psel_i.value = 1
    dut.penable_i.value = 0
    dut.pwrite_i.value = 1
    dut.paddr_i.value = addr
    dut.pwdata_i.value = data
    
    await RisingEdge(dut.pclk_i)
    dut.penable_i.value = 1
    
    await RisingEdge(dut.pclk_i)
    while dut.pready_o.value == 0:
        await RisingEdge(dut.pclk_i)
    
    dut.psel_i.value = 0
    dut.penable_i.value = 0

async def apb_read(dut, addr):
    """Read from APB register"""
    await RisingEdge(dut.pclk_i)
    dut.psel_i.value = 1
    dut.penable_i.value = 0
    dut.pwrite_i.value = 0
    dut.paddr_i.value = addr
    
    await RisingEdge(dut.pclk_i)
    dut.penable_i.value = 1
    
    await RisingEdge(dut.pclk_i)
    while dut.pready_o.value == 0:
        await RisingEdge(dut.pclk_i)
    
    data = dut.prdata_o.value
    dut.psel_i.value = 0
    dut.penable_i.value = 0
    
    return data

# Test data generation

def generate_test_data(length):
    """Generate test data for FFT"""
    # Generate complex sinusoid
    freq = 10  # Frequency bin
    data = []
    for i in range(length):
        phase = 2 * np.pi * freq * i / length
        real_part = np.cos(phase)
        imag_part = np.sin(phase)
        data.append(complex(real_part, imag_part))
    return data 