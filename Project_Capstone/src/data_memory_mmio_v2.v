// Data memory plus MMIO region for UART inputs and CPU result.
// Verilog-2001, async read, sync write. No change to CPU single-cycle CPI.
// 0x000..0x1FF : 128 x 32-bit local RAM
// 0x1000       : operand A read-only
// 0x1004       : operand B read-only
// 0x1008       : command ID read-only (1=ADD,2=SUB,3=MUL,4=SUM,5=FIB,6=TEST20)
// 0x100C       : command ready read-only
// 0x1010       : CPU result write-only, emits one-clock result_strobe.
module data_memory_mmio_v2 #(
    parameter MEM_SIZE = 128
)(
    input  wire        clk,
    input  wire        rst,
    input  wire [31:0] addr,
    input  wire [31:0] wr_data,
    input  wire        mem_write,
    input  wire        mem_read,
    input  wire [31:0] operand_a,
    input  wire [31:0] operand_b,
    input  wire [2:0]  command_id,
    input  wire        command_ready,
    output reg  [31:0] result_data,
    output reg         result_strobe,
    output wire [31:0] rd_data,
    output wire        addr_misaligned,
    output wire        addr_out_of_range
);
    reg [31:0] mem [0:MEM_SIZE-1];
    wire in_ram = (addr < (MEM_SIZE * 4));
    wire io_a = (addr == 32'h00001000);
    wire io_b = (addr == 32'h00001004);
    wire io_op = (addr == 32'h00001008);
    wire io_ready = (addr == 32'h0000100C);
    wire io_result = (addr == 32'h00001010);
    wire io_valid = io_a || io_b || io_op || io_ready || io_result;
    wire addr_valid = !addr_misaligned && !addr_out_of_range;
    reg [31:0] io_read_data;

    assign addr_misaligned = (addr[1:0] != 2'b00);
    assign addr_out_of_range = !in_ram && !io_valid;

    always @* begin
        io_read_data = 32'd0;
        if (io_a)           io_read_data = operand_a;
        else if (io_b)      io_read_data = operand_b;
        else if (io_op)     io_read_data = {29'd0, command_id};
        else if (io_ready)  io_read_data = {31'd0, command_ready};
    end

    assign rd_data = (mem_read && addr_valid) ?
                     (in_ram ? mem[addr[31:2]] : io_read_data) : 32'd0;

    always @(posedge clk) begin
        if (mem_write && addr_valid && in_ram)
            mem[addr[31:2]] <= wr_data;
    end

    always @(posedge clk) begin
        if (rst) begin
            result_data <= 32'd0;
            result_strobe <= 1'b0;
        end else begin
            result_strobe <= 1'b0;
            if (mem_write && addr_valid && io_result) begin
                result_data <= wr_data;
                result_strobe <= 1'b1;
            end
        end
    end
endmodule
