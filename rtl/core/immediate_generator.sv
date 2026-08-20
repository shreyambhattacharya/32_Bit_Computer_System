module immediate_generator (
    input  logic [15:0]                immediate,
    input  mini32_pkg::immediate_kind_t kind,
    output logic [31:0]                value
);
    import mini32_pkg::*;

    always_comb begin
        value = 32'h0000_0000;
        unique case (kind)
            IMM_SIGNED16:        value = {{16{immediate[15]}}, immediate};
            IMM_ZERO_EXTENDED16: value = {16'h0000, immediate};
            IMM_UPPER16:         value = {immediate, 16'h0000};
            default:             value = 32'h0000_0000;
        endcase
    end
endmodule
