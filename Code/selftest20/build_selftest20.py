#!/usr/bin/env python3
"""Assemble SELFTEST20 with original project assembler and pad ROM to 256 words."""
from pathlib import Path
import subprocess,sys
root=Path(__file__).resolve().parent.parent
folder=root/'selftest20'
asm=root/'tb'/'tools'/'asm20.py'
source=folder/'SELFTEST20.S'
dest=folder/'SELFTEST20.mem'
if not asm.exists():
    raise SystemExit(f'Missing original project mini assembler: {asm}')
subprocess.run([sys.executable,str(asm),str(source),str(dest)],check=True,cwd=root)
words=[w.strip() for w in dest.read_text(encoding='ascii').splitlines() if w.strip()]
if len(words)>256:
    raise SystemExit(f'ROM exceeds 256 words: {len(words)}')
if any(len(w)!=8 or any(c not in '0123456789abcdefABCDEF' for c in w) for w in words):
    raise SystemExit('Invalid hex word in SELFTEST20.mem')
used=len(words)
words += ['00000013']*(256-used) # 20-instruction-compatible NOP (ADDI x0,x0,0)
dest.write_text(''.join(w.lower()+'\n' for w in words),encoding='ascii')
print(f'SELFTEST20 ROM: {used} program instructions, {len(words)} total words (1 KiB)')
