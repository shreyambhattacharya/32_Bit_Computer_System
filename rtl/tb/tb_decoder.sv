module tb_decoder;
    import mini32_pkg::*;
    logic [31:0] instruction;
    opcode_t opcode;
    logic [4:0] rd, rs1, rs2;
    logic [15:0] imm16;
    logic [25:0] imm26;
    logic valid, malformed;
    integer failures = 0;

    decoder dut (.*);

    function automatic logic [31:0] r_word(input opcode_t op, input logic [4:0] d,
                                            input logic [4:0] a, input logic [4:0] b);
        return {op, d, a, b, 11'h0};
    endfunction

    task automatic check(input logic condition, input string message);
        if (!condition) begin $error("%s", message); failures = failures + 1; end
    endtask

    task automatic expect_valid(input logic [31:0] word, input string message);
        instruction = word; #1; check(valid && !malformed, message);
    endtask

    initial begin
        for (int raw_opcode = 0; raw_opcode <= 6'h17; raw_opcode++) begin
            expect_valid({raw_opcode[5:0], 26'h0}, "canonical allocated opcode is valid");
        end
        instruction = r_word(OP_ADD, 5'd3, 5'd1, 5'd2); #1;
        check(valid && opcode == OP_ADD && rd == 5'd3 && rs1 == 5'd1 && rs2 == 5'd2,
              "R format extraction");
        instruction = {OP_ADDI, 5'd5, 5'd4, 16'h8001}; #1;
        check(valid && rd == 5'd5 && rs1 == 5'd4 && imm16 == 16'h8001, "I format extraction");
        instruction = {OP_SW, 5'd9, 5'd4, 16'hfff0}; #1;
        check(valid && rs2 == 5'd9 && rs1 == 5'd4 && imm16 == 16'hfff0, "S format extraction");
        instruction = {OP_BEQ, 5'd6, 5'd7, 16'hfffc}; #1;
        check(valid && rs1 == 5'd6 && rs2 == 5'd7 && imm16 == 16'hfffc, "B format extraction");
        instruction = {OP_J, 26'h3abcde0}; #1;
        check(valid && imm26 == 26'h3abcde0, "J format extraction");
        instruction = {OP_JR, 5'd7, 21'h0}; #1;
        check(valid && rs1 == 5'd7, "JR extraction");

        instruction = {OP_NOP, 26'h1}; #1;
        check(!valid && malformed, "NOP requires canonical encoding");
        instruction = {OP_HALT, 5'd1, 21'h0}; #1;
        check(!valid && malformed, "HALT requires canonical encoding");
        instruction = r_word(OP_ADD, 5'd3, 5'd1, 5'd2) | 32'h1; #1;
        check(!valid && malformed, "R reserved bits are rejected");
        instruction = {OP_JR, 5'd7, 21'h1}; #1;
        check(!valid && malformed, "JR reserved bits are rejected");
        instruction = {OP_LUI, 5'd5, 5'd1, 16'h1000}; #1;
        check(!valid && malformed, "LUI rs1 is reserved");
        instruction = {6'h3f, 26'h0}; #1;
        check(!valid && !malformed, "unknown opcode is invalid");
        if (failures != 0) $fatal(1, "tb_decoder: %0d failures", failures);
        $display("tb_decoder passed");
        $finish;
    end
endmodule
