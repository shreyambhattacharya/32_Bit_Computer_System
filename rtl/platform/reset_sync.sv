// Active-low asynchronous assertion and two-clock synchronous reset release.
module reset_sync (
    input  logic clk,
    input  logic reset_n_async,
    output logic reset
);
    logic [1:0] release_sync;

    always_ff @(posedge clk or negedge reset_n_async) begin
        if (!reset_n_async) release_sync <= 2'b00;
        else release_sync <= {release_sync[0], 1'b1};
    end

    always_comb reset = !release_sync[1];
endmodule
