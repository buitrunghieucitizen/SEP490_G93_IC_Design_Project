`timescale 1ns/1ps

module tb_immediate_gen;
    reg [31:0] instr;
    wire [31:0] imm;
    integer errors, tests;
    immediate_gen dut (.instr(instr), .imm(imm));

    initial begin
        $dumpfile("out/waveform_immediate_gen.vcd");
        $dumpvars(0, tb_immediate_gen.instr, tb_immediate_gen.imm);
    end

    function [31:0] enc_i;
        input [11:0] x; input [6:0] op;
        begin enc_i={x,5'd0,3'b000,5'd1,op}; end
    endfunction
    function [31:0] enc_s;
        input [11:0] x;
        begin enc_s={x[11:5],5'd1,5'd2,3'b010,x[4:0],7'b0100011}; end
    endfunction
    function [31:0] enc_b;
        input [12:0] x;
        begin enc_b={x[12],x[10:5],5'd2,5'd1,3'b001,x[4:1],x[11],7'b1100011}; end
    endfunction
    function [31:0] enc_u;
        input [19:0] x; input [6:0] op;
        begin enc_u={x,5'd1,op}; end
    endfunction
    function [31:0] enc_j;
        input [20:0] x;
        begin enc_j={x[20],x[10:1],x[11],x[19:12],5'd1,7'b1101111}; end
    endfunction
    task check;
        input [31:0] test_instr;
        input [31:0] expected;
        begin
            instr=test_instr; #1; tests=tests+1;
            if (imm !== expected) begin
                $display("FAIL imm instr=%08h got=%08h expected=%08h",instr,imm,expected);
                errors=errors+1;
            end else $display("PASS imm instr=%08h actual=%08h expected=%08h",instr,imm,expected);
        end
    endtask
    initial begin
        errors=0; tests=0;
        check(enc_i(12'h7ff,7'b0010011),32'h000007ff);
        check(enc_i(12'h800,7'b0010011),32'hfffff800);
        check(enc_i(12'hfff,7'b0000011),32'hffffffff);
        check(enc_i(12'h800,7'b1100111),32'hfffff800);
        check(enc_s(12'h123),32'h00000123);
        check(enc_s(12'hffc),32'hfffffffc);
        check(enc_b(13'd10),32'h0000000a);
        check(enc_b(13'h1ffc),32'hfffffffc);
        check(enc_u(20'habcde,7'b0110111),32'habcde000);
        check(enc_u(20'h12345,7'b0010111),32'h12345000);
        check(enc_j(21'd2048),32'h00000800);
        check(enc_j(21'h1ffffc),32'hfffffffc);
        if (errors==0) $display("tb_immediate_gen: PASS (%0d checks)",tests);
        else $display("tb_immediate_gen: FAIL (%0d/%0d errors)",errors,tests);
        $finish;
    end
    initial begin #10000; $display("tb_immediate_gen: FAIL timeout"); $finish; end
endmodule
