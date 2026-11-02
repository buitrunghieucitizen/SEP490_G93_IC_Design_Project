`timescale 1ns/1ps

module tb_fpga_debug_wrapper;
    reg clk, rst;
    reg [1:0] debug_select;
    wire [31:0] debug_data;
    wire halted, illegal_instr, misaligned, access_fault;
    integer errors;

    fpga_debug_wrapper #(.MEM_FILE("tb/programs/demo_sum_1_to_10.mem")) dut (
        .clk(clk), .rst(rst), .debug_select(debug_select), .debug_data(debug_data),
        .halted(halted), .illegal_instr(illegal_instr),
        .misaligned(misaligned), .access_fault(access_fault)
    );
    initial clk=1'b0;
    always #5 clk=~clk;

    initial begin
        $dumpfile("out/waveform_fpga_debug_wrapper.vcd");
        $dumpvars(0, tb_fpga_debug_wrapper.clk, tb_fpga_debug_wrapper.rst,
                  tb_fpga_debug_wrapper.debug_select,
                  tb_fpga_debug_wrapper.debug_data,
                  tb_fpga_debug_wrapper.halted,
                  tb_fpga_debug_wrapper.illegal_instr,
                  tb_fpga_debug_wrapper.misaligned,
                  tb_fpga_debug_wrapper.access_fault,
                  tb_fpga_debug_wrapper.dut.u_cpu.debug_pc,
                  tb_fpga_debug_wrapper.dut.u_cpu.debug_instr,
                  tb_fpga_debug_wrapper.dut.u_cpu.debug_alu_result,
                  tb_fpga_debug_wrapper.dut.u_cpu.debug_wb_data);
    end

    task check_select;
        input [1:0] sel;
        input [31:0] expected;
        begin
            debug_select=sel; #1;
            if (debug_data !== expected) begin
                $display("FAIL debug select=%b data=%08h expected=%08h",sel,debug_data,expected);
                errors=errors+1;
            end else $display("PASS debug select=%b actual=%08h expected=%08h",sel,debug_data,expected);
        end
    endtask

    initial begin
        errors=0; rst=1'b1; debug_select=0;
        repeat(2) begin @(posedge clk); #1; end
        rst=1'b0;
        @(posedge clk); #1; // PC is now 4; current instruction is ADDI x2,x0,11
        check_select(2'b00,32'd4);
        check_select(2'b01,32'h00B00113);
        check_select(2'b10,32'd11);
        check_select(2'b11,32'd11);
        if (halted || illegal_instr || misaligned || access_fault) begin
            $display("FAIL debug status asserted unexpectedly"); errors=errors+1;
        end else $display("PASS debug status flags=0000");
        if (errors==0) $display("tb_fpga_debug_wrapper: PASS (4 debug mux selections and status)");
        else $display("tb_fpga_debug_wrapper: FAIL (%0d errors)",errors);
        $finish;
    end
    initial begin #10000; $display("tb_fpga_debug_wrapper: FAIL timeout"); $finish; end
endmodule
