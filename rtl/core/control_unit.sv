module control_unit (
    input  mini32_pkg::opcode_t                opcode,
    output logic                               reg_write,
    output logic                               alu_src_immediate,
    output mini32_pkg::alu_op_t                alu_operation,
    output mini32_pkg::writeback_source_t      writeback_source,
    output mini32_pkg::register_destination_t  register_destination,
    output mini32_pkg::immediate_kind_t        immediate_kind,
    output mini32_pkg::memory_operation_t      memory_operation,
    output mini32_pkg::control_flow_t          control_flow,
    output mini32_pkg::branch_predicate_t      branch_predicate,
    output logic                               halt,
    output logic                               supported
);
    import mini32_pkg::*;

    always_comb begin
        reg_write = 1'b0;
        alu_src_immediate = 1'b0;
        alu_operation = ALU_ADD;
        writeback_source = WB_ALU;
        register_destination = DEST_DECODED_RD;
        immediate_kind = IMM_NONE;
        memory_operation = MEM_NONE;
        control_flow = FLOW_SEQUENTIAL;
        branch_predicate = BRANCH_NONE;
        halt = 1'b0;
        supported = 1'b1;

        unique case (opcode)
            OP_NOP: begin end
            OP_ADD: begin reg_write = 1'b1; alu_operation = ALU_ADD; end
            OP_SUB: begin reg_write = 1'b1; alu_operation = ALU_SUB; end
            OP_AND: begin reg_write = 1'b1; alu_operation = ALU_AND; end
            OP_OR:  begin reg_write = 1'b1; alu_operation = ALU_OR; end
            OP_XOR: begin reg_write = 1'b1; alu_operation = ALU_XOR; end
            OP_SLT: begin reg_write = 1'b1; alu_operation = ALU_SLT; end
            OP_SHL: begin reg_write = 1'b1; alu_operation = ALU_SHL; end
            OP_SHR: begin reg_write = 1'b1; alu_operation = ALU_SHR; end
            OP_ADDI: begin
                reg_write = 1'b1; alu_src_immediate = 1'b1; immediate_kind = IMM_SIGNED16;
            end
            OP_ANDI: begin
                reg_write = 1'b1; alu_src_immediate = 1'b1; alu_operation = ALU_AND;
                immediate_kind = IMM_ZERO_EXTENDED16;
            end
            OP_ORI: begin
                reg_write = 1'b1; alu_src_immediate = 1'b1; alu_operation = ALU_OR;
                immediate_kind = IMM_ZERO_EXTENDED16;
            end
            OP_XORI: begin
                reg_write = 1'b1; alu_src_immediate = 1'b1; alu_operation = ALU_XOR;
                immediate_kind = IMM_ZERO_EXTENDED16;
            end
            OP_LUI: begin
                reg_write = 1'b1; alu_src_immediate = 1'b1; immediate_kind = IMM_UPPER16;
            end
            OP_LW: begin
                reg_write = 1'b1; alu_src_immediate = 1'b1; immediate_kind = IMM_SIGNED16;
                memory_operation = MEM_LOAD; writeback_source = WB_MEMORY;
            end
            OP_SW: begin
                alu_src_immediate = 1'b1; immediate_kind = IMM_SIGNED16;
                memory_operation = MEM_STORE;
            end
            OP_BEQ: begin control_flow = FLOW_CONDITIONAL_BRANCH; branch_predicate = BRANCH_EQUAL; end
            OP_BNE: begin control_flow = FLOW_CONDITIONAL_BRANCH; branch_predicate = BRANCH_NOT_EQUAL; end
            OP_BLT: begin control_flow = FLOW_CONDITIONAL_BRANCH; branch_predicate = BRANCH_SIGNED_LESS_THAN; end
            OP_BGE: begin control_flow = FLOW_CONDITIONAL_BRANCH; branch_predicate = BRANCH_SIGNED_GREATER_EQUAL; end
            OP_J: begin control_flow = FLOW_RELATIVE_JUMP; end
            OP_JAL: begin
                reg_write = 1'b1; control_flow = FLOW_RELATIVE_JUMP;
                writeback_source = WB_PC_PLUS_4; register_destination = DEST_RETURN_ADDRESS;
            end
            OP_JR: begin control_flow = FLOW_REGISTER_JUMP; end
            OP_HALT: begin halt = 1'b1; end
            default: begin supported = 1'b0; end
        endcase
    end
endmodule
