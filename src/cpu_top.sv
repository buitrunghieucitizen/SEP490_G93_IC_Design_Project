// =============================================================================
// Module  : cpu_top (Top-level)
// Project : RISC-V 32-bit Single-Cycle CPU
// Desc    : Top-level module — connects Control Unit + Datapath
//
//   ┌────────────────────────────────────────────────────────────┐
//   │                       CPU_TOP                              │
//   │                                                            │
//   │   ┌──────────────┐   control signals   ┌──────────────┐   │
//   │   │ CONTROL UNIT │──────────────────► │   DATAPATH   │   │
//   │   │              │ ◄── opcode/funct ── │              │   │
//   │   └──────────────┘                     └──────────────┘   │
//   │                                                            │
//   └────────────────────────────────────────────────────────────┘
// =============================================================================

module cpu_top (
    input  logic clk,
    input  logic rst
);

    // -------------------------------------------------------------------------
    // Control signals (from control_unit to datapath)
    // -------------------------------------------------------------------------
    logic        reg_write;
    logic        alu_src;
    logic        mem_write;
    logic        mem_read;
    logic        mem_to_reg;
    logic        branch;
    logic        jump;
    logic        jalr;
    logic        lui;
    logic        auipc;
    logic [3:0]  alu_ctrl;

    // Instruction decode fields (from datapath to control_unit)
    logic [6:0]  opcode;
    logic [2:0]  funct3;
    logic [6:0]  funct7;

    // -------------------------------------------------------------------------
    // Control Unit
    // -------------------------------------------------------------------------
    control_unit u_ctrl (
        .opcode     (opcode),
        .funct3     (funct3),
        .funct7     (funct7),
        .reg_write  (reg_write),
        .alu_src    (alu_src),
        .mem_write  (mem_write),
        .mem_read   (mem_read),
        .mem_to_reg (mem_to_reg),
        .branch     (branch),
        .jump       (jump),
        .jalr       (jalr),
        .lui        (lui),
        .auipc      (auipc),
        .alu_ctrl   (alu_ctrl)
    );

    // -------------------------------------------------------------------------
    // Datapath
    // -------------------------------------------------------------------------
    datapath u_datapath (
        .clk        (clk),
        .rst        (rst),
        .reg_write  (reg_write),
        .alu_src    (alu_src),
        .mem_write  (mem_write),
        .mem_read   (mem_read),
        .mem_to_reg (mem_to_reg),
        .branch     (branch),
        .jump       (jump),
        .jalr       (jalr),
        .lui        (lui),
        .auipc      (auipc),
        .alu_ctrl   (alu_ctrl),
        .opcode     (opcode),
        .funct3     (funct3),
        .funct7     (funct7)
    );

endmodule
