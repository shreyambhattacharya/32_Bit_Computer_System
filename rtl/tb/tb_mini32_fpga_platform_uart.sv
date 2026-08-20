module tb_mini32_fpga_platform_uart;
    import mini32_pkg::*;
    localparam integer CLOCK_HZ = 100;
    localparam integer UART_BAUD = 10;
    localparam integer CLKS_PER_BIT = 10;
    localparam integer MESSAGE_LENGTH = 14;
    logic clk = 1'b0;
    logic reset_n = 1'b0;
    logic [31:0] gpio_input = '0;
    logic [31:0] gpio_output, gpio_direction;
    logic uart_tx, halted, faulted, uart_overflow;
    logic [31:0] pc, debug_value;
    cpu_fault_t fault_code;
    logic [7:0] expected [0:MESSAGE_LENGTH-1];
    logic [7:0] received [0:MESSAGE_LENGTH-1];
    integer received_count = 0;
    logic receiver_done = 1'b0;
    logic halt_seen = 1'b0;

    mini32_fpga_platform #(
        .ROM_INIT_FILE("build/generated/hello_uart.memh"), .CLOCK_HZ(CLOCK_HZ),
        .UART_BAUD(UART_BAUD), .UART_FIFO_DEPTH(32)
    ) dut (
        .clk(clk), .reset_n(reset_n), .gpio_input(gpio_input), .gpio_output(gpio_output),
        .gpio_direction(gpio_direction), .uart_tx(uart_tx), .halted(halted), .faulted(faulted),
        .fault_code(fault_code), .pc(pc), .debug_value(debug_value), .uart_overflow(uart_overflow)
    );
    always #5 clk = ~clk;

    task automatic receive_byte(output logic [7:0] byte_value);
        integer bit_number;
        begin
            @(negedge uart_tx);
            // Start at the falling edge, then sample each data bit at its centre.
            repeat (CLKS_PER_BIT + (CLKS_PER_BIT / 2)) @(posedge clk);
            for (bit_number = 0; bit_number < 8; bit_number = bit_number + 1) begin
                byte_value[bit_number] = uart_tx;
                repeat (CLKS_PER_BIT) @(posedge clk);
            end
            if (uart_tx !== 1'b1) $fatal(1, "UART stop bit was not high");
        end
    endtask

    initial begin
        expected[0] = 8'h48; expected[1] = 8'h65; expected[2] = 8'h6c; expected[3] = 8'h6c;
        expected[4] = 8'h6f; expected[5] = 8'h20; expected[6] = 8'h4d; expected[7] = 8'h69;
        expected[8] = 8'h6e; expected[9] = 8'h69; expected[10] = 8'h33; expected[11] = 8'h32;
        expected[12] = 8'h21; expected[13] = 8'h0a;
        repeat (3) @(posedge clk);
        reset_n = 1'b1;

        fork
            begin
                for (received_count = 0; received_count < MESSAGE_LENGTH; received_count = received_count + 1) begin
                    receive_byte(received[received_count]);
                    if (received[received_count] !== expected[received_count])
                        $fatal(1, "UART byte %0d was %h, expected %h", received_count,
                               received[received_count], expected[received_count]);
                end
                receiver_done = 1'b1;
            end
            begin
                wait (halted);
                halt_seen = 1'b1;
            end
        join
        if (faulted) $fatal(1, "hello_uart faulted with code %0d", fault_code);
        if (uart_overflow) $fatal(1, "hello_uart overflowed the platform UART FIFO");
        $display("tb_mini32_fpga_platform_uart passed: Hello Mini32!\\n");
        $finish;
    end
endmodule
