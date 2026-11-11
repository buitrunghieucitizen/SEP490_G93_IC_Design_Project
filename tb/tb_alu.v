// =============================================================================
// Testbench : tb_alu (Verilog-2001)
// Project   : RISC-V 32-bit CPU
// Desc      : Unit testbench for ALU module
//             Tests: ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU
// Run       : iverilog -o out/tb_alu.vvp src/alu.v tb/tb_alu.v
//             vvp out/tb_alu.vvp
// =============================================================================

`timescale 1ns/1ps

module tb_alu;

    // DUT signals - dung reg cho input, wire cho output
    reg  [31:0] a, b;
    reg  [3:0]  alu_ctrl;
    wire [31:0] result;
    wire        zero;

    // Test tracking
    integer pass_count;
    integer fail_count;
    integer seed;
    integer i;
    reg [31:0] ra, rb;
    reg [3:0]  rctrl;
    initial begin
        pass_count = 0;
        fail_count = 0;
    end

    // -------------------------------------------------------------------------
    // DUT Instantiation
    // -------------------------------------------------------------------------
    alu dut (
        .a        (a),
        .b        (b),
        .alu_ctrl (alu_ctrl),
        .result   (result),
        .zero     (zero)
    );

    // -------------------------------------------------------------------------
    // Golden model (tinh doc lap trong testbench, theo dinh nghia phep tinh)
    // -------------------------------------------------------------------------
    function [31:0] golden;
        input [3:0] ctrl;
        input [31:0] x;
        input [31:0] y;
        begin
            case (ctrl)
                4'b0000: golden = x + y;
                4'b0001: golden = x - y;
                4'b0010: golden = x & y;
                4'b0011: golden = x | y;
                4'b0100: golden = x ^ y;
                4'b0101: golden = x << y[4:0];
                4'b0110: golden = x >> y[4:0];
                4'b0111: golden = $signed(x) >>> y[4:0];
                4'b1000: golden = ($signed(x) < $signed(y)) ? 32'd1 : 32'd0;
                4'b1001: golden = (x < y) ? 32'd1 : 32'd0;
                default: golden = 32'd0;
            endcase
        end
    endfunction

    // Quiet check for random vectors: only FAIL is printed.
    task check_quiet;
        input [31:0] expected;
        begin
            #1;
            if (result === expected) pass_count = pass_count + 1;
            else begin
                $display("  FAIL | a=%08h b=%08h ctrl=%0d | result=%08h (expected=%08h)",
                          a, b, alu_ctrl, result, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // Task: check_result
    // -------------------------------------------------------------------------
    task check_result;
        input [31:0] expected;
        begin
            #1; // let combinational logic settle
            if (result === expected) begin
                $display("  PASS | a=%0d b=%0d ctrl=%0d | result=%0d (expected=%0d)",
                          a, b, alu_ctrl, result, expected);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL | a=%0d b=%0d ctrl=%0d | result=%0d (expected=%0d)",
                          a, b, alu_ctrl, result, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // Test sequence
    // -------------------------------------------------------------------------
    // -------------------------------------------------------------------------
    // VCD Waveform Dump
    // -------------------------------------------------------------------------
    initial begin
        $dumpfile("out/waveform_alu.vcd");
        $dumpvars(0, tb_alu);
    end

    initial begin
        $display("================================================");
        $display("   ALU TESTBENCH - RISC-V 32-bit CPU");
        $display("================================================");

        // ---- ADD (ctrl=0) ----
        $display("\n[ADD]");
        alu_ctrl = 4'b0000;
        a = 32'd5;        b = 32'd3;          check_result(32'd8);
        a = 32'd0;        b = 32'd0;          check_result(32'd0);
        a = 32'hFFFFFFFF; b = 32'd1;          check_result(32'd0); // overflow wrap
        a = 32'h7FFFFFFF; b = 32'd1;          check_result(32'h80000000); // overflow to sign bit
        a = 32'h80000000; b = 32'h80000000;   check_result(32'd0); // -2^31 + -2^31 wraps to 0

        // ---- SUB (ctrl=1) ----
        $display("\n[SUB]");
        alu_ctrl = 4'b0001;
        a = 32'd10; b = 32'd4;               check_result(32'd6);
        a = 32'd5;  b = 32'd5;               check_result(32'd0);
        a = 32'd0;  b = 32'd1;               check_result(32'hFFFFFFFF); // 0-1 = -1
        a = 32'h80000000; b = 32'd1;         check_result(32'h7FFFFFFF); // -2^31 - 1 wraps
        a = 32'h7FFFFFFF; b = 32'hFFFFFFFF;  check_result(32'h80000000); // max - (-1) overflows

        // ---- AND (ctrl=2) ----
        $display("\n[AND]");
        alu_ctrl = 4'b0010;
        a = 32'hFF; b = 32'h0F;             check_result(32'h0F);
        a = 32'hAA; b = 32'h55;             check_result(32'h00);
        a = 32'hF0F0F0F0; b = 32'h0FF00FF0;  check_result(32'h00F000F0);

        // ---- OR (ctrl=3) ----
        $display("\n[OR]");
        alu_ctrl = 4'b0011;
        a = 32'hAA; b = 32'h55;             check_result(32'hFF);
        a = 32'd0;  b = 32'd0;              check_result(32'd0);
        a = 32'hF0F0F0F0; b = 32'h0FF00FF0;  check_result(32'hFFF0FFF0);

        // ---- XOR (ctrl=4) ----
        $display("\n[XOR]");
        alu_ctrl = 4'b0100;
        a = 32'hFF; b = 32'hFF;             check_result(32'h00);
        a = 32'hAA; b = 32'h55;             check_result(32'hFF);
        a = 32'hF0F0F0F0; b = 32'h0FF00FF0;  check_result(32'hFF00FF00);

        // ---- SLL (ctrl=5) ----
        $display("\n[SLL]");
        alu_ctrl = 4'b0101;
        a = 32'd1;  b = 32'd4;              check_result(32'd16);
        a = 32'd1;  b = 32'd31;             check_result(32'h80000000);
        a = 32'd1;  b = 32'd35;             check_result(32'd8); // only b[4:0]
        a = 32'hA5A5A5A5; b = 32'd0;        check_result(32'hA5A5A5A5);
        a = 32'd1;  b = 32'd32;             check_result(32'd1); // shift 32 -> shift 0

        // ---- SRL (ctrl=6) ----
        $display("\n[SRL]");
        alu_ctrl = 4'b0110;
        a = 32'h80000000; b = 32'd1;        check_result(32'h40000000);
        a = 32'd16;       b = 32'd2;        check_result(32'd4);
        a = 32'h80000000; b = 32'd31;       check_result(32'd1);
        a = 32'h80000000; b = 32'd35;       check_result(32'h10000000);
        a = 32'h80000000; b = 32'd0;        check_result(32'h80000000); // shift 0

        // ---- SRA (ctrl=7) ----
        $display("\n[SRA]");
        alu_ctrl = 4'b0111;
        a = 32'h80000000; b = 32'd1;        check_result(32'hC0000000);
        a = 32'd16;       b = 32'd2;        check_result(32'd4);
        a = 32'h80000000; b = 32'd31;       check_result(32'hFFFFFFFF);
        a = 32'h80000000; b = 32'd35;       check_result(32'hF0000000);
        a = 32'h80000000; b = 32'd0;        check_result(32'h80000000); // shift 0
        a = 32'h40000000; b = 32'd1;        check_result(32'h20000000); // positive: same as SRL

        // ---- SLT (ctrl=8) ----
        $display("\n[SLT]");
        alu_ctrl = 4'b1000;
        a = 32'hFFFFFFFF; b = 32'd0;        check_result(32'd1); // -1 < 0 signed
        a = 32'd5;        b = 32'd3;        check_result(32'd0);
        a = 32'd3;        b = 32'd5;        check_result(32'd1);
        a = 32'h80000000; b = 32'h7FFFFFFF; check_result(32'd1); // -2^31 < max signed
        a = 32'h7FFFFFFF; b = 32'h80000000; check_result(32'd0);

        // ---- SLTU (ctrl=9) ----
        $display("\n[SLTU]");
        alu_ctrl = 4'b1001;
        a = 32'hFFFFFFFF; b = 32'd0;        check_result(32'd0);
        a = 32'd0; b = 32'hFFFFFFFF;        check_result(32'd1);
        a = 32'h80000000; b = 32'h7FFFFFFF; check_result(32'd0); // unsigned: 2^31 > max-1
        a = 32'h7FFFFFFF; b = 32'h80000000; check_result(32'd1);

        // ---- Illegal alu_ctrl: default must return 0 ----
        $display("\n[Illegal ctrl]");
        a = 32'd5; b = 32'd3;
        alu_ctrl = 4'b1010; check_result(32'd0);
        alu_ctrl = 4'b1011; check_result(32'd0);
        alu_ctrl = 4'b1110; check_result(32'd0);
        alu_ctrl = 4'b1111; check_result(32'd0);

        // ---- Random: 1000 pairs, seed fixed so the run repeats ----
        $display("\n[Random 1000]");
        seed = 32'h13579bdf;
        for (i = 0; i < 1000; i = i + 1) begin
            ra = $random(seed);
            rb = $random(seed);
            rctrl = i % 10;
            a = ra; b = rb; alu_ctrl = rctrl;
            check_quiet(golden(rctrl, ra, rb));
        end
        $display("  Random done: 1000 vectors, see FAIL lines above if any");

        // ---- Zero Flag ----
        $display("\n[Zero Flag]");
        alu_ctrl = 4'b0000; // ADD
        a = 32'd5; b = 32'd0;
        #1;
        if (zero == 1'b0)
            $display("  PASS | zero=0 when result=5");
        else begin
            $display("  FAIL | zero should be 0");
            fail_count = fail_count + 1;
        end

        a = 32'd0; b = 32'd0;
        #1;
        if (zero == 1'b1)
            $display("  PASS | zero=1 when result=0");
        else begin
            $display("  FAIL | zero should be 1");
            fail_count = fail_count + 1;
        end

        // ---- Summary ----
        $display("\n================================================");
        $display("   RESULTS: %0d PASS | %0d FAIL", pass_count, fail_count);
        if (fail_count == 0)
            $display("   ALL TESTS PASSED!");
        else
            $display("   SOME TESTS FAILED - check above");
        $display("================================================\n");

        $finish;
    end

    initial begin
        #10000;
        $display("FAIL | ALU testbench timeout");
        $finish;
    end

endmodule
