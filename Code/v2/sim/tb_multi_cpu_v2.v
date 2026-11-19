`timescale 1ns/1ps
module tb_multi_cpu_v2;
    reg clk=0; always #5 clk=~clk;
    reg rst=1;
    reg [31:0] a=0,b=0;
    reg [2:0] cmd=0;
    reg ready=0;
    wire [31:0] result_data,pc,instr;
    wire result_strobe,illegal_instr,misaligned,access_fault,halted,decode_illegal_debug;
    integer checks=0;
    cpu_mmio_v2_top #(.MEM_FILE("src/program_multi_mmio.mem")) dut (
        .clk(clk),.rst(rst),.operand_a(a),.operand_b(b),.command_id(cmd),
        .command_ready(ready),.result_data(result_data),.result_strobe(result_strobe),
        .illegal_instr(illegal_instr),.misaligned(misaligned),
        .access_fault(access_fault),.halted(halted),
        .debug_pc(pc),.debug_instr(instr),.decode_illegal_debug(decode_illegal_debug));
    task command;
        input [2:0] cid; input [31:0] val_a, val_b, expected;
        integer cycles;
        begin
            @(negedge clk);
            a=val_a;b=val_b;cmd=cid;ready=1;
            cycles=0;
            while (result_strobe!==1'b1 && cycles<100000) begin
                @(negedge clk);
                cycles=cycles+1;
                if (halted) $fatal(1,"CPU fault cmd=%0d PC=%h instruction=%h flags=%b%b%b",cid,pc,instr,illegal_instr,misaligned,access_fault);
            end
            if (result_strobe!==1'b1)
                $fatal(1,"CPU TIMEOUT command %0d A=%0d B=%0d PC=%h",cid,val_a,val_b,pc);
            if (result_data!==expected)
                $fatal(1,"CPU wrong cmd=%0d A=%0d B=%0d got=%h expected=%h",cid,val_a,val_b,result_data,expected);
            $display("PASS cmd=%0d A=%0d B=%0d result=%0d cycles=%0d",cid,val_a,val_b,$signed(result_data),cycles);
            checks=checks+1;
            ready=0;
            repeat (8) @(negedge clk);
        end
    endtask
    initial begin
        repeat (5) @(negedge clk);rst=0;
        repeat (5) @(negedge clk);
        command(1,15,7,22);
        command(2,7,15,32'hfffffff8);
        command(3,15,7,105);
        command(3,9999,9999,99980001);
        command(4,10,0,55);
        command(4,0,0,0);
        command(4,9999,0,49995000);
        command(5,0,0,0);
        command(5,1,0,1);
        command(5,10,0,55);
        command(5,39,0,63245986);
        command(6,0,0,20);
        $display("PASS tb_multi_cpu_v2: %0d command results + TEST20 on MMIO datapath",checks);
        $finish;
    end
    initial begin
        repeat(150000) @(negedge clk);
        $fatal(1,"Global timeout");
    end
endmodule
