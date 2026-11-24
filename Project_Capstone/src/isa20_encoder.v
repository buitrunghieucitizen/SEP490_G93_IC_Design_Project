// Encode the user-selected instruction, not its result. x1=A, x2=B, x3=rd.
module isa20_encoder(input wire [4:0] id, input wire [31:0] a,b,
 output reg [31:0] word, output reg valid);
 wire imm_ok = ($signed(b)>=-32'sd2048 && $signed(b)<=32'sd2047);
 function [31:0] r; input [6:0] f7; input [2:0] f3;
 begin r={f7,5'd2,5'd1,f3,5'd3,7'h33};end endfunction
 function [31:0] i; input [2:0] f3; input [11:0] imm;
 begin i={imm,5'd1,f3,5'd3,7'h13};end endfunction
 always @* begin
  valid=1;word=32'h00000013;
  case(id)
   1:word=r(0,0); 2:word=r(7'h20,0); 3:word=r(0,7); 4:word=r(0,6);
   5:word=r(0,4); 6:word=r(0,1); 7:word=r(0,5); 8:word=r(7'h20,5);
   9:begin word=i(0,b[11:0]);valid=imm_ok;end
   10:begin word=i(7,b[11:0]);valid=imm_ok;end
   11:begin word=i(6,b[11:0]);valid=imm_ok;end
   12:begin word=i(4,b[11:0]);valid=imm_ok;end
   13:begin word=32'h0020a023;valid=(a<512 && a[1:0]==0);end // SW x2,0(x1)
   14:begin word=32'h0000a183;valid=(a<512 && a[1:0]==0);end // LW x3,0(x1)
   15:word=32'h00208463; // BEQ x1,x2,+8
   16:word=32'h00209463; // BNE x1,x2,+8
   17:begin word={a[20],a[10:1],a[11],a[19:12],5'd3,7'h6f};
       valid=($signed(a)>=-32'sd1048576 && $signed(a)<=32'sd1048574 && !a[0]);end
   18:begin word={b[11:0],5'd1,3'd0,5'd3,7'h67};valid=imm_ok;end
   19:begin word={a[19:0],5'd3,7'h37};valid=(a<=32'hfffff);end
   20:begin word={a[19:0],5'd3,7'h17};valid=(a<=32'hfffff);end
   default:valid=0;
  endcase
 end
endmodule
