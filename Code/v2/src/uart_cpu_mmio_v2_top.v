// v2 single-bitstream multi-program top. Original v1 top is unchanged.
// ACG525 step 4 - power-on reset + RISC-V CPU result to 7-segment LED.
// S0 is connected to reset_n in the existing board pin constraints.
// 50 MHz input clock; hold the whole system in reset for 10 ms after
// configuration and after S0 is released.
//
// Set DEBUG_MODE = 1 for diagnosis:
//   1111: decoder currently reports invalid instruction
//   2222: sticky illegal instruction fault
//   3333: halted due to a different fault
//   4444: CPU running/no indicated fault
// DEBUG_MODE = 0 (default): show the CPU MMIO result.
module uart_cpu_mmio_v2_top #(
    parameter DEBUG_MODE = 0,
    parameter MEM_FILE = "src/program_multi_mmio.mem",
    parameter integer POR_CYCLES = 500000,
    parameter integer UART_CLK_HZ = 50000000,
    parameter integer UART_BAUD = 115200
) (
    input wire clk,
    input wire reset_n,
    input wire uart_rx,
    output wire uart_tx,
    output wire ds,
    output wire sh_cp,
    output wire st_cp
);
    // Gowin FPGA initializes these registers from the configuration bitstream.
    // After release of external S0, restart the power-on-reset delay.
    reg [19:0] por_count = 20'd0;
    reg por_done = 1'b0;
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            por_count <= 20'd0;
            por_done <= 1'b0;
        end else if (!por_done) begin
            if (por_count == POR_CYCLES - 1)
                por_done <= 1'b1;
            else
                por_count <= por_count + 1'b1;
        end
    end
    wire system_reset_n = reset_n && por_done;

    wire [7:0] rx_data;
    wire rx_valid;
    wire [31:0] operand_a, operand_b;
    wire command_strobe, command_ready;
    wire [2:0] command_id;
    wire [31:0] cpu_result;
    wire result_strobe;
    wire illegal_instr, misaligned, access_fault, halted;
    wire [31:0] debug_pc, debug_instr;
    wire decode_illegal_debug;

    uart_rx #(.CLK_HZ(UART_CLK_HZ), .BAUD(UART_BAUD)) u_rx (
        .clk(clk), .reset_n(system_reset_n), .rx(uart_rx),
        .data(rx_data), .data_valid(rx_valid)
    );
    uart_command_parser_v2 u_parser (
        .clk(clk), .reset_n(system_reset_n),
        .rx_data(rx_data), .rx_valid(rx_valid),
        .operand_a(operand_a), .operand_b(operand_b),
        .command_id(command_id), .command_strobe(command_strobe),
        .busy(command_ready)
    );
    uart_command_ready u_mailbox (
        .clk(clk), .reset_n(system_reset_n),
        .command_strobe(command_strobe), .result_strobe(result_strobe),
        .ready(command_ready)
    );
    cpu_mmio_v2_top #(.MEM_FILE(MEM_FILE)) u_cpu (
        .clk(clk), .rst(~system_reset_n),
        .operand_a(operand_a), .operand_b(operand_b),
        .command_id(command_id), .command_ready(command_ready),
        .result_data(cpu_result), .result_strobe(result_strobe),
        .illegal_instr(illegal_instr), .misaligned(misaligned),
        .access_fault(access_fault), .halted(halted),
        .debug_pc(debug_pc), .debug_instr(debug_instr),
        .decode_illegal_debug(decode_illegal_debug)
    );

    // Step 6: preserve proven UART, CPU, MMIO, power-on reset.
    // A result_strobe starts conversion; display changes after 32 clocks.
    wire [31:0] signed_bcd_digits;
    wire signed_bcd_valid;
    wire unused_echo_overflow;
    signed_result_to_bcd8 u_signed_bcd (
        .clk(clk), .reset_n(system_reset_n),
        .result_strobe(result_strobe), .result_binary(cpu_result),
        .display_bcd(signed_bcd_digits),
        .display_valid(signed_bcd_valid)
    );

    // Echo UART input, and return the SAME CPU MMIO result as the LED.
    // Do not calculate anything in the UART response formatter.
    uart_result_tx #(.CLK_HZ(UART_CLK_HZ), .BAUD(UART_BAUD)) u_result_tx (
        .clk(clk), .reset_n(system_reset_n),
        .rx_data(rx_data), .rx_valid(rx_valid),
        .result_bcd(signed_bcd_digits), .bcd_valid(signed_bcd_valid),
        .uart_tx(uart_tx), .echo_overflow(unused_echo_overflow)
    );

    // Preserve DEBUG_MODE interface from the Step 4 AutoReset top.
    wire [31:0] displayed_digits = DEBUG_MODE ?
        (decode_illegal_debug ? 32'h00001111 :
         illegal_instr        ? 32'h00002222 :
         halted               ? 32'h00003333 :
                                32'h00004444) : signed_bcd_digits;

    // Special BCD nibble A = '-', E = overflow error.
    led7_scan_signed_595 u_led (
        .clk(clk), .reset_n(system_reset_n),
        .bcd_value(displayed_digits),
        .ds(ds), .sh_cp(sh_cp), .st_cp(st_cp)
    );
endmodule
