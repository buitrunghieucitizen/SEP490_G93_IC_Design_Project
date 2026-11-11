// =============================================================================
// Testbench : tb_cpu_wb_probe (Verilog-2001)
// Project   : RISC-V 32-bit Single-Cycle CPU - SEP490_G93
// Branch    : Phuoc (Tester)
// DUT       : cpu_wb_probe.v - chi nhan LW x8, 0(x0).
//             Day KHONG phai tin hieu writeback chung cho moi lenh:
//             ADD x8, LW x9, ... deu phai cho wb_valid = 0.
//
// Chay:
//   iverilog -g2001 -Wall -s tb_cpu_wb_probe \
//       -o out/tb_cpu_wb_probe.vvp src/cpu_wb_probe.v tb/tb_cpu_wb_probe.v
//   vvp out/tb_cpu_wb_probe.vvp
// =============================================================================

`timescale 1ns/1ps

module tb_cpu_wb_probe;
    reg  [31:0] debug_instr, debug_wb_data;
    reg        halted, illegal_instr, misaligned, access_fault;
    wire       wb_valid;
    wire [4:0]  wb_rd;
    wire [31:0] wb_data;
    integer errors, tests;

    cpu_wb_probe dut (
        .debug_instr(debug_instr), .debug_wb_data(debug_wb_data),
        .halted(halted), .illegal_instr(illegal_instr),
        .misaligned(misaligned), .access_fault(access_fault),
        .wb_valid(wb_valid), .wb_rd(wb_rd), .wb_data(wb_data)
    );

    initial begin
        $dumpfile("out/waveform_cpu_wb_probe.vcd");
        $dumpvars(0, tb_cpu_wb_probe.debug_instr, tb_cpu_wb_probe.debug_wb_data,
                  tb_cpu_wb_probe.halted, tb_cpu_wb_probe.illegal_instr,
                  tb_cpu_wb_probe.wb_valid, tb_cpu_wb_probe.wb_rd,
                  tb_cpu_wb_probe.wb_data);
    end

    // Kiem tra wb_valid, wb_rd, wb_data cung luc.
    task check_probe;
        input        exp_valid;
        input [4:0]  exp_rd;
        input [31:0] exp_data;
        begin
            tests = tests + 1;
            if (wb_valid !== exp_valid || wb_rd !== exp_rd ||
                wb_data !== exp_data) begin
                $display("FAIL probe valid/rd/data=%b/%0d/%08h expected=%b/%0d/%08h",
                         wb_valid, wb_rd, wb_data, exp_valid, exp_rd, exp_data);
                errors = errors + 1;
            end else
                $display("PASS probe valid=%b rd=%0d data=%08h",
                         wb_valid, wb_rd, wb_data);
        end
    endtask

    // Dua 1 lenh vao, doi logic to hop on dinh roi kiem tra.
    task drive;
        input [31:0] instr;
        input [31:0] data;
        input        h, ill, mis, acc;
        begin
            debug_instr = instr; debug_wb_data = data;
            halted = h; illegal_instr = ill;
            misaligned = mis; access_fault = acc;
            #1;
        end
    endtask

    initial begin
        errors = 0; tests = 0;
        debug_instr = 0; debug_wb_data = 0;
        halted = 0; illegal_instr = 0; misaligned = 0; access_fault = 0;

        // 1. LW x8, 0(x0) = 0x00002403, khong loi: wb_valid = 1, rd = 8.
        drive(32'h00002403, 32'd55, 1'b0, 1'b0, 1'b0, 1'b0);
        check_probe(1'b1, 5'd8, 32'd55);

        // 2. LW x9, 0(x0) = 0x00002483: sai rd, wb_valid = 0.
        drive(32'h00002483, 32'd55, 1'b0, 1'b0, 1'b0, 1'b0);
        check_probe(1'b0, 5'd9, 32'd55);

        // 3. ADD x8, x1, x2 = 0x00208433: khong phai LW, wb_valid = 0.
        drive(32'h00208433, 32'd8, 1'b0, 1'b0, 1'b0, 1'b0);
        check_probe(1'b0, 5'd8, 32'd8);

        // 4. SW x3, 0(x0) = 0x00302023: khong phai LW, wb_valid = 0.
        //    Chu y: voi lenh S-type, bits [11:7] la phan thap cua
        //    immediate (= 0), khong phai rd, nen wb_rd = 0 o day.
        drive(32'h00302023, 32'd8, 1'b0, 1'b0, 1'b0, 1'b0);
        check_probe(1'b0, 5'd0, 32'd8);

        // 5. LW x8 nhung halted = 1: wb_valid = 0.
        drive(32'h00002403, 32'd55, 1'b1, 1'b0, 1'b0, 1'b0);
        check_probe(1'b0, 5'd8, 32'd55);

        // 6. LW x8 nhung illegal_instr = 1: wb_valid = 0.
        drive(32'h00002403, 32'd55, 1'b0, 1'b1, 1'b0, 1'b0);
        check_probe(1'b0, 5'd8, 32'd55);

        // 7. LW x8 nhung misaligned = 1: wb_valid = 0.
        drive(32'h00002403, 32'd55, 1'b0, 1'b0, 1'b1, 1'b0);
        check_probe(1'b0, 5'd8, 32'd55);

        // 8. LW x8 nhung access_fault = 1: wb_valid = 0.
        drive(32'h00002403, 32'd55, 1'b0, 1'b0, 1'b0, 1'b1);
        check_probe(1'b0, 5'd8, 32'd55);

        if (errors == 0)
            $display("tb_cpu_wb_probe: PASS (%0d checks)", tests);
        else
            $display("tb_cpu_wb_probe: FAIL (%0d/%0d errors)", errors, tests);
        $finish;
    end

    initial begin
        #10000;
        $display("tb_cpu_wb_probe: FAIL timeout");
        $finish;
    end
endmodule
