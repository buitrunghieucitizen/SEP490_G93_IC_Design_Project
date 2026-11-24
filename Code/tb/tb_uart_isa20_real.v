`timescale 1ns/1ps
// Real default 50 MHz and 115200 baud; accelerated POR only.
module tb_uart_isa20_real;
    reg clk=0; always #10 clk=~clk;
    reg reset_n=0,rx=1;
    wire tx,ds,sh_cp,st_cp;
    uart_cpu_mmio_v2_top #(.POR_CYCLES(16)) dut(.clk(clk),.reset_n(reset_n),.uart_rx(rx),.uart_tx(tx),.ds(ds),.sh_cp(sh_cp),.st_cp(st_cp));
    localparam integer BIT_NS=8680;
    integer nbytes=0, nresults=0, bcd_events=0, i, nbits=0, idx;
    reg negative,check_led=0;
    reg [7:0] byte_rx;
    reg [167:0] expected;
    reg [31:0] expected_bcd,expected_result;
    reg [15:0] frame=0;
    reg [7:0] led_mask=0;
    reg [7:0] segment;
    task send_byte; input [7:0] b; integer j; begin
        @(negedge clk);rx=0;#BIT_NS;
        for(j=0;j<8;j=j+1) begin rx=b[j];#BIT_NS;end
        rx=1;#BIT_NS;
    end endtask
    // Independent serial monitor: no DUT uart_rx reuse.
    initial begin
        wait(reset_n===1);
        forever begin
            @(negedge tx); #(BIT_NS/2);
            if(tx!==0) $fatal(1,"bad start bit");
            for(i=0;i<8;i=i+1) begin #BIT_NS;byte_rx[i]=tx;end
            #BIT_NS;if(tx!==1) $fatal(1,"bad stop bit");
            if(nbytes>=21 || byte_rx!==expected[(20-nbytes)*8+:8])
                $fatal(1,"TX byte %0d got=%h",nbytes,byte_rx);
            nbytes=nbytes+1;
        end
    end
    always @(posedge clk) if(reset_n && dut.result_strobe) begin
        nresults=nresults+1;
        if(dut.cpu_result!==expected_result) $fatal(1,"wrong result");
    end
    always @(posedge clk) if(reset_n && dut.signed_bcd_valid) begin
        if(dut.signed_bcd_digits!==expected_bcd) $fatal(1,"BCD mismatch");
        bcd_events=bcd_events+1;
    end
    always @(posedge sh_cp) begin frame={frame[14:0],ds};nbits=nbits+1;end
    always @(posedge st_cp) begin
        if(check_led) begin
            if(nbits!=16) $fatal(1,"bad LED frame length");
            case(frame[7:0])
                1:idx=0;2:idx=1;4:idx=2;8:idx=3;16:idx=4;32:idx=5;64:idx=6;128:idx=7;
                default:$fatal(1,"invalid digit select %h",frame[7:0]);
            endcase
            case(expected_bcd[idx*4+:4])
                0:segment=8'hc0;2:segment=8'ha4;6:segment=8'h82;10:segment=8'hbf;
                default:$fatal(1,"unexpected expected digit");
            endcase
            if(frame[15:8]!==segment) $fatal(1,"LED digit %0d got=%h expected=%h",idx,frame[15:8],segment);
            led_mask[idx]=1;
        end
        nbits=0;
    end
    integer k,hits;
    initial begin
        negative=$test$plusargs("NEGATIVE");
        expected=negative?{"TEST20",8'h0d,8'h0d,8'h0a,"Result: -6",8'h0d,8'h0a}:{"TEST20",8'h0d,8'h0d,8'h0a,"Result: 20",8'h0d,8'h0a};
        expected_result=negative?32'hfffffffa:32'd20;
        expected_bcd=negative?32'ha0000006:32'h00000020;
        if(negative) begin
            #1;hits=0;
            for(k=0;k<256;k=k+1) if(dut.u_cpu.u_datapath.u_inst_mem.rom[k]===32'h002091b3) begin
                dut.u_cpu.u_datapath.u_inst_mem.rom[k][14:12]=3'b101;hits=hits+1;
            end
            if(hits!=1) $fatal(1,"mutation target not unique");
        end
        repeat(5) @(negedge clk);reset_n=1;
        repeat(40) @(negedge clk);
        send_byte("T");send_byte("E");send_byte("S");send_byte("T");send_byte("2");send_byte("0");send_byte(13);
        wait(nresults==1);
        wait(bcd_events==1);
        #1;if(dut.signed_bcd_digits!==expected_bcd) $fatal(1,"BCD mismatch");
        // Wait > one digit period so any frame latched before BCD update is gone.
        repeat(51000) @(negedge clk);check_led=1;
        wait(led_mask===8'hff && nbytes==21);
        repeat(1000) @(negedge clk);
        if(nresults!=1 || bcd_events!=1 || dut.halted!==0 || dut.unused_echo_overflow!==0) $fatal(1,"duplicate result or fault");
        $display("PASS tb_uart_isa20_real result=%0d TX bytes=%0d LED digits=%h",$signed(expected_result),nbytes,led_mask);$finish;
    end
    initial begin #15000000;$fatal(1,"timeout TX bytes=%0d result=%0d LED=%h",nbytes,nresults,led_mask);end
endmodule
