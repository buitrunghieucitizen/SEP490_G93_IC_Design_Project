`timescale 1ns/1ps

module tb_cpu;
    reg clk;
    reg rst;
    wire illegal_instr, misaligned, access_fault, halted;
    integer errors;
    integer i;
    integer checks;
    integer program_mode;
    reg [8*256-1:0] program_file;

    cpu_top dut (.clk(clk), .rst(rst));
    assign illegal_instr = dut.illegal_instr;
    assign misaligned = dut.misaligned;
    assign access_fault = dut.access_fault;
    assign halted = dut.halted;

    initial clk = 1'b0;
    always #5 clk = ~clk;

    // VCD waveform for GTKWave. Dump key CPU signals only, not full RAM arrays.
    initial begin
        $dumpfile("out/waveform_cpu.vcd");
        $dumpvars(0, tb_cpu.clk, tb_cpu.rst);
        $dumpvars(0, tb_cpu.dut.debug_pc, tb_cpu.dut.debug_instr,
                  tb_cpu.dut.debug_alu_result, tb_cpu.dut.debug_wb_data);
        $dumpvars(0, tb_cpu.dut.opcode, tb_cpu.dut.funct3, tb_cpu.dut.funct7,
                  tb_cpu.dut.reg_write, tb_cpu.dut.alu_src,
                  tb_cpu.dut.mem_read, tb_cpu.dut.mem_write,
                  tb_cpu.dut.branch, tb_cpu.dut.jump, tb_cpu.dut.alu_ctrl,
                  tb_cpu.dut.illegal_instr, tb_cpu.dut.misaligned,
                  tb_cpu.dut.access_fault, tb_cpu.dut.halted);
        $dumpvars(0, tb_cpu.dut.u_datapath.pc_next,
                  tb_cpu.dut.u_datapath.rs1_addr, tb_cpu.dut.u_datapath.rs2_addr,
                  tb_cpu.dut.u_datapath.rd_addr, tb_cpu.dut.u_datapath.rs1_data,
                  tb_cpu.dut.u_datapath.rs2_data, tb_cpu.dut.u_datapath.imm,
                  tb_cpu.dut.u_datapath.alu_a, tb_cpu.dut.u_datapath.alu_b,
                  tb_cpu.dut.u_datapath.mem_rd_data,
                  tb_cpu.dut.u_datapath.fault_now,
                  tb_cpu.dut.u_datapath.commit_enable);
    end

    function [31:0] enc_r;
        input [6:0] f7; input [4:0] rs2; input [4:0] rs1;
        input [2:0] f3; input [4:0] rd;
        begin enc_r = {f7,rs2,rs1,f3,rd,7'b0110011}; end
    endfunction
    function [31:0] enc_i;
        input [11:0] imm; input [4:0] rs1; input [2:0] f3;
        input [4:0] rd; input [6:0] op;
        begin enc_i = {imm,rs1,f3,rd,op}; end
    endfunction
    function [31:0] enc_s;
        input [11:0] imm; input [4:0] rs2; input [4:0] rs1; input [2:0] f3;
        begin enc_s = {imm[11:5],rs2,rs1,f3,imm[4:0],7'b0100011}; end
    endfunction
    function [31:0] enc_b;
        input [12:0] imm; input [4:0] rs2; input [4:0] rs1; input [2:0] f3;
        begin enc_b = {imm[12],imm[10:5],rs2,rs1,f3,imm[4:1],imm[11],7'b1100011}; end
    endfunction
    function [31:0] enc_u;
        input [19:0] imm; input [4:0] rd; input [6:0] op;
        begin enc_u = {imm,rd,op}; end
    endfunction
    function [31:0] enc_j;
        input [20:0] imm; input [4:0] rd;
        begin enc_j = {imm[20],imm[10:1],imm[11],imm[19:12],rd,7'b1101111}; end
    endfunction

    task put;
        input integer index;
        input [31:0] word;
        begin dut.u_datapath.u_inst_mem.rom[index] = word; end
    endtask
    task clear_program;
        integer n;
        begin
            for (n=0; n<256; n=n+1) dut.u_datapath.u_inst_mem.rom[n] = 32'h00000013;
        end
    endtask
    task begin_case;
        begin
            rst = 1'b1;
            @(posedge clk); #1;
            @(posedge clk); #1;
            rst = 1'b0;
        end
    endtask
    task wait_cycles;
        input integer count;
        integer n;
        begin for (n=0; n<count; n=n+1) begin @(posedge clk); #1; end end
    endtask
    task check_reg;
        input [4:0] index;
        input [31:0] expected;
        begin
            checks=checks+1;
            if (dut.u_datapath.u_reg_file.regfile[index] !== expected) begin
                $display("FAIL reg x%0d got=%08h expected=%08h", index,
                    dut.u_datapath.u_reg_file.regfile[index], expected);
                errors = errors + 1;
            end else $display("PASS reg x%0d actual=%08h expected=%08h",index,
                dut.u_datapath.u_reg_file.regfile[index],expected);
        end
    endtask
    task check_status;
        input exp_illegal; input exp_misaligned; input exp_access; input exp_halted;
        begin
            checks=checks+1;
            if ({illegal_instr,misaligned,access_fault,halted} !==
                {exp_illegal,exp_misaligned,exp_access,exp_halted}) begin
                $display("FAIL status illegal/misaligned/access/halted=%b%b%b%b expected=%b%b%b%b",
                    illegal_instr,misaligned,access_fault,halted,
                    exp_illegal,exp_misaligned,exp_access,exp_halted);
                errors = errors + 1;
            end else $display("PASS status actual=%b%b%b%b expected=%b%b%b%b",
                illegal_instr,misaligned,access_fault,halted,
                exp_illegal,exp_misaligned,exp_access,exp_halted);
        end
    endtask
    task check_pc;
        input [31:0] expected;
        begin
            checks=checks+1;
            if (dut.u_datapath.pc_current !== expected) begin
                $display("FAIL PC got=%08h expected=%08h",dut.u_datapath.pc_current,expected);
                errors = errors + 1;
            end else $display("PASS PC actual=%08h expected=%08h",dut.u_datapath.pc_current,expected);
        end
    endtask

    initial begin
        errors = 0;
        checks = 0;
        rst = 1'b1;
        #1;
        program_mode = $value$plusargs("PROGRAM=%s", program_file);
        if (program_mode) begin
            $readmemh(program_file, dut.u_datapath.u_inst_mem.rom);
            begin_case();
            wait_cycles(100);
            $display("tb_cpu: PROGRAM RUN complete; PC=%08h halted=%b illegal=%b misaligned=%b access_fault=%b",
                dut.u_datapath.pc_current, halted, illegal_instr, misaligned, access_fault);
            $finish;
        end else begin
        clear_program();
        // Full functional program: all 20 instructions plus signed immediates,
        // dependent operations, shift edge cases, and taken/not-taken branches.
        put(0,  enc_i(12'd5,  0,3'b000,1,7'b0010011));
        put(1,  enc_i(12'd3,  0,3'b000,2,7'b0010011));
        put(2,  enc_r(7'b0000000,2,1,3'b000,3));
        put(3,  enc_r(7'b0100000,2,1,3'b000,4));
        put(4,  enc_r(7'b0000000,2,1,3'b111,5));
        put(5,  enc_r(7'b0000000,2,1,3'b110,6));
        put(6,  enc_r(7'b0000000,2,1,3'b100,7));
        put(7,  enc_r(7'b0000000,2,1,3'b001,8));
        put(8,  enc_u(20'h80000,10,7'b0110111));
        put(9,  enc_r(7'b0000000,2,10,3'b101,9));
        put(10, enc_r(7'b0100000,2,10,3'b101,11));
        put(11, enc_i(12'hffe,1,3'b000,12,7'b0010011));
        put(12, enc_i(12'hfff,10,3'b111,13,7'b0010011));
        put(13, enc_i(12'hfff,0,3'b110,14,7'b0010011));
        put(14, enc_i(12'hfff,10,3'b100,15,7'b0010011));
        put(15, enc_s(12'd0,3,0,3'b010));
        put(16, enc_s(12'd4,4,0,3'b010));
        put(17, enc_i(12'd0,0,3'b010,16,7'b0000011));
        put(18, enc_i(12'd4,0,3'b010,17,7'b0000011));
        put(19, enc_i(12'd5,0,3'b000,18,7'b0010011));
        put(20, enc_b(13'd8,18,1,3'b000));
        put(21, enc_i(12'd99,0,3'b000,19,7'b0010011));
        put(22, enc_b(13'd8,2,1,3'b001));
        put(23, enc_i(12'd99,0,3'b000,19,7'b0010011));
        put(24, enc_b(13'd8,2,1,3'b000));
        put(25, enc_b(13'd8,1,1,3'b001));
        put(26, enc_i(12'd3,0,3'b000,19,7'b0010011));
        put(27, enc_i(12'd1,19,3'b000,19,7'b0010011));
        put(28, enc_b(13'h1ffc,18,19,3'b001)); // backward BNE -4
        put(29, enc_u(20'd0,20,7'b0010111));
        put(30, enc_i(12'd7,1,3'b000,0,7'b0010011)); // x0 destination
        put(31, enc_j(21'd8,21));
        put(32, enc_i(12'd99,0,3'b000,22,7'b0010011));
        put(33, enc_i(12'd148,0,3'b000,24,7'b0010011));
        put(34, enc_i(12'd0,24,3'b000,22,7'b1100111));
        put(35, enc_i(12'd99,0,3'b000,25,7'b0010011));
        put(36, enc_i(12'd99,0,3'b000,25,7'b0010011));
        put(37, enc_i(12'd7,0,3'b000,26,7'b0010011));
        put(38, enc_i(12'd31,0,3'b000,27,7'b0010011));
        put(39, enc_r(7'b0000000,27,1,3'b001,28)); // shift by 31
        put(40, enc_i(12'd0,0,3'b000,29,7'b0010011));
        put(41, enc_r(7'b0000000,29,10,3'b101,30)); // shift by 0
        put(42, enc_i(12'd35,0,3'b000,27,7'b0010011));
        put(43, enc_r(7'b0100000,27,10,3'b101,31)); // 35 uses shamt 3
        put(44, enc_j(21'd0,0));

        // Initialize data RAM (RAM intentionally survives CPU reset).
        dut.u_datapath.u_data_mem.mem[0] = 32'd0;
        dut.u_datapath.u_data_mem.mem[1] = 32'd0;
        begin_case();
        wait_cycles(65);
        check_reg(1,32'd5); check_reg(2,32'd3); check_reg(3,32'd8);
        check_reg(4,32'd2); check_reg(5,32'd1); check_reg(6,32'd7);
        check_reg(7,32'd6); check_reg(8,32'd40); check_reg(9,32'h10000000);
        check_reg(10,32'h80000000); check_reg(11,32'hF0000000);
        check_reg(12,32'd3); check_reg(13,32'h80000000);
        check_reg(14,32'hFFFFFFFF); check_reg(15,32'h7FFFFFFF);
        check_reg(16,32'd8); check_reg(17,32'd2); check_reg(18,32'd5);
        check_reg(19,32'd5); check_reg(20,32'd116); check_reg(21,32'd128);
        check_reg(22,32'd140); check_reg(24,32'd148); check_reg(25,32'd0);
        check_reg(26,32'd7); check_reg(27,32'd35); check_reg(28,32'h80000000);
        check_reg(29,32'd0); check_reg(30,32'h80000000); check_reg(31,32'hF0000000);
        checks=checks+1;
        if (dut.u_datapath.u_reg_file.regfile[0] !== 32'd0) begin
            $display("FAIL x0 changed"); errors=errors+1;
        end else $display("PASS x0 remains zero");
        checks=checks+1;
        if (dut.u_datapath.u_data_mem.mem[0] !== 32'd8 || dut.u_datapath.u_data_mem.mem[1] !== 32'd2) begin
            $display("FAIL RAM contents word0=%h word1=%h",dut.u_datapath.u_data_mem.mem[0],dut.u_datapath.u_data_mem.mem[1]);
            errors=errors+1;
        end else $display("PASS RAM[0]=%08h RAM[1]=%08h expected=00000008/00000002",
            dut.u_datapath.u_data_mem.mem[0],dut.u_datapath.u_data_mem.mem[1]);
        check_status(0,0,0,0);

        // Reset while running clears registers/status/PC, but retains RAM.
        rst=1'b1; @(posedge clk); #1;
        check_pc(32'd0); check_reg(1,32'd0); check_reg(0,32'd0);
        checks=checks+1;
        if (dut.u_datapath.u_data_mem.mem[0] !== 32'd8) begin $display("FAIL RAM reset policy"); errors=errors+1; end
        else $display("PASS RAM retained across reset: actual=%08h expected=00000008",dut.u_datapath.u_data_mem.mem[0]);
        rst=1'b0;

        // Illegal unsupported instruction: no register or memory side effect.
        clear_program(); put(0,32'hFFFFFFFF); begin_case(); wait_cycles(1);
        check_status(1,0,0,1); check_pc(32'd0); check_reg(1,32'd0);
        checks=checks+1;
        if (dut.u_datapath.u_data_mem.mem[0] !== 32'd8) begin $display("FAIL illegal modified RAM"); errors=errors+1; end
        else $display("PASS illegal instruction did not modify RAM[0]");
        wait_cycles(3); check_status(1,0,0,1); check_pc(32'd0); // sticky until reset
        rst=1'b1; @(posedge clk); #1; check_status(0,0,0,0); rst=1'b0;

        // Invalid R funct7, and unsupported OP-IMM shift encoding.
        clear_program(); put(0,enc_r(7'b0000001,2,1,3'b000,3)); begin_case(); wait_cycles(1);
        check_status(1,0,0,1); check_reg(3,32'd0);
        clear_program(); put(0,enc_i(12'd1,1,3'b001,3,7'b0010011)); begin_case(); wait_cycles(1);
        check_status(1,0,0,1); check_reg(3,32'd0);
        clear_program(); put(0,enc_r(7'b0000000,2,1,3'b010,3)); begin_case(); wait_cycles(1);
        check_status(1,0,0,1); check_reg(3,32'd0); // SLT is intentionally outside CPU subset

        // Invalid load/store funct3 are illegal and never commit.
        clear_program(); put(0,enc_i(12'd0,0,3'b000,5,7'b0000011)); begin_case(); wait_cycles(1);
        check_status(1,0,0,1); check_reg(5,32'd0);
        clear_program(); put(0,enc_s(12'd0,2,0,3'b000)); begin_case(); wait_cycles(1);
        check_status(1,0,0,1);
        checks=checks+1;
        if (dut.u_datapath.u_data_mem.mem[0] !== 32'd8) begin $display("FAIL illegal store wrote RAM"); errors=errors+1; end
        else $display("PASS illegal SW encoding did not modify RAM[0]");

        // Misaligned and out-of-range data accesses halt before committing.
        clear_program(); put(0,enc_i(12'd1,0,3'b000,1,7'b0010011));
        put(1,enc_i(12'd0,1,3'b010,5,7'b0000011)); begin_case(); wait_cycles(2);
        check_status(0,1,0,1); check_pc(32'd4); check_reg(5,32'd0);
        clear_program(); put(0,enc_u(20'd1,1,7'b0110111));
        put(1,enc_i(12'd0,1,3'b010,5,7'b0000011)); begin_case(); wait_cycles(2);
        check_status(0,0,1,1); check_pc(32'd4); check_reg(5,32'd0);
        clear_program(); put(0,enc_i(12'd1,0,3'b000,1,7'b0010011));
        put(1,enc_s(12'd0,2,1,3'b010)); begin_case(); wait_cycles(2);
        check_status(0,1,0,1);
        checks=checks+1;
        if (dut.u_datapath.u_data_mem.mem[0] !== 32'd8) begin $display("FAIL misaligned SW wrote RAM"); errors=errors+1; end
        else $display("PASS misaligned SW did not modify RAM[0]");
        clear_program(); put(0,enc_u(20'd1,1,7'b0110111));
        put(1,enc_s(12'd0,2,1,3'b010)); begin_case(); wait_cycles(2);
        check_status(0,0,1,1);
        checks=checks+1;
        if (dut.u_datapath.u_data_mem.mem[0] !== 32'd8) begin $display("FAIL out-of-range SW aliased to RAM"); errors=errors+1; end
        else $display("PASS out-of-range SW did not alias RAM[0]");

        // Taken branch with a 2-byte target and JAL/JALR target failures.
        clear_program(); put(0,enc_b(13'd2,0,0,3'b000)); begin_case(); wait_cycles(1);
        check_status(0,1,0,1); check_pc(32'd0);
        clear_program(); put(0,enc_b(13'd2,0,0,3'b001)); begin_case(); wait_cycles(1);
        check_status(0,0,0,0); check_pc(32'd4); // not-taken branch ignores its target
        clear_program(); put(0,enc_j(21'd2,5)); begin_case(); wait_cycles(1);
        check_status(0,1,0,1); check_pc(32'd0); check_reg(5,32'd0);
        clear_program(); put(0,enc_j(21'd1024,5)); begin_case(); wait_cycles(1);
        check_status(0,0,1,1); check_pc(32'd0); check_reg(5,32'd0);
        clear_program(); put(0,enc_u(20'd1,1,7'b0110111));
        put(1,enc_i(12'd0,1,3'b000,5,7'b1100111)); begin_case(); wait_cycles(2);
        check_status(0,0,1,1); check_pc(32'd4); check_reg(5,32'd0);
        clear_program(); put(0,enc_i(12'd6,0,3'b000,1,7'b0010011));
        put(1,enc_i(12'd0,1,3'b000,1,7'b1100111)); begin_case(); wait_cycles(2);
        check_status(0,1,0,1); check_pc(32'd4); check_reg(1,32'd6);

        // Legal JALR with rs1==rd uses the old rs1 value for target and PC+4 for link.
        clear_program(); put(0,enc_i(12'd12,0,3'b000,5,7'b0010011));
        put(1,enc_i(12'd0,5,3'b000,5,7'b1100111)); begin_case(); wait_cycles(2);
        check_pc(32'd12); check_reg(5,32'd8); check_status(0,0,0,0);

        // 32-bit arithmetic wraps modulo 2^32 in the integrated datapath.
        clear_program(); put(0,enc_u(20'h80000,1,7'b0110111));
        put(1,enc_i(12'hfff,1,3'b000,1,7'b0010011));
        put(2,enc_i(12'd1,0,3'b000,2,7'b0010011));
        put(3,enc_r(7'b0000000,2,1,3'b000,3));
        put(4,enc_r(7'b0100000,2,0,3'b000,4));
        put(5,enc_j(21'd0,0)); begin_case(); wait_cycles(6);
        check_reg(1,32'h7fffffff); check_reg(2,32'd1);
        check_reg(3,32'h80000000); check_reg(4,32'hffffffff);
        check_status(0,0,0,0);

        // Register corner cases: rs2==rd and rs1==rs2 in the same instruction.
        clear_program(); put(0,enc_i(12'd3,0,3'b000,1,7'b0010011));
        put(1,enc_i(12'd4,0,3'b000,2,7'b0010011));
        put(2,enc_r(7'b0000000,2,1,3'b000,2));
        put(3,enc_r(7'b0000000,1,1,3'b000,3));
        put(4,enc_j(21'd0,0)); begin_case(); wait_cycles(5);
        check_reg(2,32'd7); check_reg(3,32'd6); check_status(0,0,0,0);

        if (errors == 0) $display("tb_cpu: PASS (%0d assertions, 20-instruction datapath and fault cases)",checks);
        else $display("tb_cpu: FAIL (%0d errors)",errors);
        $finish;
        end
    end

    initial begin
        #100000;
        $display("tb_cpu: FAIL timeout");
        $finish;
    end
endmodule
