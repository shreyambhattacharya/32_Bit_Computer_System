package mini32_pkg;

    // Architectural v0.1 address map. Storage modules receive a 14-bit word
    // index only after system_bus has performed these full-address checks.
    localparam logic [31:0] ROM_BASE       = 32'h0000_0000;
    localparam logic [31:0] ROM_SIZE_BYTES = 32'h0001_0000;
    localparam logic [31:0] ROM_LAST       = ROM_BASE + ROM_SIZE_BYTES - 32'd1;
    localparam integer ROM_WORD_COUNT = 16384;

    localparam logic [31:0] RAM_BASE       = 32'h1000_0000;
    localparam logic [31:0] RAM_SIZE_BYTES = 32'h0001_0000;
    localparam logic [31:0] RAM_LAST       = RAM_BASE + RAM_SIZE_BYTES - 32'd1;
    localparam integer RAM_WORD_COUNT = 16384;

    localparam logic [31:0] UART_BASE       = 32'h2000_0000;
    localparam logic [31:0] UART_LAST       = 32'h2000_000F;
    localparam logic [31:0] TIMER_BASE      = 32'h2000_0100;
    localparam logic [31:0] TIMER_LAST      = 32'h2000_010F;
    localparam logic [31:0] GPIO_BASE       = 32'h2000_0200;
    localparam logic [31:0] GPIO_LAST       = 32'h2000_020F;
    localparam logic [31:0] DEBUG_BASE      = 32'h2000_0300;
    localparam logic [31:0] DEBUG_LAST      = 32'h2000_030F;
    localparam logic [31:0] STM32_BASE      = 32'h2000_0400;
    localparam logic [31:0] STM32_LAST      = 32'h2000_04FF;

    // Keep raw opcode bits representable so the decoder can identify unallocated values.
    typedef logic [5:0] opcode_t;
    localparam opcode_t OP_NOP  = 6'h00;
    localparam opcode_t OP_ADD  = 6'h01;
    localparam opcode_t OP_SUB  = 6'h02;
    localparam opcode_t OP_AND  = 6'h03;
    localparam opcode_t OP_OR   = 6'h04;
    localparam opcode_t OP_XOR  = 6'h05;
    localparam opcode_t OP_SLT  = 6'h06;
    localparam opcode_t OP_SHL  = 6'h07;
    localparam opcode_t OP_SHR  = 6'h08;
    localparam opcode_t OP_ADDI = 6'h09;
    localparam opcode_t OP_ANDI = 6'h0A;
    localparam opcode_t OP_ORI  = 6'h0B;
    localparam opcode_t OP_XORI = 6'h0C;
    localparam opcode_t OP_LUI  = 6'h0D;
    localparam opcode_t OP_LW   = 6'h0E;
    localparam opcode_t OP_SW   = 6'h0F;
    localparam opcode_t OP_BEQ  = 6'h10;
    localparam opcode_t OP_BNE  = 6'h11;
    localparam opcode_t OP_BLT  = 6'h12;
    localparam opcode_t OP_BGE  = 6'h13;
    localparam opcode_t OP_J    = 6'h14;
    localparam opcode_t OP_JAL  = 6'h15;
    localparam opcode_t OP_JR   = 6'h16;
    localparam opcode_t OP_HALT = 6'h17;

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

    typedef enum logic [1:0] {
        BUS_FETCH,
        BUS_READ,
        BUS_WRITE
    } bus_access_t;

    typedef enum logic [2:0] {
        BUS_FAULT_NONE,
        BUS_FAULT_MISALIGNED,
        BUS_FAULT_UNMAPPED,
        BUS_FAULT_READ_ONLY,
        BUS_FAULT_NON_EXECUTABLE
    } bus_fault_t;

    typedef enum logic [3:0] {
        CPU_FAULT_NONE,
        CPU_FAULT_MISALIGNED_INSTRUCTION_FETCH,
        CPU_FAULT_UNMAPPED_INSTRUCTION_FETCH,
        CPU_FAULT_NON_EXECUTABLE_INSTRUCTION_FETCH,
        CPU_FAULT_ILLEGAL_INSTRUCTION,
        CPU_FAULT_MALFORMED_INSTRUCTION,
        CPU_FAULT_UNSUPPORTED_INSTRUCTION,
        CPU_FAULT_MISALIGNED_LOAD,
        CPU_FAULT_UNMAPPED_LOAD,
        CPU_FAULT_MISALIGNED_STORE,
        CPU_FAULT_UNMAPPED_STORE,
        CPU_FAULT_READ_ONLY_STORE
    } cpu_fault_t;

    typedef enum logic [2:0] {
        CPU_STATE_FETCH,
        CPU_STATE_DECODE,
        CPU_STATE_EXECUTE,
        CPU_STATE_MEMORY,
        CPU_STATE_WRITEBACK,
        CPU_STATE_HALTED,
        CPU_STATE_FAULT
    } cpu_state_t;

endpackage
