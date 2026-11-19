`timescale 1ns/1ps
module tb_test20_parser_patch;
  reg clk=0; always #5 clk=~clk;
  reg reset_n=0, rx_valid=0, busy=0;
  reg [7:0] rx_data=0;
  wire [31:0] a,b;
  wire [2:0] id;
  wire strobe;
  integer checks=0;
  uart_command_parser_v2 dut (
    .clk(clk),.reset_n(reset_n),.rx_data(rx_data),.rx_valid(rx_valid),
    .busy(busy),.operand_a(a),.operand_b(b),
    .command_id(id),.command_strobe(strobe)
  );
  task ch; input [7:0] c; begin
    @(negedge clk); rx_data=c; rx_valid=1;
    @(negedge clk); rx_valid=0;
  end endtask
  task last; input [2:0] eid; input [31:0] ea,eb; begin
    @(negedge clk); rx_data=8'h0D; rx_valid=1;
    @(posedge clk); #1;
    if(strobe!==1 || id!==eid || a!==ea || b!==eb)
      $fatal(1,"FAIL id=%0d A=%0d B=%0d strobe=%b want %0d/%0d/%0d",id,a,b,strobe,eid,ea,eb);
    checks=checks+1;
    @(negedge clk);rx_valid=0;
    @(negedge clk);
  end endtask
  initial begin
    repeat(3) @(negedge clk); reset_n=1;
    // Original 6-character spelling.
    ch("T");ch("E");ch("S");ch("T");ch("2");ch("0");last(6,0,0);
    // Extra space sometimes typed by operators.
    ch("T");ch("E");ch("S");ch("T");ch(" ");ch("2");ch("0");last(6,0,0);
    // Diagnostic short alias.
    ch("T");last(6,0,0);
    // Lowercase.
    ch("t");ch("e");ch("s");ch("t");ch("2");ch("0");last(6,0,0);
    // Ensure normal calculator still works immediately after TEST20.
    ch("2");ch("+");ch("3");last(1,2,3);
    $display("PASS tb_test20_parser_patch: %0d commands", checks);
    $finish;
  end
endmodule
