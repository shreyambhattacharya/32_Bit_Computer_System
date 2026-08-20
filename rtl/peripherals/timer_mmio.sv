// Deterministic Mini32 instruction-time timer. retire_tick represents one
// successfully retired architectural instruction, never an FPGA clock cycle.
module timer_mmio (
    input  logic        clk,
    input  logic        reset,
    input  logic        retire_tick,
    input  logic        read_enable,
    input  logic        write_enable,
    input  logic [3:0]  register_offset,
    input  logic [31:0] write_data,
    output logic [31:0] read_data,
    output logic [31:0] timer_counter,
    output logic [31:0] timer_compare,
    output logic [31:0] timer_control
);
    logic timer_enabled;

    always_ff @(posedge clk) begin
        if (reset) begin
            read_data <= 32'h0000_0000;
            timer_counter <= 32'h0000_0000;
            timer_compare <= 32'h0000_0000;
            timer_enabled <= 1'b0;
        end else begin
            if (read_enable) begin
                case (register_offset)
                    4'h0: read_data <= timer_counter;
                    4'h4: read_data <= timer_compare;
                    4'h8: read_data <= {31'h0, timer_enabled};
                    4'hC: read_data <= {31'h0, timer_enabled && (timer_counter == timer_compare)};
                    default: read_data <= 32'h0000_0000;
                endcase
            end
            if (write_enable) begin
                case (register_offset)
                    4'h0: timer_counter <= write_data + ((retire_tick && timer_enabled) ? 32'd1 : 32'd0);
                    4'h4: begin
                        timer_compare <= write_data;
                        if (retire_tick && timer_enabled) timer_counter <= timer_counter + 32'd1;
                    end
                    4'h8: begin
                        timer_enabled <= write_data[0];
                        if (retire_tick && write_data[0]) timer_counter <= timer_counter + 32'd1;
                    end
                    default: if (retire_tick && timer_enabled) timer_counter <= timer_counter + 32'd1;
                endcase
            end else if (retire_tick && timer_enabled) begin
                timer_counter <= timer_counter + 32'd1;
            end
        end
    end

    always_comb timer_control = {31'h0, timer_enabled};
endmodule
