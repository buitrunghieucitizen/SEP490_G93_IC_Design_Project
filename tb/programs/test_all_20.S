// test_all_20.S - Chuong trinh test du 20 lenh cua CPU.
// Dich: python3 tb/tools/asm20.py tb/programs/test_all_20.S tb/programs/test_all_20.mem
// Chay: dung tb_test_all_20.v (kiem tra tu dong), hoac
//       vvp out/tb_cpu.vvp +PROGRAM=tb/programs/test_all_20.mem
//
// Ket qua dung sau khi chay xong (truoc khi vao vong lap cuoi):
//   x1=5, x2=3, x3=8, x4=2, x5=1, x6=7, x7=6, x8=40
//   x9=0x10000000, x10=0x80000000, x11=0xF0000000
//   x12=3, x13=0x80000000, x14=0xFFFFFFFF, x15=0x7FFFFFFF
//   x16=8, x17=2, x18=11, x19=100, x20=0x80000000
//   x21=108 (PC tai lenh AUIPC), x23=116, x24=55
//   DMEM[0]=8, DMEM[1]=2, PC cuoi=124, khong co co loi.
    addi x1, x0, 5
    addi x2, x0, 3
    add  x3, x1, x2
    sub  x4, x1, x2
    and  x5, x1, x2
    or   x6, x1, x2
    xor  x7, x1, x2
    sll  x8, x1, x2
    lui  x10, 0x80000
    srl  x9, x10, x2
    sra  x11, x10, x2
    addi x12, x1, -2
    andi x13, x10, -1
    ori  x14, x0, -1
    xori x15, x10, -1
    sw   x3, 0(x0)
    sw   x4, 4(x0)
    lw   x16, 0(x0)
    lw   x17, 4(x0)
    beq  x1, x1, ok_beq
    addi x18, x0, 99
ok_beq:
    bne  x1, x2, ok_bne
    addi x18, x0, 99
ok_bne:
    addi x18, x0, 11
    jal  x19, ok_jal
    addi x20, x0, 99
ok_jal:
    lui  x20, 0x80000
    auipc x21, 0
    jalr x23, done(x0)
    addi x24, x0, 99
done:
    addi x24, x0, 55
end:
    jal  x0, end
