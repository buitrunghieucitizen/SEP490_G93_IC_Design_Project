`timescale 1ns/1ps
module tb_isa20_trace;
    reg clk=0; always #10 clk=~clk;
    reg rst=1;
    wire [31:0] pc, instr, result_data;
    wire strobe,ill,mis,acc,halt,decode;
    cpu_mmio_v2_top dut(.clk(clk),.rst(rst),.operand_a(32'd0),.operand_b(32'd0),
        .command_id(3'd6),.command_ready(1'b1),.result_data(result_data),.result_strobe(strobe),
        .illegal_instr(ill),.misaligned(mis),.access_fault(acc),.halted(halt),
        .debug_pc(pc),.debug_instr(instr),.decode_illegal_debug(decode));
    reg [1023:0] rompath,tracepath,vcdpath;
    integer fd,n,i,k,steps,seen_result;
    reg [31:0] epc,einst,enext,erd,ewb,esw,eaddr,edata,eres,slot;
    reg [31:0] expected_regs[0:31];
    reg [19:0] coverage=0;
    function [8*5-1:0] mnemonic;
        input integer k;
        begin
            case(k)
                0:mnemonic="ADD";1:mnemonic="SUB";2:mnemonic="AND";3:mnemonic="OR";
                4:mnemonic="XOR";5:mnemonic="SLL";6:mnemonic="SRL";7:mnemonic="SRA";
                8:mnemonic="ADDI";9:mnemonic="ANDI";10:mnemonic="ORI";11:mnemonic="XORI";
                12:mnemonic="SW";13:mnemonic="LW";14:mnemonic="BEQ";15:mnemonic="BNE";
                16:mnemonic="JAL";17:mnemonic="JALR";18:mnemonic="LUI";19:mnemonic="AUIPC";
                default:mnemonic="BAD";
            endcase
        end
    endfunction
    initial begin
        if (!$value$plusargs("ROM=%s",rompath) || !$value$plusargs("TRACE=%s",tracepath) || !$value$plusargs("VCD=%s",vcdpath)) $fatal(1,"missing arguments");
        $dumpfile(vcdpath);
        $dumpvars(0,clk,rst,pc,instr,result_data,strobe,ill,mis,acc,halt,coverage);
        $dumpvars(0,dut.u_datapath.rd_addr,dut.u_datapath.rd_data,dut.u_datapath.rs1_data,dut.u_datapath.rs2_data,dut.u_datapath.pc_next,dut.u_datapath.alu_result,dut.u_datapath.commit_enable);
        #1; $readmemh(rompath,dut.u_datapath.u_inst_mem.rom);
        fd=$fopen(tracepath,"r"); if(!fd) $fatal(1,"cannot open trace");
        repeat(3) @(negedge clk);
        for(i=0;i<32;i=i+1) expected_regs[i]=0;
        rst=0; steps=0; seen_result=0;
        n=$fscanf(fd,"%h %h %h %h %h %h %h %h %h %h\n",epc,einst,enext,erd,ewb,esw,eaddr,edata,eres,slot);
        while(n==10) begin
            #1;
            if(pc!==epc || instr!==einst || {ill,mis,acc,halt,decode}!==5'b0 || dut.u_datapath.commit_enable!==1'b1)
                $fatal(1,"fetch/commit step %0d PC=%h expected=%h instr=%h expected=%h",steps,pc,epc,instr,einst);
            if ((dut.reg_write && dut.u_datapath.commit_enable && dut.u_datapath.rd_addr!=0) !== (erd!=0)) $fatal(1,"write enable step %0d",steps);
            if(erd!=0 && (dut.u_datapath.rd_addr!==erd[4:0] || dut.u_datapath.rd_data!==ewb)) $fatal(1,"writeback step %0d PC=%h rd=%d expected=%d data=%h expected=%h",steps,pc,dut.u_datapath.rd_addr,erd,dut.u_datapath.rd_data,ewb);
            if((dut.mem_write && dut.u_datapath.commit_enable)!==esw[0]) $fatal(1,"store enable step %0d",steps);
            if(esw!=0 && (dut.u_datapath.alu_result!==eaddr || dut.u_datapath.rs2_data!==edata)) $fatal(1,"store address/data step %0d",steps);
            if(erd!=0) expected_regs[erd]=ewb;
            @(posedge clk); #1;
            if(pc!==enext) $fatal(1,"next PC step %0d actual=%h expected=%h",steps,pc,enext);
            for(k=0;k<32;k=k+1) if(dut.u_datapath.u_reg_file.regfile[k]!==expected_regs[k]) $fatal(1,"register x%0d mismatch step %0d",k,steps);
            if(esw!=0 && eaddr<512 && dut.u_datapath.u_dmem.mem[eaddr>>2]!==edata) $fatal(1,"RAM write step %0d",steps);
            if(strobe!==eres[0] || (eres!=0 && result_data!==edata)) $fatal(1,"MMIO result step %0d",steps);
            coverage[slot]=1; steps=steps+1; if(eres!=0) seen_result=seen_result+1;
            $display("STEP %0d %s PC=%08h instr=%08h next_actual=%08h next_expected=%08h rd=%0d wb_actual=%08h wb_expected=%08h PASS",steps,mnemonic(slot),epc,einst,pc,enext,erd,dut.u_datapath.u_reg_file.regfile[erd],ewb);
            @(negedge clk);
            n=$fscanf(fd,"%h %h %h %h %h %h %h %h %h %h\n",epc,einst,enext,erd,ewb,esw,eaddr,edata,eres,slot);
        end
        if(!$feof(fd) || seen_result!=1 || steps==0) $fatal(1,"invalid/incomplete trace");
        $fclose(fd);
        $display("PASS tb_isa20_trace steps=%0d mask=%05h result=%0d",steps,coverage,$signed(result_data)); $finish;
    end
    initial begin #100000; $fatal(1,"timeout"); end
endmodule
