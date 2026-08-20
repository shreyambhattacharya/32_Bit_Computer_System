module tb_debug_mmio;
    logic clk = 1'b0, reset, read_enable, write_enable;
    logic [3:0] register_offset;
    logic [31:0] write_data, read_data, debug_value;
    integer failures = 0;

    debug_mmio dut (.*);
    always #5 clk = ~clk;

    task automatic check(input logic condition, input string message);
        if (!condition) begin $error("%s", message); failures = failures + 1; end
    endtask

    initial begin
        reset = 1'b1; read_enable = 1'b0; write_enable = 1'b0; register_offset = 4'h0; write_data = '0;
        @(posedge clk); #1; check(debug_value == 32'h0000_0000, "reset did not clear Debug VALUE");
        reset = 1'b0;
        register_offset = 4'h0; write_data = 32'h1234_5678; write_enable = 1'b1;
        @(posedge clk); #1; write_enable = 1'b0;
        read_enable = 1'b1; @(posedge clk); #1;
        check(debug_value == 32'h1234_5678 && read_data == 32'h1234_5678, "VALUE write/readback failed");
        register_offset = 4'h4; write_data = 32'hDEAD_BEEF; write_enable = 1'b1;
        @(posedge clk); #1; write_enable = 1'b0; @(posedge clk); #1;
        check(debug_value == 32'h1234_5678 && read_data == 32'h0000_0000, "non-VALUE register changed Debug state");
        reset = 1'b1; @(posedge clk); #1; check(debug_value == 32'h0000_0000, "Debug VALUE did not reset to zero");
        if (failures != 0) $fatal(1, "tb_debug_mmio: %0d failures", failures);
        $display("tb_debug_mmio passed");
        $finish;
    end
endmodule
