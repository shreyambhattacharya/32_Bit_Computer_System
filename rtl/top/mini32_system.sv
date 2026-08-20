// Vendor-independent synthesizable Mini32 computer: CPU, bus, ROM, and RAM.
module mini32_system #(
    parameter ROM_INIT_FILE = ""
) (
    input  logic                    clk,
    input  logic                    reset,
    output logic                    halted,
    output logic                    faulted,
    output mini32_pkg::cpu_fault_t  fault_code,
    output logic [31:0]             pc,
    output logic                    retire_valid,
    output logic [31:0]             retire_pc,
    output logic [31:0]             retire_instruction,
    output logic                    retire_reg_write,
    output logic [4:0]              retire_rd,
    output logic [31:0]             retire_value
);
    import mini32_pkg::*;
    logic bus_valid, bus_ready;
    bus_access_t bus_access;
    bus_fault_t bus_fault;
    logic [31:0] bus_addr, bus_wdata, bus_rdata;
    logic [31:0] fault_pc, fault_instruction, fault_address;
    logic fault_address_valid;

    cpu_core cpu_core_instance (
        .clk(clk), .reset(reset), .bus_ready(bus_ready), .bus_rdata(bus_rdata), .bus_fault(bus_fault),
        .bus_valid(bus_valid), .bus_access(bus_access), .bus_addr(bus_addr), .bus_wdata(bus_wdata),
        .halted(halted), .faulted(faulted), .fault_code(fault_code), .fault_pc(fault_pc),
        .fault_instruction(fault_instruction), .fault_address_valid(fault_address_valid), .fault_address(fault_address),
        .pc(pc), .retire_valid(retire_valid), .retire_pc(retire_pc), .retire_instruction(retire_instruction),
        .retire_reg_write(retire_reg_write), .retire_rd(retire_rd), .retire_value(retire_value)
    );
    system_bus #(.ROM_INIT_FILE(ROM_INIT_FILE)) system_bus_instance (
        .clk(clk), .reset(reset), .request_valid(bus_valid), .request_access(bus_access),
        .request_addr(bus_addr), .request_wdata(bus_wdata), .response_ready(bus_ready),
        .response_rdata(bus_rdata), .response_fault(bus_fault)
    );
endmodule
