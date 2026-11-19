# Verification status at package creation

- PASS: Assembler `tb/tools/asm20.py` produced 155 instructions, 256 padded words.
- PASS: Independent RISC-V semantic interpreter executed 17 commands and all 20 instruction types; expected results matched.
- PASS: Negative control SLL→SRL fault in TEST20 detected as -6.
- PASS: LLVM RISC-V assembler/linker independently reproduced 155/155 instruction hex words from mini assembler.
- NOT RUN in authoring environment: Icarus Verilog testbenches (Icarus unavailable here); three simulations provided for user's Windows environment.
- NOT RUN: Gowin synthesis, P&R, timing, actual UART/LED on physical FPGA (must test using Gowin EDA + board).
- Previous v1 SELFTEST20 hardware PASS=20 is evidence for v1, **not automatically evidence for v2**.
