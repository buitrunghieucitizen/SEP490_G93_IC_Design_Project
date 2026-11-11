// =============================================================================
// Testbench : tb_test_all_20 (Verilog-2001)
// Project   : RISC-V 32-bit Single-Cycle CPU - SEP490_G93
// Branch    : Phuoc (Tester)
// DUT       : cpu_top, chay chuong trinh tb/programs/test_all_20.S.
//             Chuong trinh nay test du 20 lenh trong 1 lan chay.
//             Ket qua dung xem o dau file test_all_20.S.
//
// Chay (tu thu muc Code/):
//   iverilog -g2001 -Wall -s tb_test_all_20 -o out/tb_test_all_20.vvp \
//       src/alu.v src/register_file.v src/pc.v src/instruction_memory.v \
//       src/data_memory.v src/immediate_gen.v src/control_unit.v \
//       src/datapath.v src/cpu_top.v tb/tb_test_all_20.v
//   vvp out/tb_test_all_20.vvp
// =============================================================================

`timescale 1ns/1ps

module tb_test_all_20;
    reg clk, rst;
    wire illegal_instr, misaligned, access_fault, halted;
    integer errors, tests;

    cpu_top #(.MEM_FILE("tb/programs/test_all_20.mem")) dut (
        .clk(clk), .rst(rst),
        .illegal_instr(illegal_instr), .misaligned(misaligned),
        .access_fault(access_fault), .halted(halted)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    initial begin
        $dumpfile("out/waveform_test_all_20.vcd");
        $dumpvars(0, tb_test_all_20.clk, tb_test_all_20.rst,
                  tb_test_all_20.dut.debug_pc, tb_test_all_20.dut.debug_instr,
                  tb_test_all_20.halted, tb_test_all_20.illegal_instr);
    end

    task check_reg;
        input [4:0] index;
        input [31:0] expected;
        begin
            tests = tests + 1;
            if (dut.u_datapath.u_reg_file.regfile[index] !== expected) begin
                $display("FAIL reg x%0d got=%08h expected=%08h", index,
                         dut.u_datapath.u_reg_file.regfile[index], expected);
                errors = errors + 1;
            end else
                $display("PASS reg x%0d actual=%08h expected=%08h", index,
                         dut.u_datapath.u_reg_file.regfile[index], expected);
        end
    endtask

    initial begin
        errors = 0; tests = 0;
        rst = 1'b1;
        repeat (2) begin @(posedge clk); #1; end
        rst = 1'b0;
        // 32 lenh, moi lenh 1 chu ky; chay du 80 chu ky de chac da vao vong lap cuoi.
        repeat (80) begin @(posedge clk); #1; end

        check_reg(5'd1,  32'd5);
        check_reg(5'd2,  32'd3);
        check_reg(5'd3,  32'd8);
        check_reg(5'd4,  32'd2);
        check_reg(5'd5,  32'd1);
        check_reg(5'd6,  32'd7);
        check_reg(5'd7,  32'd6);
        check_reg(5'd8,  32'd40);
        check_reg(5'd9,  32'h10000000);
        check_reg(5'd10, 32'h80000000);
        check_reg(5'd11, 32'hF0000000);
        check_reg(5'd12, 32'd3);
        check_reg(5'd13, 32'h80000000);
        check_reg(5'd14, 32'hFFFFFFFF);
        check_reg(5'd15, 32'h7FFFFFFF);
        check_reg(5'd16, 32'd8);
        check_reg(5'd17, 32'd2);
        check_reg(5'd18, 32'd11);
        check_reg(5'd19, 32'd100);
        check_reg(5'd20, 32'h80000000);
        check_reg(5'd21, 32'd108);
        check_reg(5'd23, 32'd116);
        check_reg(5'd24, 32'd55);

        // DMEM: SW x3,0(x0) va SW x4,4(x0).
        tests = tests + 1;
        if (dut.u_datapath.u_data_mem.mem[0] !== 32'd8 ||
            dut.u_datapath.u_data_mem.mem[1] !== 32'd2) begin
            $display("FAIL DMEM got=%08h/%08h expected=00000008/00000002",
                     dut.u_datapath.u_data_mem.mem[0],
                     dut.u_datapath.u_data_mem.mem[1]);
            errors = errors + 1;
        end else
            $display("PASS DMEM[0]=8 DMEM[1]=2");

        // PC o vong lap cuoi (jal x0, end), khong co co loi.
        tests = tests + 1;
        if (dut.debug_pc !== 32'd124 || halted || illegal_instr ||
            misaligned || access_fault) begin
            $display("FAIL PC/status PC=%08h halted/illegal/mis/access=%b%b%b%b",
                     dut.debug_pc, halted, illegal_instr, misaligned, access_fault);
            errors = errors + 1;
        end else
            $display("PASS PC=124, khong co co loi");

        if (errors == 0)
            $display("tb_test_all_20: PASS (%0d checks)", tests);
        else
            $display("tb_test_all_20: FAIL (%0d/%0d errors)", errors, tests);
        $finish;
    end

    initial begin
        #20000;
        $display("tb_test_all_20: FAIL timeout");
        $finish;
    end
endmodule
