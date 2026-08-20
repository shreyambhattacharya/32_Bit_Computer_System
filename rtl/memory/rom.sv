// 64 KiB Mini32 program ROM: 16,384 little-endian architectural words.
// A .memh line is one complete 32-bit word, so raw bytes 78 56 34 12 become
// 12345678. INIT_FILE is intended for simulation and FPGA initialization.
module rom #(
    parameter INIT_FILE = ""
) (
    input  logic        clk,
    input  logic        read_enable,
    input  logic [13:0] word_address,
    output logic [31:0] read_data
);
    import mini32_pkg::*;

    logic [31:0] memory [0:ROM_WORD_COUNT - 1];

    initial begin
        if (INIT_FILE != "") $readmemh(INIT_FILE, memory);
    end

    always_ff @(posedge clk) begin
        if (read_enable) read_data <= memory[word_address];
    end
endmodule
