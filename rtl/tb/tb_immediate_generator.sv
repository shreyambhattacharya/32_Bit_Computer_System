module tb_immediate_generator;
    import mini32_pkg::*;
    logic [15:0] immediate;
    immediate_kind_t kind;
    logic [31:0] value;
    integer failures = 0;
    immediate_generator dut (.*);

    task automatic check_immediate(input immediate_kind_t input_kind, input logic [15:0] input_immediate,
                                   input logic [31:0] expected, input string message);
        kind = input_kind; immediate = input_immediate; #1;
        if (value !== expected) begin $error("%s", message); failures = failures + 1; end
    endtask

    initial begin
        check_immediate(IMM_NONE, 16'hffff, 32'h0000_0000, "NONE");
        check_immediate(IMM_SIGNED16, 16'h0001, 32'h0000_0001, "signed positive");
        check_immediate(IMM_SIGNED16, 16'h7fff, 32'h0000_7fff, "signed max");
        check_immediate(IMM_SIGNED16, 16'h8000, 32'hffff_8000, "signed min");
        check_immediate(IMM_SIGNED16, 16'hffff, 32'hffff_ffff, "signed negative one");
        check_immediate(IMM_ZERO_EXTENDED16, 16'hffff, 32'h0000_ffff, "zero extend");
        check_immediate(IMM_UPPER16, 16'h1000, 32'h1000_0000, "upper RAM address");
        check_immediate(IMM_UPPER16, 16'h2000, 32'h2000_0000, "upper UART address");
        check_immediate(IMM_UPPER16, 16'hffff, 32'hffff_0000, "upper max");
        if (failures != 0) $fatal(1, "tb_immediate_generator: %0d failures", failures);
        $display("tb_immediate_generator passed");
        $finish;
    end
endmodule
