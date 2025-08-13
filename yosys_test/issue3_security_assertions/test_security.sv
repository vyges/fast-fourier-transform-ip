// Test case for security assertion limitations
// Uses proper Yosys defines: YOSYS and SYNTHESIS

module test_security (
    input wire clk_i,
    input wire reset_n_i,
    input wire [31:0] addr_i,
    input wire [31:0] data_i,
    input wire write_en_i,
    output reg [31:0] data_o
);

parameter MAX_ADDR = 32'h0000FFFF;

// Test different security approaches
`ifdef YOSYS
    // Yosys-compatible security (limited effectiveness)
    wire security_violation;
    assign security_violation = (addr_i >= MAX_ADDR);
    
    always @(posedge clk_i) begin
        if (write_en_i && !security_violation) begin
            data_o <= data_i;
        end else if (security_violation) begin
            // Security violation - but Yosys can't detect this properly
            data_o <= 32'hDEADBEEF;
        end
    end
`else
    // Full SystemVerilog security validation
    property addr_bounds;
        @(posedge clk_i) addr_i < MAX_ADDR;
    endproperty
    
    property write_security;
        @(posedge clk_i) write_en_i |-> addr_i < MAX_ADDR;
    endproperty
    
    // These assertions may fail with Yosys
    assert property (addr_bounds) else $error("Address out of bounds");
    assert property (write_security) else $error("Write to invalid address");
    
    always @(posedge clk_i) begin
        if (write_en_i) begin
            assert (addr_i < MAX_ADDR) else $error("Security violation: write to invalid address");
            data_o <= data_i;
        end
    end
`endif

endmodule
