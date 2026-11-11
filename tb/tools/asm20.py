#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
asm20.py - Trinh dich mini cho 20 lenh cua CPU SEP490_G93.
Chi dung cho Tester, khong phai trinh dich RISC-V day du.

Ho tro:
  R-type : add, sub, and, or, xor, sll, srl, sra
  I-type : addi, andi, ori, xori
  Nho    : lw, sw (chi word, dia chi chia het cho 4)
  Nhanh  : beq, bne (nhan label)
  Nhay   : jal (nhan label), jalr rd, label(x0) hoac imm(rs1)
  Upper  : lui, auipc
  Gia    : nop, .word 0xFFFFFFFF
  Nhan   : ten:  (vi du ok_beq:)

Cach dung:
  python3 tb/tools/asm20.py tb/programs/test_all_20.S tb/programs/test_all_20.mem
  python3 tb/tools/asm20.py tb/programs/test_fault.S tb/programs/test_fault.mem

File .mem ra: moi dong 1 word hex 32-bit, khong co tien to 0x,
de $readmemh trong instruction_memory.v nap duoc.
"""
import re
import sys

REGS = {f"x{i}": i for i in range(32)}

R_OPS = {  # (funct7, funct3)
    "add": (0b0000000, 0b000), "sub": (0b0100000, 0b000),
    "sll": (0b0000000, 0b001), "xor": (0b0000000, 0b100),
    "srl": (0b0000000, 0b101), "sra": (0b0100000, 0b101),
    "or":  (0b0000000, 0b110), "and": (0b0000000, 0b111),
}
I_OPS = {"addi": 0b000, "xori": 0b100, "ori": 0b110, "andi": 0b111}
B_OPS = {"beq": 0b000, "bne": 0b001}


def reg(name):
    name = name.strip().lower()
    if name not in REGS:
        raise ValueError(f"Thanh ghi khong hop le: {name}")
    return REGS[name]


def imm_value(token, labels, pc, kind):
    """Giai ma immediate: so, hoac label.
    kind = 'abs' (jalr, lui): gia tri tuyet doi cua label.
    kind = 'rel' (beq/bne/jal): offset = dia chi label - PC hien tai.
    """
    token = token.strip()
    if token in labels:
        if kind == "abs":
            return labels[token]
        return labels[token] - pc
    return int(token, 0)


def parse_mem_operand(text):
    """'12(x5)' -> (12, 5). Nhan label cung duoc: 'done(x0)' -> ('done', 0)."""
    m = re.match(r"^\s*([^()]+)\((x\d+)\)\s*$", text.strip())
    if not m:
        raise ValueError(f"Toan hang nho khong hop le: {text}")
    return m.group(1).strip(), reg(m.group(2))


def clean_lines(path):
    lines = []
    with open(path, encoding="utf-8") as f:
        for raw in f:
            # Bo comment // va # (chu y: # khong xuat hien trong so).
            line = raw.split("//")[0].split("#")[0].strip()
            if line:
                lines.append(line)
    return lines


def first_pass(lines):
    """Thu thap label -> dia chi byte. Moi lenh/.word = 1 word = 4 byte."""
    labels, instrs, pc = {}, [], 0
    for line in lines:
        rest = line
        while ":" in rest:
            label, rest = rest.split(":", 1)
            label = label.strip()
            if not label.isidentifier():
                raise ValueError(f"Nhan khong hop le: {label}")
            if label in labels:
                raise ValueError(f"Nhan trung: {label}")
            labels[label] = pc
            rest = rest.strip()
            if not rest:
                break
        if rest:
            instrs.append((pc, rest))
            pc += 4
    return labels, instrs


def encode(pc, text, labels):
    parts = [p.strip() for p in re.split(r"[,\s]+", text) if p.strip()]
    op = parts[0].lower()

    if op == "nop":
        return 0x00000013
    if op == ".word":
        return int(parts[1], 0) & 0xFFFFFFFF

    if op in R_OPS:
        funct7, funct3 = R_OPS[op]
        rd, rs1, rs2 = reg(parts[1]), reg(parts[2]), reg(parts[3])
        return (funct7 << 25) | (rs2 << 20) | (rs1 << 15) | \
               (funct3 << 12) | (rd << 7) | 0b0110011

    if op in I_OPS:
        rd, rs1 = reg(parts[1]), reg(parts[2])
        imm = imm_value(parts[3], labels, pc, "abs") & 0xFFF
        return (imm << 20) | (rs1 << 15) | (I_OPS[op] << 12) | \
               (rd << 7) | 0b0010011

    if op == "lw":
        rd = reg(parts[1])
        imm_tok, rs1 = parse_mem_operand(" ".join(parts[2:]))
        imm = imm_value(imm_tok, labels, pc, "abs") & 0xFFF
        return (imm << 20) | (rs1 << 15) | (0b010 << 12) | (rd << 7) | 0b0000011

    if op == "sw":
        rs2 = reg(parts[1])
        imm_tok, rs1 = parse_mem_operand(" ".join(parts[2:]))
        imm = imm_value(imm_tok, labels, pc, "abs") & 0xFFF
        return ((imm >> 5) << 25) | (rs2 << 20) | (rs1 << 15) | \
               (0b010 << 12) | ((imm & 0x1F) << 7) | 0b0100011

    if op in B_OPS:
        rs1, rs2 = reg(parts[1]), reg(parts[2])
        off = imm_value(parts[3], labels, pc, "rel")
        if off % 2 or not -4096 <= off < 4096:
            raise ValueError(f"Offset branch khong hop le: {off} o '{text}'")
        off_u = off & 0x1FFF
        return ((off_u >> 12) << 31) | (((off_u >> 5) & 0x3F) << 25) | \
               (rs2 << 20) | (rs1 << 15) | (B_OPS[op] << 12) | \
               (((off_u >> 1) & 0xF) << 8) | (((off_u >> 11) & 1) << 7) | 0b1100011

    if op == "jal":
        rd = reg(parts[1])
        off = imm_value(parts[2], labels, pc, "rel")
        if off % 2 or not -(1 << 20) <= off < (1 << 20):
            raise ValueError(f"Offset jal khong hop le: {off} o '{text}'")
        off_u = off & 0x1FFFFF
        return ((off_u >> 20) << 31) | (((off_u >> 1) & 0x3FF) << 21) | \
               (((off_u >> 11) & 1) << 20) | (((off_u >> 12) & 0xFF) << 12) | \
               (rd << 7) | 0b1101111

    if op == "jalr":
        rd = reg(parts[1])
        imm_tok, rs1 = parse_mem_operand(" ".join(parts[2:]))
        imm = imm_value(imm_tok, labels, pc, "abs") & 0xFFF
        return (imm << 20) | (rs1 << 15) | (0b000 << 12) | (rd << 7) | 0b1100111

    if op in ("lui", "auipc"):
        rd = reg(parts[1])
        imm = imm_value(parts[2], labels, pc, "abs") & 0xFFFFF
        opcode = 0b0110111 if op == "lui" else 0b0010111
        return (imm << 12) | (rd << 7) | opcode

    raise ValueError(f"Lenh khong ho tro (chi 20 lenh cua CPU): {text}")


def main(argv):
    if len(argv) != 3:
        print("Dung: python3 asm20.py <vao.S> <ra.mem>")
        return 2
    labels, instrs = first_pass(clean_lines(argv[1]))
    words = [encode(pc, text, labels) for pc, text in instrs]
    with open(argv[2], "w", encoding="utf-8") as f:
        for w in words:
            f.write(f"{w:08x}\n")
    print(f"asm20: {len(words)} lenh, {len(labels)} nhan -> {argv[2]}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
