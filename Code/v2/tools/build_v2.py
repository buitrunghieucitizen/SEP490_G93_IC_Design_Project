#!/usr/bin/env python3
"""Generate single ROM containing dispatcher and SELFTEST20. Run from any cwd."""
from pathlib import Path
import subprocess, sys
v2=Path(__file__).resolve().parent.parent
root=v2.parent
asm=v2/'programs'/'MULTIPROGRAM.S'
out=v2/'programs'/'MULTIPROGRAM.mem'
assembler=root/'tb'/'tools'/'asm20.py'
if not assembler.is_file():
    raise SystemExit('Missing tb/tools/asm20.py -- copy v2 into original project first')
subprocess.run([sys.executable,str(assembler),str(asm),str(out)],check=True,cwd=root)
words=[l.strip() for l in out.read_text().splitlines() if l.strip()]
assert len(words)<=256, f'ROM overflow: {len(words)} words > 256'
assert all(len(x)==8 for x in words)
used=len(words)
words += ['00000013']*(256-used)
out.write_text(''.join(f'{line}\n' for line in words),encoding='ascii')
print(f'V2 ROM: {used} instructions, {len(words)} words/1024 bytes')
