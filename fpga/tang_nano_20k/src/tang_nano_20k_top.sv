// Sipeed Tang Nano 20K board edge.  Board-specific polarity and pin mapping
// stay here; the Mini32 generic platform remains vendor independent.
module tang_nano_20k_top #(
    parameter ROM_INIT_FILE = "rom/fpga_bringup.memh",
    parameter integer CLOCK_HZ = 27_000_000,
    parameter integer UART_BAUD = 115_200,
    parameter integer UART_FIFO_DEPTH = 256
) (
    input  logic       clk,
    input  logic       reset_button,
    output logic       uart_tx,
    output logic [5:0] led
);
    logic reset_n;
    logic [31:0] gpio_input;
    /* verilator lint_off UNUSEDSIGNAL */
    logic [31:0] gpio_output;
    logic [31:0] gpio_direction;
    mini32_pkg::cpu_fault_t unused_fault_code;
    logic [31:0] unused_pc;
    logic [31:0] unused_debug_value;
    /* verilator lint_on UNUSEDSIGNAL */
    logic halted;
    logic faulted;
    logic uart_overflow;
    logic [5:0] led_on;

    // The official Sipeed UART example uses rst_n = !rst: S1 is active-high.
    assign reset_n = !reset_button;
    // S2 is intentionally not consumed until its board-level polarity and
    // intended GPIO behavior are separately verified; inputs are deterministic.
    assign gpio_input = 32'h0000_0000;

    mini32_fpga_platform #(
        .ROM_INIT_FILE(ROM_INIT_FILE),
        .CLOCK_HZ(CLOCK_HZ),
        .UART_BAUD(UART_BAUD),
        .UART_FIFO_DEPTH(UART_FIFO_DEPTH)
    ) mini32_platform (
        .clk(clk), .reset_n(reset_n), .gpio_input(gpio_input),
        .gpio_output(gpio_output), .gpio_direction(gpio_direction), .uart_tx(uart_tx),
        .halted(halted), .faulted(faulted), .fault_code(unused_fault_code), .pc(unused_pc),
        .debug_value(unused_debug_value), .uart_overflow(uart_overflow)
    );

    // LEDs 0-3 show configured Mini32 GPIO outputs; inputs leave the LED off.
    assign led_on[0] = gpio_direction[0] && gpio_output[0];
    assign led_on[1] = gpio_direction[1] && gpio_output[1];
    assign led_on[2] = gpio_direction[2] && gpio_output[2];
    assign led_on[3] = gpio_direction[3] && gpio_output[3];
    assign led_on[4] = halted;
    assign led_on[5] = faulted || uart_overflow;
    // Tang Nano 20K LEDs are active-low.
    assign led = ~led_on;
endmodule
