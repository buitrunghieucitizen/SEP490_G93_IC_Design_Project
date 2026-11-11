// =============================================================================
// Testbench : tb_register_file (Verilog-2001)
// Project   : RISC-V 32-bit Single-Cycle CPU - SEP490_G93
// Branch    : Phuoc (Tester)
// DUT       : register_file.v - 32 thanh ghi 32-bit,
//             2 cong doc to hop, 1 cong ghi dong bo.
//             x0 luon doc bang 0 va khong cho ghi.
//
// Chay:
//   iverilog -g2001 -Wall -s tb_register_file -o out/tb_register_file.vvp \
//       src/register_file.v tb/tb_register_file.v
//   vvp out/tb_register_file.vvp
//
// Luu y: doc la to hop nen kiem tra ngay sau #1;
//        ghi la dong bo nen phai doi qua canh clock roi moi doc lai.
// =============================================================================

`timescale 1ns/1ps

module tb_register_file;
    reg        clk, rst, reg_write;
    reg  [4:0]  rs1_addr, rs2_addr, rd_addr;
    reg  [31:0] rd_data;
    wire [31:0] rs1_data, rs2_data;
    integer errors, tests, i;

    register_file dut (
        .clk(clk), .rst(rst),
        .rs1_addr(rs1_addr), .rs2_addr(rs2_addr),
        .rs1_data(rs1_data), .rs2_data(rs2_data),
        .rd_addr(rd_addr), .rd_data(rd_data), .reg_write(reg_write)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    initial begin
        $dumpfile("out/waveform_register_file.vcd");
        $dumpvars(0, tb_register_file.clk, tb_register_file.rst,
                  tb_register_file.rs1_addr, tb_register_file.rs2_addr,
                  tb_register_file.rs1_data, tb_register_file.rs2_data,
                  tb_register_file.rd_addr, tb_register_file.rd_data,
                  tb_register_file.reg_write);
    end

    // Kiem tra 1 cong doc.
    task check_read;
        input [4:0]  addr;
        input [31:0] expected;
        input        is_rs1; // 1: doc bang rs1, 0: doc bang rs2
        begin
            tests = tests + 1;
            if (is_rs1) begin
                rs1_addr = addr; #1;
                if (rs1_data !== expected) begin
                    $display("FAIL read x%0d (rs1) got=%08h expected=%08h",
                             addr, rs1_data, expected);
                    errors = errors + 1;
                end else
                    $display("PASS read x%0d actual=%08h expected=%08h",
                             addr, rs1_data, expected);
            end else begin
                rs2_addr = addr; #1;
                if (rs2_data !== expected) begin
                    $display("FAIL read x%0d (rs2) got=%08h expected=%08h",
                             addr, rs2_data, expected);
                    errors = errors + 1;
                end else
                    $display("PASS read x%0d actual=%08h expected=%08h",
                             addr, rs2_data, expected);
            end
        end
    endtask

    // Ghi 1 thanh ghi: dat du lieu, cho qua 1 canh clock, tat reg_write.
    task write_reg;
        input [4:0]  addr;
        input [31:0] data;
        begin
            rd_addr = addr; rd_data = data; reg_write = 1'b1;
            @(posedge clk); #1;
            reg_write = 1'b0;
        end
    endtask

    // Reset dong bo: bat rst trong 2 chu ky.
    task do_reset;
        begin
            rst = 1'b1; reg_write = 1'b0;
            @(posedge clk); #1;
            @(posedge clk); #1;
            rst = 1'b0;
        end
    endtask

    initial begin
        errors = 0; tests = 0;
        rst = 1'b1; reg_write = 1'b0;
        rs1_addr = 0; rs2_addr = 0; rd_addr = 0; rd_data = 0;

        // 1. Reset: tat ca thanh ghi ve 0.
        do_reset();
        check_read(5'd0,  32'd0, 1'b1);
        check_read(5'd1,  32'd0, 1'b1);
        check_read(5'd31, 32'd0, 1'b0);

        // 2. Ghi roi doc lai, dung ca 2 cong doc.
        write_reg(5'd1, 32'd5);
        check_read(5'd1, 32'd5, 1'b1);
        write_reg(5'd2, 32'h12345678);
        check_read(5'd2, 32'h12345678, 1'b0);
        // Doc 2 thanh ghi cung luc.
        rs1_addr = 5'd1; rs2_addr = 5'd2; #1;
        tests = tests + 1;
        if (rs1_data !== 32'd5 || rs2_data !== 32'h12345678) begin
            $display("FAIL dual read got=%08h/%08h expected=00000005/12345678",
                     rs1_data, rs2_data);
            errors = errors + 1;
        end else
            $display("PASS dual read x1=00000005 x2=12345678");

        // 3. Gia tri bien.
        write_reg(5'd31, 32'hFFFFFFFF);
        check_read(5'd31, 32'hFFFFFFFF, 1'b1);
        write_reg(5'd10, 32'h80000000);
        check_read(5'd10, 32'h80000000, 1'b0);

        // 4. Ghi x0: doc x0 van bang 0.
        write_reg(5'd0, 32'hFFFFFFFF);
        check_read(5'd0, 32'd0, 1'b1);
        check_read(5'd0, 32'd0, 1'b0);

        // 5. reg_write = 0: khong ghi duoc.
        rd_addr = 5'd1; rd_data = 32'd99; reg_write = 1'b0;
        @(posedge clk); #1;
        check_read(5'd1, 32'd5, 1'b1);

        // 6. Ghi tat ca x1..x31, moi thanh ghi 1 gia tri rieng, doc lai het.
        for (i = 1; i < 32; i = i + 1)
            write_reg(i[4:0], i * 32'd100);
        for (i = 1; i < 32; i = i + 1)
            check_read(i[4:0], i * 32'd100, 1'b1);

        // 7. Reset lan nua: tat ca ve 0.
        do_reset();
        check_read(5'd1,  32'd0, 1'b1);
        check_read(5'd31, 32'd0, 1'b0);

        if (errors == 0)
            $display("tb_register_file: PASS (%0d checks)", tests);
        else
            $display("tb_register_file: FAIL (%0d/%0d errors)", errors, tests);
        $finish;
    end

    initial begin
        #20000;
        $display("tb_register_file: FAIL timeout");
        $finish;
    end
endmodule
