// Vendor-independent synthesizable Mini32 computer: CPU, bus, ROM, and RAM.
module mini32_system #(
    parameter ROM_INIT_FILE = ""
) (
    input  logic                    clk,
    input  logic                    reset,
    input  logic [31:0]             gpio_input,
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
    output logic [31:0]             retire_mem_value,
    output logic                    uart_tx_valid,
    output logic [7:0]              uart_tx_data,
    output logic [31:0]             debug_value,
    output logic [31:0]             gpio_output,
    output logic [31:0]             gpio_direction,
    output logic [31:0]             timer_counter,
    output logic [31:0]             timer_compare,
    output logic [31:0]             timer_control
);
    import mini32_pkg::*;
    logic bus_valid, bus_ready;
    bus_access_t bus_access;
    bus_fault_t bus_fault;
    logic [31:0] bus_addr, bus_wdata, bus_rdata;

    cpu_core cpu_core_instance (
        .clk(clk), .reset(reset), .bus_ready(bus_ready), .bus_rdata(bus_rdata), .bus_fault(bus_fault),
        .bus_valid(bus_valid), .bus_access(bus_access), .bus_addr(bus_addr), .bus_wdata(bus_wdata),
        .halted(halted), .faulted(faulted), .fault_code(fault_code), .fault_pc(fault_pc),
        .fault_instruction(fault_instruction), .fault_address_valid(fault_address_valid), .fault_address(fault_address),
        .pc(pc), .retire_valid(retire_valid), .retire_pc(retire_pc), .retire_instruction(retire_instruction),
        .retire_next_pc(retire_next_pc), .retire_reg_write(retire_reg_write), .retire_rd(retire_rd),
        .retire_value(retire_value), .retire_mem_write(retire_mem_write), .retire_mem_addr(retire_mem_addr),
        .retire_mem_value(retire_mem_value)
    );
    system_bus #(.ROM_INIT_FILE(ROM_INIT_FILE)) system_bus_instance (
        .clk(clk), .reset(reset), .retire_tick(retire_valid), .gpio_input(gpio_input),
        .request_valid(bus_valid), .request_access(bus_access),
        .request_addr(bus_addr), .request_wdata(bus_wdata), .response_ready(bus_ready),
        .response_rdata(bus_rdata), .response_fault(bus_fault), .uart_tx_valid(uart_tx_valid),
        .uart_tx_data(uart_tx_data), .debug_value(debug_value), .gpio_output(gpio_output),
        .gpio_direction(gpio_direction), .timer_counter(timer_counter), .timer_compare(timer_compare),
        .timer_control(timer_control)
    );
endmodule
