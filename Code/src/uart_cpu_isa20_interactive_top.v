// Same FPGA ports, pin constraints, 50 MHz and 115200 baud as proven v2.
module uart_cpu_isa20_interactive_top #(
 parameter MEM_FILE="src/program_multi_mmio.mem",parameter integer POR_CYCLES=500000,
 parameter integer UART_CLK_HZ=50000000,UART_BAUD=115200
)(input wire clk,reset_n,uart_rx, output wire uart_tx,ds,sh_cp,st_cp);
 reg [19:0] por_count=0;reg por_done=0;
 always @(posedge clk or negedge reset_n)begin
  if(!reset_n)begin por_count<=0;por_done<=0;end
  else if(!por_done)begin if(por_count==POR_CYCLES-1)por_done<=1;else por_count<=por_count+1'b1;end
 end
 wire system_reset_n=reset_n&&por_done;
 wire [7:0] rx_data;wire rx_valid;
 uart_rx #(.CLK_HZ(UART_CLK_HZ),.BAUD(UART_BAUD)) u_rx(.clk(clk),.reset_n(system_reset_n),.rx(uart_rx),.data(rx_data),.data_valid(rx_valid));
 wire [4:0] id;wire [31:0] a,b;wire valid,error,parsing;
 wire engine_busy,done;wire [2:0] kind,flags;wire [31:0] word,pc_before,pc_after,wb,value;
 wire tx_busy;reg [1:0] response_state;localparam WAIT=0,BCD=1,SEND=2,TX=3;
 wire console_busy=engine_busy||done||valid||error||response_state!=WAIT||tx_busy;
 isa20_interactive_parser u_parser(.clk(clk),.reset_n(system_reset_n),.busy(console_busy),.rx_data(rx_data),.rx_valid(rx_valid),.id(id),.a(a),.b(b),.valid(valid),.error(error),.parsing(parsing));
 isa20_interactive_engine #(.MEM_FILE(MEM_FILE)) u_engine(.clk(clk),.reset_n(system_reset_n),.request(valid),.parse_error(error),.id(id),.a(a),.b(b),.busy(engine_busy),.done(done),.kind(kind),.word(word),.pc_before(pc_before),.pc_after(pc_after),.wb(wb),.value(value),.flags(flags));
 wire needs_bcd=kind==0||kind==1||kind==5;
 wire [31:0] display_bcd;wire bcd_valid;
 signed_result_to_bcd8 u_bcd(.clk(clk),.reset_n(system_reset_n),.result_strobe(done&&needs_bcd),.result_binary(value),.display_bcd(display_bcd),.display_valid(bcd_valid));
 always @(posedge clk or negedge system_reset_n)begin
  if(!system_reset_n)response_state<=WAIT;
  else case(response_state)
   WAIT:if(done)response_state<=needs_bcd?BCD:SEND;
   BCD:if(bcd_valid)response_state<=SEND;
   SEND:response_state<=TX;
   TX:if(!tx_busy)response_state<=WAIT;
  endcase
 end
 isa20_interactive_tx #(.CLK_HZ(UART_CLK_HZ),.BAUD(UART_BAUD)) u_console(.clk(clk),.reset_n(system_reset_n),.start(response_state==SEND),.kind(kind),.word(word),.pc_before(pc_before),.pc_after(pc_after),.wb(wb),.value(value),.bcd(display_bcd),.flags(flags),.tx(uart_tx),.busy(tx_busy));
 led7_scan_signed_595 u_led(.clk(clk),.reset_n(system_reset_n),.bcd_value(display_bcd),.ds(ds),.sh_cp(sh_cp),.st_cp(st_cp));
endmodule
