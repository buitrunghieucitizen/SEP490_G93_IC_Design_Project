// test_fault.S - Chuong trinh test loi illegal.
// Dich: python3 tb/tools/asm20.py tb/programs/test_fault.S tb/programs/test_fault.mem
// Ket qua dung: CPU dung o lenh illegal.
//   PC=4, halted=1, illegal_instr=1, x1=5, x2=0 (lenh sau khong chay).
    addi x1, x0, 5
    .word 0xFFFFFFFF
    addi x2, x0, 99
