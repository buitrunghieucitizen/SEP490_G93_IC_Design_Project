// Convert an unsigned 32-bit binary value to 8 decimal BCD digits.
// Range: 0..99,999,999. Values above range show the lowest 8 digits.
// Combinational double-dabble (shift-add-3), Verilog-2001.
module binary_to_bcd (
    input  wire [31:0] binary,
    output reg  [31:0] bcd
);
    integer i;
    integer j;
    reg [31:0] work;
    always @* begin
        work = 32'd0;
        for (i = 31; i >= 0; i = i - 1) begin
            for (j = 0; j < 8; j = j + 1) begin
                if (work[j*4 +: 4] >= 4'd5)
                    work[j*4 +: 4] = work[j*4 +: 4] + 4'd3;
            end
            work = {work[30:0], binary[i]};
        end
        bcd = work;
    end
endmodule
