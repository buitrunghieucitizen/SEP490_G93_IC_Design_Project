// Step 6: signed 32-bit CPU result to eight decimal 7-segment digits.
// Verilog-2001, synthesis-friendly sequential Double Dabble (32 clocks).
//
// Each output nibble is 0..9, except:
//   nibble 7 = 4'hA means minus sign ('-')
//   all 4'hE means display overflow/error ('EEEEEEEE')
//
// Display ranges:
//     0 ..  99,999,999  -> 8 decimal digits
//    -1 ..  -9,999,999  -> minus and 7 decimal digits
// Everything else shows EEEEEEEE; never truncate a CPU result.
// Source operands in current UART parser are limited to 0..9999, so
// all valid current ADD/SUB results are comfortably in range.
module signed_result_to_bcd8 (
    input  wire        clk,
    input  wire        reset_n,
    input  wire        result_strobe,
    input  wire [31:0] result_binary,
    output reg  [31:0] display_bcd,
    output reg         display_valid // one-clock pulse after BCD settles
);
    reg [31:0] shift_binary;
    reg [31:0] work_bcd;
    reg [5:0]  bit_count;
    reg        negative;
    reg        converting;

    reg [31:0] next_bcd;
    integer k;

    // Add-3 then shift one binary bit into the least-significant BCD bit.
    always @* begin
        next_bcd = work_bcd;
        for (k = 0; k < 8; k = k + 1) begin
            if (next_bcd[k*4 +: 4] >= 4'd5)
                next_bcd[k*4 +: 4] = next_bcd[k*4 +: 4] + 4'd3;
        end
        next_bcd = {next_bcd[30:0], shift_binary[31]};
    end

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            shift_binary <= 32'd0;
            work_bcd     <= 32'd0;
            bit_count    <= 6'd0;
            negative     <= 1'b0;
            converting   <= 1'b0;
            display_bcd  <= 32'd0;
            display_valid <= 1'b0;
        end else begin
            display_valid <= 1'b0;
            if (result_strobe) begin
            // New result takes priority and restarts any ongoing conversion.
            if (($signed(result_binary) > 32'sd99999999) ||
                ($signed(result_binary) < -32'sd9999999)) begin
                converting  <= 1'b0;
                display_bcd <= 32'hEEEEEEEE;
                display_valid <= 1'b1;
            end else begin
                shift_binary <= result_binary[31] ?
                                (~result_binary + 32'd1) : result_binary;
                work_bcd     <= 32'd0;
                bit_count    <= 6'd0;
                negative     <= result_binary[31];
                converting   <= 1'b1;
            end
            end else if (converting) begin
            work_bcd     <= next_bcd;
            shift_binary <= {shift_binary[30:0], 1'b0};
            if (bit_count == 6'd31) begin
                display_bcd <= negative ? {4'hA, next_bcd[27:0]} : next_bcd;
                converting  <= 1'b0;
                display_valid <= 1'b1;
            end else begin
                bit_count <= bit_count + 6'd1;
            end
            end
        end
    end
endmodule
