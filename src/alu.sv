// =============================================================================
// Module  : alu
// Project : RISC-V 32-bit Single-Cycle CPU
// FPGA    : Synthesizable — Pure RTL, no IP cores, no libraries
//
// Hardware được sinh ra (ví dụ với Gowin GW1NR-9):
//   ADD/SUB  → 32-bit adder/subtractor  (~32 LUT4)
//   AND/OR/XOR → 32 bitwise gates       (~32 LUT4)
//   SLL/SRL  → Barrel shifter           (~160 LUT4)
//   SRA      → Arithmetic barrel shifter (~160 LUT4)
//   SLT/SLTU → Comparator              (~32 LUT4)
//   MUX      → alu_ctrl decoder MUX    (~40 LUT4)
//   TOTAL    ~ 500-600 LUT4
// =============================================================================

module alu (
    input  logic [31:0] a,          // Operand A (từ rs1)
    input  logic [31:0] b,          // Operand B (từ rs2 hoặc immediate)
    input  logic [ 3:0] alu_ctrl,   // Chọn phép tính
    output logic [31:0] result,     // Kết quả
    output logic        zero        // Zero flag: result == 0
);

    // -------------------------------------------------------------------------
    // ALU Control Encoding (khớp với control_unit.sv)
    // -------------------------------------------------------------------------
    localparam ALU_ADD  = 4'b0000;
    localparam ALU_SUB  = 4'b0001;
    localparam ALU_AND  = 4'b0010;
    localparam ALU_OR   = 4'b0011;
    localparam ALU_XOR  = 4'b0100;
    localparam ALU_SLL  = 4'b0101;
    localparam ALU_SRL  = 4'b0110;
    localparam ALU_SRA  = 4'b0111;
    localparam ALU_SLT  = 4'b1000;
    localparam ALU_SLTU = 4'b1001;

    // -------------------------------------------------------------------------
    // Intermediate signals (rõ ràng từng phép, dễ đọc waveform)
    // -------------------------------------------------------------------------
    logic [31:0] add_result;
    logic [31:0] sub_result;
    logic [31:0] and_result;
    logic [31:0] or_result;
    logic [31:0] xor_result;
    logic [31:0] sll_result;
    logic [31:0] srl_result;
    logic [31:0] sra_result;
    logic [31:0] slt_result;
    logic [31:0] sltu_result;

    // -------------------------------------------------------------------------
    // Tính song song tất cả — FPGA thực hiện đồng thời, rồi MUX chọn
    // (đây là cách hardware hoạt động, khác với software tuần tự)
    // -------------------------------------------------------------------------
    assign add_result  = a + b;
    assign sub_result  = a - b;
    assign and_result  = a & b;
    assign or_result   = a | b;
    assign xor_result  = a ^ b;
    assign sll_result  = a << b[4:0];                    // Barrel shifter trái
    assign srl_result  = a >> b[4:0];                    // Barrel shifter phải (logic)
    assign sra_result  = $signed(a) >>> b[4:0];          // Barrel shifter phải (arithmetic)
    assign slt_result  = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;  // Signed comparator
    assign sltu_result = (a < b)                ? 32'd1 : 32'd0;     // Unsigned comparator

    // -------------------------------------------------------------------------
    // Output MUX — chọn kết quả theo alu_ctrl (4-bit → 10-to-1 MUX)
    // Trên FPGA: synthesize thành cây LUT4
    // -------------------------------------------------------------------------
    always_comb begin
        case (alu_ctrl)
            ALU_ADD  : result = add_result;
            ALU_SUB  : result = sub_result;
            ALU_AND  : result = and_result;
            ALU_OR   : result = or_result;
            ALU_XOR  : result = xor_result;
            ALU_SLL  : result = sll_result;
            ALU_SRL  : result = srl_result;
            ALU_SRA  : result = sra_result;
            ALU_SLT  : result = slt_result;
            ALU_SLTU : result = sltu_result;
            default  : result = 32'd0;
        endcase
    end

    // Zero flag — 32-input NOR gate trên FPGA
    assign zero = (result == 32'd0);

endmodule
