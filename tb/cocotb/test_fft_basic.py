#=============================================================================
# Basic FFT Test using Cocotb
#=============================================================================
# Description: Basic functionality test for FFT hardware accelerator
#              Tests 1024-point FFT computation with rescaling
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
FFT_LENGTH = 1024
DATA_WIDTH = 16
CLOCK_PERIOD = 1  # 1ns = 1GHz

@cocotb.test()
async def test_fft_basic_functionality(dut):
    """Test basic FFT functionality with 1024-point computation"""
    
    # Start clock
    clock = Clock(dut.clk_i, CLOCK_PERIOD, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset the design
    await reset_dut(dut)
    
    # Configure FFT for 1024 points
    await configure_fft(dut, fft_length_log2=10, fft_length=1024)
    
    # Enable rescaling
    await enable_rescaling(dut)
    
    # Load test data
    test_data = generate_test_data(FFT_LENGTH)
    await load_input_data(dut, test_data)
    
    # Start FFT computation
    await start_fft(dut)
    
    # Wait for completion
    await wait_for_completion(dut)
    
    # Read results
    output_data = await read_output_data(dut, FFT_LENGTH)
    
    # Read scale factor
    scale_factor = await read_scale_factor(dut)
    
    # Verify results
    await verify_fft_results(dut, test_data, output_data, scale_factor)

@cocotb.test()
async def test_fft_rescaling(dut):
    """Test rescaling functionality with overflow detection"""
    
    # Start clock
    clock = Clock(dut.clk_i, CLOCK_PERIOD, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset the design
    await reset_dut(dut)
    
    # Configure FFT for 256 points (smaller to trigger overflow)
    await configure_fft(dut, fft_length_log2=8, fft_length=256)
    
    # Enable all rescaling features
    await enable_rescaling_full(dut)
    
    # Load data that will cause overflow
    overflow_data = generate_overflow_data(256)
    await load_input_data(dut, overflow_data)
    
    # Start FFT computation
    await start_fft(dut)
    
    # Wait for completion
    await wait_for_completion(dut)
    
    # Check rescaling statistics
    scale_factor = await read_scale_factor(dut)
    overflow_status = await read_overflow_status(dut)
    
    # Verify rescaling occurred
    assert scale_factor > 0, "Scale factor should be greater than 0 when overflow occurs"
    assert overflow_status['overflow_count'] > 0, "Overflow count should be greater than 0"

@cocotb.test()
async def test_fft_interrupts(dut):
    """Test interrupt generation and handling"""
    
    # Start clock
    clock = Clock(dut.clk_i, CLOCK_PERIOD, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset the design
    await reset_dut(dut)
    
    # Configure FFT
    await configure_fft(dut, fft_length_log2=8, fft_length=256)
    
    # Enable interrupts
    await enable_interrupts(dut)
    
    # Load test data
    test_data = generate_test_data(256)
    await load_input_data(dut, test_data)
    
    # Start FFT computation
    await start_fft(dut)
    
    # Wait for completion interrupt
    await wait_for_interrupt(dut, 'fft_done')
    
    # Verify interrupt status
    int_status = await read_interrupt_status(dut)
    assert int_status['fft_done'] == 1, "FFT completion interrupt should be set"

@cocotb.test()
async def test_fft_performance(dut):
    """Test FFT performance and timing"""
    
    # Start clock
    clock = Clock(dut.clk_i, CLOCK_PERIOD, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset the design
    await reset_dut(dut)
    
    # Configure FFT for 1024 points
    await configure_fft(dut, fft_length_log2=10, fft_length=1024)
    
    # Disable rescaling for performance measurement
    await disable_rescaling(dut)
    
    # Load test data
    test_data = generate_test_data(FFT_LENGTH)
    await load_input_data(dut, test_data)
    
    # Measure performance
    start_time = cocotb.utils.get_sim_time('ns')
    await start_fft(dut)
    await wait_for_completion(dut)
    end_time = cocotb.utils.get_sim_time('ns')
    
    # Calculate performance
    total_time = end_time - start_time
    expected_cycles = 10240 * 6  # 10,240 butterflies * 6 cycles
    expected_time = expected_cycles * CLOCK_PERIOD
    
    # Allow 10% tolerance
    assert total_time <= expected_time * 1.1, f"Performance test failed: {total_time}ns > {expected_time * 1.1}ns"

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
    # Configure FFT length
    await apb_write(dut, 0x0008, fft_length_log2)  # FFT_CONFIG
    await apb_write(dut, 0x000C, fft_length)      # FFT_LENGTH

async def enable_rescaling(dut):
    """Enable basic rescaling functionality"""
    await apb_write(dut, 0x0000, 0x30)  # FFT_CTRL: Enable rescaling and scale tracking
    await apb_write(dut, 0x0008, 0x8000A)  # FFT_CONFIG: Enable overflow detection

async def enable_rescaling_full(dut):
    """Enable all rescaling features"""
    await apb_write(dut, 0x0000, 0x30)  # FFT_CTRL: Enable rescaling and scale tracking
    await apb_write(dut, 0x0008, 0x80008)  # FFT_CONFIG: Enable overflow detection
    await apb_write(dut, 0x0020, 0x0F)  # RESCALE_CTRL: Enable all rescaling features

async def disable_rescaling(dut):
    """Disable rescaling for performance measurement"""
    await apb_write(dut, 0x0000, 0x01)  # FFT_CTRL: Start FFT only

async def enable_interrupts(dut):
    """Enable FFT interrupts"""
    await apb_write(dut, 0x0014, 0x01)  # INT_ENABLE: Enable FFT completion interrupt

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

async def wait_for_completion(dut):
    """Wait for FFT completion"""
    while True:
        status = await apb_read(dut, 0x0004)  # FFT_STATUS
        if status & 0x02:  # FFT_DONE bit
            break
        await RisingEdge(dut.clk_i)

async def wait_for_interrupt(dut, interrupt_name):
    """Wait for specific interrupt"""
    while True:
        if getattr(dut, interrupt_name).value == 1:
            break
        await RisingEdge(dut.clk_i)

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

async def read_interrupt_status(dut):
    """Read interrupt status register"""
    int_status = await apb_read(dut, 0x0018)  # INT_STATUS
    return {
        'fft_done': (int_status >> 0) & 0x01,
        'fft_error': (int_status >> 1) & 0x01,
        'buffer_swap': (int_status >> 2) & 0x01,
        'overflow': (int_status >> 3) & 0x01,
        'rescaling': (int_status >> 4) & 0x01
    }

async def verify_fft_results(dut, input_data, output_data, scale_factor):
    """Verify FFT computation results"""
    # Apply scale factor to output data
    scale_factor_val = 2 ** scale_factor
    scaled_output = [val * scale_factor_val for val in output_data]
    
    # Compare with expected results (simplified verification)
    # In a real test, you would compare with golden reference
    assert len(scaled_output) == len(input_data), "Output length mismatch"
    
    # Check that output is not all zeros
    output_magnitude = sum(abs(val) for val in scaled_output)
    assert output_magnitude > 0, "Output data is all zeros"

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

def generate_overflow_data(length):
    """Generate data that will cause overflow"""
    # Generate data with large magnitude to trigger overflow
    data = []
    for i in range(length):
        # Use large values to cause overflow
        real_part = 0.9 if i % 2 == 0 else -0.9
        imag_part = 0.9 if i % 3 == 0 else -0.9
        data.append(complex(real_part, imag_part))
    return data 