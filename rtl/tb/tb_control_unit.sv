module tb_control_unit;
    import mini32_pkg::*;
    opcode_t opcode;
    logic reg_write, alu_src_immediate, halt, supported;
    alu_op_t alu_operation;
    writeback_source_t writeback_source;
    register_destination_t register_destination;
    immediate_kind_t immediate_kind;
    memory_operation_t memory_operation;
    control_flow_t control_flow;
    branch_predicate_t branch_predicate;
    integer failures = 0;

    control_unit dut (.*);

    task automatic check(input logic condition, input string message);
        if (!condition) begin $error("%s", message); failures = failures + 1; end
    endtask

    task automatic check_control(input opcode_t op, input logic expected_reg_write,
                                 input logic expected_imm_src, input alu_op_t expected_alu,
                                 input immediate_kind_t expected_imm, input memory_operation_t expected_mem,
                                 input writeback_source_t expected_wb, input register_destination_t expected_dest,
                                 input control_flow_t expected_flow, input branch_predicate_t expected_branch,
                                 input logic expected_halt);
        opcode = op; #1;
        check(supported && reg_write == expected_reg_write && alu_src_immediate == expected_imm_src &&
              alu_operation == expected_alu && immediate_kind == expected_imm &&
              memory_operation == expected_mem && writeback_source == expected_wb &&
              register_destination == expected_dest && control_flow == expected_flow &&
              branch_predicate == expected_branch && halt == expected_halt, "control decode mismatch");
    endtask

    initial begin
        check_control(OP_NOP,  0,0,ALU_ADD,IMM_NONE,MEM_NONE,WB_ALU,DEST_DECODED_RD,FLOW_SEQUENTIAL,BRANCH_NONE,0);
        check_control(OP_ADD,  1,0,ALU_ADD,IMM_NONE,MEM_NONE,WB_ALU,DEST_DECODED_RD,FLOW_SEQUENTIAL,BRANCH_NONE,0);
        check_control(OP_SUB,  1,0,ALU_SUB,IMM_NONE,MEM_NONE,WB_ALU,DEST_DECODED_RD,FLOW_SEQUENTIAL,BRANCH_NONE,0);
        check_control(OP_AND,  1,0,ALU_AND,IMM_NONE,MEM_NONE,WB_ALU,DEST_DECODED_RD,FLOW_SEQUENTIAL,BRANCH_NONE,0);
        check_control(OP_OR,   1,0,ALU_OR, IMM_NONE,MEM_NONE,WB_ALU,DEST_DECODED_RD,FLOW_SEQUENTIAL,BRANCH_NONE,0);
        check_control(OP_XOR,  1,0,ALU_XOR,IMM_NONE,MEM_NONE,WB_ALU,DEST_DECODED_RD,FLOW_SEQUENTIAL,BRANCH_NONE,0);
        check_control(OP_SLT,  1,0,ALU_SLT,IMM_NONE,MEM_NONE,WB_ALU,DEST_DECODED_RD,FLOW_SEQUENTIAL,BRANCH_NONE,0);
        check_control(OP_SHL,  1,0,ALU_SHL,IMM_NONE,MEM_NONE,WB_ALU,DEST_DECODED_RD,FLOW_SEQUENTIAL,BRANCH_NONE,0);
        check_control(OP_SHR,  1,0,ALU_SHR,IMM_NONE,MEM_NONE,WB_ALU,DEST_DECODED_RD,FLOW_SEQUENTIAL,BRANCH_NONE,0);
        check_control(OP_ADDI, 1,1,ALU_ADD,IMM_SIGNED16,MEM_NONE,WB_ALU,DEST_DECODED_RD,FLOW_SEQUENTIAL,BRANCH_NONE,0);
        check_control(OP_ANDI, 1,1,ALU_AND,IMM_ZERO_EXTENDED16,MEM_NONE,WB_ALU,DEST_DECODED_RD,FLOW_SEQUENTIAL,BRANCH_NONE,0);
        check_control(OP_ORI,  1,1,ALU_OR, IMM_ZERO_EXTENDED16,MEM_NONE,WB_ALU,DEST_DECODED_RD,FLOW_SEQUENTIAL,BRANCH_NONE,0);
        check_control(OP_XORI, 1,1,ALU_XOR,IMM_ZERO_EXTENDED16,MEM_NONE,WB_ALU,DEST_DECODED_RD,FLOW_SEQUENTIAL,BRANCH_NONE,0);
        check_control(OP_LUI,  1,1,ALU_ADD,IMM_UPPER16,MEM_NONE,WB_ALU,DEST_DECODED_RD,FLOW_SEQUENTIAL,BRANCH_NONE,0);
        check_control(OP_LW,   1,1,ALU_ADD,IMM_SIGNED16,MEM_LOAD,WB_MEMORY,DEST_DECODED_RD,FLOW_SEQUENTIAL,BRANCH_NONE,0);
        check_control(OP_SW,   0,1,ALU_ADD,IMM_SIGNED16,MEM_STORE,WB_ALU,DEST_DECODED_RD,FLOW_SEQUENTIAL,BRANCH_NONE,0);
        check_control(OP_BEQ,  0,0,ALU_ADD,IMM_NONE,MEM_NONE,WB_ALU,DEST_DECODED_RD,FLOW_CONDITIONAL_BRANCH,BRANCH_EQUAL,0);
        check_control(OP_BNE,  0,0,ALU_ADD,IMM_NONE,MEM_NONE,WB_ALU,DEST_DECODED_RD,FLOW_CONDITIONAL_BRANCH,BRANCH_NOT_EQUAL,0);
        check_control(OP_BLT,  0,0,ALU_ADD,IMM_NONE,MEM_NONE,WB_ALU,DEST_DECODED_RD,FLOW_CONDITIONAL_BRANCH,BRANCH_SIGNED_LESS_THAN,0);
        check_control(OP_BGE,  0,0,ALU_ADD,IMM_NONE,MEM_NONE,WB_ALU,DEST_DECODED_RD,FLOW_CONDITIONAL_BRANCH,BRANCH_SIGNED_GREATER_EQUAL,0);
        check_control(OP_J,    0,0,ALU_ADD,IMM_NONE,MEM_NONE,WB_ALU,DEST_DECODED_RD,FLOW_RELATIVE_JUMP,BRANCH_NONE,0);
        check_control(OP_JAL,  1,0,ALU_ADD,IMM_NONE,MEM_NONE,WB_PC_PLUS_4,DEST_RETURN_ADDRESS,FLOW_RELATIVE_JUMP,BRANCH_NONE,0);
        check_control(OP_JR,   0,0,ALU_ADD,IMM_NONE,MEM_NONE,WB_ALU,DEST_DECODED_RD,FLOW_REGISTER_JUMP,BRANCH_NONE,0);
        check_control(OP_HALT, 0,0,ALU_ADD,IMM_NONE,MEM_NONE,WB_ALU,DEST_DECODED_RD,FLOW_SEQUENTIAL,BRANCH_NONE,1);
        opcode = 6'h3f; #1;
        check(!supported, "unallocated opcode is unsupported");
        if (failures != 0) $fatal(1, "tb_control_unit: %0d failures", failures);
        $display("tb_control_unit passed");
        $finish;
    end
endmodule
