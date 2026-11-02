// 32-bit asynchronous instruction ROM. MEM_FILE is relative to simulator cwd.
module instruction_memory #(
    parameter MEM_DEPTH = 256,
    parameter MEM_FILE = "src/program.mem"
) (
    input  wire [31:0] addr,
    output wire [31:0] instr,
    output wire        addr_misaligned,
    output wire        addr_out_of_range
);
    reg [31:0] rom [0:MEM_DEPTH-1];
    wire addr_valid;

    initial $readmemh(MEM_FILE, rom);

    assign addr_misaligned = (addr[1:0] != 2'b00);
    assign addr_out_of_range = (addr >= (MEM_DEPTH * 4));
    assign addr_valid = !addr_misaligned && !addr_out_of_range;
    assign instr = addr_valid ? rom[addr[31:2]] : 32'd0;
endmodule
