#!/usr/bin/env python3
"""Install only NEW v2 files alongside original v1 sources; do not alter v1."""
from pathlib import Path
import shutil
v2=Path(__file__).resolve().parent.parent
root=v2.parent
src=root/'src'
if not src.is_dir():
    raise SystemExit('Place folder v2 in project root beside src, then run again')
for file in sorted((v2/'src').glob('*.v')):
    dst=src/file.name
    if dst.exists() and dst.read_bytes()!=file.read_bytes():
        bak=dst.with_name(dst.name+'.before_v2')
        if not bak.exists(): shutil.copy2(dst,bak)
    shutil.copy2(file,dst)
    print('Installed:',dst.relative_to(root))
rom=v2/'programs'/'MULTIPROGRAM.mem'
if len(rom.read_text().splitlines())!=256:
    raise SystemExit('Rebuild ROM first: python v2/tools/build_v2.py')
dst=src/'program_multi_mmio.mem'
if dst.exists() and dst.read_bytes()!=rom.read_bytes():
    bak=dst.with_name(dst.name+'.before_v2')
    if not bak.exists(): shutil.copy2(dst,bak)
shutil.copy2(rom,dst)
print('Installed:',dst.relative_to(root))
print('Original V1 and SELFTEST20 files not overwritten. Gowin top -> uart_cpu_mmio_v2_top')
