module tb_tang_nano_20k_top;
    // Accelerated simulation values; board-top defaults retain the production
    // 27 MHz / 115200 configuration used by FPGA synthesis.
    localparam integer CLOCK_HZ = 100;
    localparam integer UART_BAUD = 10;
    localparam integer CLKS_PER_BIT = CLOCK_HZ / UART_BAUD;
    localparam integer MESSAGE_LENGTH = 21;
    logic clk = 1'b0;
    logic reset_button = 1'b0;
    logic uart_tx;
    logic [5:0] led;
    logic [7:0] expected [0:MESSAGE_LENGTH-1];
    logic [7:0] received;
    integer byte_index;

    tang_nano_20k_top #(
        .ROM_INIT_FILE("../fpga/tang_nano_20k/rom/fpga_bringup.memh"),
        .CLOCK_HZ(CLOCK_HZ),
        .UART_BAUD(UART_BAUD),
        .UART_FIFO_DEPTH(256)
    ) dut (
        .clk(clk), .reset_button(reset_button), .uart_tx(uart_tx), .led(led)
    );
    always #1 clk = ~clk;

    initial begin
        repeat (200_000) @(posedge clk);
        $fatal(1,
            "Tang UART timeout: reset=%b pc=%h halted=%b faulted=%b fault_code=%0d uart_tx=%b",
            dut.mini32_platform.reset_sync_instance.reset,
            dut.mini32_platform.mini32_system_instance.pc,
            dut.mini32_platform.mini32_system_instance.halted,
            dut.mini32_platform.mini32_system_instance.faulted,
            dut.mini32_platform.mini32_system_instance.fault_code,
            uart_tx);
    end

    task automatic receive_byte(output logic [7:0] byte_value);
        integer bit_number;
        begin
            @(negedge uart_tx);
            repeat (CLKS_PER_BIT + (CLKS_PER_BIT / 2)) @(posedge clk);
            for (bit_number = 0; bit_number < 8; bit_number = bit_number + 1) begin
                byte_value[bit_number] = uart_tx;
                repeat (CLKS_PER_BIT) @(posedge clk);
            end
            if (uart_tx !== 1'b1) $fatal(1, "Tang UART stop bit was not high");
        end
    endtask

    initial begin
        expected[0] = 8'h4D; expected[1] = 8'h69; expected[2] = 8'h6E; expected[3] = 8'h69;
        expected[4] = 8'h33; expected[5] = 8'h32; expected[6] = 8'h20; expected[7] = 8'h54;
        expected[8] = 8'h61; expected[9] = 8'h6E; expected[10] = 8'h67; expected[11] = 8'h20;
        expected[12] = 8'h4E; expected[13] = 8'h61; expected[14] = 8'h6E; expected[15] = 8'h6F;
        expected[16] = 8'h20; expected[17] = 8'h32; expected[18] = 8'h30; expected[19] = 8'h4B;
        expected[20] = 8'h0A;

        #1 reset_button = 1'b1;
        repeat (2) @(posedge clk);
        #1;
        if (led !== 6'b111111) $fatal(1, "Active reset did not leave LEDs off: %b", led);
        repeat (3) @(posedge clk);
        reset_button = 1'b0;

        for (byte_index = 0; byte_index < MESSAGE_LENGTH; byte_index = byte_index + 1) begin
            receive_byte(received);
            if (received !== expected[byte_index])
                $fatal(1, "Tang UART byte %0d was %h, expected %h", byte_index,
                       received, expected[byte_index]);
        end
        // Verify status only through board-visible outputs: LED4 is active-low
        // HALT and LED5 is active-low fault/overflow indication.
        wait (led[4] === 1'b0);
        if (led !== 6'b100101)
            $fatal(1, "Tang LED mapping was %b, expected active-low 100101", led);
        if (led[5] !== 1'b1) $fatal(1, "Tang fault/overflow LED asserted unexpectedly");
        if (uart_tx !== 1'b1) $fatal(1, "Tang UART TX did not return idle");

        // Isolate the edge adapter from the CPU to verify direction gating.
        force dut.gpio_output[0] = 1'b1;
        force dut.gpio_direction[0] = 1'b0;
        #1;
        if (led[0] !== 1'b1) $fatal(1, "GPIO input direction did not leave LED0 off");
        force dut.gpio_direction[0] = 1'b1;
        #1;
        if (led[0] !== 1'b0) $fatal(1, "GPIO output direction did not illuminate LED0");
        release dut.gpio_output[0];
        release dut.gpio_direction[0];

        force dut.faulted = 1'b1;
        #1;
        if (led[5] !== 1'b0) $fatal(1, "CPU fault did not illuminate LED5");
        release dut.faulted;
        force dut.uart_overflow = 1'b1;
        #1;
        if (led[5] !== 1'b0) $fatal(1, "UART overflow did not illuminate LED5");
        release dut.uart_overflow;
        $display("tb_tang_nano_20k_top passed");
        $finish;
    end
endmodule
