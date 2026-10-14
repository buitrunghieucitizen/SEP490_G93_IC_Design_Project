// =============================================================================
// Module  : immediate_gen (Immediate Generator)
// Project : RISC-V 32-bit Single-Cycle CPU
// FPGA    : Synthesizable - Pure RTL, Gowin compatible
// Language: Verilog-2001
//
// RISC-V Immediate Formats:
//   I-type: [31:20] sign-extended 12-bit
//   S-type: [31:25|11:7] sign-extended 12-bit
//   B-type: [31|7|30:25|11:8] sign-extended 13-bit (bit 0 = 0)
//   U-type: [31:12] zero-extended + 12'b0
//   J-type: [31|19:12|20|30:21] sign-extended 21-bit (bit 0 = 0)
//
// Hardware: ~120 LUT4 (MUX + sign-extension logic)
// =============================================================================

module immediate_gen (
    input  wire [31:0] instr,  // Instruction word (32-bit)
    output reg  [31:0] imm     // Sign-extended immediate value
);

    // -------------------------------------------------------------------------
    // Opcode trich tu instruction de xac dinh loai immediate
    // -------------------------------------------------------------------------
    wire [6:0] opcode = instr[6:0];

    // -------------------------------------------------------------------------
    // Opcode constants (khop voi control_unit.v)
    // -------------------------------------------------------------------------
    localparam OP_I_ARITH = 7'b001_0011; // ADDI, SLTI, ANDI, ORI, XORI, SLLI, ...
    localparam OP_LOAD    = 7'b000_0011; // LW, LH, LB, ...
    localparam OP_STORE   = 7'b010_0011; // SW, SH, SB
    localparam OP_BRANCH  = 7'b110_0011; // BEQ, BNE, BLT, BGE, ...
    localparam OP_JAL     = 7'b110_1111; // JAL
    localparam OP_JALR    = 7'b110_0111; // JALR
    localparam OP_LUI     = 7'b011_0111; // LUI
    localparam OP_AUIPC   = 7'b001_0111; // AUIPC

    // -------------------------------------------------------------------------
    // Giai ma immediate theo dinh dang cua tung loai lenh
    // Tat ca duoc sign-extended len 32-bit (tru U-type)
    // -------------------------------------------------------------------------
    always @(*) begin
        case (opcode)

            // ------------------------------------------------------------------
            // I-type: ADDI, SLTI, ANDI, ORI, XORI, SLLI, SRLI, SRAI
            //         LW, LH, LB, LHU, LBU
            //         JALR
            // imm = sign_extend(instr[31:20])
            // ------------------------------------------------------------------
            OP_I_ARITH,
            OP_LOAD,
            OP_JALR:
                imm = {{20{instr[31]}}, instr[31:20]};

            // ------------------------------------------------------------------
            // S-type: SW, SH, SB
            // imm = sign_extend({instr[31:25], instr[11:7]})
            // ------------------------------------------------------------------
            OP_STORE:
                imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};

            // ------------------------------------------------------------------
            // B-type: BEQ, BNE, BLT, BGE, BLTU, BGEU
            // imm = sign_extend({instr[31], instr[7], instr[30:25], instr[11:8], 1'b0})
            // Bit 0 luon = 0 (instruction aligned)
            // ------------------------------------------------------------------
            OP_BRANCH:
                imm = {{19{instr[31]}}, instr[31], instr[7],
                       instr[30:25], instr[11:8], 1'b0};

            // ------------------------------------------------------------------
            // U-type: LUI, AUIPC
            // imm = {instr[31:12], 12'b0}  (khong sign-extend bit cao)
            // ------------------------------------------------------------------
            OP_LUI,
            OP_AUIPC:
                imm = {instr[31:12], 12'b0};

            // ------------------------------------------------------------------
            // J-type: JAL
            // imm = sign_extend({instr[31], instr[19:12], instr[20], instr[30:21], 1'b0})
            // ------------------------------------------------------------------
            OP_JAL:
                imm = {{11{instr[31]}}, instr[31], instr[19:12],
                       instr[20], instr[30:21], 1'b0};

            // ------------------------------------------------------------------
            // Default: tra ve 0 (NOP, hoac instruction khong ro)
            // ------------------------------------------------------------------
            default:
                imm = 32'd0;

        endcase
    end

endmodule
