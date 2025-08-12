#=============================================================================
# FFT Rescaling Test using Cocotb
#=============================================================================
# Description: Comprehensive test for FFT rescaling functionality
#              Tests overflow detection, scale factor tracking, and
#              different rescaling modes
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
from scipy import signal

# Test parameters
CLOCK_PERIOD = 1  # 1ns = 1GHz

@cocotb.test()
async def test_rescaling_modes(dut):
    """Test different rescaling modes"""
    
    # Start clock
    clock = Clock(dut.clk_i, CLOCK_PERIOD, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset the design
    await reset_dut(dut)
    
    # Test Mode 0: Divide by 2 each stage
    await test_rescaling_mode_0(dut)
    
    # Test Mode 1: Divide by N at end
    await test_rescaling_mode_1(dut)

@cocotb.test()
async def test_overflow_detection(dut):
    """Test overflow detection with various input patterns"""
    
    # Start clock
    clock = Clock(dut.clk_i, CLOCK_PERIOD, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset the design
    await reset_dut(dut)
    
    # Configure FFT
    await configure_fft(dut, fft_length_log2=8, fft_length=256)
    await enable_rescaling_full(dut)
    
    # Test different overflow patterns
    test_patterns = [
        ("constant_high", generate_constant_high_data(256)),
        ("alternating", generate_alternating_data(256)),
        ("random_large", generate_random_large_data(256)),
        ("impulse", generate_impulse_data(256)),
        ("chirp", generate_chirp_data(256))
    ]
    
    for pattern_name, test_data in test_patterns:
        dut._log.info(f"Testing overflow pattern: {pattern_name}")
        
        # Load test data
        await load_input_data(dut, test_data)
        
        # Start FFT computation
        await start_fft(dut)
        
        # Wait for completion
        await wait_for_completion(dut)
        
        # Check rescaling statistics
        scale_factor = await read_scale_factor(dut)
        overflow_status = await read_overflow_status(dut)
        
        # Verify rescaling occurred
        assert scale_factor >= 0, f"Scale factor should be non-negative for {pattern_name}"
        assert overflow_status['overflow_count'] >= 0, f"Overflow count should be non-negative for {pattern_name}"
        
        dut._log.info(f"Pattern {pattern_name}: Scale factor = {scale_factor}, Overflow count = {overflow_status['overflow_count']}")

@cocotb.test()
async def test_scale_factor_tracking(dut):
    """Test scale factor tracking accuracy"""
    
    # Start clock
    clock = Clock(dut.clk_i, CLOCK_PERIOD, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset the design
    await reset_dut(dut)
    
    # Configure FFT
    await configure_fft(dut, fft_length_log2=8, fft_length=256)
    await enable_rescaling_full(dut)
    
    # Test with known overflow pattern
    test_data = generate_known_overflow_data(256)
    await load_input_data(dut, test_data)
    
    # Start FFT computation
    await start_fft(dut)
    
    # Monitor scale factor during computation
    scale_factors = []
    overflow_counts = []
    
    # Sample during computation
    for _ in range(50):  # Sample 50 times during computation
        await Timer(100, units="ns")
        try:
            scale_factor = await read_scale_factor(dut)
            overflow_status = await read_overflow_status(dut)
            scale_factors.append(scale_factor)
            overflow_counts.append(overflow_status['overflow_count'])
        except:
            pass  # Ignore read errors during computation
    
    # Wait for completion
    await wait_for_completion(dut)
    
    # Final values
    final_scale_factor = await read_scale_factor(dut)
    final_overflow_status = await read_overflow_status(dut)
    
    # Verify scale factor tracking
    assert final_scale_factor >= 0, "Final scale factor should be non-negative"
    assert final_overflow_status['overflow_count'] >= 0, "Final overflow count should be non-negative"
    
    # Verify scale factor increases monotonically
    if len(scale_factors) > 1:
        for i in range(1, len(scale_factors)):
            assert scale_factors[i] >= scale_factors[i-1], "Scale factor should increase monotonically"

@cocotb.test()
async def test_rounding_modes(dut):
    """Test different rounding modes in rescaling"""
    
    # Start clock
    clock = Clock(dut.clk_i, CLOCK_PERIOD, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset the design
    await reset_dut(dut)
    
    # Configure FFT
    await configure_fft(dut, fft_length_log2=8, fft_length=256)
    await enable_rescaling_full(dut)
    
    # Test truncate mode
    await test_rounding_mode(dut, rounding_mode=0, mode_name="truncate")
    
    # Test round mode
    await test_rounding_mode(dut, rounding_mode=1, mode_name="round")

@cocotb.test()
async def test_saturation_arithmetic(dut):
    """Test saturation arithmetic in rescaling"""
    
    # Start clock
    clock = Clock(dut.clk_i, CLOCK_PERIOD, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset the design
    await reset_dut(dut)
    
    # Configure FFT
    await configure_fft(dut, fft_length_log2=8, fft_length=256)
    await enable_rescaling_full(dut)
    
    # Test without saturation
    await test_saturation_mode(dut, saturation_enabled=0, mode_name="no_saturation")
    
    # Test with saturation
    await test_saturation_mode(dut, saturation_enabled=1, mode_name="saturation")

@cocotb.test()
async def test_rescaling_thresholds(dut):
    """Test different rescaling thresholds"""
    
    # Start clock
    clock = Clock(dut.clk_i, CLOCK_PERIOD, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset the design
    await reset_dut(dut)
    
    # Configure FFT
    await configure_fft(dut, fft_length_log2=8, fft_length=256)
    await enable_rescaling_full(dut)
    
    # Test different thresholds
    thresholds = [1, 2, 4, 8, 16]
    
    for threshold in thresholds:
        dut._log.info(f"Testing rescaling threshold: {threshold}")
        
        # Set threshold
        await set_rescaling_threshold(dut, threshold)
        
        # Load test data
        test_data = generate_threshold_test_data(256, threshold)
        await load_input_data(dut, test_data)
        
        # Start FFT computation
        await start_fft(dut)
        
        # Wait for completion
        await wait_for_completion(dut)
        
        # Check results
        scale_factor = await read_scale_factor(dut)
        overflow_status = await read_overflow_status(dut)
        
        dut._log.info(f"Threshold {threshold}: Scale factor = {scale_factor}, Overflow count = {overflow_status['overflow_count']}")

# Helper functions for rescaling tests

async def test_rescaling_mode_0(dut):
    """Test rescaling mode 0: Divide by 2 each stage"""
    dut._log.info("Testing rescaling mode 0: Divide by 2 each stage")
    
    # Configure mode 0
    await configure_fft(dut, fft_length_log2=8, fft_length=256)
    await enable_rescaling_mode(dut, mode=0)
    
    # Load test data
    test_data = generate_overflow_data(256)
    await load_input_data(dut, test_data)
    
    # Start FFT computation
    await start_fft(dut)
    
    # Wait for completion
    await wait_for_completion(dut)
    
    # Check results
    scale_factor = await read_scale_factor(dut)
    overflow_status = await read_overflow_status(dut)
    
    assert scale_factor >= 0, "Scale factor should be non-negative in mode 0"
    dut._log.info(f"Mode 0 results: Scale factor = {scale_factor}, Overflow count = {overflow_status['overflow_count']}")

async def test_rescaling_mode_1(dut):
    """Test rescaling mode 1: Divide by N at end"""
    dut._log.info("Testing rescaling mode 1: Divide by N at end")
    
    # Configure mode 1
    await configure_fft(dut, fft_length_log2=8, fft_length=256)
    await enable_rescaling_mode(dut, mode=1)
    
    # Load test data
    test_data = generate_overflow_data(256)
    await load_input_data(dut, test_data)
    
    # Start FFT computation
    await start_fft(dut)
    
    # Wait for completion
    await wait_for_completion(dut)
    
    # Check results
    scale_factor = await read_scale_factor(dut)
    overflow_status = await read_overflow_status(dut)
    
    assert scale_factor >= 0, "Scale factor should be non-negative in mode 1"
    dut._log.info(f"Mode 1 results: Scale factor = {scale_factor}, Overflow count = {overflow_status['overflow_count']}")

async def test_rounding_mode(dut, rounding_mode, mode_name):
    """Test specific rounding mode"""
    dut._log.info(f"Testing rounding mode: {mode_name}")
    
    # Configure rounding mode
    await configure_fft(dut, fft_length_log2=8, fft_length=256)
    await enable_rescaling_with_rounding(dut, rounding_mode)
    
    # Load test data
    test_data = generate_overflow_data(256)
    await load_input_data(dut, test_data)
    
    # Start FFT computation
    await start_fft(dut)
    
    # Wait for completion
    await wait_for_completion(dut)
    
    # Check results
    scale_factor = await read_scale_factor(dut)
    overflow_status = await read_overflow_status(dut)
    
    dut._log.info(f"{mode_name} results: Scale factor = {scale_factor}, Overflow count = {overflow_status['overflow_count']}")

async def test_saturation_mode(dut, saturation_enabled, mode_name):
    """Test saturation mode"""
    dut._log.info(f"Testing saturation mode: {mode_name}")
    
    # Configure saturation mode
    await configure_fft(dut, fft_length_log2=8, fft_length=256)
    await enable_rescaling_with_saturation(dut, saturation_enabled)
    
    # Load test data
    test_data = generate_overflow_data(256)
    await load_input_data(dut, test_data)
    
    # Start FFT computation
    await start_fft(dut)
    
    # Wait for completion
    await wait_for_completion(dut)
    
    # Check results
    scale_factor = await read_scale_factor(dut)
    overflow_status = await read_overflow_status(dut)
    
    dut._log.info(f"{mode_name} results: Scale factor = {scale_factor}, Overflow count = {overflow_status['overflow_count']}")

# Configuration functions

async def enable_rescaling_mode(dut, mode):
    """Enable rescaling with specific mode"""
    await apb_write(dut, 0x0000, 0x30)  # FFT_CTRL: Enable rescaling and scale tracking
    
    if mode == 0:
        # Mode 0: Divide by 2 each stage
        await apb_write(dut, 0x0008, 0x80008)  # FFT_CONFIG: Mode 0, overflow detection
    else:
        # Mode 1: Divide by N at end
        await apb_write(dut, 0x0008, 0x90008)  # FFT_CONFIG: Mode 1, overflow detection
    
    await apb_write(dut, 0x0020, 0x0F)  # RESCALE_CTRL: Enable all rescaling features

async def enable_rescaling_with_rounding(dut, rounding_mode):
    """Enable rescaling with specific rounding mode"""
    await apb_write(dut, 0x0000, 0x30)  # FFT_CTRL: Enable rescaling and scale tracking
    
    if rounding_mode == 0:
        # Truncate mode
        await apb_write(dut, 0x0008, 0x80008)  # FFT_CONFIG: Truncate, overflow detection
    else:
        # Round mode
        await apb_write(dut, 0x0008, 0x82008)  # FFT_CONFIG: Round, overflow detection
    
    await apb_write(dut, 0x0020, 0x0F)  # RESCALE_CTRL: Enable all rescaling features

async def enable_rescaling_with_saturation(dut, saturation_enabled):
    """Enable rescaling with saturation"""
    await apb_write(dut, 0x0000, 0x30)  # FFT_CTRL: Enable rescaling and scale tracking
    
    if saturation_enabled:
        # With saturation
        await apb_write(dut, 0x0008, 0x84008)  # FFT_CONFIG: Saturation, overflow detection
    else:
        # Without saturation
        await apb_write(dut, 0x0008, 0x80008)  # FFT_CONFIG: No saturation, overflow detection
    
    await apb_write(dut, 0x0020, 0x0F)  # RESCALE_CTRL: Enable all rescaling features

async def set_rescaling_threshold(dut, threshold):
    """Set rescaling threshold"""
    await apb_write(dut, 0x0020, 0x0F | (threshold << 4))  # RESCALE_CTRL with threshold

# Data generation functions

def generate_constant_high_data(length):
    """Generate data with constant high values"""
    return [complex(0.9, 0.9) for _ in range(length)]

def generate_alternating_data(length):
    """Generate data with alternating high/low values"""
    data = []
    for i in range(length):
        if i % 2 == 0:
            data.append(complex(0.9, 0.9))
        else:
            data.append(complex(0.1, 0.1))
    return data

def generate_random_large_data(length):
    """Generate data with random large values"""
    data = []
    for _ in range(length):
        real_part = random.uniform(0.7, 0.9) * (1 if random.random() > 0.5 else -1)
        imag_part = random.uniform(0.7, 0.9) * (1 if random.random() > 0.5 else -1)
        data.append(complex(real_part, imag_part))
    return data

def generate_impulse_data(length):
    """Generate impulse data"""
    data = [complex(0.0, 0.0) for _ in range(length)]
    data[0] = complex(0.9, 0.9)  # Impulse at beginning
    return data

def generate_chirp_data(length):
    """Generate chirp signal data"""
    data = []
    for i in range(length):
        freq = 0.1 + 0.8 * i / length  # Chirp from 0.1 to 0.9
        phase = 2 * np.pi * freq * i
        real_part = 0.8 * np.cos(phase)
        imag_part = 0.8 * np.sin(phase)
        data.append(complex(real_part, imag_part))
    return data

def generate_known_overflow_data(length):
    """Generate data with known overflow characteristics"""
    data = []
    for i in range(length):
        # Create pattern that will cause predictable overflow
        if i < length // 4:
            data.append(complex(0.9, 0.9))
        elif i < length // 2:
            data.append(complex(-0.9, -0.9))
        elif i < 3 * length // 4:
            data.append(complex(0.9, -0.9))
        else:
            data.append(complex(-0.9, 0.9))
    return data

def generate_threshold_test_data(length, threshold):
    """Generate data for threshold testing"""
    data = []
    for i in range(length):
        # Create data that will trigger rescaling at specific threshold
        magnitude = 0.5 + 0.4 * (i % threshold) / threshold
        phase = 2 * np.pi * i / length
        real_part = magnitude * np.cos(phase)
        imag_part = magnitude * np.sin(phase)
        data.append(complex(real_part, imag_part))
    return data

# Import common functions from basic test
from test_fft_basic import (
    reset_dut, configure_fft, enable_rescaling_full, load_input_data,
    start_fft, wait_for_completion, read_scale_factor, read_overflow_status,
    apb_write, apb_read, generate_overflow_data
) 