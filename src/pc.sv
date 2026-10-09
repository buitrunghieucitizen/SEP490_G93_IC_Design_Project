// =============================================================================
// Module  : pc (Program Counter)
// Project : RISC-V 32-bit Single-Cycle CPU
// Desc    : Program Counter register
//           - Resets to 0x00000000
//           - Loads pc_next on every rising clock edge
// =============================================================================

module pc (
    input  logic        clk,
    input  logic        rst,
    input  logic [31:0] pc_next,    // Next PC value (from datapath)
    output logic [31:0] pc_current  // Current PC value
);

    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            pc_current <= 32'h0000_0000;
        else
            pc_current <= pc_next;
    end

endmodule
