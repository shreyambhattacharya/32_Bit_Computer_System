// Simple GPIO register block; a board wrapper later applies OUTPUT/DIRECTION to pins.
module gpio_mmio (
    input  logic        clk,
    input  logic        reset,
    input  logic        read_enable,
    input  logic        write_enable,
    input  logic [3:0]  register_offset,
    input  logic [31:0] write_data,
    input  logic [31:0] gpio_input,
    output logic [31:0] read_data,
    output logic [31:0] gpio_output,
    output logic [31:0] gpio_direction
);
    always_ff @(posedge clk) begin
        if (reset) begin
            read_data <= 32'h0000_0000;
            gpio_output <= 32'h0000_0000;
            gpio_direction <= 32'h0000_0000;
        end else begin
            if (read_enable) begin
                case (register_offset)
                    4'h0: read_data <= gpio_input;
                    4'h4: read_data <= gpio_output;
                    4'h8: read_data <= gpio_direction;
                    default: read_data <= 32'h0000_0000;
                endcase
            end
            if (write_enable) begin
                case (register_offset)
                    4'h4: gpio_output <= write_data;
                    4'h8: gpio_direction <= write_data;
                    default: begin end
                endcase
            end
        end
    end
endmodule
