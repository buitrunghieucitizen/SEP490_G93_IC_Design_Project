// ASCII line parser. Decimal signed/unsigned 32-bit or 0x hexadecimal.
// No arithmetic execution here; multiply-by-ten only converts ASCII to numbers.
// While busy, input is ignored; host must wait for each response.
module isa20_interactive_parser(input wire clk,reset_n,busy,
 input wire [7:0] rx_data,input wire rx_valid,
 output reg [4:0] id,output reg [31:0] a,b,output reg valid,error,output wire parsing);
 localparam COLLECT=0, KEY=1, GAP=2, NUM=3, DONE=4, FAIL=5;
 reg [2:0] state;
 reg [7:0] bufmem[0:47]; reg [5:0] len,pos;
 reg overflow,legacy,second,neg,hexmode,drop_line;
 reg [3:0] digits; reg [31:0] number;
 reg [47:0] key; reg [2:0] keylen;
 reg [4:0] command;
 wire [7:0] raw=(pos<len)?bufmem[pos]:8'h0d;
 wire [7:0] c=(raw>="a" && raw<="z")?raw-8'd32:raw;
 wire eol=(pos==len), space=(c==32 || c==9);
 wire digit=(c>="0" && c<="9");
 wire hexdigit=digit||(c>="A" && c<="F");
 wire [3:0] nibble=digit?c[3:0]:(c[3:0]+4'd9);
 wire [31:0] signed_number=neg?(~number+32'd1):number;
 wire numeric_ok=(digits!=0 && (!neg || number<=32'h80000000));
 wire [4:0] decoded;
 function [4:0] decode; input [47:0] k;begin case(k)
  "ADD":decode=1;"SUB":decode=2;"AND":decode=3;"OR":decode=4;"XOR":decode=5;
  "SLL":decode=6;"SRL":decode=7;"SRA":decode=8;"ADDI":decode=9;"ANDI":decode=10;
  "ORI":decode=11;"XORI":decode=12;"SW":decode=13;"LW":decode=14;"BEQ":decode=15;
  "BNE":decode=16;"JAL":decode=17;"JALR":decode=18;"LUI":decode=19;"AUIPC":decode=20;
  "SUM":decode=24;"FIB":decode=25;"TEST20":decode=26;"T":decode=26;"TEST":decode=27;
  "HELP":decode=28;"STATUS":decode=29;"CLEAR":decode=30;default:decode=0;
 endcase end endfunction
 assign decoded=decode(key);
 function [1:0] nargs; input [4:0] op;begin case(op)
  14,17,19,20,24,25,27:nargs=1;
  26,28,29,30:nargs=0;
  default:nargs=2;
 endcase end endfunction
 assign parsing=(state!=COLLECT);
 always @(posedge clk or negedge reset_n) begin
  if(!reset_n)begin state<=COLLECT;len<=0;pos<=0;overflow<=0;drop_line<=0;legacy<=0;second<=0;neg<=0;hexmode<=0;digits<=0;number<=0;key<=0;keylen<=0;command<=0;id<=0;a<=0;b<=0;valid<=0;error<=0;end
  else begin
   valid<=0;error<=0;
   case(state)
    COLLECT:if(rx_valid)begin
     if(busy || drop_line)begin len<=0;overflow<=0;drop_line<=(rx_data!=13 && rx_data!=10);end
     else if(rx_data==13 || rx_data==10)begin
      if(overflow)begin error<=1;len<=0;overflow<=0;end
      else if(len!=0)begin pos<=0;key<=0;keylen<=0;command<=0;a<=0;b<=0;legacy<=0;second<=0;state<=KEY;end
     end else if(rx_data==8 || rx_data==127)begin if(len!=0)len<=len-1'b1;end
     else if(len<48)begin bufmem[len]<=rx_data;len<=len+1'b1;end
     else overflow<=1;
    end
    KEY:begin
     if(keylen==0 && space && !eol)pos<=pos+1'b1;
     else if(keylen==0 && digit)begin legacy<=1;state<=GAP;end
     else if(eol || space)begin
      if(decoded==0)state<=FAIL;
      else begin command<=decoded;state<=GAP;if(!eol)pos<=pos+1'b1;end
     end else if(keylen<6 && ((c>="A"&&c<="Z")||digit))begin key<={key[39:0],c};keylen<=keylen+1'b1;pos<=pos+1'b1;end
     else state<=FAIL;
    end
    GAP:begin
     if(eol)begin if(!legacy && nargs(command)==0)state<=DONE;else state<=FAIL;end
     else if(space)pos<=pos+1'b1;
     else if(!legacy && nargs(command)==0)state<=FAIL;
     else begin number<=0;digits<=0;hexmode<=0;neg<=(c=="-");state<=NUM;if(c=="-")pos<=pos+1'b1;end
    end
    NUM:begin
     if(legacy && !second && (c=="+"||c=="-"||c=="*") && numeric_ok && !neg)begin
      a<=number;command<=(c=="+")?5'd21:(c=="-")?5'd22:5'd23;second<=1;pos<=pos+1'b1;state<=GAP;
     end else if(eol || space)begin
      if(!numeric_ok || (legacy && !second))state<=FAIL;
      else if(!second && nargs(command)==2)begin
       if(eol)state<=FAIL;else begin a<=signed_number;second<=1;pos<=pos+1'b1;state<=GAP;end
      end else begin
       if(second)b<=signed_number;else a<=signed_number;
       state<=DONE;if(!eol)pos<=pos+1'b1;
      end
     end else if(!hexmode && !neg && digits==1 && number==0 && c=="X")begin hexmode<=1;digits<=0;pos<=pos+1'b1;end
     else if(hexmode && hexdigit && digits<8)begin number<={number[27:0],nibble};digits<=digits+1'b1;pos<=pos+1'b1;end
     else if(!hexmode && digit && digits<10 && (number<32'd429496729 || (number==32'd429496729 && nibble<=5)))begin number<=(number<<3)+(number<<1)+{28'd0,nibble};digits<=digits+1'b1;pos<=pos+1'b1;end
     else state<=FAIL;
    end
    DONE:begin
     if(!eol)begin if(space)pos<=pos+1'b1;else state<=FAIL;end
     else begin
      if((command>=21 && command<=23 && (a>9999||b>9999)) || (command==24&&a>9999) || (command==25&&a>39) || (command==27&&a!=20))error<=1;
      else begin id<=(command==27)?5'd26:command;valid<=1;end
      len<=0;overflow<=0;state<=COLLECT;
     end
    end
    FAIL:begin error<=1;len<=0;overflow<=0;state<=COLLECT;end
    default:state<=COLLECT;
   endcase
  end
 end
endmodule
