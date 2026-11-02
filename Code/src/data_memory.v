// 32-bit word-addressed RAM with asynchronous read and synchronous write.
module data_memory #(
    parameter MEM_SIZE = 128
) (
    input  wire        clk,
    input  wire [31:0] addr,
    input  wire [31:0] wr_data,
    input  wire        mem_write,
    input  wire        mem_read,
    output wire [31:0] rd_data,
    output wire        addr_misaligned,
    output wire        addr_out_of_range
);
    reg [31:0] mem [0:MEM_SIZE-1];
    wire addr_valid;

    assign addr_misaligned = (addr[1:0] != 2'b00);
    assign addr_out_of_range = (addr >= (MEM_SIZE * 4));
    assign addr_valid = !addr_misaligned && !addr_out_of_range;

    always @(posedge clk) begin
        if (mem_write && addr_valid)
            mem[addr[31:2]] <= wr_data;
    end

    assign rd_data = (mem_read && addr_valid) ? mem[addr[31:2]] : 32'd0;
endmodule
