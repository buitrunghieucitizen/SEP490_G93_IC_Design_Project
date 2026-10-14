// =============================================================================
// Module  : register_file
// Project : RISC-V 32-bit Single-Cycle CPU
// FPGA    : Synthesizable - Pure RTL, Gowin compatible
// Language: Verilog-2001
//
// Hardware duoc sinh ra (GW1NR-9):
//   - 32 registers x 32 bit = 1024 bit
//   - Gowin EDA se map vao Distributed RAM (LUT-based) hoac BRAM
//   - Doc: Asynchronous (combinational) -> de single-cycle CPU hoat dong
//   - Ghi: Synchronous (rising edge clk)
//   - x0 luon = 0 (RISC-V spec)
//
// LUU Y GOWIN:
//   - Khong dung "initial" block - Gowin synthesis bo qua initial
//   - Dat x0 = 0 bang logic kiem tra reg_write (if rd_addr != 0)
//   - 2 cong doc dong thoi (rs1, rs2) - Gowin ho tro dual-port distributed RAM
// =============================================================================

module register_file (
    input  wire        clk,        // Clock
    input  wire        rst,        // Synchronous reset (tuy chon - xem ghi chu)
    // Doc port (asynchronous - ket qua ngay lap tuc)
    input  wire [4:0]  rs1_addr,   // Dia chi thanh ghi nguon 1 (instr[19:15])
    input  wire [4:0]  rs2_addr,   // Dia chi thanh ghi nguon 2 (instr[24:20])
    output wire [31:0] rs1_data,   // Du lieu thanh ghi nguon 1
    output wire [31:0] rs2_data,   // Du lieu thanh ghi nguon 2
    // Ghi port (synchronous)
    input  wire [4:0]  rd_addr,    // Dia chi thanh ghi dich (instr[11:7])
    input  wire [31:0] rd_data,    // Du lieu can ghi
    input  wire        reg_write   // Tin hieu cho phep ghi (tu control_unit)
);

    // -------------------------------------------------------------------------
    // Mang 32 thanh ghi x 32 bit
    // Gowin EDA tu dong map vao Distributed RAM (LUT4-based) voi doc async
    // -------------------------------------------------------------------------
    reg [31:0] regfile [0:31];

    // -------------------------------------------------------------------------
    // Ghi dong bo - rising edge clk
    // QUAN TRONG: Khong ghi vao x0 (regfile[0] luon phai = 0)
    // -------------------------------------------------------------------------
    integer i;
    always @(posedge clk) begin
        if (rst) begin
            // Reset dong bo toan bo thanh ghi ve 0
            // Tren Gowin: sau Config, FF mac dinh = 0, nen reset nay la tuy chon
            // Nhung nen giu de simulation chinh xac
            for (i = 0; i < 32; i = i + 1)
                regfile[i] <= 32'd0;
        end else begin
            if (reg_write && (rd_addr != 5'd0))
                regfile[rd_addr] <= rd_data;
        end
    end

    // -------------------------------------------------------------------------
    // Doc bat dong bo (combinational) - can cho single-cycle CPU
    // x0 luon tra ve 0 (RISC-V spec: x0 = hardwired zero)
    // Gowin: doc async = map vao LUT4 MUX tree
    // -------------------------------------------------------------------------
    assign rs1_data = (rs1_addr == 5'd0) ? 32'd0 : regfile[rs1_addr];
    assign rs2_data = (rs2_addr == 5'd0) ? 32'd0 : regfile[rs2_addr];

endmodule
