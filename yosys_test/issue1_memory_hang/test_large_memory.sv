// Minimal test case for Yosys memory synthesis hanging
// This tests whether Yosys hangs when synthesizing large memory arrays

module test_large_memory (
    input wire clk_i,
    input wire reset_n_i,
    input wire [15:0] addr_i,
    input wire [31:0] data_i,
    input wire write_en_i,
    output reg [31:0] data_o
);

// Large memory array - 64K x 32-bit
// This should test Yosys's ability to handle large memory synthesis
reg [31:0] memory [0:65535]; // 64K entries

always @(posedge clk_i or negedge reset_n_i) begin
    if (!reset_n_i) begin
        data_o <= 32'h0;
    end else if (write_en_i) begin
        memory[addr_i] <= data_i;
        data_o <= data_i;
    end else begin
        data_o <= memory[addr_i];
    end
end

endmodule
