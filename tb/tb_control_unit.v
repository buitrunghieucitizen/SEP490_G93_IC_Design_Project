`timescale 1ns/1ps

module tb_control_unit;
    reg [6:0] opcode;
    reg [2:0] funct3;
    reg [6:0] funct7;
    wire reg_write, alu_src, mem_write, mem_read, mem_to_reg;
    wire branch, jump, jalr, lui, auipc, illegal_instr;
    wire [3:0] alu_ctrl;
    integer errors, tests;

    control_unit dut (
        .opcode(opcode), .funct3(funct3), .funct7(funct7),
        .reg_write(reg_write), .alu_src(alu_src), .mem_write(mem_write),
        .mem_read(mem_read), .mem_to_reg(mem_to_reg), .branch(branch),
        .jump(jump), .jalr(jalr), .lui(lui), .auipc(auipc),
        .alu_ctrl(alu_ctrl), .illegal_instr(illegal_instr)
    );

    initial begin
        $dumpfile("out/waveform_control_unit.vcd");
        $dumpvars(0, tb_control_unit.opcode, tb_control_unit.funct3,
                  tb_control_unit.funct7, tb_control_unit.reg_write,
                  tb_control_unit.alu_src, tb_control_unit.mem_write,
                  tb_control_unit.mem_read, tb_control_unit.mem_to_reg,
                  tb_control_unit.branch, tb_control_unit.jump,
                  tb_control_unit.jalr, tb_control_unit.lui,
                  tb_control_unit.auipc, tb_control_unit.alu_ctrl,
                  tb_control_unit.illegal_instr);
    end

    function [14:0] expected;
        input ill, rw, asrc, mw, mr, m2r, br, jmp, jr, is_lui, is_auipc;
        input [3:0] alu;
        begin expected={ill,rw,asrc,mw,mr,m2r,br,jmp,jr,is_lui,is_auipc,alu}; end
    endfunction

    task check;
        input [6:0] op;
        input [2:0] f3;
        input [6:0] f7;
        input [14:0] exp;
        reg [14:0] got;
        begin
            opcode=op; funct3=f3; funct7=f7; #1;
            got={illegal_instr,reg_write,alu_src,mem_write,mem_read,mem_to_reg,
                 branch,jump,jalr,lui,auipc,alu_ctrl};
            tests=tests+1;
            if (got !== exp) begin
                $display("FAIL decode op=%b f3=%b f7=%b got=%b expected=%b",op,f3,f7,got,exp);
                errors=errors+1;
            end else $display("PASS decode op=%b f3=%b f7=%b actual=%b expected=%b",op,f3,f7,got,exp);
        end
    endtask

    initial begin
        errors=0; tests=0;
        // All 20 supported instruction encodings.
        check(7'b0110011,3'b000,7'b0000000,expected(0,1,0,0,0,0,0,0,0,0,0,4'b0000)); // ADD
        check(7'b0110011,3'b000,7'b0100000,expected(0,1,0,0,0,0,0,0,0,0,0,4'b0001)); // SUB
        check(7'b0110011,3'b001,7'b0000000,expected(0,1,0,0,0,0,0,0,0,0,0,4'b0101)); // SLL
        check(7'b0110011,3'b100,7'b0000000,expected(0,1,0,0,0,0,0,0,0,0,0,4'b0100)); // XOR
        check(7'b0110011,3'b101,7'b0000000,expected(0,1,0,0,0,0,0,0,0,0,0,4'b0110)); // SRL
        check(7'b0110011,3'b101,7'b0100000,expected(0,1,0,0,0,0,0,0,0,0,0,4'b0111)); // SRA
        check(7'b0110011,3'b110,7'b0000000,expected(0,1,0,0,0,0,0,0,0,0,0,4'b0011)); // OR
        check(7'b0110011,3'b111,7'b0000000,expected(0,1,0,0,0,0,0,0,0,0,0,4'b0010)); // AND
        check(7'b0010011,3'b000,7'b1010101,expected(0,1,1,0,0,0,0,0,0,0,0,4'b0000)); // ADDI, upper bits are immediate
        check(7'b0010011,3'b100,7'b1010101,expected(0,1,1,0,0,0,0,0,0,0,0,4'b0100)); // XORI
        check(7'b0010011,3'b110,7'b1010101,expected(0,1,1,0,0,0,0,0,0,0,0,4'b0011)); // ORI
        check(7'b0010011,3'b111,7'b1010101,expected(0,1,1,0,0,0,0,0,0,0,0,4'b0010)); // ANDI
        check(7'b0000011,3'b010,7'b0000000,expected(0,1,1,0,1,1,0,0,0,0,0,4'b0000)); // LW
        check(7'b0100011,3'b010,7'b0000000,expected(0,0,1,1,0,0,0,0,0,0,0,4'b0000)); // SW
        check(7'b1100011,3'b000,7'b0000000,expected(0,0,0,0,0,0,1,0,0,0,0,4'b0001)); // BEQ
        check(7'b1100011,3'b001,7'b0000000,expected(0,0,0,0,0,0,1,0,0,0,0,4'b0001)); // BNE
        check(7'b1101111,3'b000,7'b0000000,expected(0,1,0,0,0,0,0,1,0,0,0,4'b0000)); // JAL
        check(7'b1100111,3'b000,7'b0000000,expected(0,1,1,0,0,0,0,1,1,0,0,4'b0000)); // JALR
        check(7'b0110111,3'b000,7'b0000000,expected(0,1,0,0,0,0,0,0,0,1,0,4'b0000)); // LUI
        check(7'b0010111,3'b000,7'b0000000,expected(0,1,1,0,0,0,0,0,0,0,1,4'b0000)); // AUIPC

        // Unsupported instructions / malformed sub-encodings must be inert.
        check(7'b0110011,3'b010,7'b0000000,expected(1,0,0,0,0,0,0,0,0,0,0,4'b0000)); // SLT
        check(7'b0110011,3'b000,7'b0000001,expected(1,0,0,0,0,0,0,0,0,0,0,4'b0000)); // bad funct7
        check(7'b0010011,3'b001,7'b0000000,expected(1,0,0,0,0,0,0,0,0,0,0,4'b0000)); // SLLI
        check(7'b0000011,3'b000,7'b0000000,expected(1,0,0,0,0,0,0,0,0,0,0,4'b0000)); // LB
        check(7'b0100011,3'b001,7'b0000000,expected(1,0,0,0,0,0,0,0,0,0,0,4'b0000)); // SH
        check(7'b1100011,3'b100,7'b0000000,expected(1,0,0,0,0,0,0,0,0,0,0,4'b0000)); // BLT
        check(7'b1100111,3'b001,7'b0000000,expected(1,0,0,0,0,0,0,0,0,0,0,4'b0000)); // bad JALR funct3
        check(7'b1111111,3'b000,7'b0000000,expected(1,0,0,0,0,0,0,0,0,0,0,4'b0000)); // unknown opcode

        if (errors==0) $display("tb_control_unit: PASS (%0d checks)",tests);
        else $display("tb_control_unit: FAIL (%0d/%0d errors)",errors,tests);
        $finish;
    end
    initial begin #10000; $display("tb_control_unit: FAIL timeout"); $finish; end
endmodule
