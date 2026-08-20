module tb_ram;
    logic clk = 1'b0, read_enable, write_enable;
    logic [13:0] word_address;
    logic [31:0] write_data, read_data;
    integer failures = 0;

    ram dut (.*);
    always #5 clk = ~clk;

    task automatic check(input logic condition, input string message);
        if (!condition) begin $error("%s", message); failures = failures + 1; end
    endtask

    task automatic write_word(input logic [13:0] address, input logic [31:0] value);
        word_address = address; write_data = value; write_enable = 1'b1;
        @(posedge clk); #1;
        write_enable = 1'b0;
    endtask

    task automatic read_word(input logic [13:0] address, input logic [31:0] expected, input string message);
        logic [31:0] before_clock;
        word_address = address; read_enable = 1'b1; before_clock = read_data;
        #1; check(read_data === before_clock, "RAM read changed before its synchronous clock edge");
        @(posedge clk); #1;
        check(read_data === expected, message);
        read_enable = 1'b0;
    endtask

    initial begin
        read_enable = 1'b0; write_enable = 1'b0; word_address = '0; write_data = '0;
        write_word(14'd0, 32'h1111_1111);       // 0x10000000
        write_word(14'd256, 32'h2222_2222);     // 0x10000400
        write_word(14'd8192, 32'h3333_3333);    // 0x10008000
        write_word(14'd16383, 32'h4444_4444);   // 0x1000FFFC
        write_word(14'd256, 32'h5555_5555);
        read_word(14'd0, 32'h1111_1111, "RAM first word was changed or aliased");
        read_word(14'd256, 32'h5555_5555, "RAM overwrite did not persist");
        read_word(14'd8192, 32'h3333_3333, "RAM middle word aliased");
        read_word(14'd16383, 32'h4444_4444, "RAM final architectural word is inaccessible");
        if (failures != 0) $fatal(1, "tb_ram: %0d failures", failures);
        $display("tb_ram passed");
        $finish;
    end
endmodule
