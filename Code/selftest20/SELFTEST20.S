# SEP490_G93 SELFTEST20 -- self-checking ROM for the actual CPU/MMIO path.
# 20 supported RV32I-subset instructions. No special CPU/RTL modifications.
# Output: 20 -> all checks passed; -N -> failure at check N (1..20).
# MMIO RESULT at 0x1010; program repeats only the terminal JAL after reporting.
# Do not type anything in Tera Term: this program runs automatically on reset.
# Build: python tb/tools/asm20.py selftest20/SELFTEST20.S selftest20/SELFTEST20.mem

start:
    lui  x28, 0x1              # MMIO base = 0x1000
    addi x1, x0, 5
    addi x2, x0, 3

    # 01 ADD: 5+3=8
    addi x27, x0, -1
    add  x3, x1, x2
    addi x4, x0, 8
    bne  x3, x4, fail

    # 02 SUB: 5-3=2
    addi x27, x0, -2
    sub  x3, x1, x2
    addi x4, x0, 2
    bne  x3, x4, fail

    # 03 AND: 5 & 3 = 1
    addi x27, x0, -3
    and  x3, x1, x2
    addi x4, x0, 1
    bne  x3, x4, fail

    # 04 OR: 5 | 3 = 7
    addi x27, x0, -4
    or   x3, x1, x2
    addi x4, x0, 7
    bne  x3, x4, fail

    # 05 XOR: 5 ^ 3 = 6
    addi x27, x0, -5
    xor  x3, x1, x2
    addi x4, x0, 6
    bne  x3, x4, fail

    # 06 SLL: 5 << 3 = 40
    addi x27, x0, -6
    sll  x3, x1, x2
    addi x4, x0, 40
    bne  x3, x4, fail

    # 07 SRL: 0x80000000 >> 3 = 0x10000000 (logical)
    addi x27, x0, -7
    lui  x8, 0x80000
    srl  x3, x8, x2
    lui  x4, 0x10000
    bne  x3, x4, fail

    # 08 SRA: 0x80000000 >>> 3 = 0xF0000000 (arithmetic)
    addi x27, x0, -8
    sra  x3, x8, x2
    lui  x4, 0xF0000
    bne  x3, x4, fail

    # 09 ADDI: 5 + (-2) = 3
    addi x27, x0, -9
    addi x3, x1, -2
    addi x4, x0, 3
    bne  x3, x4, fail

    # 10 ANDI: 5 & 3 = 1
    addi x27, x0, -10
    andi x3, x1, 3
    addi x4, x0, 1
    bne  x3, x4, fail

    # 11 ORI: 5 | 8 = 13
    addi x27, x0, -11
    ori  x3, x1, 8
    addi x4, x0, 13
    bne  x3, x4, fail

    # 12 XORI: 5 ^ 3 = 6
    addi x27, x0, -12
    xori x3, x1, 3
    addi x4, x0, 6
    bne  x3, x4, fail

    # 13 SW: store a calculated 8 to RAM[0], confirm via LW
    addi x27, x0, -13
    add  x3, x1, x2
    sw   x3, 0(x0)
    lw   x6, 0(x0)
    addi x4, x0, 8
    bne  x6, x4, fail

    # 14 LW: store 2 to RAM[1], read it back to new register
    addi x27, x0, -14
    sub  x3, x1, x2
    sw   x3, 4(x0)
    lw   x7, 4(x0)
    addi x4, x0, 2
    bne  x7, x4, fail

    # 15 BEQ: must take equal branch and must NOT take unequal branch
    addi x27, x0, -15
    beq  x1, x1, beq_taken
    jal  x0, fail
beq_taken:
    beq  x1, x2, fail

    # 16 BNE: must take unequal branch and must NOT take equal branch
    addi x27, x0, -16
    bne  x1, x2, bne_taken
    jal  x0, fail
bne_taken:
    bne  x1, x1, fail

    # 17 JAL: jump to target and store the correct return PC
    addi x27, x0, -17
    auipc x10, 0               # x10 = PC of this AUIPC
    jal   x31, jal_target      # x31 = x10 + 8
    jal   x0, fail             # only reached if JAL target is wrong
jal_target:
    addi  x4, x10, 8
    bne   x31, x4, fail

    # 18 JALR: target uses rs1+imm with bit0 cleared; check link
    addi x27, x0, -18
    auipc x10, 0               # PC = P
    addi  x10, x10, 17         # target = P+17 (unaligned bit0)
    jalr  x31, 0(x10)          # jumps to P+16; link = P+12
    jal   x0, fail
jalr_target:
    addi  x4, x10, -5          # P+12
    bne   x31, x4, fail

    # 19 LUI: produce 0x00001000; independent expected via 1 << 12
    addi x27, x0, -19
    lui  x3, 0x1
    addi x4, x0, 1
    addi x12, x0, 12
    sll  x4, x4, x12
    bne  x3, x4, fail

    # 20 AUIPC: two consecutive AUIPC outputs must differ by 4
    addi x27, x0, -20
    auipc x10, 0
    auipc x11, 0
    addi x4, x10, 4
    bne  x11, x4, fail

pass:
    addi x26, x0, 20
    sw   x26, 16(x28)           # Result = 20 -> PASS
pass_loop:
    jal  x0, pass_loop

fail:
    sw   x27, 16(x28)           # Result = -N -> FAIL at test N
fail_loop:
    jal  x0, fail_loop
