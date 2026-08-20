module tb_cpu_core;
    import mini32_pkg::*;
    import mini32_tb_pkg::*;

    logic clk = 1'b0, reset;
    logic bus_ready;
    logic [31:0] bus_rdata;
    bus_fault_t bus_fault;
    logic bus_valid;
    bus_access_t bus_access;
    logic [31:0] bus_addr, bus_wdata;
    logic halted, faulted;
    cpu_fault_t fault_code;
    logic [31:0] fault_pc, fault_instruction, fault_address;
    logic fault_address_valid;
    logic [31:0] pc;
    logic retire_valid, retire_reg_write;
    logic [31:0] retire_pc, retire_instruction, retire_next_pc, retire_value;
    logic [4:0] retire_rd;
    logic retire_mem_write;
    logic [31:0] retire_mem_addr, retire_mem_value;

    logic [31:0] instruction_memory [0:255];
    logic [31:0] data_memory [0:255];
    logic active;
    bus_access_t pending_access;
    logic [31:0] pending_addr, pending_wdata;
    integer remaining_waits, configured_waits;
    bus_fault_t injected_fetch_fault, injected_data_fault;
    integer failures = 0, retire_count = 0;
    logic stalled_request_seen;
    logic saw_fetch_stall, saw_memory_stall;
    bus_access_t stalled_access;
    logic [31:0] stalled_addr, stalled_wdata;
    logic saw_r0_retirement, saw_branch_retirement, saw_jump_retirement, saw_jal_retirement;
    logic saw_jr_retirement, saw_store_retirement, saw_halt_retirement;
    logic checking_retirement_metadata;

    cpu_core dut (.*);
    always #5 clk = ~clk;

    task automatic check(input logic condition, input string message);
        if (!condition) begin $error("%s", message); failures = failures + 1; end
    endtask

    always_comb begin
        bus_ready = active && (remaining_waits == 0);
        bus_rdata = 32'h0000_0000;
        bus_fault = BUS_FAULT_NONE;
        if (bus_ready) begin
            if (pending_access == BUS_FETCH && injected_fetch_fault != BUS_FAULT_NONE) begin
                bus_fault = injected_fetch_fault;
            end else if (pending_access != BUS_FETCH && injected_data_fault != BUS_FAULT_NONE) begin
                bus_fault = injected_data_fault;
            end else if ((pending_addr & 32'h0000_0003) != 0) begin
                bus_fault = BUS_FAULT_MISALIGNED;
            end else if (pending_access == BUS_FETCH) begin
                if (pending_addr[31:10] != 22'h0) bus_fault = BUS_FAULT_UNMAPPED;
                else bus_rdata = instruction_memory[pending_addr[9:2]];
            end else if (pending_addr[31:16] == 16'h1000) begin
                if (pending_access == BUS_READ) bus_rdata = data_memory[pending_addr[9:2]];
            end else begin
                bus_fault = BUS_FAULT_UNMAPPED;
            end
        end
    end

    always @(posedge clk) begin
        if (reset) begin
            active <= 1'b0;
            remaining_waits <= 0;
            retire_count <= 0;
            stalled_request_seen <= 1'b0;
            saw_fetch_stall <= 1'b0;
            saw_memory_stall <= 1'b0;
            saw_r0_retirement <= 1'b0;
            saw_branch_retirement <= 1'b0;
            saw_jump_retirement <= 1'b0;
            saw_jal_retirement <= 1'b0;
            saw_jr_retirement <= 1'b0;
            saw_store_retirement <= 1'b0;
            saw_halt_retirement <= 1'b0;
        end else begin
            if (retire_valid) retire_count <= retire_count + 1;
            if (checking_retirement_metadata && retire_valid && retire_pc == 32'h0000_0000) begin
                check(!retire_reg_write && retire_next_pc == 32'h0000_0004 && !retire_mem_write,
                      "r0 write retirement metadata is wrong");
                saw_r0_retirement <= 1'b1;
            end
            if (checking_retirement_metadata && retire_valid && retire_pc == 32'h0000_0008) begin
                check(retire_next_pc == 32'h0000_0010 && !retire_reg_write && !retire_mem_write,
                      "branch retirement next PC is wrong");
                saw_branch_retirement <= 1'b1;
            end
            if (checking_retirement_metadata && retire_valid && retire_pc == 32'h0000_0014) begin
                check(retire_next_pc == 32'h0000_0018 && !retire_reg_write && !retire_mem_write,
                      "J retirement next PC is wrong");
                saw_jump_retirement <= 1'b1;
            end
            if (checking_retirement_metadata && retire_valid && retire_pc == 32'h0000_0010 && retire_instruction[31:26] == OP_JAL) begin
                check(retire_next_pc == 32'h0000_0024 && retire_reg_write && retire_rd == 5'd31 &&
                      retire_value == 32'h0000_0014, "JAL retirement metadata is wrong");
                saw_jal_retirement <= 1'b1;
            end
            if (checking_retirement_metadata && retire_valid && retire_pc == 32'h0000_0028) begin
                check(retire_next_pc == 32'h0000_0014 && !retire_reg_write && !retire_mem_write,
                      "JR retirement next PC is wrong");
                saw_jr_retirement <= 1'b1;
            end
            if (checking_retirement_metadata && retire_valid && retire_pc == 32'h0000_001C) begin
                check(retire_mem_write && retire_mem_addr == 32'h1000_0000 && retire_mem_value == 32'd3 &&
                      retire_next_pc == 32'h0000_0020, "SW retirement metadata is wrong");
                saw_store_retirement <= 1'b1;
            end
            if (checking_retirement_metadata && retire_valid && retire_instruction == {OP_HALT, 26'h0}) begin
                check(retire_next_pc == retire_pc + 32'd4 && !retire_reg_write && !retire_mem_write,
                      "HALT retirement metadata is wrong");
                saw_halt_retirement <= 1'b1;
            end
            if (bus_valid && !bus_ready) begin
                if (bus_access == BUS_FETCH) saw_fetch_stall <= 1'b1;
                else saw_memory_stall <= 1'b1;
                if (stalled_request_seen) begin
                    check(bus_access == stalled_access && bus_addr == stalled_addr && bus_wdata == stalled_wdata,
                          "CPU request changed while stalled");
                end else begin
                    stalled_request_seen <= 1'b1;
                    stalled_access <= bus_access;
                    stalled_addr <= bus_addr;
                    stalled_wdata <= bus_wdata;
                end
            end else begin
                stalled_request_seen <= 1'b0;
            end

            if (!active && bus_valid) begin
                active <= 1'b1;
                pending_access <= bus_access;
                pending_addr <= bus_addr;
                pending_wdata <= bus_wdata;
                remaining_waits <= configured_waits;
            end else if (active && remaining_waits != 0) begin
                remaining_waits <= remaining_waits - 1;
            end else if (active && remaining_waits == 0) begin
                if (pending_access == BUS_WRITE && bus_fault == BUS_FAULT_NONE &&
                    pending_addr[31:16] == 16'h1000) begin
                    data_memory[pending_addr[9:2]] <= pending_wdata;
                end
                active <= 1'b0;
            end
        end
    end

    task automatic clear_memories;
        for (int index = 0; index < 256; index++) begin
            instruction_memory[index] = 32'h0000_0000;
            data_memory[index] = 32'h0000_0000;
        end
    endtask

    task automatic start_case(input integer waits);
        checking_retirement_metadata = 1'b0;
        configured_waits = waits;
        injected_fetch_fault = BUS_FAULT_NONE;
        injected_data_fault = BUS_FAULT_NONE;
        reset = 1'b1;
        repeat (2) @(posedge clk);
        reset = 1'b0;
        #1;
        check(!halted && !faulted && pc == 32'h0000_0000, "reset did not recover CPU");
    endtask

    task automatic run_to_stop(input integer maximum_cycles, input string message);
        for (int cycle = 0; cycle < maximum_cycles && !halted && !faulted; cycle++) begin
            @(posedge clk);
        end
        #1;
        check(halted || faulted, message);
    endtask

    task automatic test_arithmetic;
        clear_memories();
        instruction_memory[0] = encode_i(OP_ADDI, 5'd1, 5'd0, 16'd7);
        instruction_memory[1] = encode_i(OP_ADDI, 5'd2, 5'd0, 16'd5);
        instruction_memory[2] = encode_r(OP_ADD, 5'd3, 5'd1, 5'd2);
        instruction_memory[3] = encode_r(OP_SUB, 5'd4, 5'd3, 5'd2);
        instruction_memory[4] = encode_i(OP_ADDI, 5'd0, 5'd0, 16'd99);
        instruction_memory[5] = encode_i(OP_LUI, 5'd10, 5'd0, 16'h1000);
        instruction_memory[6] = encode_s(5'd3, 5'd10, 16'd0);
        instruction_memory[7] = encode_s(5'd4, 5'd10, 16'd4);
        instruction_memory[8] = encode_s(5'd0, 5'd10, 16'd8);
        instruction_memory[9] = {OP_HALT, 26'h0};
        start_case(0); run_to_stop(300, "arithmetic program did not stop");
        check(halted && !faulted, "arithmetic program faulted");
        check(data_memory[0] == 32'd12 && data_memory[1] == 32'd7 && data_memory[2] == 32'd0,
              "arithmetic or r0 result is wrong");
    endtask

    task automatic test_memory_wait_states;
        clear_memories();
        instruction_memory[0] = encode_i(OP_LUI, 5'd1, 5'd0, 16'h1000);
        instruction_memory[1] = encode_i(OP_ADDI, 5'd2, 5'd0, 16'd42);
        instruction_memory[2] = encode_s(5'd2, 5'd1, 16'd0);
        instruction_memory[3] = encode_i(OP_LW, 5'd3, 5'd1, 16'd0);
        instruction_memory[4] = encode_s(5'd3, 5'd1, 16'd4);
        instruction_memory[5] = {OP_HALT, 26'h0};
        start_case(3); run_to_stop(800, "wait-state memory program did not stop");
        check(halted && !faulted && data_memory[0] == 32'd42 && data_memory[1] == 32'd42,
              "load/store wait-state roundtrip failed");
        check(saw_fetch_stall && saw_memory_stall, "fetch and memory wait states were not both observed");
    endtask

    task automatic test_logical_immediate;
        clear_memories();
        instruction_memory[0] = encode_i(OP_ADDI, 5'd1, 5'd0, 16'hff00);
        instruction_memory[1] = encode_i(OP_ANDI, 5'd2, 5'd1, 16'h8000);
        instruction_memory[2] = encode_i(OP_ORI, 5'd3, 5'd0, 16'hffff);
        instruction_memory[3] = encode_i(OP_XORI, 5'd4, 5'd3, 16'hffff);
        instruction_memory[4] = encode_i(OP_ADDI, 5'd5, 5'd0, 16'd16);
        instruction_memory[5] = encode_r(OP_AND, 5'd6, 5'd1, 5'd3);
        instruction_memory[6] = encode_r(OP_OR, 5'd7, 5'd2, 5'd4);
        instruction_memory[7] = encode_r(OP_XOR, 5'd8, 5'd3, 5'd1);
        instruction_memory[8] = encode_r(OP_SLT, 5'd9, 5'd1, 5'd0);
        instruction_memory[9] = encode_r(OP_SHL, 5'd11, 5'd3, 5'd5);
        instruction_memory[10] = encode_r(OP_SHR, 5'd12, 5'd11, 5'd5);
        instruction_memory[11] = encode_i(OP_LUI, 5'd10, 5'd0, 16'h1000);
        instruction_memory[12] = encode_s(5'd2, 5'd10, 16'd0);
        instruction_memory[13] = encode_s(5'd4, 5'd10, 16'd4);
        instruction_memory[14] = encode_s(5'd6, 5'd10, 16'd8);
        instruction_memory[15] = encode_s(5'd7, 5'd10, 16'd12);
        instruction_memory[16] = encode_s(5'd8, 5'd10, 16'd16);
        instruction_memory[17] = encode_s(5'd9, 5'd10, 16'd20);
        instruction_memory[18] = encode_s(5'd12, 5'd10, 16'd24);
        instruction_memory[19] = {OP_HALT, 26'h0};
        start_case(0); run_to_stop(800, "logical/immediate program did not stop");
        check(halted && !faulted && data_memory[0] == 32'h0000_8000 && data_memory[1] == 32'h0 &&
              data_memory[2] == 32'h0000_ff00 && data_memory[3] == 32'h0000_8000 &&
              data_memory[4] == 32'hffff_00ff && data_memory[5] == 32'd1 && data_memory[6] == 32'h0000_ffff,
              "logical/immediate results are wrong");
    endtask

    task automatic test_control_flow;
        clear_memories();
        instruction_memory[0] = encode_i(OP_ADDI, 5'd1, 5'd0, 16'd3);
        instruction_memory[1] = encode_i(OP_ADDI, 5'd2, 5'd0, 16'd0);
        instruction_memory[2] = encode_r(OP_ADD, 5'd2, 5'd2, 5'd1);
        instruction_memory[3] = encode_i(OP_ADDI, 5'd1, 5'd1, 16'hffff);
        instruction_memory[4] = encode_b(OP_BNE, 5'd1, 5'd0, 16'hfffd);
        instruction_memory[5] = encode_b(OP_BEQ, 5'd1, 5'd0, 16'd1);
        instruction_memory[6] = encode_i(OP_ADDI, 5'd3, 5'd0, 16'd99);
        instruction_memory[7] = encode_b(OP_BLT, 5'd1, 5'd2, 16'd1);
        instruction_memory[8] = encode_i(OP_ADDI, 5'd3, 5'd0, 16'd88);
        instruction_memory[9] = encode_b(OP_BGE, 5'd2, 5'd1, 16'd1);
        instruction_memory[10] = encode_i(OP_ADDI, 5'd3, 5'd0, 16'd77);
        instruction_memory[11] = encode_j(OP_J, 26'd1);
        instruction_memory[12] = encode_i(OP_ADDI, 5'd3, 5'd0, 16'd66);
        instruction_memory[13] = encode_i(OP_LUI, 5'd10, 5'd0, 16'h1000);
        instruction_memory[14] = encode_s(5'd2, 5'd10, 16'd0);
        instruction_memory[15] = {OP_HALT, 26'h0};
        start_case(0); run_to_stop(600, "control-flow program did not stop");
        check(halted && !faulted && data_memory[0] == 32'd6, "branch loop result is wrong");
    endtask

    task automatic test_branch_edges;
        clear_memories();
        instruction_memory[0] = encode_i(OP_ADDI, 5'd1, 5'd0, 16'd1);
        instruction_memory[1] = encode_b(OP_BEQ, 5'd1, 5'd0, 16'd1);
        instruction_memory[2] = encode_i(OP_ADDI, 5'd2, 5'd0, 16'd7);
        instruction_memory[3] = encode_b(OP_BEQ, 5'd2, 5'd2, 16'd1);
        instruction_memory[4] = encode_i(OP_ADDI, 5'd2, 5'd0, 16'd99);
        instruction_memory[5] = encode_i(OP_LUI, 5'd10, 5'd0, 16'h1000);
        instruction_memory[6] = encode_s(5'd2, 5'd10, 16'd0);
        instruction_memory[7] = {OP_HALT, 26'h0};
        start_case(0); run_to_stop(300, "branch edge program did not stop");
        check(halted && !faulted && data_memory[0] == 32'd7, "taken/non-taken BEQ behavior is wrong");
    endtask

    task automatic test_call_return;
        clear_memories();
        instruction_memory[0] = encode_i(OP_ADDI, 5'd1, 5'd0, 16'd3);
        instruction_memory[1] = encode_j(OP_JAL, 26'd3);
        instruction_memory[2] = encode_i(OP_LUI, 5'd10, 5'd0, 16'h1000);
        instruction_memory[3] = encode_s(5'd4, 5'd10, 16'd0);
        instruction_memory[4] = {OP_HALT, 26'h0};
        instruction_memory[5] = encode_i(OP_ADDI, 5'd4, 5'd1, 16'd3);
        instruction_memory[6] = encode_i(OP_LUI, 5'd11, 5'd0, 16'h1000);
        instruction_memory[7] = encode_s(5'd31, 5'd11, 16'd4);
        instruction_memory[8] = encode_jr(5'd31);
        start_case(0); run_to_stop(400, "JAL/JR program did not stop");
        check(halted && !faulted && data_memory[0] == 32'd6 && data_memory[1] == 32'd8,
              "JAL/JR result or return address is wrong");
        check(retire_count == 9, "JAL/JR retirement count is wrong");
    endtask

    task automatic expect_fault(input logic [31:0] word, input cpu_fault_t expected, input string message);
        clear_memories(); instruction_memory[0] = word;
        start_case(0); run_to_stop(100, message);
        check(faulted && fault_code == expected && fault_pc == 32'h0000_0000 && !retire_valid && !bus_valid,
              message);
    endtask

    task automatic test_faults;
        expect_fault({6'h3f, 26'h0}, CPU_FAULT_ILLEGAL_INSTRUCTION, "illegal opcode fault");
        expect_fault({OP_HALT, 5'd1, 21'h0}, CPU_FAULT_MALFORMED_INSTRUCTION, "malformed encoding fault");

        clear_memories(); instruction_memory[0] = 32'h0000_0000; injected_fetch_fault = BUS_FAULT_MISALIGNED;
        start_case(0); injected_fetch_fault = BUS_FAULT_MISALIGNED; run_to_stop(100, "misaligned fetch fault");
        check(fault_code == CPU_FAULT_MISALIGNED_INSTRUCTION_FETCH, "misaligned fetch mapping");
        injected_fetch_fault = BUS_FAULT_UNMAPPED; start_case(0); injected_fetch_fault = BUS_FAULT_UNMAPPED;
        run_to_stop(100, "unmapped fetch fault"); check(fault_code == CPU_FAULT_UNMAPPED_INSTRUCTION_FETCH, "unmapped fetch mapping");
        injected_fetch_fault = BUS_FAULT_NON_EXECUTABLE; start_case(0); injected_fetch_fault = BUS_FAULT_NON_EXECUTABLE;
        run_to_stop(100, "non-executable fetch fault"); check(fault_code == CPU_FAULT_NON_EXECUTABLE_INSTRUCTION_FETCH, "non-executable fetch mapping");

        clear_memories(); instruction_memory[0] = encode_i(OP_ADDI, 5'd1, 5'd0, 16'd2);
        instruction_memory[1] = encode_i(OP_LW, 5'd2, 5'd1, 16'd0); start_case(0); run_to_stop(150, "misaligned load fault");
        check(fault_code == CPU_FAULT_MISALIGNED_LOAD && fault_pc == 32'd4 && fault_address_valid,
              "misaligned load mapping");
        clear_memories(); instruction_memory[0] = encode_i(OP_LUI, 5'd1, 5'd0, 16'h3000);
        instruction_memory[1] = encode_i(OP_LW, 5'd2, 5'd1, 16'd0); start_case(0); run_to_stop(150, "unmapped load fault");
        check(fault_code == CPU_FAULT_UNMAPPED_LOAD && fault_pc == 32'd4, "unmapped load mapping");
        clear_memories(); instruction_memory[0] = encode_i(OP_ADDI, 5'd1, 5'd0, 16'd2);
        instruction_memory[1] = encode_i(OP_ADDI, 5'd2, 5'd0, 16'd1); instruction_memory[2] = encode_s(5'd2, 5'd1, 16'd0);
        start_case(0); run_to_stop(200, "misaligned store fault");
        check(fault_code == CPU_FAULT_MISALIGNED_STORE && fault_pc == 32'd8, "misaligned store mapping");
        clear_memories(); instruction_memory[0] = encode_i(OP_LUI, 5'd1, 5'd0, 16'h3000);
        instruction_memory[1] = encode_i(OP_ADDI, 5'd2, 5'd0, 16'd1); instruction_memory[2] = encode_s(5'd2, 5'd1, 16'd0);
        start_case(0); run_to_stop(200, "unmapped store fault");
        check(fault_code == CPU_FAULT_UNMAPPED_STORE && fault_pc == 32'd8, "unmapped store mapping");
        clear_memories(); instruction_memory[0] = encode_i(OP_LUI, 5'd1, 5'd0, 16'h1000);
        instruction_memory[1] = encode_i(OP_ADDI, 5'd2, 5'd0, 16'd1); instruction_memory[2] = encode_s(5'd2, 5'd1, 16'd0);
        start_case(0); injected_data_fault = BUS_FAULT_READ_ONLY; run_to_stop(200, "read-only store fault");
        check(fault_code == CPU_FAULT_READ_ONLY_STORE && fault_pc == 32'd8, "read-only store mapping");
    endtask

    task automatic test_misaligned_jr;
        clear_memories(); instruction_memory[0] = encode_i(OP_ADDI, 5'd1, 5'd0, 16'd2);
        instruction_memory[1] = encode_jr(5'd1); start_case(0); run_to_stop(150, "misaligned JR did not fault");
        check(fault_code == CPU_FAULT_MISALIGNED_INSTRUCTION_FETCH && fault_pc == 32'd2,
              "JR fetch fault mapping");
    endtask

    task automatic test_negative_jump;
        clear_memories(); instruction_memory[0] = encode_j(OP_J, 26'h3ffffff);
        start_case(0);
        repeat (40) @(posedge clk);
        #1;
        check(!faulted && !halted && pc == 32'h0000_0000 && retire_count != 0, "negative J did not loop at PC zero");
    endtask

    task automatic test_retirement_metadata;
        clear_memories();
        instruction_memory[0] = encode_i(OP_ADDI, 5'd0, 5'd0, 16'd1);
        instruction_memory[1] = encode_i(OP_ADDI, 5'd1, 5'd0, 16'd3);
        instruction_memory[2] = encode_b(OP_BEQ, 5'd1, 5'd1, 16'd1);
        instruction_memory[3] = encode_i(OP_ADDI, 5'd1, 5'd0, 16'd99);
        instruction_memory[4] = encode_j(OP_JAL, 26'd4);
        instruction_memory[5] = encode_j(OP_J, 26'd0);
        instruction_memory[6] = encode_i(OP_LUI, 5'd10, 5'd0, 16'h1000);
        instruction_memory[7] = encode_s(5'd1, 5'd10, 16'd0);
        instruction_memory[8] = {OP_HALT, 26'h0};
        instruction_memory[9] = encode_i(OP_ADDI, 5'd2, 5'd0, 16'd7);
        instruction_memory[10] = encode_jr(5'd31);
        start_case(0); checking_retirement_metadata = 1'b1; run_to_stop(500, "retirement-metadata program did not stop");
        check(halted && !faulted && saw_r0_retirement && saw_branch_retirement && saw_jump_retirement &&
              saw_jal_retirement && saw_jr_retirement && saw_store_retirement && saw_halt_retirement,
              "retirement metadata coverage is incomplete");

        clear_memories();
        instruction_memory[0] = encode_i(OP_ADDI, 5'd1, 5'd0, 16'd1);
        instruction_memory[1] = encode_s(5'd1, 5'd0, 16'd0);
        start_case(0); injected_data_fault = BUS_FAULT_READ_ONLY; run_to_stop(200, "faulting store did not stop");
        repeat (2) @(posedge clk);
        check(faulted && fault_code == CPU_FAULT_READ_ONLY_STORE && retire_count == 1,
              "faulting store incorrectly retired");
    endtask

    initial begin
        reset = 1'b0; active = 1'b0; configured_waits = 0; injected_fetch_fault = BUS_FAULT_NONE;
        injected_data_fault = BUS_FAULT_NONE;
        test_arithmetic();
        test_memory_wait_states();
        test_logical_immediate();
        test_control_flow();
        test_branch_edges();
        test_call_return();
        test_misaligned_jr();
        test_negative_jump();
        test_retirement_metadata();
        test_faults();
        if (failures != 0) $fatal(1, "tb_cpu_core: %0d failures", failures);
        $display("tb_cpu_core passed");
        $finish;
    end
endmodule
