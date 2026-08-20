// Non-architectural event FIFO between Mini32 UART MMIO and the physical UART.
module uart_tx_fifo #(
    parameter integer DEPTH = 256
) (
    input  logic       clk,
    input  logic       reset,
    input  logic       event_valid,
    input  logic [7:0] event_data,
    output logic       out_valid,
    output logic [7:0] out_data,
    input  logic       out_ready,
    output logic       overflow
);
    localparam integer POINTER_WIDTH = (DEPTH <= 2) ? 1 : $clog2(DEPTH);
    localparam integer COUNT_WIDTH = $clog2(DEPTH + 1);
    localparam logic [POINTER_WIDTH-1:0] LAST_POINTER = POINTER_WIDTH'(DEPTH - 1);
    localparam logic [COUNT_WIDTH-1:0] DEPTH_COUNT = COUNT_WIDTH'(DEPTH);

    logic [7:0] storage [0:DEPTH-1];
    logic [POINTER_WIDTH-1:0] write_pointer, read_pointer;
    logic [COUNT_WIDTH-1:0] count;
    logic enqueue, dequeue;

    function automatic logic [POINTER_WIDTH-1:0] advance_pointer(
        input logic [POINTER_WIDTH-1:0] pointer
    );
        if (pointer == LAST_POINTER) advance_pointer = '0;
        else advance_pointer = pointer + 1'b1;
    endfunction

    always_comb begin
        out_valid = (count != 0);
        out_data = storage[read_pointer];
        dequeue = out_valid && out_ready;
        // A simultaneous dequeue frees a full FIFO slot for the arriving event.
        enqueue = event_valid && ((count < DEPTH_COUNT) || dequeue);
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            write_pointer <= '0;
            read_pointer <= '0;
            count <= '0;
            overflow <= 1'b0;
        end else begin
            if (enqueue) begin
                storage[write_pointer] <= event_data;
                write_pointer <= advance_pointer(write_pointer);
            end
            if (dequeue) read_pointer <= advance_pointer(read_pointer);
            case ({enqueue, dequeue})
                2'b10: count <= count + 1'b1;
                2'b01: count <= count - 1'b1;
                default: count <= count;
            endcase
            if (event_valid && !enqueue) overflow <= 1'b1;
        end
    end
endmodule
