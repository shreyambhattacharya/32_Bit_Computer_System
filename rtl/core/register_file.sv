module register_file (
    input  logic        clk,
    input  logic        reset,
    input  logic [4:0]  rs1_addr,
    input  logic [4:0]  rs2_addr,
    output logic [31:0] rs1_data,
    output logic [31:0] rs2_data,
    input  logic        write_enable,
    input  logic [4:0]  write_addr,
    input  logic [31:0] write_data
);
    logic [31:0] registers [0:31];
    integer index;

    // A synchronous reset makes every writable architectural register deterministic.
    always_ff @(posedge clk) begin
        if (reset) begin
            for (index = 1; index < 32; index = index + 1) begin
                registers[index] <= 32'h0000_0000;
            end
        end else if (write_enable && (write_addr != 5'd0)) begin
            registers[write_addr] <= write_data;
        end
    end

    // r0 is architecturally hardwired to zero; writes are discarded.
    always_comb begin
        rs1_data = (rs1_addr == 5'd0) ? 32'h0000_0000 : registers[rs1_addr];
        rs2_data = (rs2_addr == 5'd0) ? 32'h0000_0000 : registers[rs2_addr];
    end
endmodule
