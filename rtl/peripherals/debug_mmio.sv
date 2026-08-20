// Host-visible, reset-zero 32-bit debug register. Only VALUE (+0x00) stores.
module debug_mmio (
    input  logic        clk,
    input  logic        reset,
    input  logic        read_enable,
    input  logic        write_enable,
    input  logic [3:0]  register_offset,
    input  logic [31:0] write_data,
    output logic [31:0] read_data,
    output logic [31:0] debug_value
);
    always_ff @(posedge clk) begin
        if (reset) begin
            read_data <= 32'h0000_0000;
            debug_value <= 32'h0000_0000;
        end else begin
            if (read_enable) begin
                if (register_offset == 4'h0) read_data <= debug_value;
                else read_data <= 32'h0000_0000;
            end
            if (write_enable && register_offset == 4'h0) debug_value <= write_data;
        end
    end
endmodule
