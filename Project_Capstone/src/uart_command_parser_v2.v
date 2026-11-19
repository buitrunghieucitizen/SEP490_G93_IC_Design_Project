// Multi-command UART ASCII parser, SEP490_G93 v2. Verilog-2001.
// Accept: A+B, A-B, A*B, SUM N, FIB N (0..39), TEST20; terminate with CR or LF.
// Each numeric token has 1..4 decimal digits (0..9999). Upper/lowercase keywords.
// No arithmetic result is computed here. One pending request; busy entries ignored.
// command_id: 1 ADD, 2 SUB, 3 MUL, 4 SUM, 5 FIB, 6 TEST20.
// Diagnostic aliases also accept T<Enter> and TEST 20<Enter>.
module uart_command_parser_v2 (
    input wire clk,
    input wire reset_n,
    input wire [7:0] rx_data,
    input wire rx_valid,
    input wire busy,
    output reg [31:0] operand_a,
    output reg [31:0] operand_b,
    output reg [2:0] command_id,
    output reg command_strobe
);
    localparam [4:0] IDLE=0, NUMBER_A=1, NUMBER_B=2,
        SUM_U=3, SUM_M=4, FIB_I=5, FIB_B=6,
        UNARY_SEPARATOR=7, UNARY_NUMBER=8,
        TEST_E=9, TEST_S=10, TEST_T=11, TEST_2=12,
        TEST_0=13, TEST_END=14, TEST_SPACE=15;
    reg [4:0] state;
    reg [13:0] pending_a, pending_b;
    reg [2:0] digits_a, digits_b;
    reg [2:0] pending_operation;
    wire [7:0] chr = (rx_data >= "a" && rx_data <= "z") ? (rx_data - 8'd32) : rx_data;
    wire is_digit = (chr >= "0" && chr <= "9");
    wire [3:0] digit = chr[3:0];
    wire is_enter = (chr==8'h0d || chr==8'h0a);
    wire is_space = (chr==" " || chr==8'h09);

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state <= IDLE;
            pending_a <= 0; pending_b <= 0;
            digits_a <= 0; digits_b <= 0;
            pending_operation <= 0;
            operand_a <= 0; operand_b <= 0;
            command_id <= 0; command_strobe <= 0;
        end else begin
            command_strobe <= 1'b0;
            if (rx_valid) begin
                case (state)
                    IDLE: begin
                        pending_a <= 0; pending_b <= 0;
                        digits_a <= 0; digits_b <= 0;
                        pending_operation <= 0;
                        if (is_digit) begin
                            pending_a <= {10'd0,digit};
                            digits_a <= 3'd1;
                            state <= NUMBER_A;
                        end else if (chr=="S") state <= SUM_U;
                        else if (chr=="F") state <= FIB_I;
                        else if (chr=="T") state <= TEST_E;
                    end
                    NUMBER_A: begin
                        if (is_digit && digits_a < 4) begin
                            pending_a <= (pending_a << 3) + (pending_a << 1) + digit;
                            digits_a <= digits_a + 1'b1;
                        end else if (chr=="+" || chr=="-" || chr=="*") begin
                            pending_operation <= (chr=="+")?3'd1:(chr=="-")?3'd2:3'd3;
                            pending_b <= 0; digits_b <= 0;
                            state <= NUMBER_B;
                        end else state <= IDLE;
                    end
                    NUMBER_B: begin
                        if (is_digit && digits_b < 4) begin
                            pending_b <= (pending_b << 3) + (pending_b << 1) + digit;
                            digits_b <= digits_b + 1'b1;
                        end else begin
                            if (is_enter && digits_b != 0 && !busy) begin
                                operand_a <= {18'd0,pending_a};
                                operand_b <= {18'd0,pending_b};
                                command_id <= pending_operation;
                                command_strobe <= 1'b1;
                            end
                            state <= IDLE;
                        end
                    end
                    SUM_U: state <= (chr=="U") ? SUM_M : IDLE;
                    SUM_M: begin
                        if (chr=="M") begin
                            pending_operation <= 3'd4;
                            state <= UNARY_SEPARATOR;
                        end else state <= IDLE;
                    end
                    FIB_I: state <= (chr=="I") ? FIB_B : IDLE;
                    FIB_B: begin
                        if (chr=="B") begin
                            pending_operation <= 3'd5;
                            state <= UNARY_SEPARATOR;
                        end else state <= IDLE;
                    end
                    UNARY_SEPARATOR: begin
                        if (is_space) begin
                            pending_a <= 0; digits_a <= 0;
                            state <= UNARY_NUMBER;
                        end else state <= IDLE;
                    end
                    UNARY_NUMBER: begin
                        if (is_space && digits_a == 0) begin
                            state <= UNARY_NUMBER;
                        end else if (is_digit && digits_a < 4) begin
                            pending_a <= (pending_a << 3) + (pending_a << 1) + digit;
                            digits_a <= digits_a + 1'b1;
                        end else begin
                            if (is_enter && digits_a != 0 && !busy &&
                                (pending_operation != 3'd5 || pending_a <= 14'd39)) begin
                                operand_a <= {18'd0,pending_a};
                                operand_b <= 0;
                                command_id <= pending_operation;
                                command_strobe <= 1'b1;
                            end
                            state <= IDLE;
                        end
                    end
                    // Diagnostic alias T<Enter> requests the same CPU self-test.
                    // If T works on hardware but TEST20 does not, investigate
                    // lost or altered characters in the longer UART command.
                    TEST_E: begin
                        if (chr=="E") state <= TEST_S;
                        else begin
                            if (is_enter && !busy) begin
                                operand_a <= 0; operand_b <= 0;
                                command_id <= 3'd6;
                                command_strobe <= 1'b1;
                            end
                            state <= IDLE;
                        end
                    end
                    TEST_S: state <= (chr=="S") ? TEST_T : IDLE;
                    TEST_T: state <= (chr=="T") ? TEST_2 : IDLE;
                    TEST_2: begin
                        if (chr=="2") state <= TEST_0;
                        else if (is_space) state <= TEST_SPACE;
                        else state <= IDLE;
                    end
                    TEST_SPACE: begin
                        if (chr=="2") state <= TEST_0;
                        else if (is_space) state <= TEST_SPACE;
                        else state <= IDLE;
                    end
                    TEST_0: state <= (chr=="0") ? TEST_END : IDLE;
                    TEST_END: begin
                        if (is_enter) begin
                            if (!busy) begin
                                operand_a <= 0; operand_b <= 0;
                                command_id <= 3'd6;
                                command_strobe <= 1'b1;
                            end
                            state <= IDLE;
                        end else if (is_space) state <= TEST_END;
                        else state <= IDLE;
                    end
                    default: state <= IDLE;
                endcase
            end
        end
    end
endmodule
