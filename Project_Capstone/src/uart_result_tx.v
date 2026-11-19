// UART result response formatter for SEP490_G93 (Verilog-2001).
// One transmitter handles RX echo and CPU-produced decimal results.
// Input BCD is the ALREADY converted display_bcd from signed_result_to_bcd8:
// - 0..9 decimal digits, A minus sign, E overflow indicator.
// On bcd_valid: queue one result, and print "\r\nResult: <signed-decimal>\r\n".
// To preserve echo while a response is being sent, incoming bytes are queued
// in a 64-byte echo FIFO. For continuous input beyond buffer capacity the
// echo_overflow flag is set. Parser and CPU data flow are not affected.
// Result mailbox is one entry: intended for human-entered UART commands.
module uart_result_tx #(
    parameter integer CLK_HZ = 50000000,
    parameter integer BAUD = 115200
)(
    input  wire        clk,
    input  wire        reset_n,
    input  wire [7:0]  rx_data,
    input  wire        rx_valid,
    input  wire [31:0] result_bcd,
    input  wire        bcd_valid,
    output wire        uart_tx,
    output reg         echo_overflow
);
    localparam [2:0] IDLE = 3'd0, PREFIX = 3'd1,
                     DIGITS = 3'd2, SEND_CR = 3'd3, SEND_LF = 3'd4;

    reg [2:0] state;
    reg [3:0] prefix_index;
    reg [2:0] digit_index;
    reg       digit_started; // suppress zeros after optional minus sign
    reg [31:0] digits_latched;
    reg        pending;
    reg [31:0] pending_digits;

    // A FIFO separates the RX byte rate from TX echo/reply scheduling.
    reg [7:0] echo_fifo [0:63];
    reg [5:0] wr_ptr, rd_ptr;
    reg [6:0] echo_count;

    wire tx_busy;
    wire launch_echo = (state == IDLE) && (echo_count != 0) && !tx_busy;
    wire launch_reply = (state == IDLE) && (echo_count == 0) && pending && !tx_busy;
    wire launch_prefix = (state == PREFIX) && !tx_busy;
    wire [3:0] current_nibble = digits_latched[digit_index*4 +: 4];
    wire skip_zero = (state == DIGITS) && !tx_busy && !digit_started &&
                     (current_nibble == 4'd0) && (digit_index != 3'd0);
    wire launch_digit = (state == DIGITS) && !tx_busy && !skip_zero;
    wire launch_cr = (state == SEND_CR) && !tx_busy;
    wire launch_lf = (state == SEND_LF) && !tx_busy;
    wire tx_start = launch_echo || launch_prefix || launch_digit || launch_cr || launch_lf;
    wire echo_push = rx_valid && ((echo_count < 7'd64) || launch_echo);

    function [2:0] top_digit;
        input [31:0] bcd;
        integer i;
        begin
            top_digit = 3'd0;
            for (i = 0; i < 8; i = i + 1)
                if (bcd[(i*4) +: 4] != 4'd0)
                    top_digit = i;
        end
    endfunction

    function [7:0] header_byte;
        input [3:0] index;
        begin
            case(index)
                4'd0: header_byte=8'h0d; // CR
                4'd1: header_byte=8'h0a; // LF
                4'd2: header_byte="R";
                4'd3: header_byte="e";
                4'd4: header_byte="s";
                4'd5: header_byte="u";
                4'd6: header_byte="l";
                4'd7: header_byte="t";
                4'd8: header_byte=":";
                default: header_byte=" ";
            endcase
        end
    endfunction

    function [7:0] digit_byte;
        input [3:0] val;
        begin
            if (val <= 4'd9) digit_byte = 8'd48 + {4'd0, val};
            else if (val == 4'hA) digit_byte = "-";
            else digit_byte = "E";
        end
    endfunction

    reg [7:0] tx_data;
    always @* begin
        tx_data = 8'h00;
        if (launch_echo) tx_data = echo_fifo[rd_ptr];
        else case (state)
            PREFIX: tx_data = header_byte(prefix_index);
            DIGITS: tx_data = digit_byte(current_nibble);
            SEND_CR: tx_data = 8'h0d;
            SEND_LF: tx_data = 8'h0a;
            default: tx_data = 8'h00;
        endcase
    end

    uart_tx #(.CLK_HZ(CLK_HZ), .BAUD(BAUD)) u_serial (
        .clk(clk), .reset_n(reset_n),
        .data_in(tx_data), .data_start(tx_start),
        .tx(uart_tx), .busy(tx_busy)
    );

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            wr_ptr <= 6'd0;
            rd_ptr <= 6'd0;
            echo_count <= 7'd0;
            echo_overflow <= 1'b0;
        end else begin
            if (echo_push) begin
                echo_fifo[wr_ptr] <= rx_data;
                wr_ptr <= wr_ptr + 1'b1;
            end else if (rx_valid) begin
                echo_overflow <= 1'b1;
            end
            if (launch_echo) rd_ptr <= rd_ptr + 1'b1;
            case ({echo_push, launch_echo})
                2'b10: echo_count <= echo_count + 1'b1;
                2'b01: echo_count <= echo_count - 1'b1;
                default: echo_count <= echo_count;
            endcase
        end
    end

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state <= IDLE;
            pending <= 1'b0;
            pending_digits <= 32'd0;
            digits_latched <= 32'd0;
            digit_index <= 3'd0;
            digit_started <= 1'b0;
            prefix_index <= 4'd0;
        end else begin
            if (launch_reply) begin
                pending <= 1'b0;
                digits_latched <= pending_digits;
                digit_index <= top_digit(pending_digits);
                digit_started <= 1'b0;
                prefix_index <= 4'd0;
                state <= PREFIX;
            end else if (launch_prefix) begin
                if (prefix_index == 4'd9) state <= DIGITS;
                else prefix_index <= prefix_index + 1'b1;
            end else if (skip_zero) begin
                digit_index <= digit_index - 1'b1;
            end else if (launch_digit) begin
                if (current_nibble != 4'hA) digit_started <= 1'b1;
                if (digit_index == 3'd0) state <= SEND_CR;
                else digit_index <= digit_index - 1'b1;
            end else if (launch_cr) begin
                state <= SEND_LF;
            end else if (launch_lf) begin
                state <= IDLE;
            end
            // Result arriving while sending a previous reply is remembered.
            // A single mailbox is sufficient for human-paced Tera Term entry.
            if (bcd_valid) begin
                pending_digits <= result_bcd;
                pending <= 1'b1;
            end
        end
    end
endmodule
