// Board-independent debug wrapper. Board pin mapping and clock/reset polarity
// must be supplied for the selected Gowin board.
module fpga_debug_wrapper #(
    parameter IMEM_DEPTH = 256,
    parameter DMEM_SIZE = 128,
    parameter MEM_FILE = "src/program.mem"
) (
    input  wire        clk,
    input  wire        rst,
    input  wire [1:0]  debug_select,
    output reg  [31:0] debug_data,
    output wire        halted,
    output wire        illegal_instr,
    output wire        misaligned,
    output wire        access_fault
);
    wire [31:0] debug_pc;
    wire [31:0] debug_instr;
    wire [31:0] debug_alu_result;
    wire [31:0] debug_wb_data;

    cpu_top #(
        .IMEM_DEPTH(IMEM_DEPTH),
        .DMEM_SIZE(DMEM_SIZE),
        .MEM_FILE(MEM_FILE)
    ) u_cpu (
        .clk(clk),
        .rst(rst),
        .illegal_instr(illegal_instr),
        .misaligned(misaligned),
        .access_fault(access_fault),
        .halted(halted),
        .debug_pc(debug_pc),
        .debug_instr(debug_instr),
        .debug_alu_result(debug_alu_result),
        .debug_wb_data(debug_wb_data)
    );

    always @(*) begin
        case (debug_select)
            2'b00: debug_data = debug_pc;
            2'b01: debug_data = debug_instr;
            2'b10: debug_data = debug_alu_result;
            2'b11: debug_data = debug_wb_data;
            default: debug_data = 32'd0;
        endcase
    end
endmodule
