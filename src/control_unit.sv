// =============================================================================
// Module  : control_unit
// Project : RISC-V 32-bit Single-Cycle CPU
// Desc    : Main Control Unit — decodes opcode and funct3/funct7
//           to generate all datapath control signals
//
// Supported Instructions (14 core):
//   R-type : ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU
//   I-type : ADDI, LW, JALR
//   S-type : SW
//   B-type : BEQ, BNE
//   J-type : JAL
//   U-type : LUI, AUIPC
// =============================================================================

module control_unit (
    input  logic [6:0] opcode,      // instr[6:0]
    input  logic [2:0] funct3,      // instr[14:12]
    input  logic [6:0] funct7,      // instr[31:25]
    // Datapath control outputs
    output logic       reg_write,   // 1 = write to register file
    output logic       alu_src,     // 0 = rs2, 1 = immediate
    output logic       mem_write,   // 1 = write data memory (SW)
    output logic       mem_read,    // 1 = read data memory  (LW)
    output logic       mem_to_reg,  // 0 = ALU result, 1 = memory data
    output logic       branch,      // 1 = branch instruction
    output logic       jump,        // 1 = JAL/JALR
    output logic       jalr,        // 1 = JALR specifically
    output logic       lui,         // 1 = LUI (bypass ALU)
    output logic       auipc,       // 1 = AUIPC (PC + upper imm)
    output logic [3:0] alu_ctrl     // ALU operation select
);

    // -------------------------------------------------------------------------
    // Opcode constants
    // -------------------------------------------------------------------------
    localparam OP_R      = 7'b011_0011;
    localparam OP_I_ARITH= 7'b001_0011;
    localparam OP_LOAD   = 7'b000_0011;
    localparam OP_STORE  = 7'b010_0011;
    localparam OP_BRANCH = 7'b110_0011;
    localparam OP_JAL    = 7'b110_1111;
    localparam OP_JALR   = 7'b110_0111;
    localparam OP_LUI    = 7'b011_0111;
    localparam OP_AUIPC  = 7'b001_0111;

    // ALU ctrl encoding (matches alu.sv)
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
    // Main decode logic
    // -------------------------------------------------------------------------
    always_comb begin
        // Default: all signals de-asserted
        reg_write  = 1'b0;
        alu_src    = 1'b0;
        mem_write  = 1'b0;
        mem_read   = 1'b0;
        mem_to_reg = 1'b0;
        branch     = 1'b0;
        jump       = 1'b0;
        jalr       = 1'b0;
        lui        = 1'b0;
        auipc      = 1'b0;
        alu_ctrl   = ALU_ADD;

        case (opcode)
            // ------------------------------------------------------------------
            // R-type: ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU
            // ------------------------------------------------------------------
            OP_R: begin
                reg_write = 1'b1;
                alu_src   = 1'b0; // use rs2
                case ({funct7[5], funct3})
                    4'b0_000: alu_ctrl = ALU_ADD;   // ADD
                    4'b1_000: alu_ctrl = ALU_SUB;   // SUB
                    4'b0_111: alu_ctrl = ALU_AND;   // AND
                    4'b0_110: alu_ctrl = ALU_OR;    // OR
                    4'b0_100: alu_ctrl = ALU_XOR;   // XOR
                    4'b0_001: alu_ctrl = ALU_SLL;   // SLL
                    4'b0_101: alu_ctrl = ALU_SRL;   // SRL
                    4'b1_101: alu_ctrl = ALU_SRA;   // SRA
                    4'b0_010: alu_ctrl = ALU_SLT;   // SLT
                    4'b0_011: alu_ctrl = ALU_SLTU;  // SLTU
                    default:  alu_ctrl = ALU_ADD;
                endcase
            end

            // ------------------------------------------------------------------
            // I-type Arithmetic: ADDI, SLTI, ANDI, ORI, XORI, SLLI, SRLI, SRAI
            // ------------------------------------------------------------------
            OP_I_ARITH: begin
                reg_write = 1'b1;
                alu_src   = 1'b1; // use immediate
                case (funct3)
                    3'b000: alu_ctrl = ALU_ADD;                                  // ADDI
                    3'b111: alu_ctrl = ALU_AND;                                  // ANDI
                    3'b110: alu_ctrl = ALU_OR;                                   // ORI
                    3'b100: alu_ctrl = ALU_XOR;                                  // XORI
                    3'b010: alu_ctrl = ALU_SLT;                                  // SLTI
                    3'b011: alu_ctrl = ALU_SLTU;                                 // SLTIU
                    3'b001: alu_ctrl = ALU_SLL;                                  // SLLI
                    3'b101: alu_ctrl = funct7[5] ? ALU_SRA : ALU_SRL;           // SRAI/SRLI
                    default: alu_ctrl = ALU_ADD;
                endcase
            end

            // ------------------------------------------------------------------
            // Load: LW (only word load for now)
            // ------------------------------------------------------------------
            OP_LOAD: begin
                reg_write  = 1'b1;
                alu_src    = 1'b1; // base + offset
                mem_read   = 1'b1;
                mem_to_reg = 1'b1;
                alu_ctrl   = ALU_ADD;
            end

            // ------------------------------------------------------------------
            // Store: SW
            // ------------------------------------------------------------------
            OP_STORE: begin
                alu_src   = 1'b1; // base + offset
                mem_write = 1'b1;
                alu_ctrl  = ALU_ADD;
            end

            // ------------------------------------------------------------------
            // Branch: BEQ, BNE
            // ------------------------------------------------------------------
            OP_BRANCH: begin
                branch   = 1'b1;
                alu_src  = 1'b0; // compare rs1 vs rs2
                alu_ctrl = ALU_SUB; // subtract to check equality
            end

            // ------------------------------------------------------------------
            // JAL: Jump And Link
            // ------------------------------------------------------------------
            OP_JAL: begin
                reg_write = 1'b1;
                jump      = 1'b1;
                alu_ctrl  = ALU_ADD;
            end

            // ------------------------------------------------------------------
            // JALR: Jump And Link Register
            // ------------------------------------------------------------------
            OP_JALR: begin
                reg_write = 1'b1;
                alu_src   = 1'b1;
                jump      = 1'b1;
                jalr      = 1'b1;
                alu_ctrl  = ALU_ADD;
            end

            // ------------------------------------------------------------------
            // LUI: Load Upper Immediate
            // ------------------------------------------------------------------
            OP_LUI: begin
                reg_write = 1'b1;
                lui       = 1'b1;
            end

            // ------------------------------------------------------------------
            // AUIPC: Add Upper Immediate to PC
            // ------------------------------------------------------------------
            OP_AUIPC: begin
                reg_write = 1'b1;
                auipc     = 1'b1;
                alu_src   = 1'b1;
                alu_ctrl  = ALU_ADD;
            end

            default: begin
                // ! Unknown opcode — all signals de-asserted (NOP behavior)
            end
        endcase
    end

endmodule
