`timescale 1ns/1ps
// Serial monitor is independent of uart_rx RTL: sample physical TX at bit centers.
module tb_isa20_interactive_uart #(parameter REAL_UART=0);
 localparam BAUD=REAL_UART?115200:1562500;
 localparam TICKS=50000000/BAUD;
 reg clk=0;always #10 clk=~clk;reg reset_n=0,serial_in=1;
 wire serial_out,ds,sh_cp,st_cp;
 uart_cpu_isa20_interactive_top #(.POR_CYCLES(4),.UART_CLK_HZ(50000000),.UART_BAUD(BAUD)) dut(.clk(clk),.reset_n(reset_n),.uart_rx(serial_in),.uart_tx(serial_out),.ds(ds),.sh_cp(sh_cp),.st_cp(st_cp));
 reg [7:0] rxbytes[0:4095];integer nbytes=0,checks=0,bitno;reg [7:0] rxchar;
 initial forever begin
  @(negedge serial_out);
  if(reset_n)begin
   repeat(TICKS/2)@(posedge clk);#1;if(serial_out!==0)$fatal(1,"Invalid UART start");
   for(bitno=0;bitno<8;bitno=bitno+1)begin repeat(TICKS)@(posedge clk);#1;rxchar[bitno]=serial_out;end
   repeat(TICKS)@(posedge clk);#1;if(serial_out!==1)$fatal(1,"Invalid UART stop");
   if(nbytes>=4096)$fatal(1,"Monitor overflow");rxbytes[nbytes]=rxchar;nbytes=nbytes+1;
  end
 end
 task serial_byte;input [7:0] c;integer k;
 begin @(negedge clk);serial_in=0;repeat(TICKS)@(negedge clk);
 for(k=0;k<8;k=k+1)begin serial_in=c[k];repeat(TICKS)@(negedge clk);end
 serial_in=1;repeat(TICKS)@(negedge clk);end endtask
 task command;
 input [8*64-1:0] msg;input [8*128-1:0] expected;
 integer j,start,len,waited,index;
 begin
 start=nbytes;len=0;
 for(j=127;j>=0;j=j-1)if(expected[j*8+:8]!=0)len=len+1;
 for(j=63;j>=0;j=j-1)if(msg[j*8+:8]!=0)serial_byte(msg[j*8+:8]);
 serial_byte(13);waited=0;
 while(nbytes<start+len && waited<1500*TICKS+110000)begin @(negedge clk);waited=waited+1;end
 if(nbytes!=start+len)$fatal(1,"UART %0s: response length %d expected %d",msg,nbytes-start,len);
 index=start;
 for(j=127;j>=0;j=j-1)if(expected[j*8+:8]!=0)begin
  if(rxbytes[index]!==expected[j*8+:8])$fatal(1,"UART %0s: byte %d got=%h expected=%h",msg,index-start,rxbytes[index],expected[j*8+:8]);index=index+1;
 end
 repeat(TICKS*3)@(negedge clk);
 if(dut.console_busy || nbytes!=start+len)$fatal(1,"UART extra bytes or busy after response");
 checks=checks+1;$display("PASS UART %0s",msg);
 end endtask
 initial begin
 repeat(5)@(negedge clk);reset_n=1;repeat(25)@(negedge clk);
 if(!REAL_UART)begin
 `include "uart_vectors.vh"
 end else begin
 command("ADD 15 3",{8'h0d,8'h0a,"WORD=002081B3 PC=0000000C NEXT=00000010 WB=00000012 VALUE=00000012",8'h0d,8'h0a});
 if(dut.display_bcd!==32'h00000018)$fatal(1,"LED BCD ADD");
 command("SRA -16 2",{8'h0d,8'h0a,"WORD=4020D1B3 PC=0000000C NEXT=00000010 WB=FFFFFFFC VALUE=FFFFFFFC",8'h0d,8'h0a});
 if(dut.display_bcd!==32'ha0000004)$fatal(1,"LED BCD negative");
 end
 command("ADD 0x7fffffff 1",{8'h0d,8'h0a,"WORD=002081B3 PC=0000000C NEXT=00000010 WB=80000000 VALUE=80000000",8'h0d,8'h0a});
 if(dut.display_bcd!==32'heeeeeeee)$fatal(1,"LED overflow indicator");
 command("15+7",{8'h0d,8'h0a,"Result: 22",8'h0d,8'h0a});
 if(dut.display_bcd!==32'h00000022)$fatal(1,"LED BCD legacy");
 command("7-15",{8'h0d,8'h0a,"Result: -8",8'h0d,8'h0a});
 command("TEST20",{8'h0d,8'h0a,"Result: 20",8'h0d,8'h0a});
 command("ADDI 0 2048",{8'h0d,8'h0a,"ERROR: INVALID COMMAND OR OPERAND",8'h0d,8'h0a});
 command("JAL 2",{8'h0d,8'h0a,"FAULT WORD=002001EF PC=0000000C NEXT=0000000C FLAGS=2",8'h0d,8'h0a});
 command("STATUS",{8'h0d,8'h0a,"Status: READY",8'h0d,8'h0a});
 command("CLEAR",{8'h0d,8'h0a,"Display cleared",8'h0d,8'h0a});
 if(dut.display_bcd!==0)$fatal(1,"CLEAR LED");
 $display("PASS tb_isa20_interactive_uart: %0d exact serial replies REAL_UART=%0d",checks,REAL_UART);$finish;
 end
 initial begin #1000000000;$fatal(1,"UART global timeout");end
endmodule
