// =============================================================================
// Testbench : tb_instruction_memory (Verilog-2001)
// Project   : RISC-V 32-bit CPU
// Desc      : Unit testbench for instruction_memory, split from tb_memory.v
//             (Phase 0, buoc 3). ROM doc to hop, nap tu file .mem.
// Run       : iverilog -g2001 -Wall -s tb_instruction_memory -o out/tb_instruction_memory.vvp \
//               src/instruction_memory.v tb/tb_instruction_memory.v
//             vvp out/tb_instruction_memory.vvp
//             (chay tu thu muc Code/, vi MEM_FILE la duong dan tuong doi)
// =============================================================================

`timescale 1ns/1ps

module tb_instruction_memory;
    reg [31:0] imem_addr;
    wire [31:0] instr;
    wire imem_misaligned, imem_out_of_range;
    integer errors, tests;

    instruction_memory #(.MEM_DEPTH(256), .MEM_FILE("src/program.mem")) imem (
        .addr(imem_addr), .instr(instr), .addr_misaligned(imem_misaligned),
        .addr_out_of_range(imem_out_of_range)
    );

    task check;
        input [31:0] test_addr;
        input [31:0] expected_instr;
        input expected_misaligned;
        input expected_out_of_range;
        begin
            imem_addr = test_addr; #1; tests = tests + 1;
            if (instr !== expected_instr || imem_misaligned !== expected_misaligned
                || imem_out_of_range !== expected_out_of_range) begin
                $display("FAIL IMEM addr=%08h got instr=%08h mis=%b oor=%b | expected instr=%08h mis=%b oor=%b",
                         test_addr, instr, imem_misaligned, imem_out_of_range,
                         expected_instr, expected_misaligned, expected_out_of_range);
                errors = errors + 1;
            end else $display("PASS IMEM addr=%08h instr=%08h mis=%b oor=%b",
                              test_addr, instr, imem_misaligned, imem_out_of_range);
        end
    endtask

    initial begin
        $dumpfile("out/waveform_instruction_memory.vcd");
        $dumpvars(0, tb_instruction_memory.imem_addr, tb_instruction_memory.instr,
                  tb_instruction_memory.imem_misaligned,
                  tb_instruction_memory.imem_out_of_range);
    end

    initial begin
        errors = 0; tests = 0; imem_addr = 0;
        #1;
        // File .mem da nap: src/program.mem [0]=00500093 (addi x1,x0,5),
        // [1]=00300113 (addi x2,x0,3), [2]=002081b3 (add x3,x1,x2).
        check(32'd0, 32'h00500093, 1'b0, 1'b0);
        check(32'd4, 32'h00300113, 1'b0, 1'b0);
        check(32'd8, 32'h002081b3, 1'b0, 1'b0);

        // Ghi truc tiep ROM de test word dau / word cuoi.
        imem.rom[0] = 32'h11223344;
        imem.rom[255] = 32'hAABBCCDD;
        check(32'd0, 32'h11223344, 1'b0, 1'b0);
        check(32'd1020, 32'hAABBCCDD, 1'b0, 1'b0);

        // Sai can chinh 1, 2, 3: bao misaligned, tra 0.
        check(32'd1, 32'd0, 1'b1, 1'b0);
        check(32'd2, 32'd0, 1'b1, 1'b0);
        check(32'd3, 32'd0, 1'b1, 1'b0);

        // Ngoai vung: 1024, 0x1000, 0xFFFFFFFC -- bao out_of_range, tra 0,
        // khong alias ve word 0 (neu alias thi instr se la 11223344).
        check(32'd1024, 32'd0, 1'b0, 1'b1);
        check(32'h00001000, 32'd0, 1'b0, 1'b1);
        check(32'hFFFFFFFC, 32'd0, 1'b0, 1'b1);

        // Doc lai word cuoi sau cac dia chi xau: ROM khong bi doi.
        check(32'd1020, 32'hAABBCCDD, 1'b0, 1'b0);

        if (errors == 0) $display("tb_instruction_memory: PASS (%0d checks)", tests);
        else $display("tb_instruction_memory: FAIL (%0d/%0d errors)", errors, tests);
        $finish;
    end
    initial begin #10000; $display("tb_instruction_memory: FAIL timeout"); $finish; end
endmodule
