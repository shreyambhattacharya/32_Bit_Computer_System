package mini32_pkg;

    typedef enum logic [5:0] {
        OP_NOP  = 6'h00,
        OP_ADD  = 6'h01,
        OP_SUB  = 6'h02,
        OP_AND  = 6'h03,
        OP_OR   = 6'h04,
        OP_XOR  = 6'h05,
        OP_SLT  = 6'h06,
        OP_SHL  = 6'h07,
        OP_SHR  = 6'h08,
        OP_ADDI = 6'h09,
        OP_ANDI = 6'h0A,
        OP_ORI  = 6'h0B,
        OP_XORI = 6'h0C,
        OP_LUI  = 6'h0D,
        OP_LW   = 6'h0E,
        OP_SW   = 6'h0F,
        OP_BEQ  = 6'h10,
        OP_BNE  = 6'h11,
        OP_BLT  = 6'h12,
        OP_BGE  = 6'h13,
        OP_J    = 6'h14,
        OP_JAL  = 6'h15,
        OP_JR   = 6'h16,
        OP_HALT = 6'h17
    } opcode_t;

    typedef enum logic [3:0] {
        ALU_ADD,
        ALU_SUB,
        ALU_AND,
        ALU_OR,
        ALU_XOR,
        ALU_SLT,
        ALU_SHL,
        ALU_SHR
    } alu_op_t;

    typedef enum logic [1:0] {
        IMM_NONE,
        IMM_SIGNED16,
        IMM_ZERO_EXTENDED16,
        IMM_UPPER16
    } immediate_kind_t;

    typedef enum logic [1:0] {
        MEM_NONE,
        MEM_LOAD,
        MEM_STORE
    } memory_operation_t;

    typedef enum logic [1:0] {
        WB_ALU,
        WB_MEMORY,
        WB_PC_PLUS_4
    } writeback_source_t;

    typedef enum logic {
        DEST_DECODED_RD,
        DEST_RETURN_ADDRESS
    } register_destination_t;

    typedef enum logic [1:0] {
        FLOW_SEQUENTIAL,
        FLOW_CONDITIONAL_BRANCH,
        FLOW_RELATIVE_JUMP,
        FLOW_REGISTER_JUMP
    } control_flow_t;

    typedef enum logic [2:0] {
        BRANCH_NONE,
        BRANCH_EQUAL,
        BRANCH_NOT_EQUAL,
        BRANCH_SIGNED_LESS_THAN,
        BRANCH_SIGNED_GREATER_EQUAL
    } branch_predicate_t;

endpackage
