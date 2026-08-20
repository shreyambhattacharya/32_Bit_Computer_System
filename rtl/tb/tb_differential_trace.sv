// Generic JSONL trace runner. It consumes only mini32_system's verification
// outputs, so differential checks remain independent of private RTL state.
module tb_differential_trace #(
    parameter ROM_INIT_FILE = "",
    parameter integer MAX_CYCLES = 100000
);
    import mini32_pkg::*;
    logic clk = 1'b0, reset;
    logic halted, faulted;
    cpu_fault_t fault_code;
    logic [31:0] fault_pc, fault_instruction, fault_address, pc;
    logic fault_address_valid;
    logic retire_valid, retire_reg_write, retire_mem_write;
    logic [31:0] retire_pc, retire_instruction, retire_next_pc, retire_value;
    logic [31:0] retire_mem_addr, retire_mem_value;
    logic [4:0] retire_rd;
    integer retire_index = 0;
    logic uart_tx_valid;
    logic [7:0] uart_tx_data;
    logic [31:0] debug_value;
    logic [7:0] uart_bytes [0:1023];
    integer uart_count = 0;
    logic finished = 1'b0;

    mini32_system #(.ROM_INIT_FILE(ROM_INIT_FILE)) dut (.*);
    always #5 clk = ~clk;

    function automatic string fault_name(input cpu_fault_t fault);
        case (fault)
            CPU_FAULT_MISALIGNED_INSTRUCTION_FETCH: fault_name = "MisalignedInstructionFetch";
            CPU_FAULT_UNMAPPED_INSTRUCTION_FETCH: fault_name = "UnmappedInstructionFetch";
            CPU_FAULT_NON_EXECUTABLE_INSTRUCTION_FETCH: fault_name = "NonExecutableInstructionFetch";
            CPU_FAULT_ILLEGAL_INSTRUCTION: fault_name = "IllegalInstruction";
            CPU_FAULT_MALFORMED_INSTRUCTION: fault_name = "MalformedInstruction";
            CPU_FAULT_UNSUPPORTED_INSTRUCTION: fault_name = "UnsupportedInstruction";
            CPU_FAULT_MISALIGNED_LOAD: fault_name = "MisalignedLoad";
            CPU_FAULT_UNMAPPED_LOAD: fault_name = "UnmappedLoad";
            CPU_FAULT_MISALIGNED_STORE: fault_name = "MisalignedStore";
            CPU_FAULT_UNMAPPED_STORE: fault_name = "UnmappedStore";
            CPU_FAULT_READ_ONLY_STORE: fault_name = "ReadOnlyStore";
            default: fault_name = "None";
        endcase
    endfunction

    function automatic string uart_hex();
        string result;
        integer index;
        begin
            result = "";
            for (index = 0; index < uart_count; index = index + 1)
                result = {result, $sformatf("%02x", uart_bytes[index])};
            uart_hex = result;
        end
    endfunction

    always @(posedge clk) begin
        if (!reset && !finished) begin
            if (uart_tx_valid) begin
                if (uart_count >= 1024) $fatal(1, "UART transcript exceeded 1024 bytes");
                uart_bytes[uart_count] <= uart_tx_data;
                uart_count <= uart_count + 1;
            end
            if (retire_valid) begin
                $display("MINI32_TRACE {\"type\":\"retire\",\"index\":%0d,\"pc\":\"%08X\",\"instruction\":\"%08X\",\"next_pc\":\"%08X\",\"reg_write\":%s,\"rd\":%0d,\"reg_value\":\"%08X\",\"mem_write\":%s,\"mem_addr\":\"%08X\",\"mem_value\":\"%08X\"}",
                         retire_index, retire_pc, retire_instruction, retire_next_pc,
                         retire_reg_write ? "true" : "false", retire_rd, retire_value,
                         retire_mem_write ? "true" : "false", retire_mem_addr, retire_mem_value);
                retire_index <= retire_index + 1;
            end
            if (halted) begin
                $display("MINI32_TRACE {\"type\":\"final\",\"status\":\"halted\",\"pc\":\"%08X\",\"retired\":%0d,\"uart_tx\":\"%s\",\"debug_value\":\"%08X\"}",
                         pc, retire_index + (retire_valid ? 1 : 0), uart_hex(), debug_value);
                finished <= 1'b1;
                $finish;
            end else if (faulted) begin
                $display("MINI32_TRACE {\"type\":\"final\",\"status\":\"faulted\",\"pc\":\"%08X\",\"retired\":%0d,\"uart_tx\":\"%s\",\"debug_value\":\"%08X\",\"fault\":\"%s\",\"fault_pc\":\"%08X\",\"fault_instruction\":\"%08X\",\"fault_address_valid\":%s,\"fault_address\":\"%08X\"}",
                         pc, retire_index + (retire_valid ? 1 : 0), uart_hex(), debug_value, fault_name(fault_code),
                         fault_pc, fault_instruction, fault_address_valid ? "true" : "false", fault_address);
                finished <= 1'b1;
                $finish;
            end
        end
    end

    initial begin
        reset = 1'b1;
        repeat (2) @(posedge clk);
        reset = 1'b0;
        for (int cycle = 0; cycle < MAX_CYCLES; cycle++) @(posedge clk);
        if (!finished) begin
            $display("MINI32_TRACE_ERROR cycle limit reached after %0d cycles", MAX_CYCLES);
            $fatal(1, "differential trace cycle limit reached");
        end
    end
endmodule
