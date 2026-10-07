// Verilog-2001 control decoder for the supported 20-instruction subset.
module control_unit (
    input  wire [6:0] opcode,
    input  wire [2:0] funct3,
    input  wire [6:0] funct7,
    output reg        reg_write,
    output reg        alu_src,
    output reg        mem_write,
    output reg        mem_read,
    output reg        mem_to_reg,
    output reg        branch,
    output reg        jump,
    output reg        jalr,
    output reg        lui,
    output reg        auipc,
    output reg  [3:0] alu_ctrl,
    output reg        illegal_instr
);
    localparam OP_R       = 7'b0110011;
    localparam OP_I_ARITH = 7'b0010011;
    localparam OP_LOAD    = 7'b0000011;
    localparam OP_STORE   = 7'b0100011;
    localparam OP_BRANCH  = 7'b1100011;
    localparam OP_JAL     = 7'b1101111;
    localparam OP_JALR    = 7'b1100111;
    localparam OP_LUI     = 7'b0110111;
    localparam OP_AUIPC   = 7'b0010111;

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

    always @(*) begin
        reg_write = 1'b0;
        alu_src = 1'b0;
        mem_write = 1'b0;
        mem_read = 1'b0;
        mem_to_reg = 1'b0;
        branch = 1'b0;
        jump = 1'b0;
        jalr = 1'b0;
        lui = 1'b0;
        auipc = 1'b0;
        alu_ctrl = ALU_ADD;
        illegal_instr = 1'b0;

        case (opcode)
            OP_R: begin
                case ({funct7, funct3})
                    {7'b0000000,3'b000}: begin reg_write=1'b1; alu_ctrl=ALU_ADD; end
                    {7'b0100000,3'b000}: begin reg_write=1'b1; alu_ctrl=ALU_SUB; end
                    {7'b0000000,3'b001}: begin reg_write=1'b1; alu_ctrl=ALU_SLL; end
                    {7'b0000000,3'b100}: begin reg_write=1'b1; alu_ctrl=ALU_XOR; end
                    {7'b0000000,3'b101}: begin reg_write=1'b1; alu_ctrl=ALU_SRL; end
                    {7'b0100000,3'b101}: begin reg_write=1'b1; alu_ctrl=ALU_SRA; end
                    {7'b0000000,3'b110}: begin reg_write=1'b1; alu_ctrl=ALU_OR;  end
                    {7'b0000000,3'b111}: begin reg_write=1'b1; alu_ctrl=ALU_AND; end
                    default: illegal_instr=1'b1;
                endcase
            end
            OP_I_ARITH: begin
                alu_src = 1'b1;
                case (funct3)
                    3'b000: begin reg_write=1'b1; alu_ctrl=ALU_ADD; end
                    3'b100: begin reg_write=1'b1; alu_ctrl=ALU_XOR; end
                    3'b110: begin reg_write=1'b1; alu_ctrl=ALU_OR;  end
                    3'b111: begin reg_write=1'b1; alu_ctrl=ALU_AND; end
                    default: begin alu_src=1'b0; illegal_instr=1'b1; end
                endcase
            end
            OP_LOAD: begin
                if (funct3 == 3'b010) begin
                    reg_write=1'b1; alu_src=1'b1; mem_read=1'b1; mem_to_reg=1'b1;
                end else illegal_instr=1'b1;
            end
            OP_STORE: begin
                if (funct3 == 3'b010) begin alu_src=1'b1; mem_write=1'b1; end
                else illegal_instr=1'b1;
            end
            OP_BRANCH: begin
                if (funct3 == 3'b000 || funct3 == 3'b001) begin
                    branch=1'b1; alu_ctrl=ALU_SUB;
                end else illegal_instr=1'b1;
            end
            OP_JAL: begin reg_write=1'b1; jump=1'b1; end
            OP_JALR: begin
                if (funct3 == 3'b000) begin reg_write=1'b1; alu_src=1'b1; jump=1'b1; jalr=1'b1; end
                else illegal_instr=1'b1;
            end
            OP_LUI: begin reg_write=1'b1; lui=1'b1; end
            OP_AUIPC: begin reg_write=1'b1; auipc=1'b1; alu_src=1'b1; end
            default: illegal_instr=1'b1;
        endcase
    end
endmodule
