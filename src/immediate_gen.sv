// =============================================================================
// Module  : immediate_gen (Immediate Generator)
// Project : RISC-V 32-bit Single-Cycle CPU
// Desc    : Extracts and sign-extends immediate values from RV32I instructions
//
// Instruction formats:
//   I-type : ADDI, LW, JALR        → imm[11:0]
//   S-type : SW                     → imm[11:5|4:0]
//   B-type : BEQ, BNE               → imm[12|10:5|4:1|11]
//   U-type : LUI, AUIPC             → imm[31:12]
//   J-type : JAL                    → imm[20|10:1|11|19:12]
// =============================================================================

module immediate_gen (
    input  logic [31:0] instr,  // Full 32-bit instruction
    output logic [31:0] imm     // Sign-extended immediate
);

    // Instruction opcode (bits [6:0])
    logic [6:0] opcode;
    assign opcode = instr[6:0];

    // -------------------------------------------------------------------------
    // Opcode Encoding (RV32I)
    // -------------------------------------------------------------------------
    localparam OP_I_ARITH = 7'b001_0011; // ADDI, SLTI, ANDI, ORI, XORI, SLLI...
    localparam OP_LOAD    = 7'b000_0011; // LW
    localparam OP_STORE   = 7'b010_0011; // SW
    localparam OP_BRANCH  = 7'b110_0011; // BEQ, BNE
    localparam OP_JAL     = 7'b110_1111; // JAL
    localparam OP_JALR    = 7'b110_0111; // JALR
    localparam OP_LUI     = 7'b011_0111; // LUI
    localparam OP_AUIPC   = 7'b001_0111; // AUIPC

    // -------------------------------------------------------------------------
    // Immediate Extraction + Sign Extension
    // -------------------------------------------------------------------------
    always_comb begin
        case (opcode)
            // I-type: sign_ext(inst[31:20])
            OP_I_ARITH,
            OP_LOAD,
            OP_JALR  : imm = {{20{instr[31]}}, instr[31:20]};

            // S-type: sign_ext({inst[31:25], inst[11:7]})
            OP_STORE : imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};

            // B-type: sign_ext({inst[31],inst[7],inst[30:25],inst[11:8],1'b0})
            OP_BRANCH: imm = {{19{instr[31]}}, instr[31], instr[7],
                               instr[30:25], instr[11:8], 1'b0};

            // U-type: {inst[31:12], 12'b0}
            OP_LUI,
            OP_AUIPC : imm = {instr[31:12], 12'b0};

            // J-type: sign_ext({inst[31],inst[19:12],inst[20],inst[30:21],1'b0})
            OP_JAL   : imm = {{11{instr[31]}}, instr[31], instr[19:12],
                               instr[20], instr[30:21], 1'b0};

            default  : imm = 32'd0;
        endcase
    end

endmodule
