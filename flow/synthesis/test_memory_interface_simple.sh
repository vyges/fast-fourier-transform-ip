#!/bin/bash
echo "Testing memory_interface synthesis with reduced memory..."
# Create a temporary file with reduced memory size
cat > temp_memory_interface.sv << 'EOF'
`timescale 1ns/1ps

module memory_interface #(
    parameter int APB_ADDR_WIDTH = 16,
    parameter int AXI_ADDR_WIDTH = 32,
    parameter int AXI_DATA_WIDTH = 64
) (
    input  logic        clk_i,
    input  logic        reset_n_i,
    input  logic        pclk_i,
    input  logic        preset_n_i,
    input  logic        psel_i,
    input  logic        penable_i,
    input  logic        pwrite_i,
    input  logic [APB_ADDR_WIDTH-1:0] paddr_i,
    input  logic [31:0] pwdata_i,
    output logic [31:0] prdata_o,
    output logic        pready_o,
    input  logic [15:0] mem_addr_i,
    input  logic [31:0] mem_data_i,
    input  logic        mem_write_i,
    output logic [31:0] mem_data_o,
    output logic        mem_ready_o,
    output logic        fft_start_o,
    output logic        fft_reset_o,
    input  logic        fft_busy_i,
    input  logic        fft_done_i
);

    // Simplified internal registers
    logic [31:0] fft_ctrl_reg;
    logic [31:0] fft_status_reg;
    
    // Simplified APB state machine
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
        end else if (apb_state == APB_ACCESS && pwrite_i) begin
            case (paddr_i[15:0])
                16'h0000: fft_ctrl_reg <= pwdata_i;
                default: ; // Ignore writes to read-only registers
            endcase
        end
    end
    
    // APB read data
    always_comb begin
        case (paddr_i[15:0])
            16'h0000: prdata_o = fft_ctrl_reg;
            16'h0004: prdata_o = fft_status_reg;
            default: prdata_o = 32'h00000000;
        endcase
    end
    
    // Status register updates
    always_comb begin
        fft_status_reg = {
            30'h00000000,                   // Reserved
            fft_done_i,                     // FFT done (1 bit)
            fft_busy_i                      // FFT busy (1 bit)
        };
    end
    
    // Control signal assignments
    assign fft_start_o = fft_ctrl_reg[0];
    assign fft_reset_o = fft_ctrl_reg[1];
    
    // Simplified memory interface (smaller memory)
    logic [31:0] fft_memory [0:1023];  // Reduced to 1K x 32-bit memory
    
    // Memory read operation
    always_comb begin
        mem_data_o = fft_memory[mem_addr_i[9:0]];  // Use only lower 10 bits
    end
    
    // Memory write operation
    always_ff @(posedge clk_i) begin
        if (mem_write_i) begin
            fft_memory[mem_addr_i[9:0]] <= mem_data_i;  // Use only lower 10 bits
        end
    end
    
    // Memory ready signal
    assign mem_ready_o = 1'b1;

endmodule
EOF

yosys -p "read_verilog -sv temp_memory_interface.sv; hierarchy -top memory_interface; synth -top memory_interface; stat"
rm temp_memory_interface.sv
echo "memory_interface synthesis completed" 