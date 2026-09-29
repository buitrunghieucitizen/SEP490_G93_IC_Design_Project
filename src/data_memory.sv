// =============================================================================
// Module  : data_memory
// Project : RISC-V 32-bit Single-Cycle CPU
// FPGA    : Synthesizable — maps to Block RAM (BRAM) trên Gowin
//
// Hardware:
//   - 1024 × 32-bit = 32KB → dùng BRAM của FPGA Gowin
//   - Gowin GW1NR-9: có 4 × B_RAM_9K blocks
//   - Write: Synchronous (cạnh lên clk)
//   - Read : Synchronous (BRAM mode) hoặc Asynchronous (LUT-RAM)
//
// LƯU Ý CHO FPGA:
//   - Xóa initial block (BRAM tự khởi động = 0 sau config)
//   - Không dùng $display/$monitor trong synthesis
//   - BRAM trên Gowin hỗ trợ read-during-write = undefined behavior
//     → Giả sử không xảy ra (LW và SW ở địa chỉ khác nhau)
// =============================================================================

module data_memory #(
    parameter MEM_SIZE = 1024   // Số từ 32-bit (1024 × 4 byte = 4KB)
) (
    input  logic        clk,
    input  logic [31:0] addr,       // Byte address (từ ALU result)
    input  logic [31:0] wr_data,    // Dữ liệu ghi (từ rs2)
    input  logic        mem_write,  // Write enable — SW instruction
    input  logic        mem_read,   // Read enable  — LW instruction
    output logic [31:0] rd_data     // Dữ liệu đọc (đến rd qua write-back)
);

    // -------------------------------------------------------------------------
    // Memory Array
    // Gowin EDA tự suy ra đây là BRAM khi thấy pattern: sync write + array lớn
    // -------------------------------------------------------------------------
    logic [31:0] mem [0:MEM_SIZE-1];

    // -------------------------------------------------------------------------
    // Synchronous Write — LW: ghi tại rising edge
    // addr[11:2]: lấy bit 11 đến 2 → word address (bỏ 2 bit thấp vì word-aligned)
    // -------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (mem_write) begin
            mem[addr[11:2]] <= wr_data;
        end
    end

    // -------------------------------------------------------------------------
    // Asynchronous Read — kết quả ngay trong cùng chu kỳ (cần cho single-cycle)
    // Nếu FPGA map vào BRAM → đọc có 1-cycle latency → cần pipeline (pipeline CPU)
    // Với single-cycle: tool sẽ dùng Distributed RAM (LUT-based) để read async
    // -------------------------------------------------------------------------
    assign rd_data = mem_read ? mem[addr[11:2]] : 32'd0;

endmodule
