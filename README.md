# SEP490 G93 — Design and Implementation of a 32-bit RISC-V Processor

Hướng dẫn cài đặt, mô phỏng RTL, triển khai FPGA và sử dụng giao diện UART của phiên bản **ISA20 Interactive** trên Windows 10/11.

## 1. Giới thiệu

Project triển khai bộ xử lý RISC-V 32-bit theo kiến trúc Single-Cycle bằng Verilog HDL, hỗ trợ 20 lệnh thuộc tập con RV32I. CPU chạy chương trình mã máy trong Instruction Memory; các chương trình demo Calculator, SUM, Fibonacci và TEST20 giao tiếp với UART thông qua MMIO. Chế độ Interactive cho phép nhập từng lệnh và toán hạng từ máy tính, mã hóa thành mã máy thực tế, thực thi bằng datapath CPU và quan sát kết quả qua UART và LED 7 đoạn.

| Thông số | Giá trị |
|---|---|
| Board | ACG525 |
| FPGA | Gowin GW5A-LV25UG324C2/I1 (GW5A-25A) |
| Clock mục tiêu | 50 MHz (20 ns) |
| Register File | 32 thanh ghi × 32 bit, x0 = 0 |
| Instruction Memory | 256 word × 32 bit (1024 byte) |
| Data Memory | 128 word × 32 bit (512 byte), ngoài vùng MMIO |
| UART | 115200 baud, 8N1, không flow control |
| Top module triển khai | `uart_cpu_isa20_interactive_top` |

Tập lệnh hỗ trợ:

- R-type: `ADD`, `SUB`, `AND`, `OR`, `XOR`, `SLL`, `SRL`, `SRA`.
- I-type arithmetic: `ADDI`, `ANDI`, `ORI`, `XORI`.
- Load/store: `LW`, `SW`.
- Branch: `BEQ`, `BNE`.
- Jump: `JAL`, `JALR`.
- U-type: `LUI`, `AUIPC`.

Đây là tập con 20 lệnh, không phải toàn bộ RV32I. Giao diện Interactive là bộ mẫu lệnh với các thanh ghi cố định, không phải assembler hoặc program loader tổng quát.

## 2. Cấu trúc repository

Cấu trúc cần có sau khi tích hợp các bản cập nhật:

```text
SEP490_G93_IC_Design_Project/
├── README.md
├── Code/
│   ├── src/                         # RTL dùng cho mô phỏng và ROM
│   │   ├── alu.v
│   │   ├── control_unit.v
│   │   ├── register_file.v
│   │   ├── program_multi_mmio.mem
│   │   └── ...
│   ├── tb/                          # 7 testbench cơ bản
│   │   ├── run_regression.ps1
│   │   └── tools/asm20.py            # Assembler cho tập con 20 lệnh
│   ├── v2/
│   │   ├── programs/                # MULTIPROGRAM.S, .mem, .disasm
│   │   ├── sim/                     # 3 testbench MultiProgram v2
│   │   ├── src/
│   │   └── tools/
│   ├── isa20_verify/                # 5 testbench kiểm chứng ISA20
│   │   └── run_isa20.py
│   └── isa20_interactive/
│       ├── src/                     # 7 RTL Interactive (bản đã đồng bộ)
│       ├── sim/                     # 3 testbench Interactive + vectors
│       │   └── run_interactive.py
│       └── tools/                   # verify_vectors.py, install.py
└── Project_Capstone/
    ├── Project_Capstone.gprj         # Mở bằng Gowin EDA
    └── src/
        ├── Project_Capstone.cst      # Pin assignment
        ├── FPGA_DOAN.sdc             # Timing constraint
        ├── program_multi_mmio.mem
        ├── uart_cpu_isa20_interactive_top.v
        └── ...                      # RTL dùng để tổng hợp FPGA
```

`Code/src` và `Project_Capstone/src` phải thống nhất nội dung các RTL đang sử dụng và file ROM. Các thư mục `sim`, `tb` và `isa20_verify` chỉ dành cho mô phỏng; không thêm testbench vào danh sách RTL tổng hợp của Gowin.

## 3. Cài đặt phần mềm

| Công cụ | Mục đích | Link tải / tài liệu |
|---|---|---|
| Git for Windows | Clone repository, quản lý phiên bản | [Git for Windows](https://git-scm.com/install/win) |
| Python 3 (khuyến nghị 3.10+) | Chạy regression, assembler và mô hình tham chiếu | [Python for Windows](https://www.python.org/downloads/windows/) |
| Icarus Verilog | Biên dịch RTL và chạy testbench (`iverilog`, `vvp`) | [Windows installer](https://bleyer.org/icarus/), [hướng dẫn Icarus](https://steveicarus.github.io/iverilog/usage/installation.html) |
| GTKWave (tùy chọn) | Xem waveform VCD | [Tài liệu GTKWave](https://gtkwave.github.io/gtkwave/index.html); có thể cài kèm Icarus Windows nếu installer hỗ trợ |
| Gowin EDA | Synthesis, Place & Route, Timing Analysis và tạo bitstream | [GOWIN EDA Download](https://www.gowinsemi.com/en/support/download_eda) |
| Gowin Programmer | Nạp bitstream qua cáp lập trình | [GOWIN Programmer](https://www.gowinsemi.com/en/support/download_eda) |
| Tera Term 5 | Gửi lệnh, nhận phản hồi UART | [Tera Term Releases](https://github.com/TeraTermProject/teraterm/releases), [trang dự án](https://teratermproject.github.io/index-en.html) |
| WCH USB-UART driver (nếu cần) | Nhận COM cho chip CH9102/CH910x | [CH343SER — WCH](https://www.wch-ic.com/downloads/CH343SER_ZIP.html) |

### 3.1. Cài Python và Git

1. Tải bộ cài Windows x64 phù hợp và chạy installer.
2. Đảm bảo Python và Git dùng được trong terminal (bật Add Python to PATH nếu installer có lựa chọn này).
3. Mở PowerShell mới và kiểm tra:

```powershell
git --version
python --version
```

Nếu máy dùng Python Launcher, có thể thay `python` bằng `py -3` trong các lệnh bên dưới. Các script Python hiện tại sử dụng thư viện chuẩn; không cần cài gói pip hoặc RISC-V GCC để chạy regression.

### 3.2. Cài Icarus Verilog và GTKWave

1. Tải bộ cài Icarus Verilog dành cho Windows x64 từ bảng trên.
2. Cài đặt vào thư mục ví dụ `C:\iverilog` (đường dẫn thực tế có thể khác).
3. Thêm thư mục chứa `iverilog.exe` và `vvp.exe` (ví dụ `C:\iverilog\bin`) vào User PATH: Start → Edit environment variables for your account → Path → Edit → New.
4. Nếu có tùy chọn GTKWave thì cài kèm; nếu không, cài GTKWave riêng khi cần xem sóng.
5. Đóng terminal cũ, mở PowerShell mới và kiểm tra:

```powershell
iverilog -V
vvp -V
Get-Command iverilog, vvp
```

### 3.3. Cài Gowin và Tera Term

- Gowin EDA: phiên bản đã dùng trong project là **V1.9.11.01 Education (64-bit)**. Ưu tiên cùng phiên bản hoặc bản tương thích có hỗ trợ GW5A-25A. Cài Gowin Programmer và driver cáp lập trình theo bộ cài; kiểm tra yêu cầu license nếu dùng bản Standard.
- Tera Term: mở trang Releases chính thức, chọn bộ cài Tera Term 5 phù hợp với Windows, tải và cài đặt. Không cần Tera Term để chạy testbench.
- Nếu Windows chưa nhận USB-UART CH9102, cài driver WCH phù hợp từ link trên. Driver UART và driver cáp lập trình JTAG có thể là hai driver khác nhau.

## 4. Clone project

Mở PowerShell tại thư mục muốn lưu repository:

```powershell
git clone https://github.com/buitrunghieucitizen/SEP490_G93_IC_Design_Project.git
cd SEP490_G93_IC_Design_Project
```

Nếu repository yêu cầu quyền truy cập, đăng nhập bằng tài khoản được cấp quyền. Có thể dùng Download ZIP rồi giải nén nếu chỉ cần chạy project. Các hướng dẫn sau giả định bản ISA20 Interactive đã được commit đầy đủ; nếu clone còn thiếu thư mục hoặc module Interactive, cần lấy đúng phiên bản đã tích hợp trước khi chạy.

## 5. Chạy Testbench (RTL simulation)

Không cần board FPGA, Gowin hoặc Tera Term để chạy mô phỏng. Mở PowerShell **tại thư mục gốc repository**, sau đó vào `Code`:

```powershell
cd Code
```

Các lệnh trong mục 5 đều chạy từ thư mục `Code`.

### 5.1. Chạy bộ testbench cơ bản

Script cũ `run_regression.ps1` có đường dẫn Icarus mặc định phụ thuộc máy của người viết. Truyền đường dẫn lấy từ PATH để không phải chỉnh script:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tb\run_regression.ps1 -Iverilog (Get-Command iverilog).Source -Vvp (Get-Command vvp).Source
```

`-ExecutionPolicy Bypass` ở đây chỉ áp dụng cho tiến trình chạy script đã được kiểm tra trong repository, không thay đổi chính sách toàn hệ thống.

Kỳ vọng: `ALL REGRESSION TESTS PASSED`. Bộ này gồm ALU, Control Unit, Immediate Generator, Memory, CPU, SUM demo và FPGA Debug Wrapper.

### 5.2. Chạy bộ MultiProgram v2

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\v2\sim\run_v2_tests.ps1
```

Kỳ vọng: `ALL V2 HDL TESTS PASSED`. Gồm command parser v2, CPU v2 và UART v2; file biên dịch được tạo trong `build/v2/`.

### 5.3. Chạy bộ kiểm chứng ISA20 (khuyến nghị)

```powershell
python .\isa20_verify\run_isa20.py
```

Script này bao gồm cả 7 testbench cơ bản và 3 testbench v2, bổ sung các test PC, Register File, trace đối chiếu mô hình, MMIO fault và UART baud thực. Tổng cộng 15 testbench / 18 lượt mô phỏng, kèm mô hình tham chiếu. Không bắt buộc chạy lại mục 5.1 và 5.2 nếu đã chạy trọn mục này.

Kỳ vọng: `ALL ISA20 VERIFICATION TESTS PASSED (RTL + MODEL)`. Log, trace và VCD được lưu tại `Code/out/isa20/`.

Chỉ chạy mô hình tham chiếu khi cần kiểm tra assembler/vector (không thay thế HDL simulation):

```powershell
python .\isa20_verify\run_isa20.py --model-only
```

### 5.4. Chạy testbench phiên bản ISA20 Interactive

```powershell
python .\isa20_interactive\sim\run_interactive.py
```

| Testbench | Nội dung |
|---|---|
| `tb_isa20_interactive_parser.v` | Cú pháp, toán hạng, lệnh sai, chữ hoa/thường, CR/LF/Backspace |
| `tb_isa20_interactive_cpu.v` | 32 vector, 20 loại lệnh, PC, write-back, RAM, fault và phục hồi |
| `tb_isa20_interactive_uart.v` | Luồng UART end-to-end ở chế độ tăng tốc và nhóm ca đại diện 115200 baud thực |

Kỳ vọng: `ALL INTERACTIVE ISA20 HDL TESTS PASSED (4 runs + reference model)`. Có 3 testbench nhưng 4 lượt mô phỏng vì UART được chạy hai chế độ. Log và waveform nằm trong `Code/out/isa20_interactive/`.

**Để chạy toàn bộ bộ kiểm thử một lần không trùng lặp:**

```powershell
python .\isa20_verify\run_isa20.py
# Chỉ chạy tiếp khi lệnh trên PASS
python .\isa20_interactive\sim\run_interactive.py
```

Tổng dự kiến: 18 testbench khác nhau, 22 lượt HDL simulation, ngoài các bước kiểm chứng mô hình. Chỉ ghi nhận PASS khi script thực sự hoàn thành thành công.

Nếu Icarus chưa có trong PATH, hai script Python hỗ trợ đường dẫn tường minh:

```powershell
python .\isa20_verify\run_isa20.py --iverilog "C:\iverilog\bin\iverilog.exe" --vvp "C:\iverilog\bin\vvp.exe"
python .\isa20_interactive\sim\run_interactive.py --iverilog "C:\iverilog\bin\iverilog.exe" --vvp "C:\iverilog\bin\vvp.exe"
```

Thay đường dẫn ví dụ bằng đường dẫn thực tế. Script v2 yêu cầu `iverilog` và `vvp` trên PATH.

### 5.5. Chạy riêng một testbench và xem waveform

Ví dụ ALU (vẫn tại `Code`):

```powershell
New-Item -ItemType Directory -Force out | Out-Null
iverilog -g2001 -Wall -s tb_alu -o out/tb_alu.vvp src/alu.v tb/tb_alu.v
vvp out/tb_alu.vvp
```

Để xem waveform CPU Interactive sau khi chạy mục 5.4:

```powershell
gtkwave out/isa20_interactive/cpu.vcd
```

Nếu `gtkwave` chưa có trên PATH, mở GTKWave bằng Start menu rồi chọn File → Open New Tab/Open, trỏ đến file VCD. Có thể thêm các tín hiệu `clk`, `reset_n`, `cpu_pc`, `cpu_instr`, `rs1_data`, `rs2_data`, `alu_result`, `cpu_wb`, `commit` để phân tích. Không phải testbench nào cũng sinh VCD.

## 6. Tổng hợp Verilog và nạp FPGA

### 6.1. Mở project có sẵn

1. Mở Gowin EDA → File → Open Project.
2. Chọn `Project_Capstone/Project_Capstone.gprj` trong repository đã clone.
3. Kiểm tra device là **GW5A-LV25UG324C2/I1**.
4. Kiểm tra danh sách Design Files chứa RTL nền, ROM `src/program_multi_mmio.mem` và 7 RTL Interactive:

```text
isa20_encoder.v
isa20_interactive_parser.v
isa20_interactive_tx.v
isa20_interactive_engine.v
datapath_isa20_interactive.v
cpu_isa20_interactive.v
uart_cpu_isa20_interactive_top.v
```

5. Nếu thiếu file tham chiếu nhưng file thật đã có trong `Project_Capstone/src`, dùng Add Files để bổ sung. Không thêm `tb_*.v` vào thiết kế FPGA.
6. Đặt `uart_cpu_isa20_interactive_top` làm Top Module bằng Set as Top Module hoặc mục Top Module trong cấu hình Synthesis (tùy phiên bản Gowin).

### 6.2. Pin assignment và timing constraint

Project đã có `Project_Capstone/src/Project_Capstone.cst` và `Project_Capstone/src/FPGA_DOAN.sdc`. Kiểm tra chúng được thêm và Enable trong project.

| Port | Pin | Direction | I/O standard |
|---|---|---|---|
| `clk` | T9 | Input | LVCMOS33 |
| `reset_n` | B16 | Input | LVCMOS33 |
| `uart_rx` | U8 | Input | LVCMOS33 |
| `uart_tx` | V8 | Output | LVCMOS33 |
| `ds` | F4 | Output | LVCMOS33 |
| `sh_cp` | H4 | Output | LVCMOS33 |
| `st_cp` | F3 | Output | LVCMOS33 |

Clock constraint hiện tại:

```tcl
create_clock -name clk -period 20.000 [get_ports {clk}]
```

**Không cần gán lại từng chân nếu dùng đúng board, cùng pinout và các constraint đã được lưu trong `.gprj`.** Nếu sử dụng board khác, kiểm tra pinout và điện áp của board trước khi chạy. Không đổi SDC sang chu kỳ dài hơn chỉ để che lỗi timing ở clock vật lý 50 MHz.

### 6.3. Synthesis, Place & Route

1. Trong Process, chạy Synthesize.
2. Khi Synthesis thành công, chạy Place & Route (hoặc Run All).
3. Kiểm tra log, Pin Report và Timing Analysis: Actual Fmax tối thiểu 50 MHz, setup/hold slack không âm, không có endpoint vi phạm setup/hold đối với các đường được phân tích. Kiểm tra Resource Usage và các cảnh báo.
4. Sau khi build thành công, tìm bitstream `.fs` mới trong `Project_Capstone/impl/pnr/` (thường là `Project_Capstone.fs`). Đối chiếu thời gian tạo để tránh nạp nhầm bản cũ.

### 6.4. Nạp vào SRAM để thử nghiệm

1. Kết nối board với máy tính bằng cáp dữ liệu/cáp lập trình JTAG theo hướng dẫn board; cấp nguồn theo thiết kế board.
2. Mở Gowin Programmer từ Gowin EDA hoặc Start menu.
3. Scan/Detect Device và xác nhận nhận đúng FPGA.
4. Mở Device Configuration của FPGA → chọn Access Mode **SRAM Mode**, Operation **SRAM Program** (hoặc Program and Verify nếu có), chọn bitstream `.fs` vừa tạo ở Programming File.
5. Nhấn Program/Configure và kiểm tra kết quả thành công. Không ngắt cáp trong khi nạp.
6. Reset board nếu cần và kiểm tra bằng Tera Term theo mục 7.

SRAM chỉ giữ cấu hình khi có nguồn; sau power cycle board có thể khởi động lại từ bản đã lưu trong Flash. Thử SRAM trước để giữ bản Flash cũ làm dự phòng.

### 6.5. Nạp SPI Flash (tùy chọn, sau khi đã xác minh)

Sau khi toàn bộ regression và test phần cứng đạt, có thể dùng Gowin Programmer để lưu bitstream vào SPI Flash ngoài của board. Chọn External Flash Mode và thao tác erase/program/verify tương ứng với GW5A và đúng loại Flash trên board; kiểm tra cấu hình theo tài liệu nhà sản xuất và cấu hình board đã dùng trước đó. Không đoán model Flash hoặc địa chỉ. Chỉ thực hiện khi chấp nhận ghi đè phiên bản cũ. Sau khi thành công, tắt/bật nguồn và chạy lại `STATUS`, `ADD 15 3`, `TEST20` để xác nhận. Không coi việc nạp SRAM thành công là đã ghi Flash.

## 7. Sử dụng Tera Term

### 7.1. Kết nối UART

1. Mở Device Manager → Ports (COM & LPT), tìm cổng `USB-Enhanced-SERIAL CH9102` hoặc cổng USB-UART tương ứng (ví dụ COM10; mỗi máy có thể khác).
2. Mở Tera Term → File → New connection → Serial → chọn đúng COM.
3. Vào Setup → Serial port và đặt:

| Setting | Value |
|---|---|
| Speed/Baud rate | 115200 |
| Data | 8 bit |
| Parity | None |
| Stop bits | 1 bit |
| Flow control | None |
| Transmit delay | 0 ban đầu; có thể thử 1 ms/character, 100 ms/line khi chẩn đoán |

4. Vào Setup → Terminal:

| Setting | Value |
|---|---|
| Transmit newline | CR |
| Receive newline | CR (hoặc chế độ tự nhận nếu phiên bản hỗ trợ) |
| Local echo | ON |

5. Reset board, đợi khoảng 1 giây. Không có banner tự động ở bản Interactive này. Gõ `STATUS` rồi Enter, chờ `Status: READY`. Gõ `HELP` để xem danh sách lệnh.

Local echo chỉ hiển thị ký tự bạn gõ tại máy tính, không phải phản hồi từ FPGA. Gửi từng dòng, chờ phản hồi hoàn tất trước khi gửi dòng tiếp; không dán cả bảng lệnh một lượt vì console không có hàng đợi lệnh.

### 7.2. Demo Calculator và chương trình ROM

| Nhập | Phản hồi mong đợi |
|---|---|
| `15+7` | `Result: 22` |
| `7-15` | `Result: -8` |
| `15*7` | `Result: 105` |
| `SUM 10` | `Result: 55` |
| `FIB 10` | `Result: 55` |
| `FIB 39` | `Result: 63245986` |
| `TEST20` (hoặc `T`, `TEST 20`) | `Result: 20` |
| `HELP` | Danh sách lệnh |
| `STATUS` | `Status: READY` |
| `CLEAR` | `Display cleared` (LED về 0, không xóa RAM) |

Calculator legacy nhận mỗi toán hạng 0..9999; SUM 0..9999; FIB 0..39. Không cần khoảng trắng trong biểu thức dạng `15+7`.

### 7.3. Demo đủ 20 lệnh Interactive

Nhập lần lượt từng lệnh; thực hiện SW trước LW tại cùng địa chỉ. Bảng dưới là kết quả mong đợi, khớp với các phản hồi UART đã quan sát trong lần thử nghiệm phần cứng của nhóm.

| # | Lệnh | WORD (hex) | NEXT (hex) | VALUE (hex) | Giá trị LED dự kiến |
|---:|---|---|---|---|---:|
| 1 | `ADD 15 3` | `002081B3` | `00000010` | `00000012` | 18 |
| 2 | `SUB 15 3` | `402081B3` | `00000010` | `0000000C` | 12 |
| 3 | `AND 15 3` | `0020F1B3` | `00000010` | `00000003` | 3 |
| 4 | `OR 8 3` | `0020E1B3` | `00000010` | `0000000B` | 11 |
| 5 | `XOR 15 3` | `0020C1B3` | `00000010` | `0000000C` | 12 |
| 6 | `SLL 15 2` | `002091B3` | `00000010` | `0000003C` | 60 |
| 7 | `SRL 15 2` | `0020D1B3` | `00000010` | `00000003` | 3 |
| 8 | `SRA -16 2` | `4020D1B3` | `00000010` | `FFFFFFFC` | -4 |
| 9 | `ADDI 15 -3` | `FFD08193` | `00000010` | `0000000C` | 12 |
| 10 | `ANDI 15 7` | `0070F193` | `00000010` | `00000007` | 7 |
| 11 | `ORI 8 3` | `0030E193` | `00000010` | `0000000B` | 11 |
| 12 | `XORI 15 3` | `0030C193` | `00000010` | `0000000C` | 12 |
| 13 | `SW 0 123` | `0020A023` | `00000010` | `0000007B` | 123 |
| 14 | `LW 0` | `0000A183` | `00000010` | `0000007B` | 123 |
| 15 | `BEQ 5 5` | `00208463` | `00000014` | `00000001` | 1 |
| 16 | `BNE 5 3` | `00209463` | `00000014` | `00000001` | 1 |
| 17 | `JAL 8` | `008001EF` | `00000014` | `00000010` | 16 |
| 18 | `JALR 21 0` | `000081E7` | `00000014` | `00000010` | 16 |
| 19 | `LUI 2` | `000021B7` | `00000010` | `00002000` | 8192 |
| 20 | `AUIPC 1` | `00001197` | `00000010` | `0000100C` | 4108 |

Ví dụ thực tế:

```text
ADD 15 3
WORD=002081B3 PC=0000000C NEXT=00000010 WB=00000012 VALUE=00000012
```

- `WORD`: mã máy 32 bit; `PC`: địa chỉ lệnh thử (0x0C); `NEXT`: PC ngay sau khi thực thi.
- `WB`: dữ liệu write-back (0 nếu không ghi thanh ghi); `VALUE`: kết quả hiển thị, là WB đối với lệnh ghi thanh ghi, giá trị đọc lại với SW, hoặc 1/0 với branch taken/not taken.
- UART hiển thị các trường trên ở dạng hex 32 bit. LED hiển thị số thập phân có dấu nếu biểu diễn được trong 8 chữ số; vượt giới hạn thì hiển thị `EEEEEEEE` (UART vẫn đủ 32 bit).

### 7.4. Quy tắc nhập và giới hạn

- Không phân biệt chữ hoa/thường. Tối đa 48 ký tự mỗi dòng. Dùng dấu cách giữa tên lệnh và toán hạng (`LW 4`, không phải `LW4`; `FIB 39`, không phải `FIB39`).
- Toán hạng 32-bit: số thập phân có dấu -2147483648..2147483647, không dấu 0..4294967295 hoặc hex `0x` kèm 1..8 chữ số. Phép toán wrap modulo 2^32.
- Immediate I-type: -2048..2047; U-type: trường 20-bit 0..0xFFFFF, chưa dịch 12 bit.
- SW/LW: địa chỉ byte 0..508, chia hết cho 4. RAM không được khởi tạo lại khi reset CPU; SW trước khi LW nếu chưa biết nội dung. TEST20 có thể ghi đè một số ô RAM.
- BEQ/BNE sử dụng offset +8 byte cố định. JAL nhận offset byte; JALR nhận base và immediate 12 bit. Đích nhảy phải trong ROM và chia hết cho 4 sau quy tắc xóa bit 0 của JALR. Demo chỉ thực thi lệnh nhảy và báo đích, không chạy chương trình tiếp ở đích.

Ví dụ lỗi hợp lệ: `ADDI 0 2048`, `LW 512`, `ABC` phải bị từ chối. `JAL 2` gây fault alignment. Sau fault, console có cơ chế quay lại trạng thái nhận lệnh.

## 8. Xử lý sự cố

| Hiện tượng | Cách kiểm tra |
|---|---|
| `iverilog`/`vvp` not found | Cài Icarus, thêm đúng thư mục bin vào PATH, mở terminal mới hoặc truyền đường dẫn tuyệt đối |
| Python không chạy | Kiểm tra `python --version` hoặc `py -3 --version` |
| `Installed RTL differs` | Đồng bộ `Code/isa20_interactive/src` và `Code/src`, đặc biệt Datapath tối ưu timing |
| `FPGA/Code source mismatch` | Đồng bộ RTL/ROM đang dùng giữa `Code/src` và `Project_Capstone/src` |
| `$readmemh` không tìm thấy file | Kiểm tra thư mục làm việc `Code`, file `.mem`, đường dẫn tương đối `src/program_multi_mmio.mem` và file list Gowin |
| Không có COM | Kiểm tra cáp dữ liệu, Device Manager, driver WCH đúng chip |
| COM bị chiếm | Đóng chương trình serial khác đang sử dụng cùng COM |
| Không thấy ký tự khi gõ | Bật Local Echo trong Setup → Terminal |
| Có ký tự nhưng không phản hồi | Kiểm tra COM, 115200 8N1, Transmit CR, bitstream/top đúng; reset board, chờ 1 giây rồi `STATUS` |
| Lệnh hợp lệ báo ERROR lần đầu | Chờ phản hồi trước đó kết thúc, gõ tay, thử Enter một lần rồi nhập lại; lưu log nếu lỗi tái diễn. Có thể thử transmit delay ở mục 7.1 để chẩn đoán |
| Setup timing âm/Fmax dưới 50 MHz | Kiểm tra Datapath tối ưu mới nhất, file constraint và Timing Details; không coi build thành công là timing PASS |
| Sau tắt/bật nguồn lại ra bản cũ | SRAM mất cấu hình khi mất nguồn; xác minh đã nạp SPI Flash nếu cần chạy tự động |

## 9. Dành cho người duy trì repository

Trước khi commit bản Interactive, cần sao lưu RTL đang chạy đúng. Lấy các file từ bản đã build và test thực tế trên FPGA làm nguồn chuẩn, không ghi đè bằng bản add-on cũ.

### 9.1. Đồng bộ RTL đã tối ưu

Đóng Gowin. Từ **gốc repository**, xác nhận các thư mục add-on đã được giải nén vào `Code` và 7 RTL trong `Project_Capstone/src` là bản đã kiểm thử. Sau đó dùng PowerShell:

```powershell
$files = @(
    'isa20_encoder.v', 'isa20_interactive_parser.v',
    'isa20_interactive_tx.v', 'isa20_interactive_engine.v',
    'datapath_isa20_interactive.v', 'cpu_isa20_interactive.v',
    'uart_cpu_isa20_interactive_top.v'
)
foreach ($f in $files) {
    Copy-Item "Project_Capstone/src/$f" "Code/src/$f" -ErrorAction Stop
    Copy-Item "Project_Capstone/src/$f" "Code/isa20_interactive/src/$f" -ErrorAction Stop
}
```

Script `run_interactive.py` kiểm tra các bản RTL add-on và mô phỏng giống nhau (chuẩn hóa LF/CRLF). Không cần chạy `install.py` khi đã clone bản tích hợp đầy đủ. Installer ban đầu có kiểm tra phiên bản nền v2 và từ chối ghi đè bản tùy chỉnh; không dùng nó để quay về Datapath cũ.

### 9.2. Những file cần đưa lên GitHub

- `README.md` tại gốc repository (hoặc đặt trong `Code` nếu muốn tài liệu riêng cho mã nguồn).
- `Code/src/` gồm RTL đang dùng và ROM; `Code/tb/` gồm cả `tools/asm20.py` và file `.mem` test.
- `Code/v2/`, `Code/isa20_verify/`, toàn bộ `Code/isa20_interactive/` (src, sim, tools, vectors).
- `Project_Capstone/Project_Capstone.gprj` đã thêm các RTL Interactive; toàn bộ source cần thiết trong `Project_Capstone/src/`, đặc biệt `.cst`, `.sdc`, `.mem`.
- Nếu cần, lưu báo cáo timing và UART log minh chứng trong thư mục tài liệu riêng, không đưa toàn bộ file build trung gian lên repo.

Nên loại khỏi Git các thư mục/file sinh tự động như `Code/out/`, `Code/build/`, `Project_Capstone/impl/`, `.gprj.user`, `*.vvp`, `*.vcd`, `__pycache__/`. Thêm vào `.gitignore` phù hợp; lưu ý `.gitignore` không tự bỏ các file đã được track. Không dùng lệnh xóa hàng loạt khi chưa kiểm tra.

Sau khi chạy regression và xác nhận hardware, kiểm tra diff rồi stage những file chủ đích:

```powershell
git status
git diff
git add README.md Code/isa20_interactive Code/isa20_verify
# Chỉ stage tiếp sau khi kiểm tra thay đổi source và constraint:
git add Code/src Code/tb Code/v2 Project_Capstone/src Project_Capstone/Project_Capstone.gprj
git diff --cached --stat
git diff --cached --name-only
git commit -m "Finalize ISA20 interactive FPGA demo and setup guide"
git push -u origin HEAD
```

Nếu đặt README trong Code thay vì gốc, thay `README.md` trong lệnh stage bằng `Code/README.md`. Nếu repository có thay đổi từ thành viên khác, tích hợp chúng theo quy trình của nhóm; không force push.

### 9.3. Trạng thái xác minh

Theo kết quả thực nghiệm của nhóm ngày 24/11/2026: UART trả về kết quả đúng cho 20/20 loại lệnh Interactive đã thử, Calculator, SUM, FIB, TEST20, HELP, STATUS và CLEAR. Timing 50 MHz được xác nhận đạt sau khi tối ưu Datapath. Hiện tượng một số lệnh hợp lệ bị từ chối ở lần nhập đầu từng xuất hiện, nhưng không tái hiện trong các bài thử reset/idle tiếp theo; nguyên nhân chưa được xác định. Cần giữ log và theo dõi khi demo.

Kết quả trên không thay thế cho regression trên bản mã nguồn cuối cùng. Chạy mục 5.3–5.4 trên bản clone sạch, kiểm tra Timing Report mới và xác nhận power cycle sau khi nạp Flash trước khi công bố bản phát hành cuối.
