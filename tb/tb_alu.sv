// =============================================================================
// Testbench : tb_alu
// Project   : RISC-V 32-bit Single-Cycle CPU
// Desc      : Unit testbench for ALU module
//             Tests: ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU
// Run       : iverilog -g2012 -o out/sim.vvp src/alu.sv tb/tb_alu.sv
//             vvp out/sim.vvp
// =============================================================================

`timescale 1ns/1ps

module tb_alu;

    // DUT signals
    logic [31:0] a, b;
    logic [3:0]  alu_ctrl;
    logic [31:0] result;
    logic        zero;

    // Test tracking
    integer pass_count = 0;
    integer fail_count = 0;

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
    // Task: check_result
    // -------------------------------------------------------------------------
    task check_result;
        input [31:0] expected;
        input [63:0] test_name; // just a number for display
        begin
            #1; // let combinational logic settle
            if (result === expected) begin
                $display("  ✅ PASS | a=%0d b=%0d ctrl=%0d | result=%0d (expected=%0d)",
                          a, b, alu_ctrl, result, expected);
                pass_count++;
            end else begin
                $display("  ❌ FAIL | a=%0d b=%0d ctrl=%0d | result=%0d (expected=%0d)",
                          a, b, alu_ctrl, result, expected);
                fail_count++;
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // Test sequence
    // -------------------------------------------------------------------------
    initial begin
        $display("================================================");
        $display("   ALU TESTBENCH — RISC-V 32-bit CPU");
        $display("================================================");

        // ---- ADD (ctrl=0) ----
        $display("\n[ADD]");
        alu_ctrl = 4'b0000;
        a = 32'd5;  b = 32'd3;   check_result(32'd8,   0);  // 5+3=8
        a = 32'd0;  b = 32'd0;   check_result(32'd0,   0);  // 0+0=0 (zero flag)
        a = 32'hFFFFFFFF; b = 32'd1; check_result(32'd0, 0); // overflow wrap

        // ---- SUB (ctrl=1) ----
        $display("\n[SUB]");
        alu_ctrl = 4'b0001;
        a = 32'd10; b = 32'd4;   check_result(32'd6,   0);  // 10-4=6
        a = 32'd5;  b = 32'd5;   check_result(32'd0,   0);  // 5-5=0 (zero flag test)
        a = 32'd0;  b = 32'd1;   check_result(32'hFFFFFFFF, 0); // 0-1 = -1 (unsigned wrap)

        // ---- AND (ctrl=2) ----
        $display("\n[AND]");
        alu_ctrl = 4'b0010;
        a = 32'hFF; b = 32'h0F;  check_result(32'h0F,  0);  // 0xFF & 0x0F
        a = 32'hAA; b = 32'h55;  check_result(32'h00,  0);  // no overlap

        // ---- OR (ctrl=3) ----
        $display("\n[OR]");
        alu_ctrl = 4'b0011;
        a = 32'hAA; b = 32'h55;  check_result(32'hFF,  0);
        a = 32'd0;  b = 32'd0;   check_result(32'd0,   0);

        // ---- XOR (ctrl=4) ----
        $display("\n[XOR]");
        alu_ctrl = 4'b0100;
        a = 32'hFF; b = 32'hFF;  check_result(32'h00,  0);  // same → 0
        a = 32'hAA; b = 32'h55;  check_result(32'hFF,  0);

        // ---- SLL - Shift Left Logical (ctrl=5) ----
        $display("\n[SLL]");
        alu_ctrl = 4'b0101;
        a = 32'd1;  b = 32'd4;   check_result(32'd16,  0);  // 1<<4=16
        a = 32'd1;  b = 32'd31;  check_result(32'h80000000, 0);

        // ---- SRL - Shift Right Logical (ctrl=6) ----
        $display("\n[SRL]");
        alu_ctrl = 4'b0110;
        a = 32'h80000000; b = 32'd1; check_result(32'h40000000, 0); // logical: fills 0
        a = 32'd16; b = 32'd2;    check_result(32'd4, 0);

        // ---- SRA - Shift Right Arithmetic (ctrl=7) ----
        $display("\n[SRA]");
        alu_ctrl = 4'b0111;
        a = 32'h80000000; b = 32'd1; check_result(32'hC0000000, 0); // arithmetic: fills sign
        a = 32'd16; b = 32'd2;       check_result(32'd4, 0);

        // ---- SLT - Set Less Than signed (ctrl=8) ----
        $display("\n[SLT]");
        alu_ctrl = 4'b1000;
        a = 32'hFFFFFFFF; b = 32'd0; check_result(32'd1, 0); // -1 < 0 (signed) → 1
        a = 32'd5;        b = 32'd3; check_result(32'd0, 0); // 5 < 3 → 0
        a = 32'd3;        b = 32'd5; check_result(32'd1, 0); // 3 < 5 → 1

        // ---- SLTU - Set Less Than Unsigned (ctrl=9) ----
        $display("\n[SLTU]");
        alu_ctrl = 4'b1001;
        a = 32'hFFFFFFFF; b = 32'd0; check_result(32'd0, 0); // big unsigned > 0
        a = 32'd0; b = 32'hFFFFFFFF; check_result(32'd1, 0); // 0 < big unsigned → 1

        // ---- ZERO flag ----
        $display("\n[Zero Flag]");
        alu_ctrl = 4'b0000; // ADD
        a = 32'd5; b = 32'd0;
        #1;
        if (zero == 1'b0)
            $display("  ✅ PASS | zero=0 when result=5");
        else begin
            $display("  ❌ FAIL | zero should be 0");
            fail_count++;
        end

        a = 32'd0; b = 32'd0;
        #1;
        if (zero == 1'b1)
            $display("  ✅ PASS | zero=1 when result=0");
        else begin
            $display("  ❌ FAIL | zero should be 1");
            fail_count++;
        end

        // ---- Summary ----
        $display("\n================================================");
        $display("   RESULTS: %0d PASS | %0d FAIL", pass_count, fail_count);
        if (fail_count == 0)
            $display("   🎉 ALL TESTS PASSED!");
        else
            $display("   ⚠️  SOME TESTS FAILED — check above");
        $display("================================================\n");

        $finish;
    end

endmodule
