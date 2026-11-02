// Step 6.3: Integrate RISC-V CPU with the proven ACG525 8-digit LED controller.
// Verilog-2001. Keep led7_test_top.v in the project, but set board_top as TOP.
// Uses the existing cpu_top, cpu_wb_probe and result_capture modules.
module board_top (
    input  wire clk,
    input  wire reset_n,
    output wire ds,
    output wire sh_cp,
    output wire st_cp
);
    wire illegal_instr, misaligned, access_fault, halted;
    wire [31:0] debug_pc, debug_instr, debug_alu_result, debug_wb_data;
    wire wb_valid;
    wire [4:0] wb_rd;
    wire [31:0] wb_data;
    wire [31:0] display_data;

    cpu_top u_cpu (
        .clk(clk), .rst(~reset_n),
        .illegal_instr(illegal_instr), .misaligned(misaligned),
        .access_fault(access_fault), .halted(halted),
        .debug_pc(debug_pc), .debug_instr(debug_instr),
        .debug_alu_result(debug_alu_result), .debug_wb_data(debug_wb_data)
    );

    cpu_wb_probe u_probe (
        .debug_instr(debug_instr), .debug_wb_data(debug_wb_data),
        .halted(halted), .illegal_instr(illegal_instr),
        .misaligned(misaligned), .access_fault(access_fault),
        .wb_valid(wb_valid), .wb_rd(wb_rd), .wb_data(wb_data)
    );

    result_capture #(.TARGET_RD(5'd8)) u_capture (
        .clk(clk), .reset_n(reset_n),
        .wb_valid(wb_valid), .wb_rd(wb_rd), .wb_data(wb_data),
        .display_data(display_data)
    );

    // This is the same 74HC595 scan scheme used by led7_test_top,
    // with the fixed test pattern replaced by display_data.
    led7_display u_display (
        .clk(clk), .reset_n(reset_n), .value(display_data),
        .ds(ds), .sh_cp(sh_cp), .st_cp(st_cp)
    );
endmodule

module led7_display (
    input  wire clk,
    input  wire reset_n,
    input  wire [31:0] value,
    output reg ds,
    output reg sh_cp,
    output reg st_cp
);
    reg [15:0] scan_count = 0;
    reg [2:0] digit_index = 0;
    reg [15:0] shift_register = 16'hffff;
    reg [4:0] bit_index = 0;
    reg [2:0] state = 0;
    reg [7:0] segment_pattern;
    reg [7:0] digit_select;
    reg [3:0] nibble;

    always @* begin
        case (digit_index)
            3'd0: nibble = value[3:0];
            3'd1: nibble = value[7:4];
            3'd2: nibble = value[11:8];
            3'd3: nibble = value[15:12];
            3'd4: nibble = value[19:16];
            3'd5: nibble = value[23:20];
            3'd6: nibble = value[27:24];
            default: nibble = value[31:28];
        endcase
        case (nibble)
            4'h0: segment_pattern = 8'hc0;
            4'h1: segment_pattern = 8'hf9;
            4'h2: segment_pattern = 8'ha4;
            4'h3: segment_pattern = 8'hb0;
            4'h4: segment_pattern = 8'h99;
            4'h5: segment_pattern = 8'h92;
            4'h6: segment_pattern = 8'h82;
            4'h7: segment_pattern = 8'hf8;
            4'h8: segment_pattern = 8'h80;
            4'h9: segment_pattern = 8'h90;
            4'ha: segment_pattern = 8'h88;
            4'hb: segment_pattern = 8'h83;
            4'hc: segment_pattern = 8'hc6;
            4'hd: segment_pattern = 8'ha1;
            4'he: segment_pattern = 8'h86;
            default: segment_pattern = 8'h8e;
        endcase
        digit_select = (8'b00000001 << digit_index);
    end

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            scan_count <= 0;
            digit_index <= 0;
            shift_register <= 16'hffff;
            bit_index <= 0;
            state <= 0;
            ds <= 0;
            sh_cp <= 0;
            st_cp <= 0;
        end else begin
            case (state)
                3'd0: begin
                    sh_cp <= 0;
                    st_cp <= 0;
                    if (scan_count == 16'd49999) begin
                        scan_count <= 0;
                        shift_register <= {segment_pattern, digit_select};
                        bit_index <= 0;
                        state <= 3'd1;
                    end else scan_count <= scan_count + 1'b1;
                end
                3'd1: begin
                    sh_cp <= 0;
                    ds <= shift_register[15];
                    state <= 3'd2;
                end
                3'd2: begin
                    sh_cp <= 1;
                    state <= 3'd3;
                end
                3'd3: begin
                    sh_cp <= 0;
                    shift_register <= {shift_register[14:0], 1'b0};
                    if (bit_index == 5'd15) state <= 3'd4;
                    else begin
                        bit_index <= bit_index + 1'b1;
                        state <= 3'd1;
                    end
                end
                3'd4: begin
                    st_cp <= 1;
                    state <= 3'd5;
                end
                3'd5: begin
                    st_cp <= 0;
                    digit_index <= digit_index + 1'b1;
                    state <= 3'd0;
                end
                default: state <= 3'd0;
            endcase
        end
    end
endmodule
