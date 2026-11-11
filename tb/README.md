# Testbench — Nhánh Phuoc (Tester)

Thư mục này chỉ chứa test, không chứa RTL. RTL nằm ở `../src/`.
Testbench chỉ dùng để mô phỏng, không đem lên FPGA.

## Chạy nhanh

```bash
# Linux / WSL, từ thư mục Code/
bash tb/run_regression.sh

# Windows, từ thư mục Code/
powershell -NoProfile -ExecutionPolicy Bypass -File tb/run_regression.ps1
```

Chạy 1 testbench, ví dụ `tb_pc`:

```bash
iverilog -g2001 -Wall -s tb_pc -o out/tb_pc.vvp src/pc.v tb/tb_pc.v
vvp out/tb_pc.vvp
```

PASS thật khi: có dòng `...: PASS (...)`, không có dòng `FAIL`, không timeout.

## Các testbench

| File | Test cái gì | Loại |
| --- | --- | --- |
| `tb_alu.v` | ALU: 10 phép, số biên, shift | Unit |
| `tb_control_unit.v` | Giải mã: 20 lệnh đúng + lệnh sai | Unit |
| `tb_immediate_gen.v` | Immediate 5 dạng I/S/B/U/J | Unit |
| `tb_pc.v` | PC: reset, +4, nhảy, giữ nguyên | Unit |
| `tb_register_file.v` | 32 thanh ghi, x0, reset | Unit |
| `tb_memory.v` | IMEM + DMEM: đọc/ghi, sai căn chỉnh, ngoài vùng | Unit |
| `tb_datapath.v` | Datapath, lái control trực tiếp, không qua decode | Tích hợp |
| `tb_cpu.v` | Cả CPU, chương trình viết trong testbench | Hệ thống |
| `tb_test_all_20.v` | Cả CPU, chạy `programs/test_all_20.mem` (đủ 20 lệnh) | Hệ thống |
| `tb_test_fault.v` | Cả CPU, chạy `programs/test_fault.mem` (lệnh illegal) | Hệ thống |
| `tb_demo_sum.v` | Demo tổng 1..10 = 55 | Hệ thống |
| `tb_fpga_debug_wrapper.v` | Chọn tín hiệu debug PC/instr/ALU/writeback | Tích hợp |
| `tb_result_capture.v` | Chỉ capture đúng `TARGET_RD` | Unit |
| `tb_cpu_wb_probe.v` | Chỉ nhận LW x8 | Unit |

## Chương trình test

`programs/` chứa cặp `.S` (cho người đọc) và `.mem` (cho CPU nạp):

- `demo_sum_1_to_10.mem` — đã có từ trước.
- `test_all_20.S` / `.mem` — đủ 20 lệnh, kết quả đúng ghi ở đầu file `.S`.
- `test_fault.S` / `.mem` — lệnh illegal, CPU phải halt ở PC=4.

Dịch lại `.S` ra `.mem` bằng trình dịch mini (chỉ 20 lệnh):

```bash
python3 tb/tools/asm20.py tb/programs/test_all_20.S tb/programs/test_all_20.mem
```

## Thêm 1 test mới — checklist

1. Viết file `tb_<ten>.v`, theo mẫu `tb_pc.v`: đếm `errors`/`tests`,
   so bằng `!==`, lấy mẫu sau `@(posedge clk); #1;`,
   cuối in `tb_<ten>: PASS (... checks)` hoặc `FAIL (...)`, có watchdog timeout.
2. Thêm test đó vào `run_regression.sh` và `run_regression.ps1`
   (cùng tên top và cùng chuỗi PASS).
3. Chạy `bash tb/run_regression.sh`, PASS hết mới commit.
4. Ghi kết quả vào `docs/VERIFICATION_REPORT.md`.

Hướng dẫn đầy đủ cho Tester: xem `docs/TESTER_GUIDE.md`.
