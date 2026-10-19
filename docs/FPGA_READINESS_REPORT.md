# Báo cáo sẵn sàng FPGA Gowin

**Ngày đánh giá:** 2026-10-19  
**Target family:** Gowin GW5A.  
**Part number người dùng đã cung cấp trong hội thoại trước:** `GW5A-LV25UG324C2/I1` (device `GW5A-25A`, package `UBGA324`, speed `C2/I1`). Thông tin này chưa được cấu hình trong project Gowin/workspace để đối chiếu. **Tên board/revision, schematic, clock và pinout vẫn chưa có.** `constraints/` trống.

## Trạng thái hiện tại

| Hạng mục | Trạng thái |
|---|---|
| Verilog-2001 compile/simulation | Đã chạy Icarus regression thành công |
| Gowin EDA synthesis/P&R | Chưa chạy; không tìm thấy Gowin EDA executable trong PATH/các thư mục cài đặt đã dò |
| Device/package | Đã có part number do người dùng cung cấp; chưa có project Gowin/report để xác nhận target thực tế |
| Board, clock, reset polarity, I/O | Chưa biết |
| Pin constraints/timing constraints | Không có file trong `constraints/` |
| Resource/timing/Fmax | Chưa có số liệu và không được suy đoán |
| FPGA wrapper | Có `fpga_debug_wrapper`, compile/sim PASS; chưa map ra board pins |

## Synthesis compatibility audit

Các module dùng Verilog-2001 synthesizable RTL: `always @(*)` cho logic tổ hợp có default assignment, `always @(posedge clk)` cho trạng thái, nonblocking assignment trong sequential blocks. Không có `always_comb`, `always_ff`, interface/package hoặc testbench construct trong synthesizable source. Icarus biên dịch cả `fpga_debug_wrapper` và toàn core với `-g2001`.

`$readmemh` nằm trong initial block của instruction ROM. Đây là cách khởi tạo ROM phổ biến trong FPGA flow, nhưng cần xác nhận phiên bản Gowin EDA và memory inference report. DMEM và register file không được khởi tạo bằng RTL; DMEM không reset, RF reset đồng bộ.

## RAM inference và single-cycle tradeoff

- IMEM 256×32: ROM đọc bất đồng bộ từ `PC`; nội dung từ parameter `MEM_FILE`, mặc định `src/program.mem`.
- DMEM 1024×32: ghi đồng bộ, đọc bất đồng bộ; địa chỉ byte được kiểm tra căn chỉnh/range trước khi truy cập.
- Register file 32×32: hai cổng đọc bất đồng bộ và một cổng ghi đồng bộ; reset xóa cả register array.

Đọc bất đồng bộ của IMEM/DMEM là một rủi ro thực tế cho suy luận BSRAM vì block memory primitive có các mode/clock/latency cụ thể. Tool có thể dùng Distributed RAM hoặc LUT/Flip-Flop, hoặc không nhận ra pattern mong muốn. Không được kết luận BSRAM đã được sử dụng nếu chưa xem Gowin synthesis report. RF nhiều cổng đọc và reset toàn array cũng có thể ảnh hưởng memory inference.

Đường critical-path dự kiến dài nhất là LW: PC register → asynchronous IMEM → decode/control và RF read/immediate → address adder → asynchronous DMEM read → writeback mux → setup của RF. Đây là nhận định từ cấu trúc RTL, **không phải timing report**.

Để giữ CPI=1/Single-Cycle, chưa chuyển memory sang synchronous read và không thêm pipeline/stall/FSM. Nếu device/tool không ánh xạ được RAM bất đồng bộ trong giới hạn tài nguyên/timing, các lựa chọn là giữ dung lượng nhỏ và dùng logic/distributed memory nếu fit, dùng memory external phù hợp, hoặc tạo phiên bản kiến trúc mới dùng synchronous BSRAM với latency/multi-cycle/pipeline được công khai. Không trộn latency một chu kỳ của BSRAM vào core hiện tại rồi vẫn gọi là cùng Single-Cycle.

Tài liệu hãng cần đối chiếu: [Gowin BSRAM & SSRAM User Guide UG285](https://www.gowinsemi.com/en/document/main/database/1751/?order=DESC&page=1&support_search=&type=category), [Gowin Synthesis User Guide SUG550](https://www.gowinsemi.com/en/document/main/database/14/?page=2), và [GW5A Series Data Sheet DS1103](https://www.gowinsemi.com/en/document/main/database/2912/?page=1). Các trang hãng hiện liệt kê các tài liệu này; synthesis cho part cụ thể vẫn cần được chạy để kết luận mapping.

## Clock, reset và timing cần chuẩn bị

- Xác định clock pin và tần số oscillator từ board schematic/user guide.
- Tạo clock constraint với period/uncertainty đúng board; không đặt giá trị tùy đoán.
- Xác định reset button/polarity/debounce. Core nhận synchronous active-high; nếu board đưa reset bất đồng bộ/active-low, wrapper có thể cần synchronizer/debounce theo board.
- Tạo pin constraints chỉ từ schematic/pinout đúng package và board revision; không lấy pinout của board khác.
- Khai báo I/O standard/voltage đúng bank và điện áp board.
- Sau synthesis xem inferred memory, LUT/FF/BSRAM use; sau place-and-route xem critical path, slack và Fmax. Không báo cáo kết quả trước khi có tool report.

## FPGA wrapper

`fpga_debug_wrapper` nhận `debug_select[1:0]`: `00=PC`, `01=instruction`, `10=ALU result`, `11=writeback`. `debug_data[31:0]` và các cờ `halted/illegal_instr/misaligned/access_fault` được đưa ra ngoài. Đây là bus quan sát tổng quát, chưa gán LED/GPIO vì chưa có board pinout; demo wrapper đã được simulation kiểm tra.

## Cần người dùng cung cấp trước implementation

1. Mã part đầy đủ (family, density, voltage, package, speed grade) xác nhận trên chip/board.
2. Tên/model board, revision và schematic/pinout.
3. Clock nguồn/tần số và cách nối reset.
4. Gowin EDA version/license/installation hoặc báo cáo synthesis nếu đã chạy.
5. Chọn cách quan sát 32-bit debug bus (GPIO, LED multiplexing, UART hoặc logic analyzer) theo ngoại vi thực có.

Không tạo pin assignment, clock target, tài nguyên hay Fmax giả định trong lần này.
