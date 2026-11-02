# CPU RISC-V 32-bit Single-Cycle

Đồ án hiện thực CPU single-cycle bằng **Verilog-2001** (`.v`). Mỗi instruction hợp lệ được thực hiện trong một chu kỳ clock. Thiết kế dùng ROM/RAM đọc tổ hợp; RAM ghi tại cạnh lên.

## Cấu trúc và hierarchy

```text
cpu_top
├── u_ctrl: control_unit
└── u_datapath: datapath
    ├── u_pc: pc
    ├── u_inst_mem: instruction_memory
    ├── u_imm_gen: immediate_gen
    ├── u_reg_file: register_file
    ├── u_alu: alu
    └── u_data_mem: data_memory
```

`cpu_top` là top của lõi. [fpga_debug_wrapper](src/fpga_debug_wrapper.v) là top tùy chọn cho demo, gồm CPU và mux chọn một trong PC/instruction/ALU result/writeback ra `debug_data`. Wrapper chưa gán chân FPGA. CPU có 32 thanh ghi 32-bit, 2 cổng đọc tổ hợp, 1 cổng ghi đồng bộ; x0 luôn đọc bằng 0 và không nhận ghi.

## Tập lệnh được hỗ trợ

Decoder mặc định chỉ chấp nhận đúng 20 instruction dưới đây; các opcode/subencoding khác tạo `illegal_instr`, giữ PC và đưa CPU vào trạng thái `halted` cho đến reset.

| Nhóm | Instructions |
|---|---|
| R-type | ADD, SUB, AND, OR, XOR, SLL, SRL, SRA |
| I-type arithmetic | ADDI, ANDI, ORI, XORI |
| Memory | LW, SW (word 32-bit, địa chỉ căn chỉnh 4 byte) |
| Branch | BEQ, BNE |
| Jump | JAL, JALR |
| Upper immediate | LUI, AUIPC |

ALU vẫn giữ phép so sánh SLT/SLTU để có thể mở rộng, nhưng control unit không phát lệnh cho chúng. Các lệnh SLTI/SLTIU, SLLI/SRLI/SRAI, branch khác, byte/halfword load/store, MUL/DIV không được CPU hỗ trợ; chúng báo lệnh không hợp lệ. Phần ALU dư không đồng nghĩa CPU đã triển khai các instruction tương ứng.

## Clock, reset, bộ nhớ và chương trình

- `clk`: clock hệ thống; PC/RF dùng cạnh lên.
- `rst`: reset đồng bộ, active-high. PC về 0; toàn bộ thanh ghi x1–x31 được xóa, x0 vẫn bằng 0; các cờ lỗi và `halted` được xóa. Reset chặn mọi ghi register/RAM.
- RAM dữ liệu **không bị xóa bởi reset CPU**; nội dung được giữ lại qua reset.
- IMEM mặc định 256 word (1 KiB), địa chỉ byte bắt đầu từ 0, đọc tổ hợp.
- DMEM mặc định 128 word × 32 bit = 4,096 bit (512 byte), địa chỉ byte bắt đầu từ 0, đọc tổ hợp và ghi đồng bộ. `DMEM_SIZE` vẫn là parameter để cấu hình dung lượng lớn hơn.
- Chỉ hỗ trợ instruction dài 32 bit và `LW`/`SW` căn chỉnh 4 byte. Dữ liệu word theo quy ước little-endian; chưa có byte/halfword access.
- Địa chỉ được kiểm tra đầy đủ trước khi dùng làm chỉ số word; địa chỉ cao không bị alias về đầu RAM.
- `cpu_top` có parameter `MEM_FILE` (mặc định `src/program.mem`), `IMEM_DEPTH` và `DMEM_SIZE` (mặc định 128 word). Đường dẫn `.mem` được tính từ **thư mục làm việc hiện tại** của simulator. Khi chạy `tb_cpu`, có thể truyền `+PROGRAM=đường_dẫn.mem` để chọn chương trình.
- Mỗi dòng `.mem` là một word instruction 32-bit dạng hexadecimal, không có tiền tố `0x`. Không thay đường dẫn thành `tb/programs/program.mem` nếu muốn chạy chương trình trong `src/program.mem`; đây là hai file khác nhau.
- Trong Gowin, giữ `program.mem` ở `src/program.mem` bên dưới thư mục project (hoặc cấu hình parameter `MEM_FILE` trỏ đúng vị trí tương đối trong project). Gowin EDA chưa chạy trong lần kiểm tra này, nên cần xác nhận ROM được nạp từ file bằng báo cáo synthesis/simulation của phiên bản tool đang dùng.
- `$readmemh` nạp các dòng có trong file; nếu file ngắn hơn ROM, các word chưa nạp không có giá trị xác định. Chương trình cần tránh chạy tuần tự vào vùng chưa khởi tạo (thường kết thúc bằng vòng lặp).

Khi có instruction illegal, fetch/data/target sai căn chỉnh hoặc địa chỉ ngoài vùng nhớ, CPU chặn ghi của instruction gây lỗi, giữ PC tại instruction gây lỗi, bật cờ trạng thái tương ứng và giữ `halted` đến reset. Đây là cơ chế debug đơn giản, không phải trap chuẩn RISC-V. Với branch, chỉ kiểm tra đích khi branch được lấy. JAL/JALR có đích lỗi sẽ không ghi thanh ghi link. JALR chỉ xóa bit 0; bit 1 bằng 1 vẫn tạo lỗi căn chỉnh cho instruction 32-bit.

## Chạy mô phỏng bằng Icarus Verilog

Chạy lệnh từ thư mục gốc repository (`D:\Fall 2026\DO AN`) để đường dẫn mặc định `src/program.mem` được phân giải đúng. Trên máy này, executable được cài tại `E:\down\iverilog\bin`; nếu PATH đã cấu hình, có thể gọi ngắn `iverilog` và `vvp`.

```powershell
New-Item -ItemType Directory -Force out | Out-Null
E:\down\iverilog\bin\iverilog.exe -g2001 -Wall -s tb_alu -o out\tb_alu.vvp src\alu.v tb\tb_alu.v
E:\down\iverilog\bin\vvp.exe out\tb_alu.vvp

E:\down\iverilog\bin\iverilog.exe -g2001 -Wall -s tb_cpu -o out\tb_cpu.vvp src\alu.v src\register_file.v src\pc.v src\instruction_memory.v src\data_memory.v src\immediate_gen.v src\control_unit.v src\datapath.v src\cpu_top.v tb\tb_cpu.v
E:\down\iverilog\bin\vvp.exe out\tb_cpu.vvp
```

Để biên dịch/chạy toàn bộ unit, integration, demo và wrapper tests:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tb\run_regression.ps1
```

Các testbench unit, CPU và demo đều ghi waveform VCD dưới `out/`. Ví dụ mở waveform CPU bằng GTKWave:

```powershell
E:\down\iverilog\bin\gtkwave.exe .\out\waveform_cpu.vcd
```

File tương ứng: `waveform_alu.vcd`, `waveform_control_unit.vcd`, `waveform_immediate_gen.vcd`, `waveform_memory.vcd`, `waveform_cpu.vcd`, `waveform_demo_sum.vcd`, `waveform_fpga_debug_wrapper.vcd`. Trong GTKWave, chọn các tín hiệu ở cây bên trái rồi thêm vào vùng waveform. VCD chỉ dump tín hiệu cần quan sát, không dump toàn bộ mảng RAM.

Mặc định script dùng Icarus trong `E:\down\iverilog\bin`; có thể truyền `-Iverilog` và `-Vvp` để trỏ sang cài đặt khác. Testbench lấy mẫu sau cạnh clock và sau nonblocking updates; regression dừng với exit code khác 0 khi compile fail, có FAIL hoặc thiếu thông báo PASS. Để chạy chương trình khác, dùng `E:\down\iverilog\bin\vvp.exe out\tb_cpu.vvp +PROGRAM=tb/programs/program.mem`; chế độ này chạy 100 chu kỳ rồi in PC/trạng thái, không tuyên bố chương trình đúng expected.

## Trạng thái kiểm thử

Bảng dưới đây ghi kết quả thực tế của regression Icarus ngày 2026-10-19.

| Lệnh | Trạng thái `tb_cpu` | Expected được kiểm tra |
|---|---|---|
| ADD | PASS | x3 = 8; thêm ca tràn 32-bit |
| SUB | PASS | x4 = 2; thêm ca tràn 32-bit |
| AND | PASS | x5 = 1 |
| OR | PASS | x6 = 7 |
| XOR | PASS | x7 = 6 |
| SLL | PASS | x8 = 40; thêm shift 31 |
| SRL | PASS | x9 = `0x10000000`; kiểm tra shift 0 |
| SRA | PASS | x11 = `0xF0000000`; rs2=35 chỉ dùng 5 bit thấp |
| ADDI | PASS | immediate âm/dương, nguồn x0 và chuỗi phụ thuộc |
| ANDI | PASS | immediate âm `-1` |
| ORI | PASS | immediate âm `-1` |
| XORI | PASS | immediate âm `-1` |
| LW | PASS | đọc lại hai word đã SW |
| SW | PASS | ghi hai địa chỉ word khác nhau |
| BEQ | PASS | taken và not-taken; nhánh không lấy bỏ qua kiểm tra đích |
| BNE | PASS | taken/not-taken, vòng lặp nhánh lùi |
| JAL | PASS | kiểm tra target và PC+4 trong rd |
| JALR | PASS | kiểm tra target/link và trường hợp rs1=rd |
| LUI | PASS | tạo `0x80000000` |
| AUIPC | PASS | tại PC=116, kết quả x20=116 |

| Bộ test | Kết quả mô phỏng gần nhất |
|---|---|
| `tb_alu` | PASS: 29 kiểm tra, 0 lỗi |
| `tb_cpu` | PASS: 91 assertions; 20 lệnh, datapath, reset và fault cases |
| Negative cases | PASS: opcode/lệnh ngoài phạm vi, funct sai, load/store funct3 sai; lỗi alignment/range chặn side effect |

| Testbench | Phạm vi | Kết quả thực tế |
|---|---|---|
| `tb_control_unit` | 20 encoding hợp lệ và 8 lệnh/mã hóa không hợp lệ | PASS: 28 checks |
| `tb_immediate_gen` | I/S/B/U/J, immediate dương/âm, J/B offsets | PASS: 12 checks |
| `tb_memory` | IMEM read/boundary/alignment/range; DMEM sync write, async read, word cuối và địa chỉ 512 ngoài vùng | PASS: 12 checks |
| `tb_demo_sum` | Chương trình tổng 1..10; x3/x4/DMEM[0] = 55 | PASS: 6 checks |
| `tb_fpga_debug_wrapper` | Chọn PC, instruction, ALU result, writeback và trạng thái | PASS: 5 checks |

## Demo: tổng số nguyên từ 1 đến 10

File [demo_sum_1_to_10.mem](tb/programs/demo_sum_1_to_10.mem) chạy loop bằng ADDI, ADD và BNE, sau đó SW/LW kết quả và lặp bằng JAL. Testbench [tb_demo_sum.v](tb/tb_demo_sum.v) tự kiểm tra x3=55, x4=55, DMEM[0]=55 và không có cờ fault.

| PC | Instruction | Tác dụng |
|---:|---|---|
| `0x00` | `ADDI x1,x0,1` | Khởi tạo i=1 |
| `0x04` | `ADDI x2,x0,11` | Giới hạn loop (exclusive) |
| `0x08` | `ADDI x3,x0,0` | Khởi tạo sum=0 |
| `0x0C` | `ADD x3,x3,x1` | sum += i |
| `0x10` | `ADDI x1,x1,1` | i++ |
| `0x14` | `BNE x1,x2,-8` | Lặp về `0x0C` khi i != 11 |
| `0x18` | `SW x3,0(x0)` | Lưu 55 vào DMEM word 0 |
| `0x1C` | `LW x4,0(x0)` | Đọc lại 55 vào x4 |
| `0x20` | `JAL x0,0` | Giữ CPU trong vòng lặp cuối |

Chạy `tb/run_regression.ps1` để kiểm chứng demo. Trên FPGA, chọn `debug_select=00` để quan sát PC, `01` instruction, `10` ALU result, `11` writeback; cần board/pin mapping cụ thể trước khi nối GPIO/LED.

## Ghi chú triển khai

RTL hiện dùng truy cập ROM/RAM bất đồng bộ để giữ ngữ nghĩa single-cycle. Khả năng suy luận BSRAM/Distributed RAM/LUT-FF và timing phải được xác nhận bằng Gowin EDA; README này không khẳng định đã synthesis hoặc chạy trên FPGA. Chưa có mã chip/package/board được chốt trong project và thư mục constraints đang trống, vì vậy không có pin assignment.
