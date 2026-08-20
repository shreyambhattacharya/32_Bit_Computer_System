// Vendor-independent physical 8N1 UART transmitter.  The actual baud is
// CLOCK_HZ / CLKS_PER_BIT, where CLKS_PER_BIT is the nearest integer divider.
module uart_tx_phy #(
    parameter integer CLOCK_HZ = 50_000_000,
    parameter integer BAUD_RATE = 115_200
) (
    input  logic       clk,
    input  logic       reset,
    input  logic       tx_valid,
    input  logic [7:0] tx_data,
    output logic       tx_ready,
    output logic       tx
);
    localparam integer CLKS_PER_BIT_ROUNDED = (CLOCK_HZ + (BAUD_RATE / 2)) / BAUD_RATE;
    localparam integer CLKS_PER_BIT = (CLKS_PER_BIT_ROUNDED < 1) ? 1 : CLKS_PER_BIT_ROUNDED;
    localparam integer BAUD_COUNT_WIDTH = (CLKS_PER_BIT <= 1) ? 1 : $clog2(CLKS_PER_BIT);
    localparam logic [BAUD_COUNT_WIDTH-1:0] LAST_BAUD_COUNT = BAUD_COUNT_WIDTH'(CLKS_PER_BIT - 1);

    typedef enum logic [1:0] { UART_IDLE, UART_START, UART_DATA, UART_STOP } uart_state_t;
    uart_state_t state;
    logic [BAUD_COUNT_WIDTH-1:0] baud_count;
    logic [2:0] bit_index;
    logic [7:0] latched_data;

    always_comb begin
        tx = 1'b1;
        if (state == UART_START) tx = 1'b0;
        else if (state == UART_DATA) tx = latched_data[bit_index];
        tx_ready = (state == UART_IDLE);
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            state <= UART_IDLE;
            baud_count <= '0;
            bit_index <= '0;
            latched_data <= '0;
        end else if (state == UART_IDLE) begin
            baud_count <= '0;
            bit_index <= '0;
            if (tx_valid) begin
                latched_data <= tx_data;
                state <= UART_START;
            end
        end else if (baud_count == LAST_BAUD_COUNT) begin
            baud_count <= '0;
            case (state)
                UART_START: state <= UART_DATA;
                UART_DATA: begin
                    if (bit_index == 3'd7) begin
                        bit_index <= '0;
                        state <= UART_STOP;
                    end else begin
                        bit_index <= bit_index + 1'b1;
                    end
                end
                UART_STOP: state <= UART_IDLE;
                default: state <= UART_IDLE;
            endcase
        end else begin
            baud_count <= baud_count + 1'b1;
        end
    end
endmodule
