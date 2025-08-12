`ifndef FFT_MEMORY_INTERFACE_SV
`define FFT_MEMORY_INTERFACE_SV

`include "fft_timescale.vh"
`include "fft_defines.vh"

//=============================================================================
// Memory Interface Module
//=============================================================================
// Description: Memory interface module providing APB and AXI bus interfaces
//              for the FFT accelerator. Handles register access and data
//              transfer between host processor and FFT engine.
// Author:      Vyges IP Development Team
// Date:        2025-07-21
// License:     Apache-2.0
//=============================================================================

module memory_interface #(
    parameter int APB_ADDR_WIDTH = 16,         // APB address width
    parameter int AXI_ADDR_WIDTH = 32,         // AXI address width
    parameter int AXI_DATA_WIDTH = 64          // AXI data width
) (
    // Clock and Reset
    input  logic        clk_i,
    input  logic        reset_n_i,
    
    // APB Interface
    input  logic        pclk_i,
    input  logic        preset_n_i,
    input  logic        psel_i,
    input  logic        penable_i,
    input  logic        pwrite_i,
    input  logic [APB_ADDR_WIDTH-1:0] paddr_i,
    input  logic [31:0] pwdata_i,
    output logic [31:0] prdata_o,
    output logic        pready_o,
    
    // AXI Interface
    input  logic        axi_aclk_i,
    input  logic        axi_areset_n_i,
    input  logic [AXI_ADDR_WIDTH-1:0] axi_awaddr_i,
    input  logic        axi_awvalid_i,
    output logic        axi_awready_o,
    input  logic [AXI_DATA_WIDTH-1:0] axi_wdata_i,
    input  logic        axi_wvalid_i,
    output logic        axi_wready_o,
    input  logic [AXI_ADDR_WIDTH-1:0] axi_araddr_i,
    input  logic        axi_arvalid_i,
    output logic        axi_arready_o,
    output logic [AXI_DATA_WIDTH-1:0] axi_rdata_o,
    output logic        axi_rvalid_o,
    input  logic        axi_rready_i,
    
    // FFT Engine Interface
    input  logic [15:0] mem_addr_i,
    input  logic [31:0] mem_data_i,
    input  logic        mem_write_i,
    output logic [31:0] mem_data_o,
    output logic        mem_ready_o,
    
    // Control Interface
    output logic        fft_start_o,
    output logic        fft_reset_o,
    output logic [11:0] fft_length_log2_o,
    output logic        rescale_en_o,
    output logic        scale_track_en_o,
    output logic        rescale_mode_o,
    output logic        rounding_mode_o,
    output logic        saturation_en_o,
    output logic        overflow_detect_o,
    output logic        buffer_swap_o,
    output logic [1:0]  buffer_sel_o,
    output logic [7:0]  int_enable_o,
    
    // Status Interface
    input  logic        fft_busy_i,
    input  logic        fft_done_i,
    input  logic        fft_error_i,
    input  logic        buffer_active_i,
    input  logic        rescaling_active_i,
    input  logic        overflow_detected_i,
    input  logic [7:0]  scale_factor_i,
    input  logic [7:0]  stage_count_i,
    input  logic [7:0]  overflow_count_i,
    input  logic [7:0]  last_overflow_stage_i,
    input  logic [7:0]  max_overflow_magnitude_i,
    input  logic [7:0]  int_status_i
);

    // Internal registers
    logic [31:0] fft_ctrl_reg;
    logic [31:0] fft_status_reg;
    logic [31:0] fft_config_reg;
    logic [31:0] fft_length_reg;
    logic [31:0] buffer_sel_reg;
    logic [31:0] int_enable_reg;
    logic [31:0] int_status_reg;
    logic [31:0] scale_factor_reg;
    logic [31:0] rescale_ctrl_reg;
    logic [31:0] overflow_status_reg;
    
    // APB state machine
    typedef enum logic [1:0] {
        APB_IDLE,
        APB_SETUP,
        APB_ACCESS
    } apb_state_t;
    
    apb_state_t apb_state, apb_next_state;
    
    // APB state machine
    always_ff @(posedge pclk_i or negedge preset_n_i) begin
        if (!preset_n_i) begin
            apb_state <= APB_IDLE;
        end else begin
            apb_state <= apb_next_state;
        end
    end
    
    // APB next state logic
    always_comb begin
        apb_next_state = apb_state;
        
        case (apb_state)
            APB_IDLE: begin
                if (psel_i && !penable_i) begin
                    apb_next_state = APB_SETUP;
                end
            end
            
            APB_SETUP: begin
                if (psel_i && penable_i) begin
                    apb_next_state = APB_ACCESS;
                end else if (!psel_i) begin
                    apb_next_state = APB_IDLE;
                end
            end
            
            APB_ACCESS: begin
                apb_next_state = APB_IDLE;
            end
            
            default: begin
                apb_next_state = APB_IDLE;
            end
        endcase
    end
    
    // APB control signals
    assign pready_o = (apb_state == APB_ACCESS);
    
    // APB register access
    always_ff @(posedge pclk_i or negedge preset_n_i) begin
        if (!preset_n_i) begin
            fft_ctrl_reg <= 32'h00000000;
            fft_config_reg <= 32'h00000000;
            fft_length_reg <= 32'h00000400;  // Default 1024 points
            buffer_sel_reg <= 32'h00000000;
            int_enable_reg <= 32'h00000000;
            rescale_ctrl_reg <= 32'h00000000;
        end else if (apb_state == APB_ACCESS && pwrite_i) begin
            case (paddr_i[15:0])
                16'h0000: fft_ctrl_reg <= pwdata_i;
                16'h0008: fft_config_reg <= pwdata_i;
                16'h000C: fft_length_reg <= pwdata_i;
                16'h0010: buffer_sel_reg <= pwdata_i;
                16'h0014: int_enable_reg <= pwdata_i;
                16'h0020: rescale_ctrl_reg <= pwdata_i;
                default: ; // Ignore writes to read-only registers
            endcase
        end
    end
    
    // APB read data
    always_comb begin
        case (paddr_i[15:0])
            16'h0000: prdata_o = fft_ctrl_reg;
            16'h0004: prdata_o = fft_status_reg;
            16'h0008: prdata_o = fft_config_reg;
            16'h000C: prdata_o = fft_length_reg;
            16'h0010: prdata_o = buffer_sel_reg;
            16'h0014: prdata_o = int_enable_reg;
            16'h0018: prdata_o = int_status_reg;
            16'h001C: prdata_o = scale_factor_reg;
            16'h0020: prdata_o = rescale_ctrl_reg;
            16'h0024: prdata_o = overflow_status_reg;
            default: prdata_o = 32'h00000000;
        endcase
    end
    
    // Status register updates
    always_comb begin
        logic [7:0] overflow_count_val;
        logic [7:0] stage_count_val;
        logic [7:0] scale_factor_val;
        logic [7:0] int_status_val;
        
        overflow_count_val = overflow_count_i;
        stage_count_val = stage_count_i;
        scale_factor_val = scale_factor_i;
        int_status_val = int_status_i;
        
        fft_status_reg = {
            2'h0,                           // Reserved (reduced from 8 to 2 bits)
            overflow_count_val,             // Overflow count (8 bits)
            stage_count_val,                // Stage count (8 bits)
            scale_factor_val,               // Scale factor (8 bits)
            overflow_detected_i,            // Overflow detected (1 bit)
            rescaling_active_i,             // Rescaling active (1 bit)
            buffer_active_i,                // Buffer active (1 bit)
            fft_error_i,                    // FFT error (1 bit)
            fft_done_i,                     // FFT done (1 bit)
            fft_busy_i                      // FFT busy (1 bit)
        };
        
        int_status_reg = {
            24'h000000,                     // Reserved (reduced from 25 to 24 bits)
            int_status_val                  // Interrupt status (8 bits)
        };
        
        scale_factor_reg = {
            overflow_count_val,             // Overflow count
            8'h00,                          // Reserved
            stage_count_val,                // Stage count
            scale_factor_val                // Scale factor
        };
        
        overflow_status_reg = {
            8'h00,                          // Reserved
            max_overflow_magnitude_i,       // Max overflow magnitude
            last_overflow_stage_i,          // Last overflow stage
            overflow_count_val              // Overflow count
        };
    end
    
    // Control signal assignments
    assign fft_start_o = fft_ctrl_reg[0];
    assign fft_reset_o = fft_ctrl_reg[1];
    assign buffer_swap_o = fft_ctrl_reg[2];
    assign rescale_en_o = fft_ctrl_reg[4];
    assign scale_track_en_o = fft_ctrl_reg[5];
    
    assign fft_length_log2_o = fft_config_reg[11:0];
    assign rescale_mode_o = fft_config_reg[16];
    assign rounding_mode_o = fft_config_reg[17];
    assign saturation_en_o = fft_config_reg[18];
    assign overflow_detect_o = fft_config_reg[19];
    
    assign buffer_sel_o = buffer_sel_reg[1:0];
    assign int_enable_o = int_enable_reg[7:0];
    
    // AXI interface (simplified for this example)
    assign axi_awready_o = 1'b1;
    assign axi_wready_o = 1'b1;
    assign axi_arready_o = 1'b1;
    assign axi_rdata_o = 64'h0000000000000000;
    assign axi_rvalid_o = 1'b0;

    // Memory interface logic
    // Optimized memory model for FFT data storage with synthesis attributes
    
    // FFT Memory: 1024 complex words × 2 buffers × 32 bits = 64K bits
    // Using synthesis attributes to force memory macro generation
    (* ram_style = "block" *)  // Force BRAM/block RAM synthesis
    (* ram_init_file = "" *)    // No initialization file needed
    logic [31:0] fft_memory [0:2047];  // 2048 x 32-bit = 64K bits (correct size)
    
    // Memory read operation (registered for better timing)
    always_ff @(posedge clk_i) begin
        if (!reset_n_i) begin
            mem_data_o <= 32'h00000000;
        end else begin
            mem_data_o <= fft_memory[mem_addr_i[10:0]];  // 11-bit address for 2048 locations
        end
    end
    
    // Memory write operation
    always_ff @(posedge clk_i) begin
        if (mem_write_i) begin
            fft_memory[mem_addr_i[10:0]] <= mem_data_i;
        end
    end
    
    // Memory ready signal (pipelined for better performance)
    logic mem_ready_reg;
    always_ff @(posedge clk_i or negedge reset_n_i) begin
        if (!reset_n_i) begin
            mem_ready_reg <= 1'b0;
        end else begin
            mem_ready_reg <= 1'b1;  // Always ready after reset
        end
    end
    assign mem_ready_o = mem_ready_reg;

    //=============================================================================
    // Security Assertions - Dual Mode (Yosys + Full SystemVerilog)
    //=============================================================================
    
    // Address bounds checking - prevent illegal memory access
    // Yosys-compatible security checks (synthesis-safe)
    `ifdef YOSYS_SYNTHESIS
    // Note: Yosys doesn't support $error or SystemVerilog assertions
    // These are implemented as synthesis-safe logic that can be optimized out
    logic security_violation_write;
    logic security_violation_read;
    logic security_violation_fsm;
    logic security_violation_access;
    
    // Address bounds checking - synthesis-safe implementation
    assign security_violation_write = mem_write_i && (mem_addr_i >= 2048);
    assign security_violation_read = mem_ready_o && (mem_addr_i >= 2048);
    
    // FSM state validity - synthesis-safe implementation
    assign security_violation_fsm = !(apb_state == APB_IDLE || apb_state == APB_SETUP || apb_state == APB_ACCESS);
    
    // Memory access validation - synthesis-safe implementation
    assign security_violation_access = mem_write_i && mem_ready_o;
    
    // These signals can be used for formal verification or external monitoring
    // In synthesis, they will be optimized out if not used
    `endif
    
    // Full SystemVerilog security assertions (for simulation and formal verification)
    `ifdef SECURITY_ASSERTIONS
    property address_bounds_check;
        @(posedge clk_i) disable iff (!reset_n_i)
        (mem_write_i) |-> (mem_addr_i < 2048); // 2048 is the max address
    endproperty
    
    property address_bounds_check_read;
        @(posedge clk_i) disable iff (!reset_n_i)
        (mem_ready_o) |-> (mem_addr_i < 2048); // 2048 is the max address
    endproperty
    
    // FSM state validity - ensure stable state transitions
    property fsm_state_validity;
        @(posedge pclk_i) disable iff (!preset_n_i)
        (apb_state == APB_IDLE || apb_state == APB_SETUP || apb_state == APB_ACCESS);
    endproperty
    
    // Reset synchronization - ensure proper reset behavior
    property reset_synchronization;
        @(posedge pclk_i)
        !preset_n_i |-> (apb_state == APB_IDLE);
    endproperty
    
    // Memory access validation - prevent simultaneous read/write
    property memory_access_validation;
        @(posedge clk_i) disable iff (!reset_n_i)
        !(mem_write_i && mem_ready_o);
    endproperty
    
    // Assert the security properties
    assert property (address_bounds_check) else
        $error("Security violation: Illegal write address access detected");
    
    assert property (address_bounds_check_read) else
        $error("Security violation: Illegal read address access detected");
    
    assert property (fsm_state_validity) else
        $error("Security violation: Invalid FSM state detected");
    
    assert property (reset_synchronization) else
        $error("Security violation: Improper reset behavior detected");
    
    assert property (memory_access_validation) else
        $error("Security violation: Simultaneous read/write access detected");
    `endif
    
    //=============================================================================
    // End Security Assertions
    //=============================================================================

endmodule

`endif // FFT_MEMORY_INTERFACE_SV 