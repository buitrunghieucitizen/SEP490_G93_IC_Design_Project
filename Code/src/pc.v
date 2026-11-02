// =============================================================================
// Module  : pc (Program Counter)
// Project : RISC-V 32-bit Single-Cycle CPU
// Language: Verilog-2001
// =============================================================================

module pc (
    input  wire        clk,        // Clock
    input  wire        rst,        // Synchronous reset tich cuc cao
    input  wire [31:0] pc_next,    // Gia tri PC tiep theo (tu datapath)
    output reg  [31:0] pc_current  // Gia tri PC hien tai
);

    // -------------------------------------------------------------------------
    // Synchronous 32-bit PC register with active-high reset.
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst)
            pc_current <= 32'h0000_0000;  // Reset ve dia chi 0 (entry point)
        else
            pc_current <= pc_next;
    end

endmodule
