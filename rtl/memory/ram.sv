// 64 KiB Mini32 data RAM: 16,384 little-endian architectural words.
// v0.1 has only aligned LW/SW, so a word array exactly preserves its external
// little-endian word semantics. RAM has no reset and powers up unspecified.
module ram (
    input  logic        clk,
    input  logic        read_enable,
    input  logic        write_enable,
    input  logic [13:0] word_address,
    input  logic [31:0] write_data,
    output logic [31:0] read_data
);
    import mini32_pkg::*;

    logic [31:0] memory [0:RAM_WORD_COUNT - 1];

    always_ff @(posedge clk) begin
        if (write_enable) memory[word_address] <= write_data;
        if (read_enable) read_data <= memory[word_address];
    end
endmodule
