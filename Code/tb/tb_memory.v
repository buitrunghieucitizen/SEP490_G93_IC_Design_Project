`timescale 1ns/1ps

module tb_memory;
    reg clk;
    reg [31:0] addr, wr_data;
    reg mem_write, mem_read;
    wire [31:0] rd_data;
    wire dmem_misaligned, dmem_out_of_range;
    wire [31:0] debug_dmem_word0, debug_dmem_word1;
    reg [31:0] imem_addr;
    wire [31:0] instr;
    wire imem_misaligned, imem_out_of_range;
    integer errors, tests;

    // Use the RTL default depth (128 words) and exercise its last valid address.
    data_memory dmem (
        .clk(clk), .addr(addr), .wr_data(wr_data), .mem_write(mem_write),
        .mem_read(mem_read), .rd_data(rd_data),
        .addr_misaligned(dmem_misaligned), .addr_out_of_range(dmem_out_of_range)
    );
    instruction_memory #(.MEM_DEPTH(256), .MEM_FILE("src/program.mem")) imem (
        .addr(imem_addr), .instr(instr), .addr_misaligned(imem_misaligned),
        .addr_out_of_range(imem_out_of_range)
    );

    assign debug_dmem_word0 = dmem.mem[0];
    assign debug_dmem_word1 = dmem.mem[1];

    initial clk=1'b0;
    always #5 clk=~clk;

    initial begin
        $dumpfile("out/waveform_memory.vcd");
        $dumpvars(0, tb_memory.clk, tb_memory.addr, tb_memory.wr_data,
                  tb_memory.mem_write, tb_memory.mem_read, tb_memory.rd_data,
                  tb_memory.dmem_misaligned, tb_memory.dmem_out_of_range,
                  tb_memory.imem_addr, tb_memory.instr,
                  tb_memory.imem_misaligned, tb_memory.imem_out_of_range,
                  tb_memory.debug_dmem_word0, tb_memory.debug_dmem_word1);
    end

    initial begin
        errors=0; tests=0; addr=0; wr_data=32'h12345678; mem_write=0; mem_read=0; imem_addr=0;
        #1;
        imem.rom[0]=32'h11223344;
        imem.rom[255]=32'hAABBCCDD;

        // Asynchronous instruction fetch and full byte-address checks.
        #1;
        tests=tests+1;
        if (instr !== 32'h11223344 || imem_misaligned || imem_out_of_range) begin
            $display("FAIL IMEM base read"); errors=errors+1;
        end else $display("PASS IMEM[0] actual=%08h expected=11223344",instr);
        imem_addr=32'd1020; #1;
        tests=tests+1;
        if (instr !== 32'hAABBCCDD || imem_misaligned || imem_out_of_range) begin
            $display("FAIL IMEM final word read"); errors=errors+1;
        end else $display("PASS IMEM[255] actual=%08h expected=AABBCCDD",instr);
        imem_addr=32'd2; #1;
        tests=tests+1;
        if (!imem_misaligned || instr !== 32'd0) begin $display("FAIL IMEM alignment protection"); errors=errors+1; end
        else $display("PASS IMEM address 2: misaligned=%b instr=%08h expected=1/00000000",imem_misaligned,instr);
        imem_addr=32'd1024; #1;
        tests=tests+1;
        if (!imem_out_of_range || instr !== 32'd0) begin $display("FAIL IMEM range protection"); errors=errors+1; end
        else $display("PASS IMEM address 1024: out_of_range=%b instr=%08h expected=1/00000000",imem_out_of_range,instr);

        // Synchronous word write and asynchronous readback.
        addr=32'd0; wr_data=32'h12345678; mem_write=1; mem_read=0;
        @(posedge clk); #1; mem_write=0; mem_read=1; #1;
        tests=tests+1;
        if (rd_data !== 32'h12345678) begin $display("FAIL DMEM write/read word0"); errors=errors+1; end
        else $display("PASS DMEM[0] actual=%08h expected=12345678",rd_data);
        addr=32'd4; wr_data=32'h89ABCDEF; mem_write=1; mem_read=0;
        @(posedge clk); #1; mem_write=0; mem_read=1; #1;
        tests=tests+1;
        if (rd_data !== 32'h89ABCDEF) begin $display("FAIL DMEM write/read word1"); errors=errors+1; end
        else $display("PASS DMEM[1] actual=%08h expected=89abcdef",rd_data);

        // Invalid byte alignment and address range must never alias/write.
        addr=32'd1; wr_data=32'hFFFFFFFF; mem_write=1; mem_read=0; #1;
        tests=tests+1;
        if (!dmem_misaligned || dmem_out_of_range) begin $display("FAIL DMEM alignment flags"); errors=errors+1; end
        else $display("PASS DMEM address 1 alignment flags: misaligned=1 out_of_range=0");
        @(posedge clk); #1; mem_write=0;
        tests=tests+1;
        if (dmem.mem[0] !== 32'h12345678) begin $display("FAIL misaligned store changed word0"); errors=errors+1; end
        else $display("PASS misaligned SW preserved DMEM[0]=%08h",dmem.mem[0]);
        addr=32'd508; wr_data=32'h55AA55AA; mem_write=1; mem_read=0;
        #1;
        tests=tests+1;
        if (dmem_misaligned || dmem_out_of_range) begin
            $display("FAIL DMEM last word address 508 rejected"); errors=errors+1;
        end else $display("PASS DMEM last word address 508 accepted");
        @(posedge clk); #1; mem_write=0; mem_read=1; #1;
        tests=tests+1;
        if (rd_data !== 32'h55AA55AA) begin
            $display("FAIL DMEM[127] actual=%08h expected=55AA55AA",rd_data); errors=errors+1;
        end else $display("PASS DMEM[127] actual=%08h expected=55AA55AA",rd_data);

        addr=32'd512; mem_write=1; mem_read=0; #1;
        tests=tests+1;
        if (!dmem_out_of_range || dmem_misaligned) begin $display("FAIL DMEM range flags"); errors=errors+1; end
        else $display("PASS DMEM address 512 alignment/range flags: 0/1");
        @(posedge clk); #1; mem_write=0;
        tests=tests+1;
        if (dmem.mem[0] !== 32'h12345678) begin $display("FAIL out-of-range store aliased word0"); errors=errors+1; end
        else $display("PASS out-of-range SW preserved DMEM[0]=%08h",dmem.mem[0]);

        if (errors==0) $display("tb_memory: PASS (%0d checks, IMEM and DMEM)",tests);
        else $display("tb_memory: FAIL (%0d/%0d errors)",errors,tests);
        $finish;
    end
    initial begin #10000; $display("tb_memory: FAIL timeout"); $finish; end
endmodule
