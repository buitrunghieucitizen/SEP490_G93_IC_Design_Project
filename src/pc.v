// =============================================================================
// Module  : pc (Program Counter)
// Project : RISC-V 32-bit Single-Cycle CPU
// FPGA    : Synthesizable - Pure RTL, Gowin compatible
// Language: Verilog-2001
//
// Hardware duoc sinh ra (GW1NR-9):
//   - 1x DFF 32-bit (~32 FF)
//   - Reset dong bo hoac bat dong bo tuy theo tool map
//
// LUU Y GOWIN:
//   - Dung reset dong bo (synchronous reset) de BRAM va FF hoat dong chinh xac
//   - Khong dung asynchronous reset tru khi can thiet (Gowin ho tro ca hai)
// =============================================================================

module pc (
    input  wire        clk,        // Clock
    input  wire        rst,        // Synchronous reset tich cuc cao
    input  wire [31:0] pc_next,    // Gia tri PC tiep theo (tu datapath)
    output reg  [31:0] pc_current  // Gia tri PC hien tai
);

    // -------------------------------------------------------------------------
    // Flip-flop 32-bit voi synchronous reset
    // Gowin: FF se duoc pack vao slice FF, reset = 0x0000_0000
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst)
            pc_current <= 32'h0000_0000;  // Reset ve dia chi 0 (entry point)
        else
            pc_current <= pc_next;
    end

endmodule
