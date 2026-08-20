module tb_reset_sync;
    logic clk = 1'b0;
    logic reset_n_async = 1'b0;
    logic reset;

    reset_sync dut (.clk(clk), .reset_n_async(reset_n_async), .reset(reset));
    always #5 clk = ~clk;

    initial begin
        #1;
        if (!reset) $fatal(1, "Reset was not asserted asynchronously");
        @(negedge clk);
        reset_n_async = 1'b1;
        #1;
        if (!reset) $fatal(1, "Reset deasserted asynchronously");
        @(posedge clk);
        #1;
        if (!reset) $fatal(1, "Reset released before two synchronizer edges");
        @(posedge clk);
        #1;
        if (reset) $fatal(1, "Reset did not release after two synchronizer edges");
        #2;
        reset_n_async = 1'b0;
        #1;
        if (!reset) $fatal(1, "Reset reassertion was not asynchronous");
        $display("tb_reset_sync passed");
        $finish;
    end
endmodule
