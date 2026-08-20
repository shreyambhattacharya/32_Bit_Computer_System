module tb_mini32_system;
    import mini32_pkg::*;
    logic clk = 1'b0, reset;
    logic memory_halted, memory_faulted, smoke_halted, smoke_faulted, fault_halted, fault_faulted, hello_halted, hello_faulted;
    logic readback_halted, readback_faulted;
    cpu_fault_t memory_fault_code, smoke_fault_code, fault_fault_code;
    logic [31:0] memory_pc, smoke_pc, fault_pc;
    logic memory_retire_valid, memory_retire_reg_write, smoke_retire_valid, smoke_retire_reg_write;
    logic fault_retire_valid, fault_retire_reg_write;
    logic [31:0] memory_retire_pc, memory_retire_instruction, memory_retire_value;
    logic [31:0] smoke_retire_pc, smoke_retire_instruction, smoke_retire_value;
    logic [31:0] fault_retire_pc, fault_retire_instruction, fault_retire_value;
    logic [4:0] memory_retire_rd, smoke_retire_rd, fault_retire_rd;
    logic readback_retire_valid, readback_retire_reg_write;
    logic [4:0] readback_retire_rd;
    logic [31:0] readback_retire_value, readback_debug_value;
    logic saw_memory_r3, saw_smoke_r3, saw_smoke_r4, saw_smoke_r5, saw_smoke_r6, fault_wrote_r2;
    logic saw_uart_status_read, saw_debug_value_read;
    logic hello_uart_tx_valid;
    logic [7:0] hello_uart_tx_data;
    logic [31:0] hello_debug_value;
    integer hello_uart_count = 0, failures = 0;

    mini32_system #(.ROM_INIT_FILE("build/generated/memory_roundtrip.memh")) memory_dut (
        .clk(clk), .reset(reset), .halted(memory_halted), .faulted(memory_faulted),
        .fault_code(memory_fault_code), .pc(memory_pc), .retire_valid(memory_retire_valid),
        .retire_pc(memory_retire_pc), .retire_instruction(memory_retire_instruction),
        .retire_reg_write(memory_retire_reg_write), .retire_rd(memory_retire_rd), .retire_value(memory_retire_value)
    );
    mini32_system #(.ROM_INIT_FILE("build/generated/rtl_system_smoke.memh")) smoke_dut (
        .clk(clk), .reset(reset), .halted(smoke_halted), .faulted(smoke_faulted),
        .fault_code(smoke_fault_code), .pc(smoke_pc), .retire_valid(smoke_retire_valid),
        .retire_pc(smoke_retire_pc), .retire_instruction(smoke_retire_instruction),
        .retire_reg_write(smoke_retire_reg_write), .retire_rd(smoke_retire_rd), .retire_value(smoke_retire_value)
    );
    mini32_system #(.ROM_INIT_FILE("build/generated/rtl_system_fault.memh")) fault_dut (
        .clk(clk), .reset(reset), .halted(fault_halted), .faulted(fault_faulted),
        .fault_code(fault_fault_code), .pc(fault_pc), .retire_valid(fault_retire_valid),
        .retire_pc(fault_retire_pc), .retire_instruction(fault_retire_instruction),
        .retire_reg_write(fault_retire_reg_write), .retire_rd(fault_retire_rd), .retire_value(fault_retire_value)
    );
    mini32_system #(.ROM_INIT_FILE("build/generated/hello_uart.memh")) hello_dut (
        .clk(clk), .reset(reset), .halted(hello_halted), .faulted(hello_faulted),
        .uart_tx_valid(hello_uart_tx_valid), .uart_tx_data(hello_uart_tx_data), .debug_value(hello_debug_value)
    );
    mini32_system #(.ROM_INIT_FILE("build/generated/peripheral_readback.memh")) readback_dut (
        .clk(clk), .reset(reset), .halted(readback_halted), .faulted(readback_faulted),
        .debug_value(readback_debug_value), .retire_valid(readback_retire_valid),
        .retire_reg_write(readback_retire_reg_write), .retire_rd(readback_retire_rd),
        .retire_value(readback_retire_value)
    );
    always #5 clk = ~clk;

    always @(posedge clk) begin
        if (reset) begin
            saw_memory_r3 <= 1'b0;
            saw_smoke_r3 <= 1'b0; saw_smoke_r4 <= 1'b0; saw_smoke_r5 <= 1'b0; saw_smoke_r6 <= 1'b0;
            fault_wrote_r2 <= 1'b0;
            hello_uart_count <= 0;
            saw_uart_status_read <= 1'b0;
            saw_debug_value_read <= 1'b0;
        end else begin
            if (memory_retire_valid && memory_retire_reg_write && memory_retire_rd == 5'd3 && memory_retire_value == 32'd42)
                saw_memory_r3 <= 1'b1;
            if (smoke_retire_valid && smoke_retire_reg_write && smoke_retire_rd == 5'd3 && smoke_retire_value == 32'd6)
                saw_smoke_r3 <= 1'b1;
            if (smoke_retire_valid && smoke_retire_reg_write && smoke_retire_rd == 5'd4 && smoke_retire_value == 32'd6)
                saw_smoke_r4 <= 1'b1;
            if (smoke_retire_valid && smoke_retire_reg_write && smoke_retire_rd == 5'd5 && smoke_retire_value == 32'd7)
                saw_smoke_r5 <= 1'b1;
            if (smoke_retire_valid && smoke_retire_reg_write && smoke_retire_rd == 5'd6 && smoke_retire_value == 32'd7)
                saw_smoke_r6 <= 1'b1;
            if (fault_retire_valid && fault_retire_reg_write && fault_retire_rd == 5'd2) fault_wrote_r2 <= 1'b1;
            if (hello_uart_tx_valid) hello_uart_count <= hello_uart_count + 1;
            if (readback_retire_valid && readback_retire_reg_write && readback_retire_rd == 5'd2 &&
                readback_retire_value == 32'h0000_0001) saw_uart_status_read <= 1'b1;
            if (readback_retire_valid && readback_retire_reg_write && readback_retire_rd == 5'd5 &&
                readback_retire_value == 32'hCAFE_BEEF) saw_debug_value_read <= 1'b1;
        end
    end

    task automatic check(input logic condition, input string message);
        if (!condition) begin $error("%s", message); failures = failures + 1; end
    endtask

    initial begin
        reset = 1'b1;
        repeat (2) @(posedge clk);
        reset = 1'b0;
        repeat (800) @(posedge clk);
        #1;
        check(memory_halted && !memory_faulted, "memory_roundtrip assembled ROM did not halt cleanly");
        check(saw_memory_r3, "memory_roundtrip did not retire r3 = 42");
        check(smoke_halted && !smoke_faulted, "rtl_system_smoke assembled ROM did not halt cleanly");
        check(saw_smoke_r3 && saw_smoke_r4 && saw_smoke_r5 && saw_smoke_r6,
              "rtl_system_smoke did not retire arithmetic/store/load results");
        check(fault_faulted && !fault_halted && fault_fault_code == CPU_FAULT_UNMAPPED_LOAD,
              "assembled unmapped-load program did not report CPU_FAULT_UNMAPPED_LOAD");
        check(!fault_wrote_r2, "faulting load incorrectly retired a register write");
        check(hello_halted && !hello_faulted && hello_uart_count == 14,
              "hello_uart did not emit 14 bytes and halt cleanly through RTL MMIO");
        check(readback_halted && !readback_faulted && readback_debug_value == 32'hCAFE_BEEF,
              "peripheral readback program did not retain Debug VALUE");
        check(saw_uart_status_read && saw_debug_value_read,
              "peripheral readback program did not retire UART/Debug read values");
        if (failures != 0) $fatal(1, "tb_mini32_system: %0d failures", failures);
        $display("tb_mini32_system passed");
        $finish;
    end
endmodule
