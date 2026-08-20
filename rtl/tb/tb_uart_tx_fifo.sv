module tb_uart_tx_fifo;
    localparam integer DEPTH = 4;
    logic clk = 1'b0;
    logic reset = 1'b1;
    logic event_valid = 1'b0;
    logic [7:0] event_data = '0;
    logic out_valid;
    logic [7:0] out_data;
    logic out_ready = 1'b0;
    logic overflow;

    uart_tx_fifo #(.DEPTH(DEPTH)) dut (
        .clk(clk), .reset(reset), .event_valid(event_valid), .event_data(event_data),
        .out_valid(out_valid), .out_data(out_data), .out_ready(out_ready), .overflow(overflow)
    );
    always #5 clk = ~clk;

    task automatic enqueue(input logic [7:0] byte_value);
        begin
            @(negedge clk);
            event_valid = 1'b1;
            event_data = byte_value;
            @(negedge clk);
            event_valid = 1'b0;
        end
    endtask

    task automatic dequeue_expect(input logic [7:0] byte_value);
        begin
            @(negedge clk);
            if (!out_valid || out_data !== byte_value)
                $fatal(1, "FIFO output %h, expected %h", out_data, byte_value);
            out_ready = 1'b1;
            @(negedge clk);
            out_ready = 1'b0;
        end
    endtask

    initial begin
        repeat (2) @(posedge clk);
        reset = 1'b0;
        @(negedge clk);
        if (out_valid || overflow) $fatal(1, "FIFO was not empty after reset");

        enqueue(8'h11);
        enqueue(8'h22);
        enqueue(8'h33);
        dequeue_expect(8'h11);
        dequeue_expect(8'h22);
        dequeue_expect(8'h33);

        // Exercise pointer wraparound and simultaneous enqueue/dequeue.
        enqueue(8'h40);
        enqueue(8'h41);
        enqueue(8'h42);
        enqueue(8'h43);
        @(negedge clk);
        if (!out_valid || out_data !== 8'h40) $fatal(1, "FIFO did not fill in order");
        event_valid = 1'b1;
        event_data = 8'h44;
        out_ready = 1'b1;
        @(negedge clk);
        event_valid = 1'b0;
        out_ready = 1'b0;
        if (overflow) $fatal(1, "Simultaneous full FIFO dequeue/enqueue overflowed");
        dequeue_expect(8'h41);
        dequeue_expect(8'h42);
        dequeue_expect(8'h43);
        dequeue_expect(8'h44);

        enqueue(8'hA0);
        enqueue(8'hA1);
        enqueue(8'hA2);
        enqueue(8'hA3);
        enqueue(8'hA4);
        @(negedge clk);
        if (!overflow) $fatal(1, "FIFO overflow was not sticky");
        dequeue_expect(8'hA0);
        dequeue_expect(8'hA1);
        dequeue_expect(8'hA2);
        dequeue_expect(8'hA3);
        if (out_valid) $fatal(1, "FIFO did not drain after full condition");

        reset = 1'b1;
        @(posedge clk);
        #1;
        if (out_valid || overflow) $fatal(1, "FIFO reset did not clear control state");
        $display("tb_uart_tx_fifo passed");
        $finish;
    end
endmodule
