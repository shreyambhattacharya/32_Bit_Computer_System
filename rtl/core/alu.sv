module alu (
    input  logic [31:0]       lhs,
    input  logic [31:0]       rhs,
    input  mini32_pkg::alu_op_t operation,
    output logic [31:0]       result
);
    import mini32_pkg::*;

    always_comb begin
        result = 32'h0000_0000;
        unique case (operation)
            ALU_ADD: result = lhs + rhs;
            ALU_SUB: result = lhs - rhs;
            ALU_AND: result = lhs & rhs;
            ALU_OR:  result = lhs | rhs;
            ALU_XOR: result = lhs ^ rhs;
            ALU_SLT: result = ($signed(lhs) < $signed(rhs)) ? 32'd1 : 32'd0;
            ALU_SHL: result = lhs << rhs[4:0];
            ALU_SHR: result = lhs >> rhs[4:0];
            default: result = 32'h0000_0000;
        endcase
    end
endmodule
