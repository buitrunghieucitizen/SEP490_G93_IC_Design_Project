// UART 8N1 receiver, 50 MHz / 115200 by default.
// A pulse on data_valid marks a newly received byte.
// Verilog-2001, no vendor-specific IP.
module uart_rx #(
    parameter integer CLK_HZ = 50000000,
    parameter integer BAUD   = 115200
)(
    input  wire       clk,
    input  wire       reset_n,
    input  wire       rx,
    output reg [7:0] data,
    output reg       data_valid
);
    localparam integer CLKS_PER_BIT = CLK_HZ / BAUD;
    localparam integer HALF_BIT     = CLKS_PER_BIT / 2;
    localparam [1:0] IDLE = 2'd0, START = 2'd1,
                     DATA = 2'd2, STOP = 2'd3;
    reg [1:0] state;
    reg rx_meta, rx_sync;
    reg [15:0] timer;
    reg [2:0] bit_index;
    reg [7:0] shift_data;

    // Synchronize asynchronous serial input to FPGA clock.
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            rx_meta <= 1'b1;
            rx_sync <= 1'b1;
        end else begin
            rx_meta <= rx;
            rx_sync <= rx_meta;
        end
    end

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state <= IDLE;
            timer <= 16'd0;
            bit_index <= 3'd0;
            shift_data <= 8'd0;
            data <= 8'd0;
            data_valid <= 1'b0;
        end else begin
            data_valid <= 1'b0;
            case (state)
                IDLE: begin
                    if (!rx_sync) begin
                        // Check the start bit at its midpoint.
                        timer <= HALF_BIT - 1;
                        state <= START;
                    end
                end
                START: begin
                    if (timer != 0) timer <= timer - 1'b1;
                    else if (!rx_sync) begin
                        timer <= CLKS_PER_BIT - 1;
                        bit_index <= 3'd0;
                        state <= DATA;
                    end else state <= IDLE;  // Glitch, not a start bit.
                end
                DATA: begin
                    if (timer != 0) timer <= timer - 1'b1;
                    else begin
                        shift_data[bit_index] <= rx_sync;
                        timer <= CLKS_PER_BIT - 1;
                        if (bit_index == 3'd7) state <= STOP;
                        else bit_index <= bit_index + 1'b1;
                    end
                end
                STOP: begin
                    if (timer != 0) timer <= timer - 1'b1;
                    else begin
                        if (rx_sync) begin // Valid stop bit.
                            data <= shift_data;
                            data_valid <= 1'b1;
                        end
                        state <= IDLE;
                    end
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule
