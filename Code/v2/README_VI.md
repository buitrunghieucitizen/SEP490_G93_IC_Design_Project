# SEP490_G93 — MultiProgram v2 (1 bitstream, 6 loại lệnh)

## Mục tiêu

**Giữ nguyên CPU core, Control Unit, ALU và tất cả module v1.** v2 sử dụng tên top mới
`uart_cpu_mmio_v2_top` và một ROM mới `src/program_multi_mmio.mem`.
Sau một lần tổng hợp/nạp, có thể gõ nhiều lệnh qua Tera Term mà không phải thay ROM.

| Nhập (gõ rồi Enter) | Kết quả LED / UART TX |
|---|---|
| `15+7` | `22` / `Result: 22` |
| `7-15` | `-8` / `Result: -8` |
| `15*7` | `105` / `Result: 105` |
| `SUM 10` | `55` / `Result: 55` |
| `FIB 10` | `55` / `Result: 55` |
| `TEST20` | `20` / `Result: 20` (PASS 20 kiểm tra) |

UART: **115200 baud, 8 data bits, parity none, 1 stop bit, flow control none.**
Terminal: truyền Enter theo **CR**; CRLF cũng được. Tắt Local Echo (v1/v2 tự echo).
`TEST20` không in chữ PASS: kết quả số `20` là PASS, `-N` chỉ lỗi bài N.

### Các giới hạn cố ý của bản v2

- A, B và N nhập **0..9999**, không nhận số âm ở vị trí toán hạng.
- Phép toán tương tác: `+`, `-`, `*`; chưa có chia.
- **`FIB N` chấp nhận 0..39** để kết quả nằm trong giới hạn LED 8 chữ số.
- `SUM N` chấp nhận 0..9999, `A*B` cho 0..9999 mỗi toán hạng.
- Parser không tính đáp án; tính toán thực hiện bằng **mã lệnh RISC-V trong ROM**.
- Nhập sai cú pháp hoặc gửi lệnh trong khi CPU còn bận sẽ bị bỏ qua; terminal hiện tại chỉ echo, không báo lỗi cú pháp.
- V2 vẫn dùng ROM cố định và dispatcher; **chưa phải UART loader cho chương trình máy tùy ý**.
- Testbench HDL/Gowin trên board vẫn phải chạy tại máy người dùng; không nên coi các kết quả ISS là thay thế RTL simulation.

## Bước 0 — Sao lưu

Giữ nguyên project Gowin/Flash đang có bản Fibonacci và bản SELFTEST20 đã PASS.
**Không xóa hoặc ghi lại external SPI Flash trước khi xác nhận v2 trên SRAM.**
Gói này không thay đổi `uart_cpu_mmio_top.v`, `program_uart_mmio.mem`, `alu.v`, `control_unit.v`, `datapath_mmio.v`.

## Bước 1 — Giải nén và copy

Đặt **thư mục `v2`** cạnh các thư mục `src`, `tb`, `sim`, `toolchain` của dự án:

```
D:\SEP490_IC_Design\SEP490_G93_Upgrade_v1\SEP490_G93_Upgrade_v1\
  src\
  tb\
  toolchain\
  v2\
    src\
    programs\
    sim\
    tools\
```

Dùng CMD / PowerShell trong thư mục gốc dự án:

```cmd
python .\v2\tools\build_v2.py
python .\v2\tools\verify_iss.py
python .\v2\tools\install_v2.py
```

`build_v2.py` dùng `tb/tools/asm20.py` hiện có để biên dịch Assembly.
Kết quả ROM là **155 mã lệnh / 256 words**, phần trống được điền NOP `00000013`.
`verify_iss.py` là bộ kiểm tra phần mềm độc lập, không phải HDL test.
`install_v2.py` chỉ thêm 5 file `.v` mới và `src/program_multi_mmio.mem`.

## Bước 2 — HDL simulation trên Windows 11

Máy đã có Icarus Verilog 13.0:

```cmd
powershell -ExecutionPolicy Bypass -File .\v2\sim\run_v2_tests.ps1
```

Chờ ba testbench chạy **PASS**:

```
PASS tb_command_parser_v2
PASS tb_multi_cpu_v2
PASS tb_uart_multi_v2
ALL V2 HDL TESTS PASSED
```

- `tb_command_parser_v2`: kiểm tra cú pháp UART, số và busy.
- `tb_multi_cpu_v2`: kiểm tra CPU đọc MMIO và chương trình RISC-V, gồm SUM 9999, FIB 39, TEST20.
- `tb_uart_multi_v2`: kiểm thử end-to-end UART RX → CPU/MMIO → UART TX.

**Nếu có lỗi, giữ nguyên FPGA đang chạy và gửi nguyên log.** Không nạp thử khi HDL chưa PASS.

## Bước 3 — Gowin EDA

1. **Dùng bản copy của project Gowin hiện tại** để dễ rollback.
2. Bảo đảm ROM mới `src/program_multi_mmio.mem` nằm trong đường dẫn mà công cụ Gowin chạy `$readmemh`.
3. Thêm 5 nguồn HDL mới từ thư mục `src` vào Gowin Design Files:
   - `uart_command_parser_v2.v`
   - `data_memory_mmio_v2.v`
   - `datapath_mmio_v2.v`
   - `cpu_mmio_v2_top.v`
   - `uart_cpu_mmio_v2_top.v`
4. Chuyển Top Module thành **`uart_cpu_mmio_v2_top`**, không dùng top cũ.
5. Giữ nguyên file chân `Project_Capstone.cst` và clock 50 MHz (20 ns).
6. Synthesize → Place & Route → Generate Bitstream. **Kiểm tra STA**; đặc biệt vì v1 đã có rất ít setup margin.
7. Nạp file `.fs` **vào SRAM/JTAG để thử trước**. Không chọn `exFlash Bulk Erase` và không ghi Flash.

## Bước 4 — Demo với Tera Term

Nhập từng lệnh, nhấn Enter rồi **đợi kết quả `Result:` hiện ra** trước khi nhập lệnh tiếp.

```
15+7
Result: 22
7-15
Result: -8
15*7
Result: 105
SUM 10
Result: 55
FIB 10
Result: 55
TEST20
Result: 20
```

Đầu ra LED là cùng kết quả MMIO với UART TX.
Nếu nạp SRAM thành công nhưng tắt và bật nguồn lại hiện Fibonacci 55,
đó là bình thường: Flash cũ chưa bị ghi đè.

## Bản đồ module mới

```
Tera Term --> uart_rx.v --> uart_command_parser_v2.v
                           |   A, B, command_id, command_strobe
                           +--> uart_command_ready.v
                           | 
                           +--> cpu_mmio_v2_top.v
                                   | control_unit.v (v1 unchanged)
                                   + datapath_mmio_v2.v
                                       | pc.v / instruction_memory.v / register_file.v
                                       | immediate_gen.v / alu.v
                                       + data_memory_mmio_v2.v
                                             0x1000 operand A
                                             0x1004 operand B
                                             0x1008 command_id
                                             0x100C command_ready
                                             0x1010 CPU result
                                           |
                                           v
                                  signed_result_to_bcd8.v
                                        /            \
                            LED 7-seg (74HC595)    uart_result_tx.v --> UART TX
```

## Ghi vào report

- Nội dung ROM: 155 RISC-V instructions, tối đa 256 words/1 KiB.
- Six command IDs but only **20 lệnh ISA được hỗ trợ**: ADD,SUB,AND,OR,XOR,SLL,SRL,SRA,ADDI,ANDI,ORI,XORI,LW,SW,BEQ,BNE,JAL,JALR,LUI,AUIPC.
- Nhân là **shift-add bằng lệnh RV32I subset**, không có lệnh `MUL` phần cứng.
- Dùng cùng một bitstream, thay đổi dữ liệu và thuật toán bằng UART.
- Tài nguyên/timing cần trích **report P&R của v2**, không sử dụng số v1 để khẳng định v2.
- Kết quả mô phỏng độc lập (ISS/LLVM) không phải kết quả HDL hoặc FPGA.

**Khi chạy v2 lên board và ghi lại kết quả, gửi log hoặc ảnh để cập nhật Report 5–7.**
