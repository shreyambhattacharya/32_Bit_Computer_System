module tb_register_file;
    logic clk = 1'b0, reset;
    logic [4:0] rs1_addr, rs2_addr, write_addr;
    logic [31:0] rs1_data, rs2_data, write_data;
    logic write_enable;
    integer failures = 0;

    register_file dut (.*);
    always #5 clk = ~clk;

    task automatic check(input logic condition, input string message);
        if (!condition) begin $error("%s", message); failures = failures + 1; end
    endtask

    task automatic write_register(input logic [4:0] address, input logic [31:0] value);
        write_enable = 1'b1; write_addr = address; write_data = value;
        @(posedge clk); #1;
        write_enable = 1'b0;
    endtask

    initial begin
        reset = 1'b1; write_enable = 1'b0; rs1_addr = 5'd1; rs2_addr = 5'd31;
        write_addr = '0; write_data = '0;
        @(posedge clk); #1;
        check(rs1_data == 32'd0 && rs2_data == 32'd0, "reset clears writable registers");
        reset = 1'b0;
        write_register(5'd1, 32'h1234_5678);
        check(rs1_data == 32'h1234_5678, "write/read r1");
        write_register(5'd31, 32'hfeed_beef);
        check(rs2_data == 32'hfeed_beef, "write/read r31");
        write_register(5'd1, 32'h0bad_f00d);
        check(rs1_data == 32'h0bad_f00d, "overwrite r1");
        rs1_addr = 5'd1; rs2_addr = 5'd31; #1;
        check(rs1_data == 32'h0bad_f00d && rs2_data == 32'hfeed_beef, "two read ports independent");
        write_register(5'd0, 32'hffff_ffff);
        rs1_addr = 5'd0; rs2_addr = 5'd0; #1;
        check(rs1_data == 32'd0 && rs2_data == 32'd0, "r0 stays zero");
        reset = 1'b1; @(posedge clk); #1; reset = 1'b0;
        rs1_addr = 5'd1; rs2_addr = 5'd31; #1;
        check(rs1_data == 32'd0 && rs2_data == 32'd0, "reset after writes clears registers");
        if (failures != 0) $fatal(1, "tb_register_file: %0d failures", failures);
        $display("tb_register_file passed");
        $finish;
    end
endmodule
