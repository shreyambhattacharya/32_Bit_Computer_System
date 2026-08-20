module cpu_core (
    input  logic                    clk,
    input  logic                    reset,
    input  logic                    bus_ready,
    input  logic [31:0]             bus_rdata,
    input  mini32_pkg::bus_fault_t  bus_fault,
    output logic                    bus_valid,
    output mini32_pkg::bus_access_t bus_access,
    output logic [31:0]             bus_addr,
    output logic [31:0]             bus_wdata,
    output logic                    halted,
    output logic                    faulted,
    output mini32_pkg::cpu_fault_t  fault_code,
    output logic [31:0]             fault_pc,
    output logic [31:0]             fault_instruction,
    output logic                    fault_address_valid,
    output logic [31:0]             fault_address,
    output logic [31:0]             pc,
    output logic                    retire_valid,
    output logic [31:0]             retire_pc,
    output logic [31:0]             retire_instruction,
    output logic [31:0]             retire_next_pc,
    output logic                    retire_reg_write,
    output logic [4:0]              retire_rd,
    output logic [31:0]             retire_value,
    output logic                    retire_mem_write,
    output logic [31:0]             retire_mem_addr,
    output logic [31:0]             retire_mem_value
);
    import mini32_pkg::*;

    cpu_state_t state;
    logic [31:0] instruction_register;
    logic [31:0] operand_lhs_latch;
    logic [31:0] operand_rhs_latch;
    logic [31:0] alu_result_latch;
    logic [31:0] store_data_latch;
    logic [31:0] memory_data_latch;
    logic [31:0] next_pc_latch;

    opcode_t decoded_opcode;
    logic [4:0] decoded_rd, decoded_rs1, decoded_rs2;
    logic [15:0] decoded_imm16;
    logic [25:0] decoded_imm26;
    logic decode_valid, decode_malformed;
    logic control_reg_write, control_alu_src_immediate, control_halt, control_supported;
    alu_op_t control_alu_operation;
    writeback_source_t control_writeback_source;
    register_destination_t control_register_destination;
    immediate_kind_t control_immediate_kind;
    memory_operation_t control_memory_operation;
    control_flow_t control_flow;
    branch_predicate_t control_branch_predicate;
    logic [31:0] rs1_data, rs2_data, writeback_current_value, immediate_value, alu_result;
    logic [31:0] writeback_value;
    logic [4:0] writeback_destination;
    logic register_write_enable;
    logic branch_taken;
    logic [31:0] branch_displacement, jump_displacement;

    decoder decoder_instance (
        .instruction(instruction_register), .opcode(decoded_opcode), .rd(decoded_rd),
        .rs1(decoded_rs1), .rs2(decoded_rs2), .imm16(decoded_imm16), .imm26(decoded_imm26),
        .valid(decode_valid), .malformed(decode_malformed)
    );
    control_unit control_unit_instance (
        .opcode(decoded_opcode), .reg_write(control_reg_write),
        .alu_src_immediate(control_alu_src_immediate), .alu_operation(control_alu_operation),
        .writeback_source(control_writeback_source),
        .register_destination(control_register_destination), .immediate_kind(control_immediate_kind),
        .memory_operation(control_memory_operation), .control_flow(control_flow),
        .branch_predicate(control_branch_predicate), .halt(control_halt), .supported(control_supported)
    );
    register_file register_file_instance (
        .clk(clk), .reset(reset), .rs1_addr(decoded_rs1), .rs2_addr(decoded_rs2),
        .observe_addr(writeback_destination), .rs1_data(rs1_data), .rs2_data(rs2_data),
        .observe_data(writeback_current_value), .write_enable(register_write_enable),
        .write_addr(writeback_destination), .write_data(writeback_value)
    );
    immediate_generator immediate_generator_instance (
        .immediate(decoded_imm16), .kind(control_immediate_kind), .value(immediate_value)
    );
    alu alu_instance (
        .lhs(operand_lhs_latch), .rhs(operand_rhs_latch),
        .operation(control_alu_operation), .result(alu_result)
    );

    assign halted = (state == CPU_STATE_HALTED);
    assign faulted = (state == CPU_STATE_FAULT);

    always_comb begin
        bus_valid = 1'b0;
        bus_access = BUS_FETCH;
        bus_addr = 32'h0000_0000;
        bus_wdata = 32'h0000_0000;
        if (state == CPU_STATE_FETCH) begin
            bus_valid = 1'b1;
            bus_access = BUS_FETCH;
            bus_addr = pc;
        end else if (state == CPU_STATE_MEMORY) begin
            bus_valid = 1'b1;
            if (control_memory_operation == MEM_STORE) bus_access = BUS_WRITE;
            else bus_access = BUS_READ;
            bus_addr = alu_result_latch;
            bus_wdata = store_data_latch;
        end
    end

    always_comb begin
        branch_displacement = {{14{decoded_imm16[15]}}, decoded_imm16, 2'b00};
        jump_displacement = {{4{decoded_imm26[25]}}, decoded_imm26, 2'b00};
        branch_taken = 1'b0;
        unique case (control_branch_predicate)
            BRANCH_EQUAL: branch_taken = (operand_lhs_latch == operand_rhs_latch);
            BRANCH_NOT_EQUAL: branch_taken = (operand_lhs_latch != operand_rhs_latch);
            BRANCH_SIGNED_LESS_THAN: branch_taken = ($signed(operand_lhs_latch) < $signed(operand_rhs_latch));
            BRANCH_SIGNED_GREATER_EQUAL: branch_taken = ($signed(operand_lhs_latch) >= $signed(operand_rhs_latch));
            default: branch_taken = 1'b0;
        endcase
    end

    always_comb begin
        writeback_value = alu_result_latch;
        unique case (control_writeback_source)
            WB_MEMORY: writeback_value = memory_data_latch;
            WB_PC_PLUS_4: writeback_value = pc + 32'd4;
            default: writeback_value = alu_result_latch;
        endcase
        writeback_destination = (control_register_destination == DEST_RETURN_ADDRESS) ? 5'd31 : decoded_rd;
        register_write_enable = (state == CPU_STATE_WRITEBACK) && control_reg_write;
    end

    function automatic cpu_fault_t fetch_fault(input bus_fault_t bus_error);
        case (bus_error)
            BUS_FAULT_MISALIGNED: fetch_fault = CPU_FAULT_MISALIGNED_INSTRUCTION_FETCH;
            BUS_FAULT_NON_EXECUTABLE: fetch_fault = CPU_FAULT_NON_EXECUTABLE_INSTRUCTION_FETCH;
            default: fetch_fault = CPU_FAULT_UNMAPPED_INSTRUCTION_FETCH;
        endcase
    endfunction

    function automatic cpu_fault_t load_fault(input bus_fault_t bus_error);
        if (bus_error == BUS_FAULT_MISALIGNED) load_fault = CPU_FAULT_MISALIGNED_LOAD;
        else load_fault = CPU_FAULT_UNMAPPED_LOAD;
    endfunction

    function automatic cpu_fault_t store_fault(input bus_fault_t bus_error);
        case (bus_error)
            BUS_FAULT_MISALIGNED: store_fault = CPU_FAULT_MISALIGNED_STORE;
            BUS_FAULT_READ_ONLY: store_fault = CPU_FAULT_READ_ONLY_STORE;
            default: store_fault = CPU_FAULT_UNMAPPED_STORE;
        endcase
    endfunction

    // These signals describe committed architectural effects, not attempted
    // writes. In particular, writes to immutable r0 do not set reg_write.
    task automatic record_retirement(input logic writes_register, input logic [4:0] destination,
                                     input logic [31:0] value, input logic [31:0] committed_next_pc,
                                     input logic writes_memory, input logic [31:0] memory_address,
                                     input logic [31:0] memory_value);
        retire_valid <= 1'b1;
        retire_pc <= pc;
        retire_instruction <= instruction_register;
        retire_next_pc <= committed_next_pc;
        retire_reg_write <= writes_register && (destination != 5'd0) && (value != writeback_current_value);
        retire_rd <= destination;
        retire_value <= value;
        retire_mem_write <= writes_memory;
        retire_mem_addr <= memory_address;
        retire_mem_value <= memory_value;
    endtask

    task automatic enter_fault(input cpu_fault_t error, input logic [31:0] error_instruction,
                               input logic address_is_valid, input logic [31:0] error_address);
        fault_code <= error;
        fault_pc <= pc;
        fault_instruction <= error_instruction;
        fault_address_valid <= address_is_valid;
        fault_address <= error_address;
        state <= CPU_STATE_FAULT;
    endtask

    always_ff @(posedge clk) begin
        if (reset) begin
            state <= CPU_STATE_FETCH;
            pc <= 32'h0000_0000;
            instruction_register <= 32'h0000_0000;
            operand_lhs_latch <= 32'h0000_0000;
            operand_rhs_latch <= 32'h0000_0000;
            alu_result_latch <= 32'h0000_0000;
            store_data_latch <= 32'h0000_0000;
            memory_data_latch <= 32'h0000_0000;
            next_pc_latch <= 32'h0000_0000;
            fault_code <= CPU_FAULT_NONE;
            fault_pc <= 32'h0000_0000;
            fault_instruction <= 32'h0000_0000;
            fault_address_valid <= 1'b0;
            fault_address <= 32'h0000_0000;
            retire_valid <= 1'b0;
            retire_pc <= 32'h0000_0000;
            retire_instruction <= 32'h0000_0000;
            retire_next_pc <= 32'h0000_0000;
            retire_reg_write <= 1'b0;
            retire_rd <= 5'h00;
            retire_value <= 32'h0000_0000;
            retire_mem_write <= 1'b0;
            retire_mem_addr <= 32'h0000_0000;
            retire_mem_value <= 32'h0000_0000;
        end else begin
            retire_valid <= 1'b0;
            retire_reg_write <= 1'b0;
            retire_mem_write <= 1'b0;
            case (state)
                CPU_STATE_FETCH: begin
                    if (bus_ready) begin
                        if (bus_fault == BUS_FAULT_NONE) begin
                            instruction_register <= bus_rdata;
                            state <= CPU_STATE_DECODE;
                        end else begin
                            enter_fault(fetch_fault(bus_fault), 32'h0000_0000, 1'b0, 32'h0000_0000);
                        end
                    end
                end
                CPU_STATE_DECODE: begin
                    if (!decode_valid) begin
                        enter_fault(decode_malformed ? CPU_FAULT_MALFORMED_INSTRUCTION : CPU_FAULT_ILLEGAL_INSTRUCTION,
                                    instruction_register, 1'b0, 32'h0000_0000);
                    end else if (!control_supported) begin
                        enter_fault(CPU_FAULT_UNSUPPORTED_INSTRUCTION, instruction_register, 1'b0, 32'h0000_0000);
                    end else begin
                        operand_lhs_latch <= rs1_data;
                        operand_rhs_latch <= control_alu_src_immediate ? immediate_value : rs2_data;
                        store_data_latch <= rs2_data;
                        next_pc_latch <= pc + 32'd4;
                        state <= CPU_STATE_EXECUTE;
                    end
                end
                CPU_STATE_EXECUTE: begin
                    alu_result_latch <= alu_result;
                    if (control_flow == FLOW_CONDITIONAL_BRANCH) begin
                        pc <= branch_taken ? (pc + 32'd4 + branch_displacement) : (pc + 32'd4);
                        record_retirement(1'b0, 5'h00, 32'h0000_0000,
                                          branch_taken ? (pc + 32'd4 + branch_displacement) : (pc + 32'd4),
                                          1'b0, 32'h0000_0000, 32'h0000_0000);
                        state <= CPU_STATE_FETCH;
                    end else if (control_flow == FLOW_RELATIVE_JUMP) begin
                        next_pc_latch <= pc + 32'd4 + jump_displacement;
                        if (!control_reg_write) begin
                            pc <= pc + 32'd4 + jump_displacement;
                            record_retirement(1'b0, 5'h00, 32'h0000_0000,
                                              pc + 32'd4 + jump_displacement,
                                              1'b0, 32'h0000_0000, 32'h0000_0000);
                            state <= CPU_STATE_FETCH;
                        end else begin
                            state <= CPU_STATE_WRITEBACK;
                        end
                    end else if (control_flow == FLOW_REGISTER_JUMP) begin
                        pc <= operand_lhs_latch;
                        record_retirement(1'b0, 5'h00, 32'h0000_0000, operand_lhs_latch,
                                          1'b0, 32'h0000_0000, 32'h0000_0000);
                        state <= CPU_STATE_FETCH;
                    end else if (control_memory_operation != MEM_NONE) begin
                        state <= CPU_STATE_MEMORY;
                    end else begin
                        state <= CPU_STATE_WRITEBACK;
                    end
                end
                CPU_STATE_MEMORY: begin
                    if (bus_ready) begin
                        if (bus_fault != BUS_FAULT_NONE) begin
                            if (control_memory_operation == MEM_LOAD) begin
                                enter_fault(load_fault(bus_fault), instruction_register, 1'b1, alu_result_latch);
                            end else begin
                                enter_fault(store_fault(bus_fault), instruction_register, 1'b1, alu_result_latch);
                            end
                        end else if (control_memory_operation == MEM_LOAD) begin
                            memory_data_latch <= bus_rdata;
                            state <= CPU_STATE_WRITEBACK;
                        end else begin
                            pc <= next_pc_latch;
                            record_retirement(1'b0, 5'h00, 32'h0000_0000, next_pc_latch,
                                              1'b1, alu_result_latch, store_data_latch);
                            state <= CPU_STATE_FETCH;
                        end
                    end
                end
                CPU_STATE_WRITEBACK: begin
                    pc <= next_pc_latch;
                    record_retirement(control_reg_write, writeback_destination, writeback_value, next_pc_latch,
                                      1'b0, 32'h0000_0000, 32'h0000_0000);
                    state <= control_halt ? CPU_STATE_HALTED : CPU_STATE_FETCH;
                end
                CPU_STATE_HALTED, CPU_STATE_FAULT: begin
                    state <= state;
                end
                default: state <= CPU_STATE_FAULT;
            endcase
        end
    end
endmodule
