// =============================================================================
// Module  : register_file
// Project : RISC-V 32-bit Single-Cycle CPU
// Language: Verilog-2001
//
// Structure: 32 x 32-bit register array, two asynchronous read ports,
// one synchronous write port. x0 is architecturally hardwired to zero.
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
    // Register array. Physical mapping depends on synthesis and target device.
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
            // Clear all registers on the synchronous CPU reset.
            for (i = 0; i < 32; i = i + 1)
                regfile[i] <= 32'd0;
        end else begin
            if (reg_write && (rd_addr != 5'd0))
                regfile[rd_addr] <= rd_data;
        end
    end

    // -------------------------------------------------------------------------
    // Asynchronous reads required by this single-cycle datapath.
    // x0 always reads as zero, independently of the stored array element.
    // -------------------------------------------------------------------------
    assign rs1_data = (rs1_addr == 5'd0) ? 32'd0 : regfile[rs1_addr];
    assign rs2_data = (rs2_addr == 5'd0) ? 32'd0 : regfile[rs2_addr];

endmodule
