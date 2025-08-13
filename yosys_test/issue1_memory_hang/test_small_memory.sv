// Control test case with small memory for comparison
// This should synthesize quickly without hanging

module test_small_memory (
    input wire clk_i,
    input wire reset_n_i,
    input wire [7:0] addr_i,
    input wire [31:0] data_i,
    input wire write_en_i,
    output reg [31:0] data_o
);

// Small memory array - 256 x 32-bit
// This should work fine and provide a baseline for comparison
reg [31:0] memory [0:255]; // 256 entries

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
