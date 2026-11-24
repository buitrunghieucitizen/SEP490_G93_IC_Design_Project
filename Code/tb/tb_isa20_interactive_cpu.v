`timescale 1ns/1ps
module tb_isa20_interactive_cpu;
 reg clk=0;always #10 clk=~clk;
 reg reset_n=0,request=0,parse_error=0;reg [4:0] id=0;reg [31:0] a=0,b=0;
 wire busy,done;wire [2:0] kind,flags;wire [31:0] word,pc_before,pc_after,wb,value;
 integer checks=0;reg [19:0] covered=0;reg [31:0] actual_word,actual_pc_after,actual_x3;reg observed;
 isa20_interactive_engine dut(.clk(clk),.reset_n(reset_n),.request(request),.parse_error(parse_error),.id(id),.a(a),.b(b),.busy(busy),.done(done),.kind(kind),.word(word),.pc_before(pc_before),.pc_after(pc_after),.wb(wb),.value(value),.flags(flags));
 // Observe the real fetch and register file/PC after the target edge,
 // independent of the response registers.
 always @(posedge clk) if(reset_n && dut.state==2 && dut.cpu_pc==12 && dut.commit)begin
  actual_word=dut.cpu_instr;
  #1;actual_pc_after=dut.cpu_pc;actual_x3=dut.u_cpu.u_datapath.u_reg_file.regfile[3];observed=1;
 end
 task send;
 input [4:0] op;input [31:0] va,vb;
 integer n;
 begin
  @(negedge clk);id=op;a=va;b=vb;observed=0;request=1;
  @(negedge clk);request=0;n=0;
  while(done!==1 && n<110000)begin @(negedge clk);n=n+1;end
  if(done!==1)$fatal(1,"TIMEOUT id=%d",op);
 end endtask
 task check_demo;
 input [8*24-1:0] name;input [4:0] op;input [31:0] va,vb,exp_word,exp_pc,exp_wb,exp_val;
 begin
  send(op,va,vb);
  if(kind!==0 || flags!==0 || word!==exp_word || pc_before!==12 || pc_after!==exp_pc || wb!==exp_wb || value!==exp_val)
   $fatal(1,"%0s: got kind=%d flags=%b word=%h PC=%h->%h WB=%h VALUE=%h expected word=%h next=%h WB=%h value=%h",name,kind,flags,word,pc_before,pc_after,wb,value,exp_word,exp_pc,exp_wb,exp_val);
  if(!observed || actual_word!==exp_word || actual_pc_after!==exp_pc || actual_x3!==exp_wb)
   $fatal(1,"%0s: actual committed state mismatch word=%h next=%h x3=%h",name,actual_word,actual_pc_after,actual_x3);
  if(op==13 && dut.u_cpu.u_datapath.u_dmem.mem[va>>2]!==vb)$fatal(1,"SW actual RAM mismatch");
  covered[op-1]=1;checks=checks+1;
  $display("PASS %0s word=%h PC=%h->%h WB=%h VALUE=%h",name,word,pc_before,pc_after,wb,value);
 end endtask
 task legacy;
 input [4:0] op;input [31:0] va,vb,expected;
 begin send(op,va,vb);if(kind!==1 || value!==expected)$fatal(1,"Legacy id=%d value=%h expected=%h",op,value,expected);checks=checks+1;end endtask
 task invalid;
 input [4:0] op;input [31:0] va,vb;
 begin send(op,va,vb);if(kind!==2 || observed)$fatal(1,"Invalid operand accepted id=%d",op);checks=checks+1;end endtask
 task fault;
 input [4:0] op;input [31:0] va,vb;input [2:0] exp_flags;
 begin send(op,va,vb);if(kind!==6 || flags!==exp_flags || observed)$fatal(1,"Fault expected id=%d got kind=%d flags=%b",op,kind,flags);checks=checks+1;end endtask
 initial begin
  $dumpfile("out/isa20_interactive/cpu.vcd");
  $dumpvars(0,clk,reset_n,request,id,a,b,word,pc_before,pc_after,wb,value,kind,flags,done);
  $dumpvars(0,dut.cpu_pc,dut.cpu_instr,dut.cpu_wb,dut.commit,dut.state,dut.u_cpu.u_datapath.rs1_data,dut.u_cpu.u_datapath.rs2_data,dut.u_cpu.u_datapath.alu_result);
  repeat(5)@(negedge clk);reset_n=1;repeat(3)@(negedge clk);
  `include "instruction_vectors.vh"
  invalid(9,0,2048);invalid(10,0,-2049);invalid(13,1,7);invalid(14,512,0);invalid(19,32'h100000,0);invalid(17,1,0);
  fault(17,2,0,3'b010);fault(17,1024,0,3'b001);fault(18,6,0,3'b010);
  check_demo("Recovery",1,2,3,32'h002081b3,16,5,5);
  legacy(21,15,7,22);legacy(22,7,15,-8);legacy(23,9999,9999,99980001);
  legacy(24,9999,0,49995000);legacy(25,39,0,63245986);legacy(26,0,0,20);
  check_demo("After TEST20",14,0,0,32'h0000a183,16,8,8);
  if(covered!==20'hfffff)$fatal(1,"Missing instruction coverage %h",covered);
  $display("PASS tb_isa20_interactive_cpu: %0d checks, coverage=%h",checks,covered);$finish;
 end
 initial begin #10000000;$fatal(1,"Global CPU timeout");end
endmodule
