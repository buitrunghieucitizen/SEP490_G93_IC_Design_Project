// Step 6: 8-digit ACG525 LED display using two cascaded 74HC595 shift registers.
// Data is eight BCD digits (4 bits each). A represents minus, E represents error.
// IMPORTANT hardware-verified polarity: digit_select is ACTIVE HIGH.
// Segment codes are ACTIVE LOW, and bytes are shifted MSB first.
module led7_scan_signed_595 (
    input wire clk,
    input wire reset_n,
    input wire [31:0] bcd_value,
    output reg ds,
    output reg sh_cp,
    output reg st_cp
);
    reg [15:0] scan_count;
    reg [2:0]  digit_index;
    reg [15:0] shift_register;
    reg [4:0]  bit_index;
    reg [2:0]  state;
    reg [7:0]  segment_pattern;
    reg [7:0]  digit_select;
    reg [3:0]  nibble;

    always @* begin
        case (digit_index)
            3'd0: nibble = bcd_value[3:0];
            3'd1: nibble = bcd_value[7:4];
            3'd2: nibble = bcd_value[11:8];
            3'd3: nibble = bcd_value[15:12];
            3'd4: nibble = bcd_value[19:16];
            3'd5: nibble = bcd_value[23:20];
            3'd6: nibble = bcd_value[27:24];
            default: nibble = bcd_value[31:28];
        endcase
        case (nibble)
            4'h0: segment_pattern = 8'hC0;
            4'h1: segment_pattern = 8'hF9;
            4'h2: segment_pattern = 8'hA4;
            4'h3: segment_pattern = 8'hB0;
            4'h4: segment_pattern = 8'h99;
            4'h5: segment_pattern = 8'h92;
            4'h6: segment_pattern = 8'h82;
            4'h7: segment_pattern = 8'hF8;
            4'h8: segment_pattern = 8'h80;
            4'h9: segment_pattern = 8'h90;
            4'hA: segment_pattern = 8'hBF;  // '-' : segment g only, active LOW
            4'hE: segment_pattern = 8'h86;  // 'E' : error/overflow
            default: segment_pattern = 8'hFF;
        endcase
        // Tested on ACG525 board: SELECT IS ACTIVE HIGH.
        digit_select = (8'b00000001 << digit_index);
    end

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            scan_count <= 16'd0;
            digit_index <= 3'd0;
            shift_register <= 16'hFFFF;
            bit_index <= 5'd0;
            state <= 3'd0;
            ds <= 1'b0;
            sh_cp <= 1'b0;
            st_cp <= 1'b0;
        end else begin
            case (state)
                3'd0: begin
                    sh_cp <= 1'b0;
                    st_cp <= 1'b0;
                    if (scan_count == 16'd49999) begin
                        scan_count <= 16'd0;
                        shift_register <= {segment_pattern, digit_select};
                        bit_index <= 5'd0;
                        state <= 3'd1;
                    end else scan_count <= scan_count + 1'b1;
                end
                3'd1: begin
                    sh_cp <= 1'b0;
                    ds <= shift_register[15];
                    state <= 3'd2;
                end
                3'd2: begin
                    sh_cp <= 1'b1;
                    state <= 3'd3;
                end
                3'd3: begin
                    sh_cp <= 1'b0;
                    shift_register <= {shift_register[14:0], 1'b0};
                    if (bit_index == 5'd15) state <= 3'd4;
                    else begin
                        bit_index <= bit_index + 1'b1;
                        state <= 3'd1;
                    end
                end
                3'd4: begin
                    st_cp <= 1'b1;
                    state <= 3'd5;
                end
                3'd5: begin
                    st_cp <= 1'b0;
                    digit_index <= digit_index + 1'b1;
                    state <= 3'd0;
                end
                default: state <= 3'd0;
            endcase
        end
    end
endmodule
