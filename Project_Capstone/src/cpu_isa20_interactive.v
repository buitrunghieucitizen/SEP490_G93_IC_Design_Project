// CPU integrating the unmodified control_unit and the MMIO datapath.
// Existing cpu_top.v remains untouched and independently usable.
module cpu_isa20_interactive #(
    parameter IMEM_DEPTH = 256,
    parameter DMEM_SIZE = 128,
    parameter MEM_FILE = "src/program_multi_mmio.mem"
)(
    input wire demo_mode, demo_hold,
    input wire [31:0] demo_word,
    output wire [31:0] demo_wb,
    output wire demo_commit,
    input wire clk,
    input wire rst,
    input wire [31:0] operand_a,
    input wire [31:0] operand_b,
    input wire [2:0] command_id,
    input wire command_ready,
    output wire [31:0] result_data,
    output wire result_strobe,
    output wire illegal_instr,
    output wire misaligned,
    output wire access_fault,
    output wire halted,
    output wire [31:0] debug_pc,
    output wire [31:0] debug_instr,
    output wire decode_illegal_debug
);
    wire reg_write,alu_src,mem_write,mem_read,mem_to_reg;
    wire branch,jump,jalr,lui,auipc;
    wire [3:0] alu_ctrl;
    wire [6:0] opcode,funct7;
    wire [2:0] funct3;
    wire decode_illegal_instr;
    assign decode_illegal_debug = decode_illegal_instr;
    control_unit u_ctrl(
        .opcode(opcode),.funct3(funct3),.funct7(funct7),
        .reg_write(reg_write),.alu_src(alu_src),.mem_write(mem_write),
        .mem_read(mem_read),.mem_to_reg(mem_to_reg),.branch(branch),
        .jump(jump),.jalr(jalr),.lui(lui),.auipc(auipc),
        .alu_ctrl(alu_ctrl),.illegal_instr(decode_illegal_instr)
    );
    datapath_isa20_interactive #(.IMEM_DEPTH(IMEM_DEPTH),.DMEM_SIZE(DMEM_SIZE),.MEM_FILE(MEM_FILE)) u_datapath(
        .demo_mode(demo_mode),.demo_hold(demo_hold),.demo_word(demo_word),
        .demo_wb(demo_wb),.demo_commit(demo_commit),
        .clk(clk),.rst(rst),.reg_write(reg_write),.alu_src(alu_src),
        .mem_write(mem_write),.mem_read(mem_read),.mem_to_reg(mem_to_reg),
        .branch(branch),.jump(jump),.jalr(jalr),.lui(lui),.auipc(auipc),
        .alu_ctrl(alu_ctrl),.decode_illegal_instr(decode_illegal_instr),
        .operand_a(operand_a),.operand_b(operand_b),.command_id(command_id),
        .command_ready(command_ready),.result_data(result_data),
        .result_strobe(result_strobe),
        .opcode(opcode),.funct3(funct3),.funct7(funct7),
        .illegal_instr(illegal_instr),.misaligned(misaligned),
        .access_fault(access_fault),.halted(halted),
        .debug_pc(debug_pc),.debug_instr(debug_instr)
    );
endmodule
