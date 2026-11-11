// =============================================================================
// Testbench : tb_result_capture (Verilog-2001)
// Project   : RISC-V 32-bit Single-Cycle CPU - SEP490_G93
// Branch    : Phuoc (Tester)
// DUT       : result_capture.v - chi capture khi wb_valid = 1
//             va wb_rd dung TARGET_RD. Reset active-low (reset_n = 0).
//
// Chay:
//   iverilog -g2001 -Wall -s tb_result_capture \
//       -o out/tb_result_capture.vvp src/result_capture.v tb/tb_result_capture.v
//   vvp out/tb_result_capture.vvp
// =============================================================================

`timescale 1ns/1ps

module tb_result_capture;
    reg        clk, reset_n, wb_valid;
    reg  [4:0]  wb_rd;
    reg  [31:0] wb_data;
    wire [31:0] display_data;
    wire [31:0] display_data_5; // ban sao voi TARGET_RD = 5, de test parameter
    integer errors, tests;

    // DUT mac dinh: TARGET_RD = 8.
    result_capture dut (
        .clk(clk), .reset_n(reset_n), .wb_valid(wb_valid),
        .wb_rd(wb_rd), .wb_data(wb_data), .display_data(display_data)
    );
    // DUT thu 2: TARGET_RD = 5, de chac parameter co tac dung.
    result_capture #(.TARGET_RD(5'd5)) dut5 (
        .clk(clk), .reset_n(reset_n), .wb_valid(wb_valid),
        .wb_rd(wb_rd), .wb_data(wb_data), .display_data(display_data_5)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    initial begin
        $dumpfile("out/waveform_result_capture.vcd");
        $dumpvars(0, tb_result_capture.clk, tb_result_capture.reset_n,
                  tb_result_capture.wb_valid, tb_result_capture.wb_rd,
                  tb_result_capture.wb_data, tb_result_capture.display_data);
    end

    task check_display;
        input [31:0] expected;
        begin
            tests = tests + 1;
            if (display_data !== expected) begin
                $display("FAIL display got=%08h expected=%08h", display_data, expected);
                errors = errors + 1;
            end else
                $display("PASS display actual=%08h expected=%08h", display_data, expected);
        end
    endtask

    // Dua 1 lan capture roi cho qua 1 canh clock.
    task try_capture;
        input        valid;
        input [4:0]  rd;
        input [31:0] data;
        begin
            wb_valid = valid; wb_rd = rd; wb_data = data;
            @(posedge clk); #1;
            wb_valid = 1'b0;
        end
    endtask

    initial begin
        errors = 0; tests = 0;
        reset_n = 1'b0; wb_valid = 1'b0; wb_rd = 0; wb_data = 0;

        // 1. Reset: display ve 0.
        @(posedge clk); #1;
        @(posedge clk); #1;
        check_display(32'd0);
        reset_n = 1'b1;

        // 2. Capture dung rd (x8): display = 55.
        try_capture(1'b1, 5'd8, 32'd55);
        check_display(32'd55);

        // 3. Capture sai rd (x9): display khong doi.
        try_capture(1'b1, 5'd9, 32'd99);
        check_display(32'd55);

        // 4. wb_valid = 0: display khong doi, du rd dung.
        try_capture(1'b0, 5'd8, 32'd77);
        check_display(32'd55);

        // 5. Capture gia tri moi (x8): display doi theo.
        try_capture(1'b1, 5'd8, 32'h12345678);
        check_display(32'h12345678);

        // 6. Parameter: DUT thu 2 (TARGET_RD = 5) chi capture khi rd = 5.
        //    Lan capture o buoc 5 co rd = 8 nen display_data_5 phai bang 0.
        tests = tests + 1;
        if (display_data_5 !== 32'd0) begin
            $display("FAIL display_5 got=%08h expected=00000000", display_data_5);
            errors = errors + 1;
        end else
            $display("PASS display_5 actual=00000000 (khong capture rd=8)");
        try_capture(1'b1, 5'd5, 32'd42);
        tests = tests + 1;
        if (display_data_5 !== 32'd42) begin
            $display("FAIL display_5 got=%08h expected=0000002a", display_data_5);
            errors = errors + 1;
        end else
            $display("PASS display_5 actual=0000002a (capture rd=5)");

        // 7. Reset lai: display ve 0.
        reset_n = 1'b0;
        @(posedge clk); #1;
        check_display(32'd0);
        reset_n = 1'b1;

        if (errors == 0)
            $display("tb_result_capture: PASS (%0d checks)", tests);
        else
            $display("tb_result_capture: FAIL (%0d/%0d errors)", errors, tests);
        $finish;
    end

    initial begin
        #10000;
        $display("tb_result_capture: FAIL timeout");
        $finish;
    end
endmodule
