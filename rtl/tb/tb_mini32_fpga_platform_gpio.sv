module tb_mini32_fpga_platform_gpio;
    import mini32_pkg::*;
    logic clk = 1'b0;
    logic reset_n = 1'b0;
    logic [31:0] gpio_input = 32'hA5A5_5A5A;
    logic [31:0] gpio_output, gpio_direction;
    logic uart_tx, halted, faulted, uart_overflow;
    logic [31:0] pc, debug_value;
    cpu_fault_t fault_code;

    mini32_fpga_platform #(
        .ROM_INIT_FILE("build/generated/gpio_demo.memh"), .CLOCK_HZ(100), .UART_BAUD(10),
        .UART_FIFO_DEPTH(4)
    ) dut (
        .clk(clk), .reset_n(reset_n), .gpio_input(gpio_input), .gpio_output(gpio_output),
        .gpio_direction(gpio_direction), .uart_tx(uart_tx), .halted(halted), .faulted(faulted),
        .fault_code(fault_code), .pc(pc), .debug_value(debug_value), .uart_overflow(uart_overflow)
    );
    always #5 clk = ~clk;

    initial begin
        repeat (3) @(posedge clk);
        reset_n = 1'b1;
        wait (halted);
        if (faulted) $fatal(1, "gpio_demo faulted with code %0d", fault_code);
        if (gpio_direction !== 32'h0000_000F) $fatal(1, "GPIO direction was %h", gpio_direction);
        if (gpio_output !== 32'h0000_000A) $fatal(1, "GPIO output was %h", gpio_output);
        if (uart_overflow) $fatal(1, "GPIO demo unexpectedly overflowed UART FIFO");
        $display("tb_mini32_fpga_platform_gpio passed");
        $finish;
    end
endmodule
