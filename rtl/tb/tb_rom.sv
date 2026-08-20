module tb_rom;
    import mini32_pkg::*;
    logic clk = 1'b0, read_enable;
    logic [13:0] word_address;
    logic [31:0] read_data;
    integer failures = 0;

    rom #(.INIT_FILE("build/generated/memory_roundtrip.memh")) dut (.*);
    always #5 clk = ~clk;

    task automatic check(input logic condition, input string message);
        if (!condition) begin $error("%s", message); failures = failures + 1; end
    endtask

    task automatic read_word(input logic [13:0] address, input logic [31:0] expected, input string message);
        logic [31:0] before_clock;
        word_address = address;
        read_enable = 1'b1;
        before_clock = read_data;
        #1;
        check(read_data === before_clock, "ROM read changed before its synchronous clock edge");
        @(posedge clk); #1;
        check(read_data === expected, message);
        read_enable = 1'b0;
    endtask

    initial begin
        read_enable = 1'b0;
        word_address = '0;
        #1;
        // Generated from programs/memory_roundtrip.asm by the normal assembler flow.
        read_word(14'd0, 32'h3420_1000, "ROM image first word is wrong");
        dut.memory[1] = 32'h1234_5678;
        dut.memory[1024] = 32'h89AB_CDEF;
        dut.memory[8192] = 32'h0BAD_F00D;
        dut.memory[16383] = 32'hFEED_BEEF;
        read_word(14'd1, 32'h1234_5678, "ROM second word is wrong");
        read_word(14'd1024, 32'h89AB_CDEF, "ROM 4 KiB word aliased");
        read_word(14'd8192, 32'h0BAD_F00D, "ROM middle word aliased");
        read_word(14'd16383, 32'hFEED_BEEF, "ROM final architectural word is inaccessible");
        read_word(14'd0, 32'h3420_1000, "ROM distinct locations aliased with first word");
        if (failures != 0) $fatal(1, "tb_rom: %0d failures", failures);
        $display("tb_rom passed");
        $finish;
    end
endmodule
