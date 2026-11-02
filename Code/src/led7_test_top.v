// Step 1: standalone 8-digit 7-segment display test for Gowin ACG525.
// Displays hexadecimal 01234567. 50 MHz clock.
// Pin mapping will be configured in Step 2, not in this file.
// Assumes two cascaded 74HC595 devices, active-low segment/digit signals.
// Serial order and polarity must be verified on the actual board.
module led7_test_top (
    input  wire clk,
    input  wire reset_n,
    output reg  ds,
    output reg  sh_cp,
    output reg  st_cp
);
    reg [15:0] scan_count = 0;
    reg [2:0] digit_index = 0;
    reg [15:0] shift_word = 16'hffff;
    reg [15:0] shift_register = 16'hffff;
    reg [4:0] bit_index = 0;
    reg [2:0] state = 0;
    reg [7:0] segment_pattern;
    reg [7:0] digit_select;
    reg [3:0] nibble;

    // Hex value 32'h01234567, rightmost digit is 7.
    always @* begin
        case (digit_index)
            3'd0: nibble = 4'h7;
            3'd1: nibble = 4'h6;
            3'd2: nibble = 4'h5;
            3'd3: nibble = 4'h4;
            3'd4: nibble = 4'h3;
            3'd5: nibble = 4'h2;
            3'd6: nibble = 4'h1;
            default: nibble = 4'h0;
        endcase
        case (nibble)
            4'h0: segment_pattern = 8'hc0;
            4'h1: segment_pattern = 8'hf9;
            4'h2: segment_pattern = 8'ha4;
            4'h3: segment_pattern = 8'hb0;
            4'h4: segment_pattern = 8'h99;
            4'h5: segment_pattern = 8'h92;
            4'h6: segment_pattern = 8'h82;
            4'h7: segment_pattern = 8'hf8;
            4'h8: segment_pattern = 8'h80;
            4'h9: segment_pattern = 8'h90;
            4'ha: segment_pattern = 8'h88;
            4'hb: segment_pattern = 8'h83;
            4'hc: segment_pattern = 8'hc6;
            4'hd: segment_pattern = 8'ha1;
            4'he: segment_pattern = 8'h86;
            default: segment_pattern = 8'h8e;
        endcase
        digit_select = ~(8'b00000001 << digit_index);
    end

    // Shift 16 bits and latch; one digit refresh roughly every 1 ms.
    // Shift data MSB first, rising edge of SH_CP captures DS.
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            scan_count <= 0;
            digit_index <= 0;
            shift_word <= 16'hffff;
            shift_register <= 16'hffff;
            bit_index <= 0;
            state <= 0;
            ds <= 0;
            sh_cp <= 0;
            st_cp <= 0;
        end else begin
            case (state)
                3'd0: begin
                    sh_cp <= 0;
                    st_cp <= 0;
                    if (scan_count == 16'd49999) begin
                        scan_count <= 0;
                        // {DP=off, seven segments, digit select}
                        shift_word <= {segment_pattern, digit_select};
                        shift_register <= {segment_pattern, digit_select};
                        bit_index <= 0;
                        state <= 3'd1;
                    end else begin
                        scan_count <= scan_count + 1'b1;
                    end
                end
                3'd1: begin
                    sh_cp <= 0;
                    ds <= shift_register[15];
                    state <= 3'd2;
                end
                3'd2: begin
                    sh_cp <= 1;
                    state <= 3'd3;
                end
                3'd3: begin
                    sh_cp <= 0;
                    shift_register <= {shift_register[14:0], 1'b0};
                    if (bit_index == 5'd15) state <= 3'd4;
                    else begin
                        bit_index <= bit_index + 1'b1;
                        state <= 3'd1;
                    end
                end
                3'd4: begin
                    st_cp <= 1;
                    state <= 3'd5;
                end
                3'd5: begin
                    st_cp <= 0;
                    digit_index <= digit_index + 1'b1;
                    state <= 3'd0;
                end
                default: state <= 3'd0;
            endcase
        end
    end
endmodule
