# SELFTEST20 – Bảng kiểm 20 lệnh trên CPU/MMIO (SEP490_G93)

| Test ID | Mnemonic | Dữ liệu và điều kiện kiểm tra | Giá trị đợi / điều kiện đợi | Mã lỗi nếu FAIL |
|---:|---|---|---|---:|
| 01 | ADD | 5 + 3 | 8 | -1 |
| 02 | SUB | 5 - 3 | 2 | -2 |
| 03 | AND | 5 & 3 | 1 | -3 |
| 04 | OR | 5 \| 3 | 7 | -4 |
| 05 | XOR | 5 ^ 3 | 6 | -5 |
| 06 | SLL | 5 << 3 | 40 | -6 |
| 07 | SRL | 0x80000000 >> 3 (logical) | 0x10000000 | -7 |
| 08 | SRA | 0x80000000 >> 3 (arithmetic) | 0xF0000000 | -8 |
| 09 | ADDI | 5 + (-2) | 3 | -9 |
| 10 | ANDI | 5 & 3 | 1 | -10 |
| 11 | ORI | 5 \| 8 | 13 | -11 |
| 12 | XORI | 5 ^ 3 | 6 | -12 |
| 13 | SW | STORE 8 tại RAM[0], đọc lại | 8 | -13 |
| 14 | LW | LOAD 2 từ RAM[1] | 2 | -14 |
| 15 | BEQ | Branch taken khi 5==5; not taken khi 5!=3 | đúng đường PC | -15 |
| 16 | BNE | Branch taken khi 5!=3; not taken khi 5==5 | đúng đường PC | -16 |
| 17 | JAL | Target hợp lệ và link = PC+4 | đúng đường PC và thanh ghi link | -17 |
| 18 | JALR | Target=(rs1+imm)&~1 và link=PC+4 | đúng target/link, xóa bit 0 | -18 |
| 19 | LUI | LUI 0x1 | 4096 | -19 |
| 20 | AUIPC | Hai AUIPC liên tiếp, địa chỉ kết quả cách nhau 4 | delta = 4 | -20 |

PASS: chương trình ghi 20 vào MMIO `0x1010` (sau khi 20 bài kiểm tra đều hoàn tất). FAIL: ghi -N. Bảng kiểm mẫu không thay thế exhaustive verification, branch fault injection, hay timing trên FPGA.
