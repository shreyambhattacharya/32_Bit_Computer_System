package mini32_tb_pkg;
    import mini32_pkg::*;

    function automatic logic [31:0] encode_r(input opcode_t opcode, input logic [4:0] rd,
                                              input logic [4:0] rs1, input logic [4:0] rs2);
        return {opcode, rd, rs1, rs2, 11'h000};
    endfunction

    function automatic logic [31:0] encode_i(input opcode_t opcode, input logic [4:0] rd,
                                              input logic [4:0] rs1, input logic [15:0] immediate);
        return {opcode, rd, rs1, immediate};
    endfunction

    function automatic logic [31:0] encode_s(input logic [4:0] rs2, input logic [4:0] rs1,
                                              input logic [15:0] immediate);
        return {OP_SW, rs2, rs1, immediate};
    endfunction

    function automatic logic [31:0] encode_b(input opcode_t opcode, input logic [4:0] rs1,
                                              input logic [4:0] rs2, input logic [15:0] immediate);
        return {opcode, rs1, rs2, immediate};
    endfunction

    function automatic logic [31:0] encode_j(input opcode_t opcode, input logic [25:0] immediate);
        return {opcode, immediate};
    endfunction

    function automatic logic [31:0] encode_jr(input logic [4:0] rs1);
        return {OP_JR, rs1, 21'h000000};
    endfunction
endpackage
