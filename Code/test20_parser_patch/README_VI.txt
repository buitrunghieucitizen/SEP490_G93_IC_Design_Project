SEP490_G93 - Diagnostic patch TEST20 for MultiProgram v2
========================================================

WHY:
- TEST20 without result, then 2+3 still works means CPU is still executing
  the polling loop. One plausible cause is that the UART parser did not
  recognize the TEST20 command; this is not yet confirmed.
- The original parser already accepts TEST20 in simulation. This patch is
  for targeted diagnosis and increased input tolerance, not a proven fix.

CHANGES:
- TEST20<Enter>: unchanged
- TEST 20<Enter>: now accepted
- T<Enter>: short diagnostic alias for TEST20
- test20<Enter>: unchanged (case-insensitive)
- Other arithmetic, SUM N, FIB N: unchanged
- No change to CPU ALU, MMIO, Assembly, ROM, UART RX/TX, or FPGA pins.

INSTALL:
1. Unzip this folder as test20_parser_patch in PROJECT ROOT.
2. Make a backup of src\uart_command_parser_v2.v
3. Copy test20_parser_patch\patch\uart_command_parser_v2.v to
   src\uart_command_parser_v2.v (overwrite)
4. In PowerShell at project root:
   powershell -ExecutionPolicy Bypass -File .\test20_parser_patch\run_parser_patch_test.ps1
5. Also run the full v2 HDL tests:
   powershell -ExecutionPolicy Bypass -File .\v2\sim\run_v2_tests.ps1
6. Copy patched src\uart_command_parser_v2.v to Gowin source directory IF
   Gowin uses a separate source folder.
7. Rebuild (Synthesize, Place & Route, timing check), load SRAM/JTAG only.
   Do NOT overwrite the working FPGA SPI Flash image yet.
8. In Tera Term, type T then Enter. Expect Result: 20 on UART and 20 on LED.
   Then try TEST20 and TEST 20.

INTERPRETATION:
- T works, TEST20 does not: data reception / multi-character parsing issue.
- None work, but 2+3 does: check command_id, command_strobe, command_ready,
  debug_pc, halted, result_strobe in FPGA-specific diagnostic, and ROM map.
- All work: parser change solved practical operation, but exact earlier
  cause is still not established.

This patch is not yet HDL-verified in the author environment: you must run
Icarus on your PC before building a Gowin bitstream.
