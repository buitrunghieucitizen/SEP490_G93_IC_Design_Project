`timescale 1ns/1ps
module tb_command_parser_v2;
    reg clk=0; always #5 clk=~clk;
    reg reset_n=0, rx_valid=0, busy=0;
    reg [7:0] rx_data=0;
    wire [31:0] a,b;
    wire [2:0] id;
    wire strobe;
    integer count=0;
    uart_command_parser_v2 dut(
        .clk(clk),.reset_n(reset_n),.rx_data(rx_data),.rx_valid(rx_valid),
        .busy(busy),.operand_a(a),.operand_b(b),.command_id(id),.command_strobe(strobe));
    task chr; input [7:0] c; begin
        @(negedge clk); rx_data=c; rx_valid=1;
        @(negedge clk); rx_valid=0;
    end endtask
    task check; input [2:0] expected_id; input [31:0] expected_a,expected_b;
    begin
        #1;
        if (strobe!==1 || id!==expected_id || a!==expected_a || b!==expected_b)
            $fatal(1,"parser FAIL id=%0d a=%0d b=%0d strobe=%b (expected %0d %0d %0d)",id,a,b,strobe,expected_id,expected_a,expected_b);
        count=count+1;
    end endtask
    initial begin
        repeat(4) @(negedge clk); reset_n=1;
        chr("1");chr("5");chr("+");chr("7");
        @(negedge clk); rx_data=13; rx_valid=1;
        @(posedge clk); #1; check(1,15,7);
        @(negedge clk);rx_valid=0;
        chr(10); // CRLF trailing LF ignored
        chr("7");chr("-");chr("1");chr("5");
        @(negedge clk); rx_data=13;rx_valid=1;
        @(posedge clk);#1;check(2,7,15);
        @(negedge clk);rx_valid=0;
        chr("1");chr("2");chr("*");chr("5");
        @(negedge clk);rx_data=13;rx_valid=1;
        @(posedge clk);#1;check(3,12,5);
        @(negedge clk);rx_valid=0;
        chr("s");chr("u");chr("m");chr(" ");chr("1");chr("0");
        @(negedge clk);rx_data=13;rx_valid=1;
        @(posedge clk);#1;check(4,10,0);
        @(negedge clk);rx_valid=0;
        chr("F");chr("I");chr("B");chr(" ");chr("3");chr("9");
        @(negedge clk);rx_data=13;rx_valid=1;
        @(posedge clk);#1;check(5,39,0);
        @(negedge clk);rx_valid=0;
        chr("T");chr("E");chr("S");chr("T");chr("2");chr("0");
        @(negedge clk);rx_data=13;rx_valid=1;
        @(posedge clk);#1;check(6,0,0);
        @(negedge clk);rx_valid=0;
        // FIB 40 intentionally invalid: parser must not issue a request.
        chr("F");chr("I");chr("B");chr(" ");chr("4");chr("0");chr(13);
        if (strobe!==0) $fatal(1,"FIB 40 improperly accepted");
        // When busy, valid command must NOT replace outstanding operands.
        busy=1;
        chr("1");chr("+");chr("2");chr(13);
        if (strobe!==0) $fatal(1,"Busy parser improperly strobing");
        $display("PASS tb_command_parser_v2: %0d valid commands, FIB bound and busy",count);
        $finish;
    end
endmodule
