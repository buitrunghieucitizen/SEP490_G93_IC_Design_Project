// Verilog-2001 single-cycle datapath with sticky debug-fault handling.
module datapath #(
    parameter IMEM_DEPTH = 256,
    parameter DMEM_SIZE = 128,
    parameter MEM_FILE = "src/program.mem"
) (
    input  wire        clk,
    input  wire        rst,
    input  wire        reg_write,
    input  wire        alu_src,
    input  wire        mem_write,
    input  wire        mem_read,
    input  wire        mem_to_reg,
    input  wire        branch,
    input  wire        jump,
    input  wire        jalr,
    input  wire        lui,
    input  wire        auipc,
    input  wire [3:0]  alu_ctrl,
    input  wire        decode_illegal_instr,
    output wire [6:0]  opcode,
    output wire [2:0]  funct3,
    output wire [6:0]  funct7,
    output reg         illegal_instr,
    output reg         misaligned,
    output reg         access_fault,
    output reg         halted,
    output wire [31:0]  debug_pc,
    output wire [31:0]  debug_instr,
    output wire [31:0]  debug_alu_result,
    output wire [31:0]  debug_wb_data
);
    wire [31:0] pc_current;
    reg  [31:0] pc_next;
    wire [31:0] pc_plus4;
    wire [31:0] instr;
    wire [4:0] rs1_addr, rs2_addr, rd_addr;
    wire [31:0] rs1_data, rs2_data;
    reg  [31:0] rd_data;
    wire [31:0] imm;
    wire [31:0] alu_a, alu_b, alu_result, mem_rd_data;
    wire imem_misaligned, imem_out_of_range;
    wire dmem_misaligned, dmem_out_of_range;
    wire branch_taken;
    wire [31:0] jalr_target, control_target;
    wire control_target_valid;
    wire fetch_fault, decode_fault, data_align_fault, data_range_fault;
    wire target_align_fault, target_range_fault, fault_now, commit_enable;

    assign debug_pc = pc_current;
    assign debug_instr = instr;
    assign debug_alu_result = alu_result;
    assign debug_wb_data = rd_data;

    pc u_pc (.clk(clk), .rst(rst), .pc_next(pc_next), .pc_current(pc_current));
    assign pc_plus4 = pc_current + 32'd4;

    instruction_memory #(.MEM_DEPTH(IMEM_DEPTH), .MEM_FILE(MEM_FILE)) u_inst_mem (
        .addr(pc_current), .instr(instr),
        .addr_misaligned(imem_misaligned), .addr_out_of_range(imem_out_of_range)
    );

    assign opcode = instr[6:0];
    assign funct3 = instr[14:12];
    assign funct7 = instr[31:25];
    assign rs1_addr = instr[19:15];
    assign rs2_addr = instr[24:20];
    assign rd_addr = instr[11:7];

    immediate_gen u_imm_gen (.instr(instr), .imm(imm));
    register_file u_reg_file (
        .clk(clk), .rst(rst), .rs1_addr(rs1_addr), .rs2_addr(rs2_addr),
        .rs1_data(rs1_data), .rs2_data(rs2_data), .rd_addr(rd_addr),
        .rd_data(rd_data), .reg_write(reg_write && commit_enable)
    );

    assign alu_a = auipc ? pc_current : rs1_data;
    assign alu_b = alu_src ? imm : rs2_data;
    alu u_alu (.a(alu_a), .b(alu_b), .alu_ctrl(alu_ctrl), .result(alu_result), .zero());

    data_memory #(.MEM_SIZE(DMEM_SIZE)) u_data_mem (
        .clk(clk), .addr(alu_result), .wr_data(rs2_data),
        .mem_write(mem_write && commit_enable), .mem_read(mem_read && !halted && !rst),
        .rd_data(mem_rd_data), .addr_misaligned(dmem_misaligned),
        .addr_out_of_range(dmem_out_of_range)
    );

    assign branch_taken = branch &&
        ((funct3 == 3'b000 && rs1_data == rs2_data) ||
         (funct3 == 3'b001 && rs1_data != rs2_data));
    assign jalr_target = (rs1_data + imm) & 32'hFFFFFFFE;
    assign control_target = jalr ? jalr_target : (pc_current + imm);
    assign control_target_valid = jump || branch_taken;

    assign fetch_fault = imem_misaligned || imem_out_of_range;
    assign decode_fault = decode_illegal_instr && !fetch_fault;
    assign data_align_fault = (mem_read || mem_write) && dmem_misaligned;
    assign data_range_fault = (mem_read || mem_write) && dmem_out_of_range;
    assign target_align_fault = control_target_valid && (control_target[1:0] != 2'b00);
    assign target_range_fault = control_target_valid &&
                                (control_target >= (IMEM_DEPTH * 4));
    assign fault_now = fetch_fault || decode_fault || data_align_fault ||
                       data_range_fault || target_align_fault || target_range_fault;
    assign commit_enable = !rst && !halted && !fault_now;

    always @(*) begin
        if (lui)
            rd_data = imm;
        else if (jump)
            rd_data = pc_plus4;
        else if (mem_to_reg)
            rd_data = mem_rd_data;
        else
            rd_data = alu_result;
    end

    always @(*) begin
        if (rst || halted || fault_now)
            pc_next = pc_current;
        else if (control_target_valid)
            pc_next = control_target;
        else
            pc_next = pc_plus4;
    end

    always @(posedge clk) begin
        if (rst) begin
            illegal_instr <= 1'b0;
            misaligned <= 1'b0;
            access_fault <= 1'b0;
            halted <= 1'b0;
        end else if (!halted && fault_now) begin
            if (decode_fault)
                illegal_instr <= 1'b1;
            if (imem_misaligned || data_align_fault || target_align_fault)
                misaligned <= 1'b1;
            if (imem_out_of_range || data_range_fault || target_range_fault)
                access_fault <= 1'b1;
            halted <= 1'b1;
        end
    end
endmodule
