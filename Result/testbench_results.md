# Bang ket qua testbench (Icarus Verilog)

Du an: RISC-V 32-bit Single-Cycle CPU  |  Trinh bien dien: iverilog  |  Chay: vvp  |  Duong dan ket qua: Result\

## Tom tat

- Tong so testbench : 7
- PASS              : 7
- FAIL              : 0
- Khac / Loi        : 0

## Chi tiet tung testbench

| STT | Testbench | Ket qua | File waveform (.vcd) | Chi tiet |
|-----|-----------|---------|----------------------|----------|
| 1 | tb_alu | :white_check_mark: PASS | waveform_alu.vcd (co) | ALL TESTS PASSED! |
| 2 | tb_immediate_gen | :white_check_mark: PASS | waveform_immediate_gen.vcd (co) | tb_immediate_gen: PASS (12 checks) |
| 3 | tb_control_unit | :white_check_mark: PASS | waveform_control_unit.vcd (co) | tb_control_unit: PASS (28 checks) |
| 4 | tb_memory | :white_check_mark: PASS | waveform_memory.vcd (co) | tb_memory: PASS (12 checks, IMEM and DMEM) |
| 5 | tb_cpu | :white_check_mark: PASS | waveform_cpu.vcd (co) | tb_cpu: PASS (91 assertions, 20-instruction datapath and fault cases) |
| 6 | tb_demo_sum | :white_check_mark: PASS | waveform_demo_sum.vcd (co) | tb_demo_sum: PASS: 1+2+...+10 = 55 (x3, x4, DMEM[0]) |
| 7 | tb_fpga_debug_wrapper | :white_check_mark: PASS | waveform_fpga_debug_wrapper.vcd (co) | tb_fpga_debug_wrapper: PASS (4 debug mux selections and status) |

## Tap tin dien tu kem theo

Cac file .vcd duoc luu trong thu muc Result\ va co the mo bang GTKWave de quan sat waveform.

---
*Duoc tao boi script run_tests.ps1. Chay lai bao gio cung duoc: .\run_tests.ps1 tai goc du an.*
