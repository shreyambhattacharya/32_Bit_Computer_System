module tb_alu;
    import mini32_pkg::*;

    logic [31:0] lhs, rhs, result;
    alu_op_t operation;
    integer failures = 0;

    alu dut (.lhs(lhs), .rhs(rhs), .operation(operation), .result(result));

    task automatic check(input logic condition, input string message);
        if (!condition) begin
            $error("%s", message);
            failures = failures + 1;
        end
    endtask

    task automatic check_operation(input alu_op_t op, input logic [31:0] a, input logic [31:0] b,
                                   input logic [31:0] expected, input string message);
        operation = op; lhs = a; rhs = b; #1;
        check(result === expected, message);
    endtask

    initial begin
        check_operation(ALU_ADD, 32'd0, 32'd0, 32'd0, "ADD zero");
        check_operation(ALU_ADD, 32'd1, 32'd1, 32'd2, "ADD one");
        check_operation(ALU_ADD, 32'hffff_ffff, 32'd1, 32'd0, "ADD wraps");
        check_operation(ALU_SUB, 32'd0, 32'd1, 32'hffff_ffff, "SUB negative one");
        check_operation(ALU_SUB, 32'd5, 32'd10, 32'hffff_fffb, "SUB wraps");
        check_operation(ALU_AND, 32'hf0f0_aaaa, 32'h0ff0_0f0f, 32'h00f0_0a0a, "AND");
        check_operation(ALU_OR,  32'hf0f0_aaaa, 32'h0ff0_0f0f, 32'hfff0_afaf, "OR");
        check_operation(ALU_XOR, 32'hf0f0_aaaa, 32'h0ff0_0f0f, 32'hff00_a5a5, "XOR");
        check_operation(ALU_SLT, 32'd0, 32'd1, 32'd1, "SLT positive true");
        check_operation(ALU_SLT, 32'd1, 32'd0, 32'd0, "SLT positive false");
        check_operation(ALU_SLT, 32'hffff_ffff, 32'd0, 32'd1, "SLT negative true");
        check_operation(ALU_SLT, 32'd0, 32'hffff_ffff, 32'd0, "SLT negative false");
        check_operation(ALU_SLT, 32'h8000_0000, 32'h7fff_ffff, 32'd1, "SLT signed bounds");
        check_operation(ALU_SHL, 32'd1, 32'd0, 32'd1, "SHL zero");
        check_operation(ALU_SHL, 32'd1, 32'd1, 32'd2, "SHL one");
        check_operation(ALU_SHL, 32'd1, 32'd31, 32'h8000_0000, "SHL 31");
        check_operation(ALU_SHL, 32'd1, 32'd32, 32'd1, "SHL masks 32");
        check_operation(ALU_SHL, 32'd1, 32'd33, 32'd2, "SHL masks 33");
        check_operation(ALU_SHR, 32'h8000_0000, 32'd0, 32'h8000_0000, "SHR zero");
        check_operation(ALU_SHR, 32'h8000_0000, 32'd1, 32'h4000_0000, "SHR logical");
        check_operation(ALU_SHR, 32'h8000_0000, 32'd31, 32'd1, "SHR 31");
        check_operation(ALU_SHR, 32'h8000_0000, 32'd32, 32'h8000_0000, "SHR masks 32");
        check_operation(ALU_SHR, 32'h8000_0000, 32'd33, 32'h4000_0000, "SHR masks 33");
        if (failures != 0) $fatal(1, "tb_alu: %0d failures", failures);
        $display("tb_alu passed");
        $finish;
    end
endmodule
