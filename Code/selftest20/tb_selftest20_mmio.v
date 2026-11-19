`timescale 1ns/1ps
// SELFTEST20 on EXACT CPU/MMIO integration used by uart_cpu_mmio_top.
// 1) Golden ROM must report 20, cover 20 distinct supported instruction encodings.
// 2) +INJECT_SLL mutates one program instruction and must report -6 (negative control).
module tb_selftest20_mmio;
    reg clk = 1'b0;
    always #10 clk = ~clk;   // 50 MHz
    reg rst = 1'b1;
    wire [31:0] result_data;
    wire result_strobe, illegal_instr, misaligned, access_fault, halted;
    wire [31:0] debug_pc, debug_instr;
    wire decode_illegal_debug;
    reg [19:0] coverage = 20'd0;
    integer i, slot_i;
    integer mutate_addr, mutated;
    reg injection_mode;

    cpu_mmio_top #(.MEM_FILE("selftest20/SELFTEST20.mem")) dut (
        .clk(clk), .rst(rst),
        .operand_a(32'd0),.operand_b(32'd0),.is_sub(1'b0),.command_ready(1'b0),
        .result_data(result_data),.result_strobe(result_strobe),
        .illegal_instr(illegal_instr),.misaligned(misaligned),.access_fault(access_fault),
        .halted(halted),.debug_pc(debug_pc),.debug_instr(debug_instr),
        .decode_illegal_debug(decode_illegal_debug)
    );

    // Instruction-kind scoreboard; 0..19 correspond to the twenty supported mnemonics.
    function integer instr_slot;
        input [31:0] inst;
        reg [6:0] op, f7;
        reg [2:0] f3;
        begin
            op=inst[6:0]; f3=inst[14:12]; f7=inst[31:25];
            instr_slot=-1;
            case(op)
                7'b0110011: case({f7,f3})
                    {7'b0000000,3'b000}: instr_slot=0;   // ADD
                    {7'b0100000,3'b000}: instr_slot=1;   // SUB
                    {7'b0000000,3'b111}: instr_slot=2;   // AND
                    {7'b0000000,3'b110}: instr_slot=3;   // OR
                    {7'b0000000,3'b100}: instr_slot=4;   // XOR
                    {7'b0000000,3'b001}: instr_slot=5;   // SLL
                    {7'b0000000,3'b101}: instr_slot=6;   // SRL
                    {7'b0100000,3'b101}: instr_slot=7;   // SRA
                endcase
                7'b0010011: case(f3)
                    3'b000: instr_slot=8;  // ADDI
                    3'b111: instr_slot=9;  // ANDI
                    3'b110: instr_slot=10; // ORI
                    3'b100: instr_slot=11; // XORI
                endcase
                7'b0100011: if(f3==3'b010) instr_slot=12;  // SW
                7'b0000011: if(f3==3'b010) instr_slot=13;  // LW
                7'b1100011: if(f3==3'b000) instr_slot=14;  // BEQ
                             else if(f3==3'b001) instr_slot=15; // BNE
                7'b1101111: instr_slot=16;                // JAL
                7'b1100111: if(f3==3'b000) instr_slot=17; // JALR
                7'b0110111: instr_slot=18;                // LUI
                7'b0010111: instr_slot=19;                // AUIPC
            endcase
        end
    endfunction

    always @(posedge clk) begin
        if (!rst && !halted) begin
            slot_i=instr_slot(debug_instr);
            if (slot_i >= 0 && slot_i < 20) coverage[slot_i] <= 1'b1;
        end
    end

    initial begin
        injection_mode=$test$plusargs("INJECT_SLL");
        if (injection_mode) $dumpfile("build/sim/waveform_selftest20_negative.vcd");
        else $dumpfile("build/sim/waveform_selftest20_pass.vcd");
        $dumpvars(0,tb_selftest20_mmio);
        if(injection_mode) begin
            // Wait for $readmemh initial block to complete before mutating the ROM.
            #1;
            mutated=0;
            for(mutate_addr=0;mutate_addr<256;mutate_addr=mutate_addr+1) begin
                if(dut.u_datapath.u_inst_mem.rom[mutate_addr][6:0]==7'h33 &&
                   dut.u_datapath.u_inst_mem.rom[mutate_addr][14:12]==3'b001 &&
                   dut.u_datapath.u_inst_mem.rom[mutate_addr][11:7]==5'd3 &&
                   dut.u_datapath.u_inst_mem.rom[mutate_addr][19:15]==5'd1 &&
                   dut.u_datapath.u_inst_mem.rom[mutate_addr][24:20]==5'd2) begin
                    dut.u_datapath.u_inst_mem.rom[mutate_addr][14:12]=3'b101; // SLL->SRL
                    mutated=mutated+1;
                end
            end
            if(mutated!=1) $fatal(1,"ERROR: could not locate exactly one SLL to mutate");
            $display("Negative control: modified SLL x3,x1,x2 to SRL, expect result -6");
        end
        repeat(6) @(posedge clk);
        #1; rst=1'b0;
        for(i=0;i<600;i=i+1) begin
            @(posedge clk);
            #1;
            if (halted || illegal_instr || misaligned || access_fault || decode_illegal_debug)
                $fatal(1,"CPU fault: PC=%h halted=%b ill=%b mis=%b acc=%b",debug_pc,halted,illegal_instr,misaligned,access_fault);
            if(result_strobe) begin
                if(injection_mode) begin
                    if(result_data !== 32'hFFFFFFFA)
                        $fatal(1,"Negative control FAIL: expected -6, got %h",result_data);
                    $display("tb_selftest20_mmio: PASS negative control (detected SLL fault as -6)");
                end else begin
                    if(result_data !== 32'd20)
                        $fatal(1,"SELFTEST20 reported failure code %0d",$signed(result_data));
                    if(coverage !== 20'hfffff)
                        $fatal(1,"Not all 20 instruction types were executed. coverage=%h",coverage);
                    if(dut.u_datapath.u_dmem.mem[0] !== 32'd8 ||
                       dut.u_datapath.u_dmem.mem[1] !== 32'd2)
                        $fatal(1,"RAM mismatch: [0]=%h [1]=%h",dut.u_datapath.u_dmem.mem[0],dut.u_datapath.u_dmem.mem[1]);
                    $display("tb_selftest20_mmio: PASS (20 instruction types, MMIO=20, RAM OK)");
                end
                $finish;
            end
        end
        $fatal(1,"TIMEOUT: selftest never wrote MMIO result; last PC=%h instr=%h",debug_pc,debug_instr);
    end
endmodule
