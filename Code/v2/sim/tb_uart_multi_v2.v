`timescale 1ns/1ps
// 8N1 physical UART RX -> parser -> CPU -> result BCD -> TX + LED integration.
module tb_uart_multi_v2;
    localparam BIT_TICKS=10;
    reg clk=0; always #5 clk=~clk;
    reg reset_n=0,serial_in=1;
    wire serial_out,ds,sh_cp,st_cp;
    wire [7:0] rx_monitor;
    wire rx_monitor_valid;
    integer nbytes=0, nresults=0, found22=0, found55=0, found20=0, i;
    reg [7:0] buffer [0:511];
    uart_cpu_mmio_v2_top #(
        .POR_CYCLES(4),.UART_CLK_HZ(1000000),.UART_BAUD(100000),
        .MEM_FILE("src/program_multi_mmio.mem")) dut (
        .clk(clk),.reset_n(reset_n),.uart_rx(serial_in),.uart_tx(serial_out),
        .ds(ds),.sh_cp(sh_cp),.st_cp(st_cp));
    uart_rx #(.CLK_HZ(1000000),.BAUD(100000)) rx_verify (
        .clk(clk),.reset_n(reset_n),.rx(serial_out),
        .data(rx_monitor),.data_valid(rx_monitor_valid));
    always @(posedge clk) begin
        if (reset_n && dut.result_strobe) nresults=nresults+1;
        if (reset_n && rx_monitor_valid && nbytes<512) begin
            buffer[nbytes]=rx_monitor;nbytes=nbytes+1;
        end
    end
    task serial_byte; input [7:0] val; integer bitno; begin
        @(negedge clk);serial_in=0;
        repeat(BIT_TICKS) @(negedge clk);
        for(bitno=0;bitno<8;bitno=bitno+1) begin
            serial_in=val[bitno];
            repeat(BIT_TICKS) @(negedge clk);
        end
        serial_in=1;repeat(BIT_TICKS) @(negedge clk);
    end endtask
    initial begin
        repeat(5) @(negedge clk);reset_n=1;
        repeat(25) @(negedge clk);
        serial_byte("1");serial_byte("5");serial_byte("+");serial_byte("7");serial_byte(13);
        wait(nresults>=1);
        if(dut.cpu_result!==32'd22) $fatal(1,"15+7 wrong result");
        repeat(3000) @(negedge clk);
        serial_byte("F");serial_byte("I");serial_byte("B");serial_byte(" ");serial_byte("1");serial_byte("0");serial_byte(13);
        wait(nresults>=2);
        if(dut.cpu_result!==32'd55) $fatal(1,"FIB 10 wrong result");
        repeat(3000) @(negedge clk);
        serial_byte("T");serial_byte("E");serial_byte("S");serial_byte("T");serial_byte("2");serial_byte("0");serial_byte(13);
        wait(nresults>=3);
        if(dut.cpu_result!==32'd20) $fatal(1,"TEST20 wrong result");
        repeat(5000) @(negedge clk);
        for(i=0;i<nbytes-10;i=i+1) begin
            if(buffer[i]=="R"&&buffer[i+1]=="e"&&buffer[i+2]=="s"&&
               buffer[i+3]=="u"&&buffer[i+4]=="l"&&buffer[i+5]=="t"&&
               buffer[i+6]==":"&&buffer[i+7]==" ") begin
                if(buffer[i+8]=="2"&&buffer[i+9]=="2") found22=1;
                if(buffer[i+8]=="5"&&buffer[i+9]=="5") found55=1;
                if(buffer[i+8]=="2"&&buffer[i+9]=="0") found20=1;
            end
        end
        if(nresults!=3||!found22||!found55||!found20||dut.halted)
            $fatal(1,"UART full v2 results=%0d bytes=%0d 22=%0d 55=%0d 20=%0d halt=%b",nresults,nbytes,found22,found55,found20,dut.halted);
        $display("PASS tb_uart_multi_v2: 15+7=22, FIB 10=55, TEST20=20 and TX replies");
        $finish;
    end
    initial begin
        repeat(80000) @(negedge clk);
        $fatal(1,"UART v2 TIMEOUT nresults=%0d",nresults);
    end
endmodule
