// =============================================================================
// Module  : datapath
// Project : RISC-V 32-bit Single-Cycle CPU
// Desc    : Single-cycle RISC-V datapath
//           Connects: PC → InstMem → RegFile → ALU → DataMem → RegFile
//
//                    ┌──────────────────────────────────────────────┐
//                    │                 DATAPATH                     │
//   clk,rst ────────►│                                              │
//                    │  PC → InstMem → Decoder → RegFile → ALU     │
//   Control ─────────►│                                  → DataMem │
//   Signals          │                                  → WrBack   │
//                    └──────────────────────────────────────────────┘
// =============================================================================

module datapath (
    input  logic        clk,
    input  logic        rst,
    // Control signals from control_unit
    input  logic        reg_write,
    input  logic        alu_src,
    input  logic        mem_write,
    input  logic        mem_read,
    input  logic        mem_to_reg,
    input  logic        branch,
    input  logic        jump,
    input  logic        jalr,
    input  logic        lui,
    input  logic        auipc,
    input  logic [3:0]  alu_ctrl,
    // Instruction decode outputs (to control_unit)
    output logic [6:0]  opcode,
    output logic [2:0]  funct3,
    output logic [6:0]  funct7
);

    // -------------------------------------------------------------------------
    // Internal signals
    // -------------------------------------------------------------------------
    logic [31:0] pc_current, pc_next, pc_plus4;
    logic [31:0] instr;
    logic [4:0]  rs1_addr, rs2_addr, rd_addr;
    logic [31:0] rs1_data, rs2_data, rd_data;
    logic [31:0] imm;
    logic [31:0] alu_a, alu_b, alu_result;
    logic        alu_zero;
    logic [31:0] mem_rd_data;
    logic        pc_sel;   // 1 = take branch/jump

    // -------------------------------------------------------------------------
    // PC Register
    // -------------------------------------------------------------------------
    pc u_pc (
        .clk        (clk),
        .rst        (rst),
        .pc_next    (pc_next),
        .pc_current (pc_current)
    );

    assign pc_plus4 = pc_current + 32'd4;

    // -------------------------------------------------------------------------
    // Instruction Memory
    // -------------------------------------------------------------------------
    instruction_memory u_inst_mem (
        .addr   (pc_current),
        .instr  (instr)
    );

    // -------------------------------------------------------------------------
    // Instruction decode (fields)
    // -------------------------------------------------------------------------
    assign opcode   = instr[6:0];
    assign funct3   = instr[14:12];
    assign funct7   = instr[31:25];
    assign rs1_addr = instr[19:15];
    assign rs2_addr = instr[24:20];
    assign rd_addr  = instr[11:7];

    // -------------------------------------------------------------------------
    // Immediate Generator
    // -------------------------------------------------------------------------
    immediate_gen u_imm_gen (
        .instr  (instr),
        .imm    (imm)
    );

    // -------------------------------------------------------------------------
    // Register File
    // -------------------------------------------------------------------------
    register_file u_reg_file (
        .clk       (clk),
        .rst       (rst),
        .rs1_addr  (rs1_addr),
        .rs2_addr  (rs2_addr),
        .rs1_data  (rs1_data),
        .rs2_data  (rs2_data),
        .rd_addr   (rd_addr),
        .rd_data   (rd_data),
        .reg_write (reg_write)
    );

    // -------------------------------------------------------------------------
    // ALU Input Mux
    //   alu_src=0 → B = rs2
    //   alu_src=1 → B = imm
    // -------------------------------------------------------------------------
    assign alu_a = auipc ? pc_current : rs1_data;
    assign alu_b = alu_src ? imm : rs2_data;

    // -------------------------------------------------------------------------
    // ALU
    // -------------------------------------------------------------------------
    alu u_alu (
        .a        (alu_a),
        .b        (alu_b),
        .alu_ctrl (alu_ctrl),
        .result   (alu_result),
        .zero     (alu_zero)
    );

    // -------------------------------------------------------------------------
    // Data Memory
    // -------------------------------------------------------------------------
    data_memory u_data_mem (
        .clk       (clk),
        .addr      (alu_result),
        .wr_data   (rs2_data),
        .mem_write (mem_write),
        .mem_read  (mem_read),
        .rd_data   (mem_rd_data)
    );

    // -------------------------------------------------------------------------
    // Write-back Mux
    //   lui       → imm (upper immediate)
    //   jump      → PC+4 (return address)
    //   mem_to_reg→ memory data
    //   default   → ALU result
    // -------------------------------------------------------------------------
    always_comb begin
        if (lui)
            rd_data = imm;
        else if (jump)
            rd_data = pc_plus4;
        else if (mem_to_reg)
            rd_data = mem_rd_data;
        else
            rd_data = alu_result;
    end

    // -------------------------------------------------------------------------
    // Branch/Jump control:
    //   BEQ → branch if zero=1
    //   BNE → branch if zero=0
    //   JAL/JALR → always jump
    // -------------------------------------------------------------------------
    always_comb begin
        pc_sel = 1'b0;
        if (jump)
            pc_sel = 1'b1;
        else if (branch && funct3 == 3'b000 && alu_zero)  // BEQ
            pc_sel = 1'b1;
        else if (branch && funct3 == 3'b001 && !alu_zero) // BNE
            pc_sel = 1'b1;
    end

    // -------------------------------------------------------------------------
    // PC Next Mux
    //   JALR   → (rs1 + imm) & ~1
    //   Branch/JAL → PC + imm (offset)
    //   Default    → PC + 4
    // -------------------------------------------------------------------------
    always_comb begin
        if (jalr)
            pc_next = (rs1_data + imm) & 32'hFFFF_FFFE;
        else if (pc_sel)
            pc_next = pc_current + imm;
        else
            pc_next = pc_plus4;
    end

endmodule
