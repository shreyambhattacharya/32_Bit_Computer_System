// Minimal TX-only UART MMIO register block. DATA writes produce one event;
// STATUS always reports TX_READY and all other registers are deterministic.
module uart_mmio (
    input  logic        clk,
    input  logic        reset,
    input  logic        read_enable,
    input  logic        write_enable,
    input  logic [3:0]  register_offset,
    // Mini32 UART DATA writes are architecturally low-byte-only.
    /* verilator lint_off UNUSEDSIGNAL */
    input  logic [31:0] write_data,
    /* verilator lint_on UNUSEDSIGNAL */
    output logic [31:0] read_data,
    output logic        tx_valid,
    output logic [7:0]  tx_data
);
    always_ff @(posedge clk) begin
        if (reset) begin
            read_data <= 32'h0000_0000;
            tx_valid <= 1'b0;
            tx_data <= 8'h00;
        end else begin
            if (read_enable) begin
                if (register_offset == 4'h4) read_data <= 32'h0000_0001;
                else read_data <= 32'h0000_0000;
            end
            tx_valid <= 1'b0;
            if (write_enable && register_offset == 4'h0) begin
                tx_valid <= 1'b1;
                tx_data <= write_data[7:0];
            end
        end
    end
endmodule
