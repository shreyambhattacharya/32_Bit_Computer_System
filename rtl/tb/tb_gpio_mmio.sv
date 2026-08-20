module tb_gpio_mmio;
    logic clk = 1'b0, reset, read_enable, write_enable;
    logic [3:0] register_offset;
    logic [31:0] write_data, gpio_input, read_data, gpio_output, gpio_direction;
    integer failures = 0;

    gpio_mmio dut (.*);
    always #5 clk = ~clk;

    task automatic check(input logic condition, input string message);
        if (!condition) begin $error("%s", message); failures = failures + 1; end
    endtask

    task automatic read_register(input logic [3:0] offset, input logic [31:0] expected, input string message);
        register_offset = offset; read_enable = 1'b1; @(posedge clk); #1;
        check(read_data == expected, message); read_enable = 1'b0;
    endtask

    task automatic write_register(input logic [3:0] offset, input logic [31:0] value);
        register_offset = offset; write_data = value; write_enable = 1'b1; @(posedge clk); #1; write_enable = 1'b0;
    endtask

    initial begin
        reset = 1'b1; read_enable = 1'b0; write_enable = 1'b0; register_offset = '0; write_data = '0;
        gpio_input = 32'h0000_0001;
        @(posedge clk); #1; check(gpio_output == 0 && gpio_direction == 0, "GPIO reset state wrong");
        reset = 1'b0;
        read_register(4'h0, 32'h0000_0001, "GPIO INPUT did not reflect pins");
        write_register(4'h0, 32'hFFFF_FFFF);
        read_register(4'h0, 32'h0000_0001, "GPIO INPUT write changed pins");
        write_register(4'h4, 32'h0000_000F); read_register(4'h4, 32'h0000_000F, "GPIO OUTPUT write/read failed");
        write_register(4'h4, 32'hA5A5_5A5A); read_register(4'h4, 32'hA5A5_5A5A, "GPIO OUTPUT overwrite failed");
        write_register(4'h8, 32'h0000_0001); write_register(4'h8, 32'hFFFF_FFFF);
        read_register(4'h8, 32'hFFFF_FFFF, "GPIO DIRECTION overwrite failed");
        gpio_input = 32'h0000_000F; read_register(4'h0, 32'h0000_000F, "GPIO INPUT second pattern failed");
        write_register(4'hC, 32'hA5A5_5A5A); read_register(4'hC, 32'h0000_0000, "GPIO reserved register not deterministic");
        check(gpio_output == 32'hA5A5_5A5A && gpio_direction == 32'hFFFF_FFFF, "GPIO reserved write changed state");
        if (failures != 0) $fatal(1, "tb_gpio_mmio: %0d failures", failures);
        $display("tb_gpio_mmio passed");
        $finish;
    end
endmodule
