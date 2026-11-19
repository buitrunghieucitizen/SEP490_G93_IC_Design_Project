# SEP490_G93 - SELFTEST20 (CPU/MMIO hardware self-test)

Muc tieu: chay 20 lenh RISC-V da ho tro tren `cpu_mmio_top.v`, xuat ket qua qua MMIO `0x1010` sang LED 7 doan va UART TX. Khong sua CPU RTL.

## 1. Cai AddOn
Giai nen ZIP. Copy nguyen thu muc `selftest20` vao trong thu muc goc `SEP490_G93_Upgrade_v1` (cung cap voi `src`, `tb`, `sim`, `toolchain`).

## 2. Khoi tao lai ROM tu Assembly
Mo PowerShell tai thu muc goc cua du an:

    python .\selftest20\build_selftest20.py

## 3. Chay Icarus Verilog simulation (truoc khi dong cham Gowin)

    powershell -ExecutionPolicy Bypass -File .\selftest20\run_selftest20.ps1

Ket qua mong doi: `tb_selftest20_mmio: PASS (20 instruction types, MMIO=20, RAM OK)` va `tb_selftest20_mmio: PASS negative control (detected SLL fault as -6)`. Duong negative control chi sua ROM cua bo mo phong, KHONG thay doi file `.mem` va KHONG nap len board.
Waveform PASS: `build/sim/waveform_selftest20_pass.vcd`. Waveform negative control: `build/sim/waveform_selftest20_negative.vcd`.
*Quan trong*: Neu script FAIL, dung tai day. KHONG nap len FPGA.

## 4. Chon ROM SELFTEST20 cho Gowin (chi sau khi simulation PASS)

    python .\selftest20\activate_selftest20.py

Script tao backup `src/program_uart_mmio.mem.backup_before_selftest20`, sau do copy `selftest20/SELFTEST20.mem` vao `src/program_uart_mmio.mem`.
Neu project Gowin dang dung ban sao khac, nho copy file ROM moi sang thu muc Gowin project va xac minh duong dan `MEM_FILE`.

## 5. Nap va test board
- Goi dau: test tren FPGA SRAM/JTAG truoc. KHONG can ghi de SPI Flash dang chay Fibonacci.
- Gowin: Synthesize -> Place & Route -> Generate Bitstream -> Programmer SRAM/JTAG.
- Khi FPGA khoi dong, khong can go cau lenh tren Tera Term.
- LED hien `20` va Tera Term phan hoi `Result: 20` (115200 8N1): all 20 check PASS.
- LED hien `-N` va UART `Result: -N`: check N FAIL. Neu khong ra gi: kiem tra clock/reset, IMEM path, faults va IO.
- Chup hinh LED, Tera Term, Programmer, waveform, log PASS de dua vao report.
- Day la self-test su dung phan cung thuc va phan mem Assembly thuc thi; KHONG phai Verilog hardcode phep toan.

## 6. Khoi phuc ROM Fibonacci
Doi file ROM trong `src` ve `programs/fibonacci_10.mem`:

    python .\toolchain\select_program.py fib

Neu dang dung project Gowin copy rieng, can chep lai ROM moi sang project do va rebuild bitstream. Luu y: SRAM programmer va Flash programmer la hai che do khac nhau.

## 7. Gioi han minh chung
- `20` la so loai lenh test qua, khong phai ket qua phep toan.
- SELFTEST20 tu kiem tra cac truong hop mau va target/link; KHONG chung minh moi gia tri dau vao/thoigian. Van can RTL regression/unit tests va static timing analysis.
- PASS tu simulation la bang chung mot tang, PASS tu board that la tang thu hai.
- Khong chon che do Erase Flash khi chi muon demo ban test tam thoi.
