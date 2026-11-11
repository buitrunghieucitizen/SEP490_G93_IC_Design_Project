`timescale 1ns/1ps

module tb_immediate_gen;
    reg [31:0] instr;
    wire [31:0] imm;
    integer errors, tests;
    integer seed;
    integer i;
    reg [11:0] rimm;
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
    // Quiet check for random round-trip vectors: only FAIL is printed.
    task check_quiet;
        input [31:0] test_instr;
        input [31:0] expected;
        begin
            instr=test_instr; #1; tests=tests+1;
            if (imm !== expected) begin
                $display("FAIL imm instr=%08h got=%08h expected=%08h",instr,imm,expected);
                errors=errors+1;
            end
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
        // Them 13 vector bien (Phase 0, buoc 6): tong 25 check directed.
        check(enc_i(12'h000,7'b0010011),32'h00000000); // I = 0
        check(enc_i(12'h001,7'b0010011),32'h00000001); // I = +1
        check(enc_s(12'h000),32'h00000000);           // S = 0
        check(enc_s(12'h800),32'hfffff800);           // S = -2048
        check(enc_b(13'd2),32'h00000002);             // B = +2
        check(enc_b(13'h1ffe),32'hfffffffe);          // B = -2
        check(enc_b(13'd4094),32'h00000ffe);          // B = +4094 (lon nhat, chan)
        check(enc_b(13'h1000),32'hfffff000);          // B = -4096
        check(enc_u(20'h80000,7'b0110111),32'h80000000); // U = 0x80000
        check(enc_u(20'hfffff,7'b0010111),32'hfffff000); // U = 0xfffff
        check(enc_j(21'd0),32'h00000000);             // J = 0
        check(enc_j(21'd4),32'h00000004);             // J = +4
        check(32'h00000033,32'h00000000);             // R-type: khong co immediate
        // Random round-trip: 100 I-type + 100 S-type, seed co dinh.
        seed = 32'h2468ace0;
        for (i = 0; i < 100; i = i + 1) begin
            rimm = $random(seed);
            check_quiet(enc_i(rimm,7'b0010011), {{20{rimm[11]}}, rimm});
        end
        for (i = 0; i < 100; i = i + 1) begin
            rimm = $random(seed);
            check_quiet(enc_s(rimm), {{20{rimm[11]}}, rimm});
        end
        $display("  Random done: 200 vectors, see FAIL lines above if any");
        if (errors==0) $display("tb_immediate_gen: PASS (%0d checks)",tests);
        else $display("tb_immediate_gen: FAIL (%0d/%0d errors)",errors,tests);
        $finish;
    end
    initial begin #10000; $display("tb_immediate_gen: FAIL timeout"); $finish; end
endmodule
