# Demo Guide — tổng từ 1 đến 10

## Bài toán và kết quả mong đợi

Chương trình cộng `1+2+...+10`, lưu tổng vào x3, ghi RAM word 0 rồi nạp lại vào x4. Kết quả là 55 (`0x00000037`). Cuối chương trình `JAL x0,0` giữ CPU ở PC `0x20` để dễ quan sát.

Sau khi chạy:

- x1 = 11 (counter dừng sau increment cuối).
- x2 = 11 (exclusive loop limit).
- x3 = 55 (sum).
- DMEM word 0 = 55.
- x4 = 55 (LW đọc lại).
- `halted`, `illegal_instr`, `misaligned`, `access_fault` đều bằng 0.

## Program image

File: `tb/programs/demo_sum_1_to_10.mem`. Mỗi dòng là một instruction word 32-bit, hex, không có `0x`.

| Index | PC | Word | Assembly | Giải thích |
|---:|---:|---:|---|---|
| 0 | `0x00` | `00100093` | `ADDI x1,x0,1` | i=1 |
| 1 | `0x04` | `00B00113` | `ADDI x2,x0,11` | limit=11 |
| 2 | `0x08` | `00000193` | `ADDI x3,x0,0` | sum=0 |
| 3 | `0x0C` | `001181B3` | `ADD x3,x3,x1` | sum += i |
| 4 | `0x10` | `00108093` | `ADDI x1,x1,1` | i++ |
| 5 | `0x14` | `FE209CE3` | `BNE x1,x2,-8` | Nếu i khác 11, branch về `0x0C` |
| 6 | `0x18` | `00302023` | `SW x3,0(x0)` | Ghi sum vào DMEM byte address 0 |
| 7 | `0x1C` | `00002203` | `LW x4,0(x0)` | Load sum sang x4 |
| 8 | `0x20` | `0000006F` | `JAL x0,0` | Vòng lặp cuối tại PC `0x20` |

Chương trình chỉ dùng ADDI, ADD, BNE, SW, LW và JAL; tất cả thuộc bộ 20 lệnh CPU hỗ trợ.

## Chạy tự kiểm tra

Từ thư mục gốc project:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tb\run_regression.ps1
```

Testbench `tb/tb_demo_sum.v` chạy 60 cạnh clock sau reset rồi kiểm tra từng kết quả: x1, x2, x3, x4, DMEM[0], PC và fault flags. Kết quả simulation gần nhất: `tb_demo_sum: PASS: 1+2+...+10 = 55`.

## Quan sát trên FPGA

Chọn top `fpga_debug_wrapper` trong Gowin project sau khi part/board đã được xác nhận. `debug_select` chọn bus `debug_data`:

| `debug_select` | `debug_data` |
|---|---|
| `00` | PC hiện tại |
| `01` | Instruction hiện tại |
| `10` | ALU result |
| `11` | Writeback data |

Fault/status outputs có thể đưa tới LED hoặc logic analyzer nếu board có chân phù hợp. Không có pin mapping trong project vì chưa xác định board. Để xác nhận tổng, chọn `debug_select=11` khi LW x4 thực thi hoặc dùng debug interface phù hợp để đọc register/RAM; `debug_data` bus là 32-bit nên cần GPIO/analyzer/UART strategy đã chọn theo board. Chưa nạp FPGA và chưa có phép đo phần cứng trong lần audit này.
