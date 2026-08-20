module tb_system_bus;
    import mini32_pkg::*;
    logic clk = 1'b0, reset, request_valid;
    bus_access_t request_access;
    logic [31:0] request_addr, request_wdata;
    logic response_ready;
    logic [31:0] response_rdata;
    bus_fault_t response_fault;
    integer failures = 0, write_count = 0;

    system_bus dut (.*);
    always #5 clk = ~clk;
    always @(posedge clk) if (!reset && dut.ram_write_enable) write_count <= write_count + 1;

    task automatic check(input logic condition, input string message);
        if (!condition) begin $error("%s", message); failures = failures + 1; end
    endtask

    task automatic transaction(input bus_access_t access, input logic [31:0] address,
                               input logic [31:0] data, input bus_fault_t expected_fault,
                               input logic [31:0] expected_data, input string message);
        request_access = access; request_addr = address; request_wdata = data; request_valid = 1'b1;
        @(posedge clk); #1; check(!response_ready, "bus responded in request capture cycle");
        @(posedge clk); #1;
        check(response_ready, "bus did not complete synchronous transaction");
        check(response_fault === expected_fault, message);
        if (expected_fault == BUS_FAULT_NONE && access != BUS_WRITE)
            check(response_rdata === expected_data, message);
        request_valid = 1'b0;
        @(posedge clk); #1; check(!response_ready, "ready remained asserted after response consumption");
    endtask

    initial begin
        reset = 1'b1; request_valid = 1'b0; request_access = BUS_FETCH;
        request_addr = '0; request_wdata = '0;
        dut.rom_instance.memory[0] = 32'hCAFE_BABE;
        @(posedge clk); #1; reset = 1'b0;
        transaction(BUS_FETCH, ROM_BASE, 32'h0, BUS_FAULT_NONE, 32'hCAFE_BABE, "ROM fetch failed");
        transaction(BUS_READ, ROM_BASE, 32'h0, BUS_FAULT_NONE, 32'hCAFE_BABE, "ROM data read failed");
        transaction(BUS_WRITE, ROM_BASE, 32'h1234, BUS_FAULT_READ_ONLY, 32'h0, "ROM write did not fault read-only");
        transaction(BUS_WRITE, RAM_BASE, 32'h1020_3040, BUS_FAULT_NONE, 32'h0, "RAM write failed");
        transaction(BUS_READ, RAM_BASE, 32'h0, BUS_FAULT_NONE, 32'h1020_3040, "RAM read failed");
        check(write_count == 1, "one store caused more than one RAM write");
        transaction(BUS_FETCH, RAM_BASE, 32'h0, BUS_FAULT_NON_EXECUTABLE, 32'h0, "RAM fetch did not fault non-executable");
        transaction(BUS_FETCH, 32'h0000_0002, 32'h0, BUS_FAULT_MISALIGNED, 32'h0, "misaligned fetch fault wrong");
        transaction(BUS_READ, 32'h1000_0002, 32'h0, BUS_FAULT_MISALIGNED, 32'h0, "misaligned read fault wrong");
        transaction(BUS_WRITE, 32'h1000_0002, 32'h1, BUS_FAULT_MISALIGNED, 32'h0, "misaligned write fault wrong");
        transaction(BUS_READ, 32'h3000_0000, 32'h0, BUS_FAULT_UNMAPPED, 32'h0, "unmapped read fault wrong");
        transaction(BUS_WRITE, 32'h3000_0000, 32'h0, BUS_FAULT_UNMAPPED, 32'h0, "unmapped write fault wrong");
        transaction(BUS_READ, ROM_LAST + 32'd1, 32'h0, BUS_FAULT_UNMAPPED, 32'h0, "address beyond ROM aliased");
        transaction(BUS_READ, RAM_LAST + 32'd1, 32'h0, BUS_FAULT_UNMAPPED, 32'h0, "address beyond RAM aliased");
        transaction(BUS_FETCH, UART_BASE, 32'h0, BUS_FAULT_NON_EXECUTABLE, 32'h0, "reserved MMIO fetch fault wrong");
        // Reset during an in-flight request must discard the captured request.
        request_access = BUS_FETCH; request_addr = ROM_BASE; request_wdata = 32'h0; request_valid = 1'b1;
        @(posedge clk); #1;
        reset = 1'b1; request_valid = 1'b0;
        @(posedge clk); #1; check(!response_ready, "reset did not cancel pending bus transaction");
        reset = 1'b0;
        transaction(BUS_FETCH, ROM_BASE, 32'h0, BUS_FAULT_NONE, 32'hCAFE_BABE, "bus did not recover after reset");
        if (failures != 0) $fatal(1, "tb_system_bus: %0d failures", failures);
        $display("tb_system_bus passed");
        $finish;
    end
endmodule
