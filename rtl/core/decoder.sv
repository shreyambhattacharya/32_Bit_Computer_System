module decoder (
    input  logic [31:0]          instruction,
    output mini32_pkg::opcode_t  opcode,
    output logic [4:0]           rd,
    output logic [4:0]           rs1,
    output logic [4:0]           rs2,
    output logic [15:0]          imm16,
    output logic [25:0]          imm26,
    output logic                 valid,
    output logic                 malformed
);
    import mini32_pkg::*;

    always_comb begin
        opcode = instruction[31:26];
        rd = instruction[25:21];
        rs1 = instruction[20:16];
        rs2 = instruction[15:11];
        imm16 = instruction[15:0];
        imm26 = instruction[25:0];
        valid = 1'b1;
        malformed = 1'b0;

        unique case (opcode)
            OP_NOP, OP_HALT: begin
                if (instruction[25:0] != 26'h0) begin
                    valid = 1'b0;
                    malformed = 1'b1;
                end
            end
            OP_ADD, OP_SUB, OP_AND, OP_OR, OP_XOR, OP_SLT, OP_SHL, OP_SHR: begin
                if (instruction[10:0] != 11'h0) begin
                    valid = 1'b0;
                    malformed = 1'b1;
                end
            end
            OP_ADDI, OP_ANDI, OP_ORI, OP_XORI, OP_LW: begin
            end
            OP_LUI: begin
                if (instruction[20:16] != 5'h0) begin
                    valid = 1'b0;
                    malformed = 1'b1;
                end
            end
            OP_SW: begin
                rs2 = instruction[25:21];
            end
            OP_BEQ, OP_BNE, OP_BLT, OP_BGE: begin
                rs1 = instruction[25:21];
                rs2 = instruction[20:16];
            end
            OP_J, OP_JAL: begin
            end
            OP_JR: begin
                rs1 = instruction[25:21];
                if (instruction[20:0] != 21'h0) begin
                    valid = 1'b0;
                    malformed = 1'b1;
                end
            end
            default: begin
                valid = 1'b0;
            end
        endcase
    end
endmodule
