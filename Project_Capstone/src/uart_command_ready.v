// One-entry command mailbox: set READY on parser completion,
// clear it when CPU writes its result to MMIO address 0x1010.
// For human-driven UART entry; no queue for overlapping commands.
module uart_command_ready (
    input  wire clk,
    input  wire reset_n,
    input  wire command_strobe,
    input  wire result_strobe,
    output reg  ready
);
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) ready <= 1'b0;
        else if (command_strobe) ready <= 1'b1;
        else if (result_strobe) ready <= 1'b0;
    end
endmodule
