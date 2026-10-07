// CPU integration top. MEM_FILE is resolved relative to the simulation cwd.
module cpu_top #(
    parameter IMEM_DEPTH = 256,
    parameter DMEM_SIZE = 1024,
    parameter MEM_FILE = "src/program.mem"
) (
    input  wire clk,
    input  wire rst
);
    wire reg_write, alu_src, mem_write, mem_read, mem_to_reg;
    wire branch, jump, jalr, lui, auipc;
    wire [3:0] alu_ctrl;
    wire [6:0] opcode, funct7;
    wire [2:0] funct3;
    wire decode_illegal_instr;
    wire illegal_instr, misaligned, access_fault, halted;

    control_unit u_ctrl (
        .opcode(opcode), .funct3(funct3), .funct7(funct7),
        .reg_write(reg_write), .alu_src(alu_src), .mem_write(mem_write),
        .mem_read(mem_read), .mem_to_reg(mem_to_reg), .branch(branch),
        .jump(jump), .jalr(jalr), .lui(lui), .auipc(auipc),
        .alu_ctrl(alu_ctrl), .illegal_instr(decode_illegal_instr)
    );

    datapath #(.IMEM_DEPTH(IMEM_DEPTH), .DMEM_SIZE(DMEM_SIZE), .MEM_FILE(MEM_FILE)) u_datapath (
        .clk(clk), .rst(rst), .reg_write(reg_write), .alu_src(alu_src),
        .mem_write(mem_write), .mem_read(mem_read), .mem_to_reg(mem_to_reg),
        .branch(branch), .jump(jump), .jalr(jalr), .lui(lui), .auipc(auipc),
        .alu_ctrl(alu_ctrl), .decode_illegal_instr(decode_illegal_instr),
        .opcode(opcode), .funct3(funct3), .funct7(funct7),
        .illegal_instr(illegal_instr), .misaligned(misaligned),
        .access_fault(access_fault), .halted(halted)
    );
endmodule
