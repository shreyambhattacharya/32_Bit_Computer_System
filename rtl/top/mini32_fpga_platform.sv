// Generic, vendor-independent FPGA-facing wrapper.  Board-specific pin and
// clock/reset adaptation intentionally belongs in a later wrapper.
module mini32_fpga_platform #(
    parameter ROM_INIT_FILE = "",
    parameter integer CLOCK_HZ = 50_000_000,
    parameter integer UART_BAUD = 115_200,
    parameter integer UART_FIFO_DEPTH = 256
) (
    input  logic                    clk,
    input  logic                    reset_n,
    input  logic [31:0]             gpio_input,
    output logic [31:0]             gpio_output,
    output logic [31:0]             gpio_direction,
    output logic                    uart_tx,
    output logic                    halted,
    output logic                    faulted,
    output mini32_pkg::cpu_fault_t  fault_code,
    output logic [31:0]             pc,
    output logic [31:0]             debug_value,
    output logic                    uart_overflow
);
    logic reset;
    logic uart_event_valid;
    logic [7:0] uart_event_data;
    logic fifo_out_valid;
    logic [7:0] fifo_out_data;
    logic phy_tx_ready;

    reset_sync reset_sync_instance (
        .clk(clk), .reset_n_async(reset_n), .reset(reset)
    );
    // The architectural trace/fault-detail and timer-debug ports are purposely
    // private at this generic board-independent boundary.
    /* verilator lint_off PINCONNECTEMPTY */
    mini32_system #(.ROM_INIT_FILE(ROM_INIT_FILE)) mini32_system_instance (
        .clk(clk), .reset(reset), .gpio_input(gpio_input), .halted(halted), .faulted(faulted),
        .fault_code(fault_code), .fault_pc(), .fault_instruction(), .fault_address_valid(),
        .fault_address(), .pc(pc), .retire_valid(), .retire_pc(), .retire_instruction(),
        .retire_next_pc(), .retire_reg_write(), .retire_rd(), .retire_value(), .retire_mem_write(),
        .retire_mem_addr(), .retire_mem_value(), .uart_tx_valid(uart_event_valid),
        .uart_tx_data(uart_event_data), .debug_value(debug_value), .gpio_output(gpio_output),
        .gpio_direction(gpio_direction), .timer_counter(), .timer_compare(), .timer_control()
    );
    /* verilator lint_on PINCONNECTEMPTY */
    uart_tx_fifo #(.DEPTH(UART_FIFO_DEPTH)) uart_fifo_instance (
        .clk(clk), .reset(reset), .event_valid(uart_event_valid), .event_data(uart_event_data),
        .out_valid(fifo_out_valid), .out_data(fifo_out_data), .out_ready(phy_tx_ready),
        .overflow(uart_overflow)
    );
    uart_tx_phy #(.CLOCK_HZ(CLOCK_HZ), .BAUD_RATE(UART_BAUD)) uart_phy_instance (
        .clk(clk), .reset(reset), .tx_valid(fifo_out_valid), .tx_data(fifo_out_data),
        .tx_ready(phy_tx_ready), .tx(uart_tx)
    );
endmodule
