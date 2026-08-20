module tb_timer_mmio;
    logic clk = 1'b0, reset, retire_tick, read_enable, write_enable;
    logic [3:0] register_offset;
    logic [31:0] write_data, read_data, timer_counter, timer_compare, timer_control;
    integer failures = 0;

    timer_mmio dut (.*);
    always #5 clk = ~clk;

    task automatic check(input logic condition, input string message);
        if (!condition) begin $error("%s", message); failures = failures + 1; end
    endtask

    task automatic write_register(input logic [3:0] offset, input logic [31:0] value, input logic tick);
        register_offset = offset; write_data = value; write_enable = 1'b1; retire_tick = tick;
        @(posedge clk); #1; write_enable = 1'b0; retire_tick = 1'b0;
    endtask

    task automatic read_register(input logic [3:0] offset, input logic [31:0] expected, input string message);
        register_offset = offset; read_enable = 1'b1; @(posedge clk); #1;
        check(read_data == expected, message); read_enable = 1'b0;
    endtask

    task automatic tick_once;
        retire_tick = 1'b1; @(posedge clk); #1; retire_tick = 1'b0;
    endtask

    initial begin
        reset = 1'b1; retire_tick = 1'b0; read_enable = 1'b0; write_enable = 1'b0; register_offset = '0; write_data = '0;
        @(posedge clk); #1; check(timer_counter == 0 && timer_compare == 0 && timer_control == 0, "Timer reset state wrong");
        reset = 1'b0;
        tick_once; check(timer_counter == 0, "Disabled timer ticked");
        write_register(4'h4, 32'd3, 1'b0);
        write_register(4'h8, 32'hFFFF_FFFF, 1'b1);
        check(timer_control == 1 && timer_counter == 1, "Enable write did not become first timer tick");
        tick_once; tick_once; check(timer_counter == 3, "Timer did not tick once per retirement");
        read_register(4'hC, 32'd1, "Timer MATCH not true at compare");
        tick_once; read_register(4'hC, 32'd0, "Timer MATCH not false after compare");
        write_register(4'h0, 32'hFFFF_FFFF, 1'b1); check(timer_counter == 0, "COUNTER write/tick ordering or wrap wrong");
        write_register(4'h8, 32'h0000_0000, 1'b1); check(timer_counter == 0 && timer_control == 0, "Disable write incorrectly ticked");
        tick_once; check(timer_counter == 0, "Disabled timer resumed");
        read_register(4'h8, 32'd0, "CONTROL upper bits not masked");
        if (failures != 0) $fatal(1, "tb_timer_mmio: %0d failures", failures);
        $display("tb_timer_mmio passed");
        $finish;
    end
endmodule
