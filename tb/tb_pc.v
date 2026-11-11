// =============================================================================
// Testbench : tb_pc (Verilog-2001)
// Project   : RISC-V 32-bit Single-Cycle CPU - SEP490_G93
// Branch    : Phuoc (Tester)
// DUT       : pc.v - thanh ghi PC 32-bit, reset dong bo active-high ve 0.
//
// Chay:
//   iverilog -g2001 -Wall -s tb_pc -o out/tb_pc.vvp src/pc.v tb/tb_pc.v
//   vvp out/tb_pc.vvp
//
// Quy uoc chung cua nhom Tester:
//   - So sanh bang !== de bat ca X/Z.
//   - Lay mau sau canh clock 1 don vi: @(posedge clk); #1;
//   - Cuoi test in "tb_pc: PASS (...)" hoac "tb_pc: FAIL (...)".
// =============================================================================

`timescale 1ns/1ps

module tb_pc;
    reg        clk;
    reg        rst;
    reg  [31:0] pc_next;
    wire [31:0] pc_current;
    integer errors, tests;

    pc dut (.clk(clk), .rst(rst), .pc_next(pc_next), .pc_current(pc_current));

    initial clk = 1'b0;
    always #5 clk = ~clk;

    initial begin
        $dumpfile("out/waveform_pc.vcd");
        $dumpvars(0, tb_pc.clk, tb_pc.rst, tb_pc.pc_next, tb_pc.pc_current);
    end

    // Kiem tra PC hien tai bang gia tri mong doi.
    task check_pc;
        input [31:0] expected;
        begin
            tests = tests + 1;
            if (pc_current !== expected) begin
                $display("FAIL PC got=%08h expected=%08h", pc_current, expected);
                errors = errors + 1;
            end else
                $display("PASS PC actual=%08h expected=%08h", pc_current, expected);
        end
    endtask

    // Cho qua 1 chu ky clock roi kiem tra PC.
    task step_and_check;
        input [31:0] expected;
        begin
            @(posedge clk); #1;
            check_pc(expected);
        end
    endtask

    initial begin
        errors = 0; tests = 0;
        rst = 1'b1; pc_next = 32'd0;

        // 1. Reset: PC ve 0.
        step_and_check(32'd0);
        step_and_check(32'd0);

        // 2. Chay tuan tu: PC nhan dung pc_next.
        rst = 1'b0;
        pc_next = 32'd4;  step_and_check(32'd4);
        pc_next = 32'd8;  step_and_check(32'd8);
        pc_next = 32'd12; step_and_check(32'd12);

        // 3. Nhay: PC nhan dia chi lon.
        pc_next = 32'd100; step_and_check(32'd100);

        // 4. Giu nguyen: pc_next = PC hien tai thi PC khong doi.
        pc_next = 32'd100; step_and_check(32'd100);

        // 5. Reset giua chung: dang chay thi reset, PC ve 0 ngay chu ky sau.
        rst = 1'b1; pc_next = 32'd999;
        step_and_check(32'd0);
        rst = 1'b0; pc_next = 32'd4;
        step_and_check(32'd4);

        if (errors == 0)
            $display("tb_pc: PASS (%0d checks)", tests);
        else
            $display("tb_pc: FAIL (%0d/%0d errors)", errors, tests);
        $finish;
    end

    initial begin
        #10000;
        $display("tb_pc: FAIL timeout");
        $finish;
    end
endmodule
