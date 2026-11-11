// =============================================================================
// Testbench : tb_datapath (Verilog-2001)
// Project   : RISC-V 32-bit Single-Cycle CPU - SEP490_G93
// Branch    : Phuoc (Tester)
// DUT       : datapath.v - noi PC, IMEM, ImmGen, RegFile, ALU, DMEM.
//
// Khac tb_cpu o cho: testbench nay LAI TRUC TIEP tin hieu dieu khien,
// khong qua control_unit. Nhu vay neu test FAIL thi biet loi o datapath,
// khong phai o decode. Neu muon test ca decode thi dung tb_cpu.
//
// Chay (tu thu muc Code/):
//   iverilog -g2001 -Wall -s tb_datapath -o out/tb_datapath.vvp \
//       src/alu.v src/register_file.v src/pc.v src/instruction_memory.v \
//       src/data_memory.v src/immediate_gen.v src/datapath.v tb/tb_datapath.v
//   vvp out/tb_datapath.vvp
//
// Chuong trinh test (PC : lenh):
//   0  ADDI x1, x0, 5        20 BEQ x1, x1, +8 (nhay qua PC 24)
//   4  ADDI x2, x0, 3        28 ADDI x5, x0, 7
//   8  ADD  x3, x1, x2       32 JAL x6, +8 (link 36, toi PC 40)
//   12 SW   x3, 0(x0)        40 ADDI x7, x0, 42
//   16 LW   x4, 0(x0)        44 LUI x8, 0x12345
//                            48 AUIPC x9, 0x1 (x9 = 48 + 0x1000)
//                            52 ADDI x10, x0, 1
//                            56 SW x3, 0(x10) -> sai can chinh, halt
// =============================================================================

`timescale 1ns/1ps

module tb_datapath;
    reg        clk, rst;
    reg        reg_write, alu_src, mem_write, mem_read, mem_to_reg;
    reg        branch, jump, jalr, lui, auipc, decode_illegal_instr;
    reg  [3:0] alu_ctrl;
    wire [6:0] opcode, funct7;
    wire [2:0] funct3;
    wire       illegal_instr, misaligned, access_fault, halted;
    wire [31:0] debug_pc, debug_instr, debug_alu_result, debug_wb_data;
    integer errors, tests, i;

    localparam ALU_ADD = 4'b0000;
    localparam ALU_SUB = 4'b0001;

    datapath dut (
        .clk(clk), .rst(rst),
        .reg_write(reg_write), .alu_src(alu_src),
        .mem_write(mem_write), .mem_read(mem_read), .mem_to_reg(mem_to_reg),
        .branch(branch), .jump(jump), .jalr(jalr), .lui(lui), .auipc(auipc),
        .alu_ctrl(alu_ctrl), .decode_illegal_instr(decode_illegal_instr),
        .opcode(opcode), .funct3(funct3), .funct7(funct7),
        .illegal_instr(illegal_instr), .misaligned(misaligned),
        .access_fault(access_fault), .halted(halted),
        .debug_pc(debug_pc), .debug_instr(debug_instr),
        .debug_alu_result(debug_alu_result), .debug_wb_data(debug_wb_data)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    initial begin
        $dumpfile("out/waveform_datapath.vcd");
        $dumpvars(0, tb_datapath.clk, tb_datapath.rst,
                  tb_datapath.debug_pc, tb_datapath.debug_instr,
                  tb_datapath.debug_alu_result, tb_datapath.debug_wb_data,
                  tb_datapath.illegal_instr, tb_datapath.misaligned,
                  tb_datapath.access_fault, tb_datapath.halted);
    end

    // --- Ham encode lenh (giong tb_cpu.v) ---
    function [31:0] enc_r;
        input [6:0] f7; input [4:0] rs2; input [4:0] rs1;
        input [2:0] f3; input [4:0] rd;
        begin enc_r = {f7, rs2, rs1, f3, rd, 7'b0110011}; end
    endfunction
    function [31:0] enc_i;
        input [11:0] imm; input [4:0] rs1; input [2:0] f3;
        input [4:0] rd; input [6:0] op;
        begin enc_i = {imm, rs1, f3, rd, op}; end
    endfunction
    function [31:0] enc_s;
        input [11:0] imm; input [4:0] rs2; input [4:0] rs1; input [2:0] f3;
        begin enc_s = {imm[11:5], rs2, rs1, f3, imm[4:0], 7'b0100011}; end
    endfunction
    function [31:0] enc_b;
        input [12:0] imm; input [4:0] rs2; input [4:0] rs1; input [2:0] f3;
        begin enc_b = {imm[12], imm[10:5], rs2, rs1, f3, imm[4:1], imm[11],
                       7'b1100011}; end
    endfunction
    function [31:0] enc_u;
        input [19:0] imm; input [4:0] rd; input [6:0] op;
        begin enc_u = {imm, rd, op}; end
    endfunction
    function [31:0] enc_j;
        input [20:0] imm; input [4:0] rd;
        begin enc_j = {imm[20], imm[10:1], imm[11], imm[19:12], rd,
                       7'b1101111}; end
    endfunction

    task put;
        input integer index;
        input [31:0] word;
        begin dut.u_inst_mem.rom[index] = word; end
    endtask

    task clear_program;
        integer n;
        begin
            for (n = 0; n < 256; n = n + 1)
                dut.u_inst_mem.rom[n] = 32'h00000013; // NOP: ADDI x0, x0, 0
        end
    endtask

    // Tat het tin hieu dieu khien ve 0 truoc moi lenh.
    task clear_ctrl;
        begin
            reg_write = 0; alu_src = 0; mem_write = 0; mem_read = 0;
            mem_to_reg = 0; branch = 0; jump = 0; jalr = 0;
            lui = 0; auipc = 0; decode_illegal_instr = 0;
            alu_ctrl = ALU_ADD;
        end
    endtask

    task step;
        begin @(posedge clk); #1; end
    endtask

    task check_reg;
        input [4:0] index;
        input [31:0] expected;
        begin
            tests = tests + 1;
            if (dut.u_reg_file.regfile[index] !== expected) begin
                $display("FAIL reg x%0d got=%08h expected=%08h", index,
                         dut.u_reg_file.regfile[index], expected);
                errors = errors + 1;
            end else
                $display("PASS reg x%0d actual=%08h expected=%08h", index,
                         dut.u_reg_file.regfile[index], expected);
        end
    endtask

    task check_pc;
        input [31:0] expected;
        begin
            tests = tests + 1;
            if (debug_pc !== expected) begin
                $display("FAIL PC got=%08h expected=%08h", debug_pc, expected);
                errors = errors + 1;
            end else
                $display("PASS PC actual=%08h expected=%08h", debug_pc, expected);
        end
    endtask

    task check_flags;
        input exp_ill, exp_mis, exp_acc, exp_halt;
        begin
            tests = tests + 1;
            if ({illegal_instr, misaligned, access_fault, halted} !==
                {exp_ill, exp_mis, exp_acc, exp_halt}) begin
                $display("FAIL flags ill/mis/acc/halt=%b%b%b%b expected=%b%b%b%b",
                         illegal_instr, misaligned, access_fault, halted,
                         exp_ill, exp_mis, exp_acc, exp_halt);
                errors = errors + 1;
            end else
                $display("PASS flags ill/mis/acc/halt=%b%b%b%b",
                         illegal_instr, misaligned, access_fault, halted);
        end
    endtask

    initial begin
        errors = 0; tests = 0;
        rst = 1'b1; clear_ctrl();
        #1; // cho $readmemh trong IMEM chay xong truoc khi xoa ROM
        clear_program();
        put(0,  enc_i(12'd5,  0, 3'b000, 1, 7'b0010011)); // ADDI x1, x0, 5
        put(1,  enc_i(12'd3,  0, 3'b000, 2, 7'b0010011)); // ADDI x2, x0, 3
        put(2,  enc_r(7'b0000000, 2, 1, 3'b000, 3));      // ADD x3, x1, x2
        put(3,  enc_s(12'd0, 3, 0, 3'b010));             // SW x3, 0(x0)
        put(4,  enc_i(12'd0,  0, 3'b010, 4, 7'b0000011)); // LW x4, 0(x0)
        put(5,  enc_b(13'd8,  1, 1, 3'b000));            // BEQ x1, x1, +8
        put(6,  enc_i(12'd99, 0, 3'b000, 5, 7'b0010011)); // ADDI x5, x0, 99 (bi nhay qua)
        put(7,  enc_i(12'd7,  0, 3'b000, 5, 7'b0010011)); // ADDI x5, x0, 7
        put(8,  enc_j(21'd8,  6));                       // JAL x6, +8
        put(9,  enc_i(12'd99, 0, 3'b000, 7, 7'b0010011)); // ADDI x7, x0, 99 (bi nhay qua)
        put(10, enc_i(12'd42, 0, 3'b000, 7, 7'b0010011)); // ADDI x7, x0, 42
        put(11, enc_u(20'h12345, 8, 7'b0110111));         // LUI x8, 0x12345
        put(12, enc_u(20'h00001, 9, 7'b0010111));         // AUIPC x9, 0x1
        put(13, enc_i(12'd1,  0, 3'b000, 10, 7'b0010011)); // ADDI x10, x0, 1
        put(14, enc_s(12'd0, 3, 10, 3'b010));            // SW x3, 0(x10): dia chi 1, sai can chinh

        // Reset: PC = 0, khong co co loi.
        step(); check_pc(32'd0); check_flags(1'b0, 1'b0, 1'b0, 1'b0);
        step(); check_pc(32'd0);
        rst = 1'b0;

        // ADDI x1 = 5 (PC 0 -> 4).
        clear_ctrl(); reg_write = 1; alu_src = 1;
        step(); check_reg(5'd1, 32'd5); check_pc(32'd4);

        // ADDI x2 = 3 (PC 4 -> 8).
        clear_ctrl(); reg_write = 1; alu_src = 1;
        step(); check_reg(5'd2, 32'd3); check_pc(32'd8);

        // ADD x3 = x1 + x2 = 8 (PC 8 -> 12).
        clear_ctrl(); reg_write = 1;
        step(); check_reg(5'd3, 32'd8); check_pc(32'd12);

        // SW x3, 0(x0): DMEM[0] = 8 (PC 12 -> 16).
        clear_ctrl(); alu_src = 1; mem_write = 1;
        step(); check_pc(32'd16);
        tests = tests + 1;
        if (dut.u_data_mem.mem[0] !== 32'd8) begin
            $display("FAIL DMEM[0] got=%08h expected=00000008", dut.u_data_mem.mem[0]);
            errors = errors + 1;
        end else
            $display("PASS DMEM[0] actual=00000008");

        // LW x4, 0(x0): x4 = 8 (PC 16 -> 20).
        clear_ctrl(); reg_write = 1; alu_src = 1; mem_read = 1; mem_to_reg = 1;
        step(); check_reg(5'd4, 32'd8); check_pc(32'd20);

        // BEQ x1, x1, +8 (taken): PC 20 -> 28, bo qua PC 24.
        clear_ctrl(); branch = 1; alu_ctrl = ALU_SUB;
        step(); check_pc(32'd28);

        // ADDI x5 = 7 (PC 28 -> 32).
        clear_ctrl(); reg_write = 1; alu_src = 1;
        step(); check_reg(5'd5, 32'd7); check_pc(32'd32);

        // JAL x6, +8: x6 = PC+4 = 36, PC 32 -> 40.
        clear_ctrl(); reg_write = 1; jump = 1;
        step(); check_reg(5'd6, 32'd36); check_pc(32'd40);

        // ADDI x7 = 42 (PC 40 -> 44).
        clear_ctrl(); reg_write = 1; alu_src = 1;
        step(); check_reg(5'd7, 32'd42); check_pc(32'd44);

        // LUI x8 = 0x12345000 (PC 44 -> 48).
        clear_ctrl(); reg_write = 1; lui = 1;
        step(); check_reg(5'd8, 32'h12345000); check_pc(32'd48);

        // AUIPC x9 = PC + 0x1000 = 0x1030 (PC 48 -> 52).
        clear_ctrl(); reg_write = 1; auipc = 1; alu_src = 1;
        step(); check_reg(5'd9, 32'h00001030); check_pc(32'd52);

        // ADDI x10 = 1 (PC 52 -> 56).
        clear_ctrl(); reg_write = 1; alu_src = 1;
        step(); check_reg(5'd10, 32'd1); check_pc(32'd56);

        // SW x3, 0(x10): dia chi 1, sai can chinh.
        // PC giu 56, halted = 1, misaligned = 1, DMEM[0] van = 8.
        clear_ctrl(); alu_src = 1; mem_write = 1;
        step(); check_pc(32'd56); check_flags(1'b0, 1'b1, 1'b0, 1'b1);
        tests = tests + 1;
        if (dut.u_data_mem.mem[0] !== 32'd8) begin
            $display("FAIL DMEM[0] sau loi got=%08h expected=00000008",
                     dut.u_data_mem.mem[0]);
            errors = errors + 1;
        end else
            $display("PASS DMEM[0] sau loi van = 00000008");

        // Reset sau loi: PC = 0, het halted, chay lai duoc.
        clear_ctrl(); rst = 1'b1;
        step(); check_pc(32'd0); check_flags(1'b0, 1'b0, 1'b0, 1'b0);
        rst = 1'b0;

        if (errors == 0)
            $display("tb_datapath: PASS (%0d checks)", tests);
        else
            $display("tb_datapath: FAIL (%0d/%0d errors)", errors, tests);
        $finish;
    end

    initial begin
        #20000;
        $display("tb_datapath: FAIL timeout");
        $finish;
    end
endmodule
