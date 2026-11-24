`timescale 1ns/1ps
module tb_isa20_interactive_parser;
 reg clk=0;always #10 clk=~clk;reg reset_n=0,busy=0,rx_valid=0;reg [7:0] rx_data=0;
 wire [4:0] id;wire [31:0] a,b;wire valid,error,parsing;
 integer checks=0,accepted=0,rejected=0;
 reg [4:0] last_id;reg [31:0] last_a,last_b;
 isa20_interactive_parser dut(.clk(clk),.reset_n(reset_n),.busy(busy),.rx_data(rx_data),.rx_valid(rx_valid),.id(id),.a(a),.b(b),.valid(valid),.error(error),.parsing(parsing));
 always @(negedge clk)begin if(valid)begin accepted=accepted+1;last_id=id;last_a=a;last_b=b;end if(error)rejected=rejected+1;end
 task chr;input [7:0] c;begin @(negedge clk);#1;rx_data=c;rx_valid=1;@(negedge clk);#1;rx_valid=0;end endtask
 task text;input [8*64-1:0] s;integer j;begin for(j=63;j>=0;j=j-1)if(s[j*8+:8]!=0)chr(s[j*8+:8]);end endtask
 task good;input [8*64-1:0] s;input [4:0] op;input [31:0] va,vb;integer ac,er;
 begin ac=accepted;er=rejected;text(s);chr(13);repeat(150)@(posedge clk);#1;
 if(accepted!=ac+1||rejected!=er||last_id!==op||last_a!==va||last_b!==vb)$fatal(1,"Parser %0s: id=%d a=%h b=%h valid=%d error=%d",s,last_id,last_a,last_b,accepted-ac,rejected-er);checks=checks+1;end endtask
 task bad;input [8*64-1:0] s;integer ac,er;
 begin ac=accepted;er=rejected;text(s);chr(13);repeat(150)@(posedge clk);#1;if(accepted!=ac||rejected!=er+1)$fatal(1,"Bad line %0s accepted or no error",s);checks=checks+1;end endtask
 initial begin
 repeat(4)@(negedge clk);reset_n=1;
 good("ADD 15 3",1,15,3);good("SUB 3 15",2,3,15);good("AND 0xFFFFFFFF 15",3,32'hffffffff,15);
 good("OR 8 3",4,8,3);good("XOR 15 3",5,15,3);good("SLL 1 63",6,1,63);good("SRL 0x80000000 2",7,32'h80000000,2);good("sra -16 2",8,-16,2);
 good("ADDI 15 -3",9,15,-3);good("ANDI 15 7",10,15,7);good("ORI 8 3",11,8,3);good("XORI 15 3",12,15,3);
 good("SW 508 4294967295",13,508,32'hffffffff);good("LW 508",14,508,0);good("BEQ 5 5",15,5,5);good("BNE 5 3",16,5,3);
 good("JAL -8",17,-8,0);good("JALR 25 -4",18,25,-4);good("LUI 0xfffff",19,32'hfffff,0);good("AUIPC 1",20,1,0);
 good("  ADD  -2147483648   2147483647  ",1,32'h80000000,32'h7fffffff);
 good("15+7",21,15,7);good("7-15",22,7,15);good("15*7",23,15,7);good("SUM 9999",24,9999,0);good("FIB 39",25,39,0);
 good("TEST20",26,0,0);good("T",26,0,0);good("TEST 20",26,20,0);good("HELP",28,0,0);good("STATUS",29,0,0);good("CLEAR",30,0,0);
 bad("ABC");bad("ADD 1");bad("ADD 1 2 3");bad("ADD - 2");bad("ADD 4294967296 1");bad("ADD -2147483649 1");bad("ADD 0x100000000 0");bad("ADD 0x 1");bad("15+3+8");bad("FIB 40");bad("SUM 10000");bad("TEST 21");bad("HELP 1");bad("ADD 0000000000000000000000000000000000000000000000000 1");
 text("ADD 2 8");chr(8);chr("3");chr(10);repeat(150)@(posedge clk);#1;if(last_id!==1||last_a!==2||last_b!==3)$fatal(1,"Backspace/LF");
 chr(13);repeat(10)@(posedge clk);busy=1;text("ADD 2 3");chr(13);busy=0;good("ADD 4 5",1,4,5);
 $display("PASS tb_isa20_interactive_parser: %0d directed cases",checks);$finish;
 end
 initial begin #2000000;$fatal(1,"Parser timeout");end
endmodule
