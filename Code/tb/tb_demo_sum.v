`timescale 1ns/1ps

module tb_demo_sum;
    reg clk;
    reg rst;
    wire illegal_instr, misaligned, access_fault, halted;
    wire [31:0] debug_pc, debug_instr, debug_alu_result, debug_wb_data;
    wire [31:0] debug_x1, debug_x2, debug_x3, debug_x4, debug_dmem_word0;
    integer errors;

    cpu_top #(.MEM_FILE("tb/programs/demo_sum_1_to_10.mem")) dut (
        .clk(clk), .rst(rst),
        .illegal_instr(illegal_instr), .misaligned(misaligned),
        .access_fault(access_fault), .halted(halted),
        .debug_pc(debug_pc), .debug_instr(debug_instr),
        .debug_alu_result(debug_alu_result), .debug_wb_data(debug_wb_data)
    );

    assign debug_x1 = dut.u_datapath.u_reg_file.regfile[1];
    assign debug_x2 = dut.u_datapath.u_reg_file.regfile[2];
    assign debug_x3 = dut.u_datapath.u_reg_file.regfile[3];
    assign debug_x4 = dut.u_datapath.u_reg_file.regfile[4];
    assign debug_dmem_word0 = dut.u_datapath.u_data_mem.mem[0];

    initial clk = 1'b0;
    always #5 clk = ~clk;

    initial begin
        $dumpfile("out/waveform_demo_sum.vcd");
        $dumpvars(0, tb_demo_sum.clk, tb_demo_sum.rst,
                  tb_demo_sum.debug_pc, tb_demo_sum.debug_instr,
                  tb_demo_sum.debug_alu_result, tb_demo_sum.debug_wb_data,
                  tb_demo_sum.illegal_instr, tb_demo_sum.misaligned,
                  tb_demo_sum.access_fault, tb_demo_sum.halted,
                  tb_demo_sum.dut.u_datapath.rs1_data,
                  tb_demo_sum.dut.u_datapath.rs2_data,
                  tb_demo_sum.dut.u_datapath.imm,
                  tb_demo_sum.dut.u_datapath.pc_next,
                  tb_demo_sum.debug_x1, tb_demo_sum.debug_x2,
                  tb_demo_sum.debug_x3, tb_demo_sum.debug_x4,
                  tb_demo_sum.debug_dmem_word0);
    end

    initial begin
        errors = 0;
        rst = 1'b1;
        repeat (2) begin @(posedge clk); #1; end
        rst = 1'b0;
        repeat (60) begin @(posedge clk); #1; end

        if (dut.u_datapath.u_reg_file.regfile[1] !== 32'd11) begin
            $display("FAIL demo: x1=%0d expected=11",dut.u_datapath.u_reg_file.regfile[1]);
            errors = errors + 1;
        end else $display("PASS demo x1 actual=%0d expected=11",dut.u_datapath.u_reg_file.regfile[1]);
        if (dut.u_datapath.u_reg_file.regfile[2] !== 32'd11) begin
            $display("FAIL demo: x2=%0d expected=11",dut.u_datapath.u_reg_file.regfile[2]);
            errors = errors + 1;
        end else $display("PASS demo x2 actual=%0d expected=11",dut.u_datapath.u_reg_file.regfile[2]);
        if (dut.u_datapath.u_reg_file.regfile[3] !== 32'd55) begin
            $display("FAIL demo: x3=%0d expected=55",dut.u_datapath.u_reg_file.regfile[3]);
            errors = errors + 1;
        end else $display("PASS demo x3 actual=%0d expected=55",dut.u_datapath.u_reg_file.regfile[3]);
        if (dut.u_datapath.u_reg_file.regfile[4] !== 32'd55) begin
            $display("FAIL demo: x4=%0d expected=55",dut.u_datapath.u_reg_file.regfile[4]);
            errors = errors + 1;
        end else $display("PASS demo x4 actual=%0d expected=55",dut.u_datapath.u_reg_file.regfile[4]);
        if (dut.u_datapath.u_data_mem.mem[0] !== 32'd55) begin
            $display("FAIL demo: DMEM[0]=%0d expected=55",dut.u_datapath.u_data_mem.mem[0]);
            errors = errors + 1;
        end else $display("PASS demo DMEM[0] actual=%0d expected=55",dut.u_datapath.u_data_mem.mem[0]);
        if (debug_pc !== 32'd32 || halted || illegal_instr || misaligned || access_fault) begin
            $display("FAIL demo: PC=%h halted/illegal/misaligned/access=%b%b%b%b",
                debug_pc, halted, illegal_instr, misaligned, access_fault);
            errors = errors + 1;
        end else $display("PASS demo PC/status actual=PC:%08h flags:%b%b%b%b expected PC:00000020 flags:0000",
            debug_pc,halted,illegal_instr,misaligned,access_fault);

        if (errors == 0)
            $display("tb_demo_sum: PASS: 1+2+...+10 = %0d (x3, x4, DMEM[0])",
                dut.u_datapath.u_reg_file.regfile[3]);
        else
            $display("tb_demo_sum: FAIL (%0d errors)",errors);
        $finish;
    end

    initial begin
        #10000;
        $display("tb_demo_sum: FAIL timeout");
        $finish;
    end
endmodule
