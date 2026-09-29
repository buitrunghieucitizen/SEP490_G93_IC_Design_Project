// =============================================================================
// Module  : register_file
// Project : RISC-V 32-bit Single-Cycle CPU
// FPGA    : Synthesizable — maps to Distributed RAM hoặc FF array
//
// Hardware:
//   - 32 registers × 32 bits = 1024 flip-flops
//   - Read: 2 × 32-bit MUX (5-bit address → 32-to-1 MUX)
//   - Write: Decoder 5-to-32 + 32 D-FF với write enable
//   - x0 luôn = 0: hardwired (không cần FF, chỉ là wire GND)
//
// QUAN TRỌNG:
//   - Reset FPGA: registers không có giá trị xác định khi power-on
//     → Dùng rst để đảm bảo trạng thái khởi đầu = 0
//   - Không reset thì chương trình có thể đọc giá trị rác!
// =============================================================================

module register_file (
    input  logic        clk,
    input  logic        rst,        // Active-high synchronous reset
    // Read ports — asynchronous (combinational read)
    input  logic [4:0]  rs1_addr,   // Địa chỉ thanh ghi đọc 1 (instr[19:15])
    input  logic [4:0]  rs2_addr,   // Địa chỉ thanh ghi đọc 2 (instr[24:20])
    output logic [31:0] rs1_data,   // Dữ liệu đọc ra từ rs1
    output logic [31:0] rs2_data,   // Dữ liệu đọc ra từ rs2
    // Write port — synchronous (ghi tại rising edge)
    input  logic [4:0]  rd_addr,    // Địa chỉ thanh ghi ghi (instr[11:7])
    input  logic [31:0] rd_data,    // Dữ liệu ghi vào
    input  logic        reg_write   // Write enable (từ control unit)
);

    // -------------------------------------------------------------------------
    // 32 × 32-bit Register Array
    // Trên FPGA Gowin: sẽ dùng ~1024 LUT-based FF hoặc Distributed RAM
    // -------------------------------------------------------------------------
    logic [31:0] regs [1:31];  // x1..x31 (x0 không cần FF, luôn = 0)

    // -------------------------------------------------------------------------
    // Synchronous Write + Synchronous Reset
    // Mỗi register là 32 D Flip-Flop với:
    //   - Clock enable = (reg_write && rd_addr == i)
    //   - Async reset  = rst
    // -------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (rst) begin
            // Reset tất cả về 0 — unroll loop để FPGA synthesize đúng
            regs[ 1] <= 32'd0;  regs[ 2] <= 32'd0;  regs[ 3] <= 32'd0;
            regs[ 4] <= 32'd0;  regs[ 5] <= 32'd0;  regs[ 6] <= 32'd0;
            regs[ 7] <= 32'd0;  regs[ 8] <= 32'd0;  regs[ 9] <= 32'd0;
            regs[10] <= 32'd0;  regs[11] <= 32'd0;  regs[12] <= 32'd0;
            regs[13] <= 32'd0;  regs[14] <= 32'd0;  regs[15] <= 32'd0;
            regs[16] <= 32'd0;  regs[17] <= 32'd0;  regs[18] <= 32'd0;
            regs[19] <= 32'd0;  regs[20] <= 32'd0;  regs[21] <= 32'd0;
            regs[22] <= 32'd0;  regs[23] <= 32'd0;  regs[24] <= 32'd0;
            regs[25] <= 32'd0;  regs[26] <= 32'd0;  regs[27] <= 32'd0;
            regs[28] <= 32'd0;  regs[29] <= 32'd0;  regs[30] <= 32'd0;
            regs[31] <= 32'd0;
        end else begin
            // Ghi có điều kiện: chỉ ghi khi reg_write=1 VÀ không phải x0
            if (reg_write && (rd_addr != 5'd0)) begin
                regs[rd_addr] <= rd_data;
            end
        end
    end

    // -------------------------------------------------------------------------
    // Asynchronous Read (Combinational)
    // Trên FPGA: synthesize thành 2 × (32-to-1 MUX × 32 bit)
    // x0 hardwired = 0 (không cần MUX, chỉ là wire GND)
    // -------------------------------------------------------------------------
    assign rs1_data = (rs1_addr == 5'd0) ? 32'd0 : regs[rs1_addr];
    assign rs2_data = (rs2_addr == 5'd0) ? 32'd0 : regs[rs2_addr];

endmodule
