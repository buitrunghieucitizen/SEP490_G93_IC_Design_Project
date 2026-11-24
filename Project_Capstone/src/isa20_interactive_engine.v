// Runs a bounded instruction demo on the SAME datapath as the v2 program.
// Captures the committed writeback and actual PC after the instruction edge.
module isa20_interactive_engine #(parameter MEM_FILE="src/program_multi_mmio.mem") (
 input wire clk,reset_n, input wire request,parse_error,
 input wire [4:0] id, input wire [31:0] a,b,
 output wire busy,output reg done,output reg [2:0] kind,
 output reg [31:0] word,pc_before,pc_after,wb,value,
 output reg [2:0] flags
);
 localparam IDLE=0,RESET_DEMO=1,DEMO_RUN=2,CHECK_NEXT=3,READBACK=4,
 RESET_RETURN=5,LEGACY=6,RESET_FAULT=7;
 localparam K_DEMO=0,K_LEGACY=1,K_ERROR=2,K_HELP=3,K_STATUS=4,K_CLEAR=5,K_FAULT=6;
 reg [2:0] state;
 reg [4:0] op;reg [31:0] lat_a,lat_b;
 reg [2:0] legacy_id;reg [16:0] cycles;
 wire [31:0] encoded;wire enc_valid;
 isa20_encoder enc(.id(id),.a(a),.b(b),.word(encoded),.valid(enc_valid));
 wire demo_mode=(state==RESET_DEMO||state==DEMO_RUN||state==CHECK_NEXT||state==READBACK);
 wire demo_hold=(state==CHECK_NEXT);
 wire cpu_rst=!reset_n||state==RESET_DEMO||state==RESET_RETURN||state==RESET_FAULT;
 wire [31:0] cpu_pc,cpu_instr,cpu_wb,cpu_result;
 wire commit,result_strobe,ill,mis,acc,halted;
 assign busy=(state!=IDLE);
 cpu_isa20_interactive #(.MEM_FILE(MEM_FILE)) u_cpu(
  .clk(clk),.rst(cpu_rst),.demo_mode(demo_mode),.demo_hold(demo_hold),.demo_word(word),
  .demo_wb(cpu_wb),.demo_commit(commit),.operand_a(lat_a),.operand_b(lat_b),
  .command_id(legacy_id),.command_ready(state==LEGACY),.result_data(cpu_result),.result_strobe(result_strobe),
  .illegal_instr(ill),.misaligned(mis),.access_fault(acc),.halted(halted),
  .debug_pc(cpu_pc),.debug_instr(cpu_instr),.decode_illegal_debug());
 always @(posedge clk or negedge reset_n)begin
  if(!reset_n)begin state<=IDLE;done<=0;kind<=K_STATUS;word<=0;pc_before<=0;pc_after<=0;wb<=0;value<=0;flags<=0;op<=0;lat_a<=0;lat_b<=0;legacy_id<=0;cycles<=0;end
  else begin
   done<=0;
   case(state)
    IDLE:begin
     if(parse_error)begin kind<=K_ERROR;done<=1;end
     else if(request)begin
      if(id>=1 && id<=20 && enc_valid)begin
       op<=id;lat_a<=a;lat_b<=b;word<=encoded;pc_before<=12;pc_after<=0;wb<=0;value<=0;flags<=0;cycles<=0;state<=RESET_DEMO;
      end else if(id>=21 && id<=26)begin
       legacy_id<=id-5'd20;lat_a<=a;lat_b<=b;cycles<=0;state<=LEGACY;
      end else if(id==28)begin kind<=K_HELP;done<=1;end
      else if(id==29)begin kind<=K_STATUS;done<=1;end
      else if(id==30)begin value<=0;kind<=K_CLEAR;done<=1;end
      else begin kind<=K_ERROR;done<=1;end
     end
    end
    RESET_DEMO:state<=DEMO_RUN;
    DEMO_RUN:begin
     cycles<=cycles+1'b1;
     if(halted || cycles==17'd100000)begin flags<={ill,mis,acc};pc_after<=cpu_pc;kind<=K_FAULT;state<=RESET_FAULT;end
     else if(cpu_pc==12)begin
      // At this rising edge, the actual instruction commits or faults.
      pc_before<=cpu_pc;wb<=cpu_wb;
      if(op==13 && commit)state<=READBACK;else state<=CHECK_NEXT;
     end
    end
    CHECK_NEXT:begin
     pc_after<=cpu_pc;flags<={ill,mis,acc};
     if(halted)begin kind<=K_FAULT;state<=RESET_FAULT;end
     else begin
      value<=(op==15||op==16)?((cpu_pc!=16)?32'd1:32'd0):wb;
      kind<=K_DEMO;state<=RESET_RETURN;
     end
    end
    READBACK:begin
     pc_after<=cpu_pc; // actual PC after SW, before readback LW
     if(cpu_pc==16 && commit)begin value<=cpu_wb;kind<=K_DEMO;state<=RESET_RETURN;end
     else begin flags<={ill,mis,acc};kind<=K_FAULT;state<=RESET_FAULT;end
    end
    RESET_RETURN:begin done<=1;state<=IDLE;end
    RESET_FAULT:begin done<=1;state<=IDLE;end
    LEGACY:begin
     cycles<=cycles+1'b1;
     if(result_strobe)begin value<=cpu_result;kind<=K_LEGACY;done<=1;state<=IDLE;end
     else if(halted || cycles==17'd100000)begin word<=cpu_instr;pc_before<=cpu_pc;pc_after<=cpu_pc;wb<=0;value<=0;flags<={ill,mis,acc};kind<=K_FAULT;state<=RESET_FAULT;end
    end
    default:state<=IDLE;
   endcase
  end
 end
endmodule
