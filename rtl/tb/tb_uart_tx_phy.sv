module tb_uart_tx_phy;
    localparam integer CLOCK_HZ = 100;
    localparam integer BAUD_RATE = 10;
    localparam integer CLKS_PER_BIT = 10;
    logic clk = 1'b0;
    logic reset = 1'b1;
    logic tx_valid = 1'b0;
    logic [7:0] tx_data = '0;
    logic tx_ready, tx;

    uart_tx_phy #(.CLOCK_HZ(CLOCK_HZ), .BAUD_RATE(BAUD_RATE)) dut (
        .clk(clk), .reset(reset), .tx_valid(tx_valid), .tx_data(tx_data),
        .tx_ready(tx_ready), .tx(tx)
    );

    always #5 clk = ~clk;

    task automatic expect_bit(input logic expected);
        integer cycle;
        begin
            #1;
            if (tx !== expected) $fatal(1, "UART bit began as %b, expected %b", tx, expected);
            for (cycle = 1; cycle < CLKS_PER_BIT; cycle = cycle + 1) begin
                @(posedge clk);
                #1;
                if (tx !== expected) $fatal(1, "UART bit changed before %0d clocks", CLKS_PER_BIT);
            end
            @(posedge clk);
            #1;
        end
    endtask

    task automatic expect_bit_after_elapsed(input logic expected, input integer elapsed_cycles);
        integer cycle;
        begin
            #1;
            if (tx !== expected) $fatal(1, "UART bit changed during an unready input attempt");
            for (cycle = elapsed_cycles + 1; cycle < CLKS_PER_BIT; cycle = cycle + 1) begin
                @(posedge clk);
                #1;
                if (tx !== expected) $fatal(1, "UART bit changed before %0d clocks", CLKS_PER_BIT);
            end
            @(posedge clk);
            #1;
        end
    endtask

    task automatic send_and_verify(input logic [7:0] byte_value, input logic attempt_while_busy);
        integer bit_number;
        begin
            if (!tx_ready || tx !== 1'b1) $fatal(1, "UART was not idle before frame");
            @(negedge clk);
            tx_valid = 1'b1;
            tx_data = byte_value;
            @(posedge clk);
            #1;
            tx_valid = 1'b0;
            if (tx_ready) $fatal(1, "UART did not become busy on handshake");
            if (attempt_while_busy) begin
                @(negedge clk);
                tx_valid = 1'b1;
                tx_data = ~byte_value;
                @(posedge clk);
                #1;
                tx_valid = 1'b0;
                if (tx_ready || tx !== 1'b0) $fatal(1, "Busy UART accepted or corrupted the active frame");
                expect_bit_after_elapsed(1'b0, 1);
            end else begin
                expect_bit(1'b0);
            end
            for (bit_number = 0; bit_number < 8; bit_number = bit_number + 1)
                expect_bit(byte_value[bit_number]);
            expect_bit(1'b1);
            if (!tx_ready || tx !== 1'b1) $fatal(1, "UART did not return to idle");
        end
    endtask

    initial begin
        repeat (2) @(posedge clk);
        reset = 1'b0;
        #1;
        if (!tx_ready || tx !== 1'b1) $fatal(1, "UART idle state is incorrect");
        send_and_verify(8'h00, 1'b0);
        send_and_verify(8'hFF, 1'b1);
        send_and_verify(8'hA5, 1'b0);
        send_and_verify(8'h48, 1'b0);
        $display("tb_uart_tx_phy passed");
        $finish;
    end
endmodule
