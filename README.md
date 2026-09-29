# RISC-V 32-bit Single-Cycle CPU
## Đồ án môn Thiết kế Vi mạch

---

## Cấu trúc Project

```
risc-v-cpu/
├── src/                    ← Source RTL (SystemVerilog)
│   ├── alu.sv              ✅ ALU — 10 operations
│   ├── register_file.sv    ✅ 32×32 Register File
│   ├── pc.sv               ✅ Program Counter
│   ├── instruction_memory.sv ✅ ROM (loads from .mem)
│   ├── data_memory.sv      ✅ RAM (LW/SW)
│   ├── immediate_gen.sv    ✅ Immediate Generator (5 formats)
│   ├── control_unit.sv     ✅ Control Unit (14 instructions)
│   ├── datapath.sv         ✅ Full Datapath
│   └── cpu_top.sv          ✅ Top-level
├── tb/                     ← Testbenches
│   ├── tb_alu.sv           ✅ ALU unit testbench
│   ├── tb_cpu.sv           ✅ Full CPU testbench
│   └── programs/
│       └── program.mem     ✅ Test program (hex)
├── out/                    ← Simulation output
│   ├── sim.vvp             (generated)
│   └── waveform.vcd        (generated)
├── docs/                   ← Documentation
├── constraints/            ← FPGA pin constraints
└── .vscode/                ← VS Code config
    ├── settings.json
    ├── tasks.json
    └── extensions.json
```

---

## Chạy Simulation

### Bước 1: Compile ALU testbench
```bash
iverilog -g2012 -o out/sim.vvp src/alu.sv tb/tb_alu.sv
```

### Bước 2: Run simulation
```bash
vvp out/sim.vvp
```

### Bước 3: Compile full CPU
```bash
iverilog -g2012 -o out/sim.vvp src/*.sv tb/tb_cpu.sv
vvp out/sim.vvp
```

### Bước 4: Xem waveform
```bash
gtkwave out/waveform.vcd
```

---

## Supported Instructions (Version 1 — 14 core)

| Instruction | Type | Opcode | Description |
|------------|------|--------|-------------|
| ADD        | R    | 0110011 | rd = rs1 + rs2 |
| SUB        | R    | 0110011 | rd = rs1 - rs2 |
| AND        | R    | 0110011 | rd = rs1 & rs2 |
| OR         | R    | 0110011 | rd = rs1 \| rs2 |
| XOR        | R    | 0110011 | rd = rs1 ^ rs2 |
| ADDI       | I    | 0010011 | rd = rs1 + imm |
| LW         | I    | 0000011 | rd = mem[rs1+imm] |
| SW         | S    | 0100011 | mem[rs1+imm] = rs2 |
| BEQ        | B    | 1100011 | if rs1==rs2: PC+=imm |
| BNE        | B    | 1100011 | if rs1!=rs2: PC+=imm |
| JAL        | J    | 1101111 | rd=PC+4; PC+=imm |
| JALR       | I    | 1100111 | rd=PC+4; PC=rs1+imm |
| LUI        | U    | 0110111 | rd = imm<<12 |
| AUIPC      | U    | 0010111 | rd = PC + imm<<12 |

---

## Tiến độ

- [x] Tuần 1-2: Setup, học ISA
- [x] Tuần 3: ALU module + testbench
- [x] Tuần 4: Register File + PC
- [x] Tuần 5: Immediate Gen + Control Unit
- [x] Tuần 6: Datapath integration
- [x] Tuần 7: CPU Top-level
- [ ] Tuần 8-11: Full verification
- [ ] Tuần 12: Synthesis (Gowin EDA)
- [ ] Tuần 13: FPGA implementation
- [ ] Tuần 14-15: Demo + Báo cáo
