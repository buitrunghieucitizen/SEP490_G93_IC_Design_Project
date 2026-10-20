# Báo cáo verification

**Ngày chạy:** 2026-10-19  
**Simulator:** Icarus Verilog (`iverilog`/`vvp`), `-g2001`  
**Regression command:** `powershell.exe -NoProfile -ExecutionPolicy Bypass -File tb/run_regression.ps1`

Regression script biên dịch từng top testbench riêng, chạy mô phỏng, yêu cầu thông báo PASS, dừng nếu compile/runtime thất bại hoặc có FAIL. Các assertion so sánh bằng case inequality (`!==`) để phát hiện cả X/Z. Testbench clocked lấy kết quả sau `@(posedge clk); #1` để tránh race với nonblocking assignments.

Các testbench unit, integration, demo và wrapper ghi waveform VCD vào `out/`: `waveform_alu.vcd`, `waveform_control_unit.vcd`, `waveform_immediate_gen.vcd`, `waveform_memory.vcd`, `waveform_cpu.vcd`, `waveform_demo_sum.vcd` và `waveform_fpga_debug_wrapper.vcd`. Chúng chứa các tín hiệu cần quan sát (clock/reset, inputs/outputs, PC/datapath và status tùy test), không dump toàn bộ mảng RAM. Ví dụ mở waveform CPU bằng `E:\down\iverilog\bin\gtkwave.exe .\out\waveform_cpu.vcd` từ thư mục gốc project.

## Kết quả thật từ lần chạy gần nhất

| Testbench | Kết quả |
|---|---|
| `tb_alu` | PASS — 29 PASS, 0 FAIL |
| `tb_control_unit` | PASS — 28 decode checks (20 encoding hợp lệ + 8 negative encodings) |
| `tb_immediate_gen` | PASS — 12 vectors I/S/B/U/J, positive/negative offsets |
| `tb_memory` | PASS — 12 checks IMEM/DMEM; DMEM word cuối ở byte 508 hợp lệ, byte 512 ngoài vùng bị từ chối |
| `tb_cpu` | PASS — 91 assertions; 20 instruction set và fault/reset/integration cases |
| `tb_demo_sum` | PASS — 6 checks; x3=x4=DMEM[0]=55 |
| `tb_fpga_debug_wrapper` | PASS — 4 mux selections + status |

Kết thúc runner: `ALL REGRESSION TESTS PASSED`. Không dùng kết quả giả hoặc sửa expected để ép PASS.

## Instruction coverage trong CPU integration

| Instruction | Test / expected chính |
|---|---|
| ADD | x3=8; wrap `0x7fffffff + 1 = 0x80000000`; `rs1=rs2`, `rs2=rd` |
| SUB | x4=2; wrap `0 - 1 = 0xffffffff` |
| AND/OR/XOR | x5=1, x6=7, x7=6 |
| SLL/SRL/SRA | shift 0/1/31/35; `35 & 31 = 3`; signed và logical khác nhau khi bit31=1 |
| ADDI | positive/negative, x0 source, destination x0, dependent writeback |
| ANDI/ORI/XORI | immediate `-1` kiểm tra sign extension |
| LW/SW | hai word addresses; load-after-store; alignment/range errors không ghi |
| BEQ/BNE | taken/not-taken, forward/backward; not-taken offset 2 không fault |
| JAL | link=PC+4, target, misaligned/out-of-range target chặn link |
| JALR | link/target; `rs1=rd`; bit1 target misalignment; out-of-range target chặn link |
| LUI/AUIPC | upper immediate; AUIPC tại PC khác 0 |

Negative cases gồm opcode không hỗ trợ, SLT ngoài scope, R-type funct7 sai, shift-immediate ngoài scope, LOAD/STORE funct3 sai; misaligned/out-of-range LW/SW; JAL/JALR/branch target; x0; halted sticky/reset recovery; DMEM không đổi khi lỗi.

## Memory unit test

- IMEM kiểm tra address 0, word cuối trong vùng, byte address không căn chỉnh, và address đúng cuối vùng `1024` bị từ chối.
- DMEM mặc định 128×32: kiểm tra synchronous write/asynchronous read ở word 0, word 1 và word cuối 127 (byte address 508); byte address 512 bị báo out-of-range và write không alias về word 0.
- RAM contents được seed trong testbench khi cần. RTL không giả định DMEM khởi động bằng 0.

## Warnings quan sát được

- Icarus báo `$readmemh` file có ít dòng hơn 256 word ROM. Đây là warning có thật: phần ROM không ghi trong file chưa khởi tạo. Chương trình dùng trong test kết thúc trong loop; testbench regression tự nạp toàn bộ vùng cần dùng.
- `-Wall` báo RTL module không khai báo timescale trong khi testbench khai báo timescale. Đây không phải compile error hay functional failure; có thể thêm directive thống nhất nếu muốn loại warning, nhưng không ảnh hưởng logic tổng hợp.

## Chưa được đo/kiểm chứng

- Không có coverage engine/formal proof; test là directed simulation.
- Không chạy Gowin synthesis, timing, Fmax, resource utilization hoặc board test vì Gowin EDA không có trong PATH/các vị trí đã dò và workspace thiếu device/board constraints.
- CPI=1 là cấu trúc single-cycle trong mô hình RTL cho lệnh hợp lệ, không phải phép đo frequency/performance phần cứng. Lệnh lỗi dừng CPU.
