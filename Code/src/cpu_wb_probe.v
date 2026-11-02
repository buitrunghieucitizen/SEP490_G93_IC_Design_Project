// cpu_wb_probe.v - Bridge from existing cpu_top debug ports to result_capture.
// Demo scope: recognize only LW x8, 0(x0) from the current program.mem.
// This is NOT a general architectural retirement/writeback-valid signal.
module cpu_wb_probe (
    input  wire [31:0] debug_instr,
    input  wire [31:0] debug_wb_data,
    input  wire        halted,
    input  wire        illegal_instr,
    input  wire        misaligned,
    input  wire        access_fault,
    output wire        wb_valid,
    output wire [4:0]  wb_rd,
    output wire [31:0] wb_data
);
    wire is_lw;
    assign is_lw = (debug_instr[6:0] == 7'b0000011) &&
                   (debug_instr[14:12] == 3'b010);
    assign wb_rd = debug_instr[11:7];
    assign wb_data = debug_wb_data;
    assign wb_valid = is_lw && (wb_rd == 5'd8) &&
                      !halted && !illegal_instr &&
                      !misaligned && !access_fault;
endmodule
