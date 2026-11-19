# SEP490 G93 -- one ROM, multiple RISC-V assembly algorithms.
# Commands (via 0x1008): 1 ADD, 2 SUB, 3 MUL, 4 SUM, 5 FIB, 6 TEST20.
# Input operands via MMIO 0x1000 and 0x1004, ready 0x100C;
# Output SW to 0x1010. Only CPU assembly calculates values.
# x28 = MMIO base; x26 = output; x29 = SELFTEST20 link register.
entry:
    lui  x28, 0x1
poll:
    lw   x5, 12(x28)
    beq  x5, x0, poll
    lw   x6, 8(x28)         # command id
    lw   x7, 0(x28)         # input A or N
    lw   x8, 4(x28)         # input B
    addi x9, x0, 1
    beq  x6, x9, do_add
    addi x9, x0, 2
    beq  x6, x9, do_sub
    addi x9, x0, 3
    beq  x6, x9, do_mul
    addi x9, x0, 4
    beq  x6, x9, do_sum
    addi x9, x0, 5
    beq  x6, x9, do_fib
    addi x9, x0, 6
    beq  x6, x9, do_test20
    addi x26, x0, -99      # unexpected command id
    jal  x0, publish

do_add:
    add  x26, x7, x8
    jal  x0, publish
do_sub:
    sub  x26, x7, x8
    jal  x0, publish

# Multiplication by shift/add in ISA: no hardware MUL instruction.
do_mul:
    addi x26, x0, 0
    add  x10, x7, x0       # multiplicand
    add  x11, x8, x0       # multiplier
    addi x9, x0, 1
mul_loop:
    beq  x11, x0, publish
    andi x12, x11, 1
    beq  x12, x0, mul_skip
    add  x26, x26, x10
mul_skip:
    sll  x10, x10, x9
    srl  x11, x11, x9
    jal  x0, mul_loop

# SUM N = 1+2+...+N (N in 0..9999).
do_sum:
    addi x26, x0, 0
    add  x10, x7, x0
sum_loop:
    beq  x10, x0, publish
    add  x26, x26, x10
    addi x10, x10, -1
    jal  x0, sum_loop

# F(0)=0, F(1)=1. Parser accepts N<=39 for LED numeric range.
do_fib:
    addi x10, x0, 0
    addi x11, x0, 1
fib_loop:
    beq  x7, x0, fib_done
    add  x12, x10, x11
    add  x10, x11, x0
    add  x11, x12, x0
    addi x7, x7, -1
    jal  x0, fib_loop
fib_done:
    add  x26, x10, x0
    jal  x0, publish

# SELFTEST20 is a real RISC-V procedure from the proven SELFTEST20 ROM.
# It writes x26=20 on success, or -N on failing instruction N.
do_test20:
    jal  x29, test20
    jal  x0, publish
publish:
    sw   x26, 16(x28)
    jal  x0, poll

test20:
    lui  x28, 0x1              # MMIO base = 0x1000
    addi x1, x0, 5
    addi x2, x0, 3

    # 01 ADD: 5+3=8
    addi x27, x0, -1
    add  x3, x1, x2
    addi x4, x0, 8
    bne  x3, x4, t20_fail

    # 02 SUB: 5-3=2
    addi x27, x0, -2
    sub  x3, x1, x2
    addi x4, x0, 2
    bne  x3, x4, t20_fail

    # 03 AND: 5 & 3 = 1
    addi x27, x0, -3
    and  x3, x1, x2
    addi x4, x0, 1
    bne  x3, x4, t20_fail

    # 04 OR: 5 | 3 = 7
    addi x27, x0, -4
    or   x3, x1, x2
    addi x4, x0, 7
    bne  x3, x4, t20_fail

    # 05 XOR: 5 ^ 3 = 6
    addi x27, x0, -5
    xor  x3, x1, x2
    addi x4, x0, 6
    bne  x3, x4, t20_fail

    # 06 SLL: 5 << 3 = 40
    addi x27, x0, -6
    sll  x3, x1, x2
    addi x4, x0, 40
    bne  x3, x4, t20_fail

    # 07 SRL: 0x80000000 >> 3 = 0x10000000 (logical)
    addi x27, x0, -7
    lui  x8, 0x80000
    srl  x3, x8, x2
    lui  x4, 0x10000
    bne  x3, x4, t20_fail

    # 08 SRA: 0x80000000 >>> 3 = 0xF0000000 (arithmetic)
    addi x27, x0, -8
    sra  x3, x8, x2
    lui  x4, 0xF0000
    bne  x3, x4, t20_fail

    # 09 ADDI: 5 + (-2) = 3
    addi x27, x0, -9
    addi x3, x1, -2
    addi x4, x0, 3
    bne  x3, x4, t20_fail

    # 10 ANDI: 5 & 3 = 1
    addi x27, x0, -10
    andi x3, x1, 3
    addi x4, x0, 1
    bne  x3, x4, t20_fail

    # 11 ORI: 5 | 8 = 13
    addi x27, x0, -11
    ori  x3, x1, 8
    addi x4, x0, 13
    bne  x3, x4, t20_fail

    # 12 XORI: 5 ^ 3 = 6
    addi x27, x0, -12
    xori x3, x1, 3
    addi x4, x0, 6
    bne  x3, x4, t20_fail

    # 13 SW: store a calculated 8 to RAM[0], confirm via LW
    addi x27, x0, -13
    add  x3, x1, x2
    sw   x3, 0(x0)
    lw   x6, 0(x0)
    addi x4, x0, 8
    bne  x6, x4, t20_fail

    # 14 LW: store 2 to RAM[1], read it back to new register
    addi x27, x0, -14
    sub  x3, x1, x2
    sw   x3, 4(x0)
    lw   x7, 4(x0)
    addi x4, x0, 2
    bne  x7, x4, t20_fail

    # 15 BEQ: must take equal branch and must NOT take unequal branch
    addi x27, x0, -15
    beq  x1, x1, beq_taken
    jal  x0, t20_fail
beq_taken:
    beq  x1, x2, t20_fail

    # 16 BNE: must take unequal branch and must NOT take equal branch
    addi x27, x0, -16
    bne  x1, x2, bne_taken
    jal  x0, t20_fail
bne_taken:
    bne  x1, x1, t20_fail

    # 17 JAL: jump to target and store the correct return PC
    addi x27, x0, -17
    auipc x10, 0               # x10 = PC of this AUIPC
    jal   x31, jal_target      # x31 = x10 + 8
    jal   x0, t20_fail             # only reached if JAL target is wrong
jal_target:
    addi  x4, x10, 8
    bne   x31, x4, t20_fail

    # 18 JALR: target uses rs1+imm with bit0 cleared; check link
    addi x27, x0, -18
    auipc x10, 0               # PC = P
    addi  x10, x10, 17         # target = P+17 (unaligned bit0)
    jalr  x31, 0(x10)          # jumps to P+16; link = P+12
    jal   x0, t20_fail
jalr_target:
    addi  x4, x10, -5          # P+12
    bne   x31, x4, t20_fail

    # 19 LUI: produce 0x00001000; independent expected via 1 << 12
    addi x27, x0, -19
    lui  x3, 0x1
    addi x4, x0, 1
    addi x12, x0, 12
    sll  x4, x4, x12
    bne  x3, x4, t20_fail

    # 20 AUIPC: two consecutive AUIPC outputs must differ by 4
    addi x27, x0, -20
    auipc x10, 0
    auipc x11, 0
    addi x4, x10, 4
    bne  x11, x4, t20_fail


t20_pass:
    addi x26, x0, 20
    jalr x0, 0(x29)
t20_fail:
    add  x26, x27, x0
    jalr x0, 0(x29)
