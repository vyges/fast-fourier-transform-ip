// Simple test case for frontend detection
module test_frontend (
    input wire clk_i,
    input wire reset_n_i,
    input wire [7:0] data_i,
    output reg [7:0] data_o
);

always @(posedge clk_i or negedge reset_n_i) begin
    if (!reset_n_i) begin
        data_o <= 8'h0;
    end else begin
        data_o <= data_i;
    end
end

endmodule
