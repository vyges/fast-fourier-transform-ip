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
`define DATA_WIDTH              16     // Input/output data width
`define TWIDDLE_WIDTH          16     // Twiddle factor width
`define SCALE_FACTOR_WIDTH     8      // Scale factor width
`define STAGE_COUNT_WIDTH      8      // Stage count width

// Interface Parameters
`define APB_ADDR_WIDTH         16     // APB address width
`define AXI_ADDR_WIDTH         32     // AXI address width
`define AXI_DATA_WIDTH         64     // AXI data width

// Memory Parameters
`define MEM_ADDR_WIDTH         16     // Memory address width
`define MEM_DATA_WIDTH         32     // Memory data width

//=============================================================================
// Common Type Definitions
//=============================================================================

// Data types
typedef logic [`DATA_WIDTH-1:0]     data_t;
typedef logic [`TWIDDLE_WIDTH-1:0]  twiddle_t;
typedef logic [`SCALE_FACTOR_WIDTH-1:0] scale_factor_t;
typedef logic [`STAGE_COUNT_WIDTH-1:0]  stage_count_t;

// Address types
typedef logic [`MEM_ADDR_WIDTH-1:0] mem_addr_t;
typedef logic [`MEM_DATA_WIDTH-1:0] mem_data_t;

//=============================================================================
// Common Constants
//=============================================================================

// Mathematical constants
`define PI                      3.14159265359
`define TWO_PI                 6.28318530718

// Status constants
`define STATUS_IDLE            2'b00
`define STATUS_CONFIG          2'b01
`define STATUS_LOAD            2'b10
`define STATUS_COMPUTE         2'b11

// Error constants
`define ERROR_NONE             8'h00
`define ERROR_OVERFLOW         8'h01
`define ERROR_TIMEOUT          8'h02
`define ERROR_INVALID_CONFIG   8'h03

`endif // FFT_DEFINES_VH
