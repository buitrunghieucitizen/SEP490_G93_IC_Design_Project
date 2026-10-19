# Báo cáo audit RTL

**Ngày audit:** 2026-10-19  
**RTL root:** `src/`  
**Ngôn ngữ:** Verilog-2001  
**Top lõi:** `cpu_top`; top demo tùy chọn: `fpga_debug_wrapper`

## Phạm vi đã đọc

Đã đọc chín module lõi `.v`, hai testbench cũ, hai program `.mem`, README, cấu hình VS Code, `.gitignore` và thư mục `constraints/`. Thư mục `docs/` ban đầu trống; không tìm thấy Report1/Report2/Report3 hoặc báo cáo Word. `constraints/` cũng không có file pin/timing constraint. Không đọc hoặc sửa các file `.sv` vì hiện source project dùng `.v`.

## Module hierarchy

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

fpga_debug_wrapper (top tùy chọn)
└── u_cpu: cpu_top
```

| Module | Vai trò, kết nối chính | Audit |
|---|---|---|
| `cpu_top` | Nối `control_unit` với `datapath`; đưa các tín hiệu lỗi và debug taps ra ngoài để wrapper/verification quan sát. | Các instance dùng named ports đã được compile lại sau khi thêm debug outputs. |
| `control_unit` | Decode opcode/funct3/funct7; phát register, memory, branch/jump và ALU controls. | Case decode chỉ cho phép đúng 20 instruction; encoding không hỗ trợ đặt `illegal_instr`, mọi side-effect control mặc định 0. |
| `datapath` | Đường PC → IMEM → RF/ImmGen → ALU → DMEM/writeback; chọn PC tiếp theo và quản lý fault/halt. | No pipeline registers; data/control combinational trong chu kỳ, trạng thái cập nhật ở cạnh lên. |
| `pc` | Thanh ghi PC 32-bit, reset đồng bộ active-high về 0. | `pc_next` giữ PC khi fault/halted. |
| `instruction_memory` | ROM 256×32 mặc định, đọc tổ hợp, `$readmemh(MEM_FILE)`. | Kiểm tra byte alignment và toàn bộ địa chỉ trước khi index; trả 0 khi địa chỉ không hợp lệ. |
| `immediate_gen` | Tạo immediate I/S/B/U/J. | Sign-extension/bit layout được kiểm tra bằng 12 test vectors. |
| `register_file` | 32×32, hai cổng đọc tổ hợp, một cổng ghi đồng bộ. | Reset xóa register array; x0 đọc 0 và bị chặn ghi. |
| `alu` | ADD/SUB, logic, shift; SLT/SLTU còn lại để mở rộng. | SRA dùng toán hạng signed; shift dùng `b[4:0]`. ALU dư không được decode thành instruction CPU. |
| `data_memory` | RAM 1024×32 mặc định, read tổ hợp, write tại posedge. | Kiểm tra căn chỉnh/range địa chỉ byte trước khi index; không reset/khởi tạo RAM. |
| `fpga_debug_wrapper` | Bọc CPU; `debug_select` chọn PC, instruction, ALU result hoặc writeback ra bus 32-bit; xuất fault flags. | Tách biệt logic wrapper khỏi datapath; chưa gán chân board. |

## Tập lệnh và control

Decoder chấp nhận: ADD, SUB, AND, OR, XOR, SLL, SRL, SRA; ADDI, ANDI, ORI, XORI; LW, SW; BEQ, BNE; JAL, JALR; LUI, AUIPC. I-type arithmetic không kiểm tra `funct7` vì các bit trên là immediate. R-type so sánh chính xác cả `funct7` và `funct3`. LOAD/STORE chỉ nhận `funct3=010`; branch chỉ nhận BEQ/BNE; JALR chỉ nhận `funct3=000`.

Các lệnh SLT/SLTU, SLTI/SLTIU, shift-immediate, byte/halfword memory, các branch khác, MUL/DIV không được CPU decode. ALU có thể giữ phép so sánh làm extension, nhưng các instruction tương ứng báo illegal.

## Clock/reset và dữ liệu

- Một clock `clk`; PC, RF write và DMEM write đều cập nhật tại cạnh lên.
- Reset đồng bộ, active-high. PC về 0; RF xóa toàn bộ; fault flags/halted xóa; không ghi RF/DMEM khi reset.
- DMEM giữ nội dung qua CPU reset. IMEM/DMEM read tổ hợp và DMEM write đồng bộ; đây là mô hình functional single-cycle.
- Địa chỉ CPU là byte address. LW/SW chỉ word-aligned; IMEM chỉ instruction 32-bit aligned. Địa chỉ cao được so range trước khi lấy word index, tránh high-bit alias.
- JALR mask bit 0 rồi kiểm tra căn chỉnh 4-byte; bit 1 không bị xóa. BEQ/BNE so sánh trực tiếp hai giá trị đọc RF. Branch target chỉ được kiểm tra khi taken.
- `illegal_instr`, `misaligned`, `access_fault`, `halted` là flags sticky đến reset. Lỗi chặn side effects, giữ PC và không phải trap chuẩn RISC-V.

## Vấn đề đã khắc phục / làm rõ

1. **Decode không chặt**: các mã R-type/I-type sai trước đây có thể vô tình bật `RegWrite`, opcode không biết bị coi như NOP. Sửa thành strict decode cho 20 lệnh; invalid controls giữ 0 và latch illegal/halt.
2. **Địa chỉ bộ nhớ alias**: chỉ dùng các bit địa chỉ thấp trước đây có thể làm địa chỉ ngoài vùng trỏ về đầu bộ nhớ. Sửa bằng full-address range/alignment checks trước truy cập array.
3. **Fault side effects/PC**: thêm gate commit và sticky status; lỗi branch/JAL/JALR target chặn cả link write; not-taken branch bỏ qua kiểm tra target.
4. **Mô tả phần cứng lỗi thời**: xóa ước lượng LUT/khẳng định ánh xạ GW1NR khỏi comment ALU/ImmediateGen/RegisterFile/PC. Chưa có số synthesis để hỗ trợ các nhận định đó.
5. **Debug FPGA**: thêm taps cần thiết từ datapath qua `cpu_top` và wrapper chọn tín hiệu, không dùng hierarchical reference trong RTL tổng hợp.

## Rủi ro còn lại

- `.mem` ngắn hơn 256 word gây cảnh báo `$readmemh`; các word không có trong file chưa được khởi tạo và có thể là X nếu chương trình chạy tuần tự vào đó. Chương trình demo kết thúc bằng vòng lặp.
- RTL dùng asynchronous ROM/RAM read. Không thể kết luận chúng ánh xạ vào BSRAM; Gowin EDA cần báo cáo synthesis. BSRAM mode, read latency và timing phải đối chiếu Gowin BSRAM/Synthesis guides.
- CPU hiện không có external bus/peripheral, trap vector, byte/halfword memory hoặc debug protocol.
- Các testbench dùng hierarchical memory/register reads để kiểm tra simulation; đó không phải giao diện phần cứng.

## Tài liệu Gowin cần dùng khi có thiết bị

- [Gowin BSRAM & SSRAM User Guide (UG285)](https://www.gowinsemi.com/en/document/main/database/1751/?order=DESC&page=1&support_search=&type=category)
- [Gowin Synthesis User Guide (SUG550)](https://www.gowinsemi.com/en/document/main/database/14/?page=2)
- [GW5A Series Data Sheet (DS1103)](https://www.gowinsemi.com/en/document/main/database/2912/?page=1)

Các liên kết trên là tài liệu hãng để kiểm tra mode/tài nguyên cho đúng device; chưa có report từ Gowin EDA trong workspace.
