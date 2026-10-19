// Verilog-2001 ALU. The first eight operations are used by the CPU subset;
// SLT/SLTU remain available as reusable ALU extensions but are not decoded.

module alu (
    input  wire [31:0] a,          // Operand A (tu rs1)
    input  wire [31:0] b,          // Operand B (tu rs2 hoac immediate)
    input  wire [ 3:0] alu_ctrl,   // Chon phep tinh
    output reg  [31:0] result,     // Ket qua
    output wire        zero        // Zero flag: result == 0
);

    // -------------------------------------------------------------------------
    // ALU Control Encoding (khop voi control_unit.v)
    // -------------------------------------------------------------------------
    localparam ALU_ADD  = 4'b0000;
    localparam ALU_SUB  = 4'b0001;
    localparam ALU_AND  = 4'b0010;
    localparam ALU_OR   = 4'b0011;
    localparam ALU_XOR  = 4'b0100;
    localparam ALU_SLL  = 4'b0101;
    localparam ALU_SRL  = 4'b0110;
    localparam ALU_SRA  = 4'b0111;
    localparam ALU_SLT  = 4'b1000;
    localparam ALU_SLTU = 4'b1001;

    // -------------------------------------------------------------------------
    // Intermediate signals (ro rang tung phep, de doc waveform)
    // Tat ca duoc tinh song song - FPGA thuc hien dong thoi, roi MUX chon
    // -------------------------------------------------------------------------
    wire [31:0] add_result;
    wire [31:0] sub_result;
    wire [31:0] and_result;
    wire [31:0] or_result;
    wire [31:0] xor_result;
    wire [31:0] sll_result;
    wire [31:0] srl_result;
    wire [31:0] sra_result;
    wire [31:0] slt_result;
    wire [31:0] sltu_result;

    assign add_result  = a + b;
    assign sub_result  = a - b;
    assign and_result  = a & b;
    assign or_result   = a | b;
    assign xor_result  = a ^ b;
    assign sll_result  = a << b[4:0];                        // Barrel shifter trai
    assign srl_result  = a >> b[4:0];                        // Barrel shifter phai (logic)
    assign sra_result  = $signed(a) >>> b[4:0];              // Barrel shifter phai (arithmetic)
    assign slt_result  = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;  // Signed comparator
    assign sltu_result = (a < b)                  ? 32'd1 : 32'd0;   // Unsigned comparator

    // -------------------------------------------------------------------------
    // Output mux selects the result associated with alu_ctrl.
    // -------------------------------------------------------------------------
    always @(*) begin
        case (alu_ctrl)
            ALU_ADD  : result = add_result;
            ALU_SUB  : result = sub_result;
            ALU_AND  : result = and_result;
            ALU_OR   : result = or_result;
            ALU_XOR  : result = xor_result;
            ALU_SLL  : result = sll_result;
            ALU_SRL  : result = srl_result;
            ALU_SRA  : result = sra_result;
            ALU_SLT  : result = slt_result;
            ALU_SLTU : result = sltu_result;
            default  : result = 32'd0;
        endcase
    end

    // Zero flag - 32-input NOR gate tren FPGA
    assign zero = (result == 32'd0);

endmodule
