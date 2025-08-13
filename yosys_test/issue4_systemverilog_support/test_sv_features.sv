// Test case for SystemVerilog feature support consistency
// Tests various SystemVerilog constructs to identify inconsistencies

module test_sv_features (
    input wire clk_i,
    input wire reset_n_i,
    input wire [7:0] data_i,
    input wire [7:0] addr_i,
    output reg [7:0] data_o,
    output reg [7:0] status_o
);

// Test various SystemVerilog features
logic [7:0] internal_data;
logic [7:0] counter;

// Test 1: always_ff (SystemVerilog construct)
always_ff @(posedge clk_i or negedge reset_n_i) begin
    if (!reset_n_i) begin
        counter <= 8'h0;
        status_o <= 8'h0;
    end else begin
        counter <= counter + 1;
        status_o <= counter;
    end
end

// Test 2: always_comb (SystemVerilog construct)
always_comb begin
    internal_data = data_i ^ 8'hAA;  // XOR operation
end

// Test 3: always (Verilog construct for comparison)
always @(posedge clk_i) begin
    if (reset_n_i) begin
        data_o <= internal_data;
    end
end

// Test 4: SystemVerilog parameter with type
parameter int WIDTH = 8;
parameter logic [7:0] DEFAULT_VALUE = 8'h00;

// Test 5: SystemVerilog typedef
typedef logic [7:0] byte_t;
byte_t test_byte;

// Test 6: SystemVerilog struct
typedef struct packed {
    logic [3:0] high;
    logic [3:0] low;
} nibble_pair_t;

nibble_pair_t nibbles;

// Test 7: SystemVerilog enum
typedef enum logic [1:0] {
    IDLE = 2'b00,
    ACTIVE = 2'b01,
    DONE = 2'b10,
    ERROR = 2'b11
} state_t;

state_t current_state;

// Test 8: SystemVerilog array operations
logic [7:0] test_array [0:3];

// Test 9: SystemVerilog generate (if supported)
generate
    if (WIDTH == 8) begin : gen_8bit
        assign test_byte = internal_data;
    end else begin : gen_other
        assign test_byte = 8'h00;
    end
endgenerate

endmodule
