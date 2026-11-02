// result_capture.v
// Capture a 32-bit CPU result on a qualifying register writeback.
// Verilog-2001; synchronous active-low reset.
module result_capture #(
    parameter [4:0] TARGET_RD = 5'd8
)(
    input  wire        clk,
    input  wire        reset_n,
    input  wire        wb_valid,
    input  wire [4:0]  wb_rd,
    input  wire [31:0] wb_data,
    output reg  [31:0] display_data
);
    always @(posedge clk) begin
        if (!reset_n)
            display_data <= 32'd0;
        else if (wb_valid && (wb_rd == TARGET_RD))
            display_data <= wb_data;
    end
endmodule
