// UART 8N1 transmitter. data_start must be a one-clock pulse when !busy.
module uart_tx #(
    parameter integer CLK_HZ = 50000000,
    parameter integer BAUD   = 115200
)(
    input  wire       clk,
    input  wire       reset_n,
    input  wire [7:0] data_in,
    input  wire       data_start,
    output reg        tx,
    output wire       busy
);
    localparam integer CLKS_PER_BIT = CLK_HZ / BAUD;
    localparam [1:0] IDLE=2'd0, START=2'd1, DATA=2'd2, STOP=2'd3;
    reg [1:0] state;
    reg [15:0] timer;
    reg [2:0] bit_index;
    reg [7:0] shift_data;
    assign busy = (state != IDLE);

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state <= IDLE;
            timer <= 16'd0;
            bit_index <= 3'd0;
            shift_data <= 8'd0;
            tx <= 1'b1;
        end else begin
            case (state)
                IDLE: begin
                    tx <= 1'b1;
                    if (data_start) begin
                        shift_data <= data_in;
                        tx <= 1'b0;       // Start bit.
                        timer <= CLKS_PER_BIT - 1;
                        state <= START;
                    end
                end
                START: begin
                    if (timer != 0) timer <= timer - 1'b1;
                    else begin
                        tx <= shift_data[0];
                        bit_index <= 3'd0;
                        timer <= CLKS_PER_BIT - 1;
                        state <= DATA;
                    end
                end
                DATA: begin
                    if (timer != 0) timer <= timer - 1'b1;
                    else begin
                        timer <= CLKS_PER_BIT - 1;
                        if (bit_index == 3'd7) begin
                            tx <= 1'b1;   // Stop bit.
                            state <= STOP;
                        end else begin
                            bit_index <= bit_index + 1'b1;
                            tx <= shift_data[bit_index + 1'b1];
                        end
                    end
                end
                STOP: begin
                    if (timer != 0) timer <= timer - 1'b1;
                    else state <= IDLE;
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule
