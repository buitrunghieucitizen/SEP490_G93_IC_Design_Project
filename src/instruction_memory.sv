// =============================================================================
// Module  : instruction_memory
// Project : RISC-V 32-bit Single-Cycle CPU
// FPGA    : Synthesizable — dùng $readmemh để init BRAM nội dung chương trình
//
// Hardware:
//   - ROM 1024 × 32-bit (4KB) — đủ cho ~1000 instructions
//   - Gowin: BRAM được init từ .mem file khi Generate Bitstream
//   - Read: Asynchronous (combinational) — cần thiết cho single-cycle CPU
//
// LƯU Ý QUAN TRỌNG:
//   - $readmemh() trong initial block:
//       SIMULATION: load file vào memory
//       FPGA SYNTHESIS (Gowin): tool đọc file để init BRAM content
//       → HOÀN TOÀN hợp lệ cho cả 2 mục đích!
//   - Khi nạp bitstream lên FPGA, chương trình đã được "đóng gói"
//     vào trong bitstream → FPGA chạy chương trình ngay khi bật nguồn
// =============================================================================

module instruction_memory #(
    parameter MEM_SIZE = 1024,
    parameter MEM_FILE = "tb/programs/program.mem"
) (
    input  logic [31:0] addr,       // Byte address từ PC (luôn word-aligned)
    output logic [31:0] instr       // 32-bit instruction output
);

    // -------------------------------------------------------------------------
    // ROM Array — chứa chương trình RISC-V
    // -------------------------------------------------------------------------
    logic [31:0] mem [0:MEM_SIZE-1];

    // -------------------------------------------------------------------------
    // Nạp chương trình từ file hex
    // Format file .mem: mỗi dòng là 1 word 32-bit (8 hex digits)
    // Ví dụ:
    //   00A00093   ← ADDI x1, x0, 10
    //   01400113   ← ADDI x2, x0, 20
    //   002081B3   ← ADD  x3, x1, x2
    // -------------------------------------------------------------------------
    initial begin
        $readmemh(MEM_FILE, mem);
    end

    // -------------------------------------------------------------------------
    // Asynchronous Read — Combinational
    // addr[11:2]: convert byte address → word index (chia 4)
    // PC = 0x00 → mem[0], PC = 0x04 → mem[1], PC = 0x08 → mem[2], ...
    // -------------------------------------------------------------------------
    assign instr = mem[addr[11:2]];

endmodule
