//=============================================================================
// FFT IP Common Definitions Header
//=============================================================================
// Description: Common parameter definitions and constants for FFT IP modules
// Author:      Vyges IP Development Team
// License:     Apache-2.0
//
// The value macros below are wrapped in `ifndef guards so a consumer (e.g. an
// SoC integration) may override any of them from the command line
// (+define+FFT_DATA_WIDTH=...) without triggering a redefinition warning. The
// values here are the defaults when no override is supplied.
//=============================================================================

`ifndef FFT_DEFINES_VH
`define FFT_DEFINES_VH

//=============================================================================
// FFT Configuration Parameters
//=============================================================================

// FFT Length Parameters
`ifndef FFT_MAX_LENGTH_LOG2
`define FFT_MAX_LENGTH_LOG2     12    // Maximum FFT length (log2)
`endif
`ifndef FFT_MIN_LENGTH_LOG2
`define FFT_MIN_LENGTH_LOG2     8     // Minimum FFT length (log2)
`endif
`ifndef FFT_MAX_LENGTH
`define FFT_MAX_LENGTH          4096  // Maximum FFT length (2^12)
`endif
`ifndef FFT_MIN_LENGTH
`define FFT_MIN_LENGTH          256   // Minimum FFT length (2^8)
`endif

// Data Width Parameters
`ifndef FFT_DATA_WIDTH
`define FFT_DATA_WIDTH             16     // Input/output data width
`endif
`ifndef FFT_TWIDDLE_WIDTH
`define FFT_TWIDDLE_WIDTH          16     // Twiddle factor width
`endif
`ifndef FFT_SCALE_FACTOR_WIDTH
`define FFT_SCALE_FACTOR_WIDTH     8      // Scale factor width
`endif
`ifndef FFT_STAGE_COUNT_WIDTH
`define FFT_STAGE_COUNT_WIDTH      8      // Stage count width
`endif

// Interface Parameters
`ifndef FFT_APB_ADDR_WIDTH
`define FFT_APB_ADDR_WIDTH         16     // APB address width
`endif
`ifndef FFT_AXI_ADDR_WIDTH
`define FFT_AXI_ADDR_WIDTH         32     // AXI address width
`endif
`ifndef FFT_AXI_DATA_WIDTH
`define FFT_AXI_DATA_WIDTH         64     // AXI data width
`endif

// Memory Parameters
`ifndef FFT_MEM_ADDR_WIDTH
`define FFT_MEM_ADDR_WIDTH         16     // Memory address width
`endif
`ifndef FFT_MEM_DATA_WIDTH
`define FFT_MEM_DATA_WIDTH         32     // Memory data width
`endif

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
`ifndef FFT_PI
`define FFT_PI                     3.14159265359
`endif
`ifndef FFT_TWO_PI
`define FFT_TWO_PI                 6.28318530718
`endif

// Status constants
`ifndef FFT_STATUS_IDLE
`define FFT_STATUS_IDLE            2'b00
`endif
`ifndef FFT_STATUS_CONFIG
`define FFT_STATUS_CONFIG          2'b01
`endif
`ifndef FFT_STATUS_LOAD
`define FFT_STATUS_LOAD            2'b10
`endif
`ifndef FFT_STATUS_COMPUTE
`define FFT_STATUS_COMPUTE         2'b11
`endif

// Error constants
`ifndef FFT_ERROR_NONE
`define FFT_ERROR_NONE             8'h00
`endif
`ifndef FFT_ERROR_OVERFLOW
`define FFT_ERROR_OVERFLOW         8'h01
`endif
`ifndef FFT_ERROR_TIMEOUT
`define FFT_ERROR_TIMEOUT          8'h02
`endif
`ifndef FFT_ERROR_INVALID_CONFIG
`define FFT_ERROR_INVALID_CONFIG   8'h03
`endif

`endif // FFT_DEFINES_VH
