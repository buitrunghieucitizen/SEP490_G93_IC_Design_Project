// =============================================================================
// Testbench : tb_data_memory (Verilog-2001)
// Project   : RISC-V 32-bit CPU
// Desc      : Unit testbench for data_memory, split from tb_memory.v
//             (Phase 0, buoc 3). RAM ghi dong bo, doc to hop, khong reset.
// Run       : iverilog -g2001 -Wall -s tb_data_memory -o out/tb_data_memory.vvp \
//               src/data_memory.v tb/tb_data_memory.v
//             vvp out/tb_data_memory.vvp
// =============================================================================

`timescale 1ns/1ps

module tb_data_memory;
    reg clk;
    reg [31:0] addr, wr_data;
    reg mem_write, mem_read;
    wire [31:0] rd_data;
    wire dmem_misaligned, dmem_out_of_range;
    integer errors, tests;

    data_memory dmem (
        .clk(clk), .addr(addr), .wr_data(wr_data), .mem_write(mem_write),
        .mem_read(mem_read), .rd_data(rd_data),
        .addr_misaligned(dmem_misaligned), .addr_out_of_range(dmem_out_of_range)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    initial begin
        $dumpfile("out/waveform_data_memory.vcd");
        $dumpvars(0, tb_data_memory.clk, tb_data_memory.addr, tb_data_memory.wr_data,
                  tb_data_memory.mem_write, tb_data_memory.mem_read, tb_data_memory.rd_data,
                  tb_data_memory.dmem_misaligned, tb_data_memory.dmem_out_of_range);
    end

    // Ghi 1 word roi doc lai (mem_read=1).
    task write_read;
        input [31:0] test_addr;
        input [31:0] test_data;
        begin
            addr = test_addr; wr_data = test_data; mem_write = 1; mem_read = 0;
            @(posedge clk); #1; mem_write = 0; mem_read = 1; #1;
            tests = tests + 1;
            if (rd_data !== test_data) begin
                $display("FAIL DMEM write/read addr=%0d got=%08h expected=%08h",
                         test_addr, rd_data, test_data);
                errors = errors + 1;
            end else $display("PASS DMEM[%0d] actual=%08h expected=%08h",
                              test_addr / 4, rd_data, test_data);
        end
    endtask

    // Ghi xau khong duoc lam doi DMEM[0].
    task bad_write_preserves_word0;
        input [31:0] test_addr;
        begin
            addr = test_addr; wr_data = 32'hFFFFFFFF; mem_write = 1; mem_read = 0; #1;
            tests = tests + 1;
            if (!dmem_misaligned && !dmem_out_of_range) begin
                $display("FAIL DMEM addr=%08h: khong bao loi", test_addr);
                errors = errors + 1;
            end else $display("PASS DMEM addr=%08h bao loi: mis=%b oor=%b",
                              test_addr, dmem_misaligned, dmem_out_of_range);
            @(posedge clk); #1; mem_write = 0;
            tests = tests + 1;
            if (dmem.mem[0] !== 32'h12345678) begin
                $display("FAIL DMEM addr=%08h lam doi word0: got=%08h", test_addr, dmem.mem[0]);
                errors = errors + 1;
            end else $display("PASS DMEM addr=%08h khong doi word0=%08h", test_addr, dmem.mem[0]);
        end
    endtask

    // Doc o dia chi xau hoac mem_read=0 phai tra 0.
    task check_read_zero;
        input [31:0] test_addr;
        input test_read;
        begin
            addr = test_addr; mem_write = 0; mem_read = test_read; #1;
            tests = tests + 1;
            if (rd_data !== 32'd0) begin
                $display("FAIL DMEM read addr=%08h mem_read=%b got=%08h expected=0",
                         test_addr, test_read, rd_data);
                errors = errors + 1;
            end else $display("PASS DMEM read addr=%08h mem_read=%b tra 0", test_addr, test_read);
        end
    endtask

    initial begin
        errors = 0; tests = 0; addr = 0; wr_data = 0; mem_write = 0; mem_read = 0;
        #1;
        write_read(32'd0, 32'h12345678);   // word 0
        write_read(32'd4, 32'h89ABCDEF);   // word 1
        write_read(32'd508, 32'h55AA55AA); // word cuoi (127)

        // Doc khi mem_read=0: tra 0 du dia chi hop le va da co du lieu.
        check_read_zero(32'd0, 1'b0);

        // Ghi sai can chinh 1, 2, 3: DMEM[0] khong doi.
        bad_write_preserves_word0(32'd1);
        bad_write_preserves_word0(32'd2);
        bad_write_preserves_word0(32'd3);

        // Doc sai can chinh: tra 0.
        check_read_zero(32'd1, 1'b1);
        check_read_zero(32'd2, 1'b1);

        // Ghi ngoai vung 512 va 0xFFFFFFFC: DMEM[0] khong doi.
        bad_write_preserves_word0(32'd512);
        bad_write_preserves_word0(32'hFFFFFFFC);

        // Doc ngoai vung: tra 0.
        check_read_zero(32'd512, 1'b1);
        check_read_zero(32'h00001000, 1'b1);

        // Sau cac loi, ghi/doc binh thuong van chay.
        write_read(32'd4, 32'h0BADF00D);

        if (errors == 0) $display("tb_data_memory: PASS (%0d checks)", tests);
        else $display("tb_data_memory: FAIL (%0d/%0d errors)", errors, tests);
        $finish;
    end
    initial begin #10000; $display("tb_data_memory: FAIL timeout"); $finish; end
endmodule
