`timescale 1ns/1ps
module tb_mmio_v2_faults;
    reg clk=0; always #10 clk=~clk;
    reg rst=1;
    wire [31:0] pc,instr,result_data;
    wire strobe,ill,mis,acc,halt,decode;
    integer tests=0,i,j;
    cpu_mmio_v2_top dut(.clk(clk),.rst(rst),.operand_a(32'd0),.operand_b(32'd0),
        .command_id(3'd6),.command_ready(1'b1),.result_data(result_data),.result_strobe(strobe),
        .illegal_instr(ill),.misaligned(mis),.access_fault(acc),.halted(halt),
        .debug_pc(pc),.debug_instr(instr),.decode_illegal_debug(decode));
    task fault_case;
        input [31:0] word0,word1;
        input integer prefix;
        input [2:0] flags;
        reg [31:0] snapshot[0:31];
        begin
            @(negedge clk); rst=1;
            repeat(2) @(negedge clk);
            for(i=0;i<256;i=i+1) dut.u_datapath.u_inst_mem.rom[i]=32'h00000013;
            for(i=0;i<128;i=i+1) dut.u_datapath.u_dmem.mem[i]=32'hdeadbeef;
            dut.u_datapath.u_inst_mem.rom[0]=word0;
            dut.u_datapath.u_inst_mem.rom[1]=word1;
            rst=0;
            repeat(prefix) @(negedge clk);
            for(i=0;i<32;i=i+1) snapshot[i]=dut.u_datapath.u_reg_file.regfile[i];
            repeat(3) begin
                @(posedge clk); #1;
                if({ill,mis,acc,halt}!=={flags,1'b1} || pc!==prefix*4 || strobe!==0 || result_data!==0)
                    $fatal(1,"fault case %0d status=%b pc=%h expected flags=%b",tests,{ill,mis,acc,halt},pc,flags);
                for(j=0;j<32;j=j+1) if(dut.u_datapath.u_reg_file.regfile[j]!==snapshot[j]) $fatal(1,"fault modified register");
                for(j=0;j<128;j=j+1) if(dut.u_datapath.u_dmem.mem[j]!==32'hdeadbeef) $fatal(1,"fault modified RAM");
            end
            @(negedge clk); rst=1; @(posedge clk); #1;
            if({ill,mis,acc,halt}!==0 || pc!==0) $fatal(1,"reset did not clear fault");
            for(j=0;j<32;j=j+1) if(dut.u_datapath.u_reg_file.regfile[j]!==0) $fatal(1,"reset did not clear register");
            tests=tests+1;
            $display("PASS fault %0d flags=%b PC=%0d",tests,flags,prefix*4);
        end
    endtask
    initial begin
        $dumpfile("out/isa20/faults.vcd");$dumpvars(0,clk,rst,pc,instr,ill,mis,acc,halt,strobe);
        // unsupported instruction, unsupported MUL and illegal load funct3
        fault_case(32'hffffffff,0,0,3'b100);
        fault_case(32'h022081b3,0,0,3'b100);
        fault_case(32'h00000283,0,0,3'b100);
        // x1=1; LW/SW at unaligned address (no side effects)
        fault_case(32'h00100093,32'h0000a283,1,3'b010);
        fault_case(32'h00100093,32'h0000a023,1,3'b010);
        // x1=512; LW/SW outside RAM and MMIO
        fault_case(32'h20000093,32'h0000a283,1,3'b001);
        fault_case(32'h20000093,32'h0000a023,1,3'b001);
        // x1=0x1000; LW at unmapped 0x1014
        fault_case(32'h000010b7,32'h0140a283,1,3'b001);
        // misaligned branch/jump, out-of-range JAL, JALR target=6
        fault_case(32'h00000163,0,0,3'b010);
        fault_case(32'h002002ef,0,0,3'b010);
        fault_case(32'h400002ef,0,0,3'b001);
        fault_case(32'h00600093,32'h000082e7,1,3'b010);
        $display("PASS tb_mmio_v2_faults %0d cases",tests);$finish;
    end
    initial begin #100000; $fatal(1,"timeout");end
endmodule
