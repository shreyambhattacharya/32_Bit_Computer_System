module tb_uart_mmio;
    logic clk = 1'b0, reset, read_enable, write_enable;
    logic [3:0] register_offset;
    logic [31:0] write_data, read_data;
    logic tx_valid;
    logic [7:0] tx_data;
    integer failures = 0;

    uart_mmio dut (.*);
    always #5 clk = ~clk;

    task automatic check(input logic condition, input string message);
        if (!condition) begin $error("%s", message); failures = failures + 1; end
    endtask

    task automatic write_data_register(input logic [7:0] value);
        register_offset = 4'h0; write_data = {24'h0, value}; write_enable = 1'b1;
        @(posedge clk); #1;
        check(tx_valid && tx_data == value, "DATA write did not emit expected UART event");
        write_enable = 1'b0;
        @(posedge clk); #1;
        check(!tx_valid, "UART event lasted longer than one clock");
    endtask

    initial begin
        reset = 1'b1; read_enable = 1'b0; write_enable = 1'b0; register_offset = 4'h0; write_data = '0;
        @(posedge clk); #1;
        check(!tx_valid && tx_data == 8'h00, "reset did not clear UART outputs");
        reset = 1'b0;
        read_enable = 1'b1; register_offset = 4'h4; @(posedge clk); #1;
        check(read_data == 32'h0000_0001, "STATUS did not report TX_READY");
        register_offset = 4'h0; @(posedge clk); #1; check(read_data == 32'h0000_0000, "DATA read was not deterministic zero");
        register_offset = 4'h8; @(posedge clk); #1; check(read_data == 32'h0000_0000, "reserved UART read was not deterministic zero");
        write_data_register(8'h41);
        write_data_register(8'h42);
        register_offset = 4'h4; write_data = 32'hDEAD_BEEF; write_enable = 1'b1;
        @(posedge clk); #1; check(!tx_valid, "non-DATA write emitted a UART event");
        write_enable = 1'b0;
        if (failures != 0) $fatal(1, "tb_uart_mmio: %0d failures", failures);
        $display("tb_uart_mmio passed");
        $finish;
    end
endmodule
