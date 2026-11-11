// =============================================================================
// Testbench : tb_test_fault (Verilog-2001)
// Project   : RISC-V 32-bit Single-Cycle CPU - SEP490_G93
// Branch    : Phuoc (Tester)
// DUT       : cpu_top, chay chuong trinh tb/programs/test_fault.S.
//             Chuong trinh: ADDI x1, x0, 5, roi lenh illegal 0xFFFFFFFF.
//             Ket qua dung: PC=4, halted=1, illegal_instr=1,
//             x1=5, x2=0 (lenh sau khong chay).
//
// Chay (tu thu muc Code/): xem tb_test_all_20.v, thay ten top
// bang tb_test_fault va file .mem bang test_fault.mem.
// =============================================================================

`timescale 1ns/1ps

module tb_test_fault;
    reg clk, rst;
    wire illegal_instr, misaligned, access_fault, halted;
    integer errors, tests;

    cpu_top #(.MEM_FILE("tb/programs/test_fault.mem")) dut (
        .clk(clk), .rst(rst),
        .illegal_instr(illegal_instr), .misaligned(misaligned),
        .access_fault(access_fault), .halted(halted)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

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
        repeat (10) begin @(posedge clk); #1; end

        check_reg(5'd1, 32'd5);
        check_reg(5'd2, 32'd0);

        tests = tests + 1;
        if (dut.debug_pc !== 32'd4 || !halted || !illegal_instr ||
            misaligned || access_fault) begin
            $display("FAIL PC/status PC=%08h halted/illegal/mis/access=%b%b%b%b",
                     dut.debug_pc, halted, illegal_instr, misaligned, access_fault);
            errors = errors + 1;
        end else
            $display("PASS PC=4, halted=1, illegal=1");

        // Reset sau loi: PC ve 0, het halted.
        rst = 1'b1;
        repeat (2) begin @(posedge clk); #1; end
        tests = tests + 1;
        if (dut.debug_pc !== 32'd0 || halted || illegal_instr) begin
            $display("FAIL sau reset PC=%08h halted=%b illegal=%b",
                     dut.debug_pc, halted, illegal_instr);
            errors = errors + 1;
        end else
            $display("PASS sau reset PC=0, het halted/illegal");

        if (errors == 0)
            $display("tb_test_fault: PASS (%0d checks)", tests);
        else
            $display("tb_test_fault: FAIL (%0d/%0d errors)", errors, tests);
        $finish;
    end

    initial begin
        #10000;
        $display("tb_test_fault: FAIL timeout");
        $finish;
    end
endmodule
