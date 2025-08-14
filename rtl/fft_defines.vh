//=============================================================================
// FFT IP Common Definitions Header
//=============================================================================
// Description: Common parameter definitions and constants for FFT IP modules
// Author:      Vyges IP Development Team
// Date:        2025-08-12
// License:     Apache-2.0
//=============================================================================

`ifndef FFT_DEFINES_VH
`define FFT_DEFINES_VH

//=============================================================================
// FFT Configuration Parameters
//=============================================================================

// FFT Length Parameters
`define FFT_MAX_LENGTH_LOG2     12    // Maximum FFT length (log2)
`define FFT_MIN_LENGTH_LOG2     8     // Minimum FFT length (log2)
`define FFT_MAX_LENGTH          4096  // Maximum FFT length (2^12)
`define FFT_MIN_LENGTH          256   // Minimum FFT length (2^8)

// Data Width Parameters
`define FFT_DATA_WIDTH              16     // Input/output data width
`define FFT_TWIDDLE_WIDTH          16     // Twiddle factor width
`define FFT_SCALE_FACTOR_WIDTH     8      // Scale factor width
`define FFT_STAGE_COUNT_WIDTH      8      // Stage count width

// Interface Parameters
`define FFT_APB_ADDR_WIDTH         16     // APB address width
`define FFT_AXI_ADDR_WIDTH         32     // AXI address width
`define FFT_AXI_DATA_WIDTH         64     // AXI data width

// Memory Parameters
`define FFT_MEM_ADDR_WIDTH         16     // Memory address width
`define FFT_MEM_DATA_WIDTH         32     // Memory data width

//=============================================================================
// Common Type Definitions
//=============================================================================

// Data types
typedef logic [`FFT_DATA_WIDTH-1:0]     fft_data_t;
typedef logic [`FFT_TWIDDLE_WIDTH-1:0]  fft_twiddle_t;
typedef logic [`FFT_SCALE_FACTOR_WIDTH-1:0] fft_scale_factor_t;
typedef logic [`FFT_STAGE_COUNT_WIDTH-1:0]  fft_stage_count_t;

// Address types
typedef logic [`FFT_MEM_ADDR_WIDTH-1:0] fft_mem_addr_t;
typedef logic [`FFT_MEM_DATA_WIDTH-1:0] fft_mem_data_t;

//=============================================================================
// Common Constants
//=============================================================================

// Mathematical constants
`define FFT_PI                      3.14159265359
`define FFT_TWO_PI                 6.28318530718

// Status constants
`define FFT_STATUS_IDLE            2'b00
`define FFT_STATUS_CONFIG          2'b01
`define FFT_STATUS_LOAD            2'b10
`define FFT_STATUS_COMPUTE         2'b11

// Error constants
`define FFT_ERROR_NONE             8'h00
`define FFT_ERROR_OVERFLOW         8'h01
`define FFT_ERROR_TIMEOUT          8'h02
`define FFT_ERROR_INVALID_CONFIG   8'h03

`endif // FFT_DEFINES_VH
