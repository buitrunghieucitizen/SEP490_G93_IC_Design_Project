#!/usr/bin/env python3
"""Activate SELFTEST20 ROM while keeping a backup of the active image."""
from pathlib import Path
import shutil
root = Path(__file__).resolve().parent.parent
source = root / 'selftest20' / 'SELFTEST20.mem'
target = root / 'src' / 'program_uart_mmio.mem'
backup = root / 'src' / 'program_uart_mmio.mem.backup_before_selftest20'
if not source.is_file() or not target.is_file():
    raise SystemExit('ERROR: Check that selftest20/ and src/ are alongside each other.')
words = [ln.strip() for ln in source.read_text(encoding='ascii').splitlines() if ln.strip()]
if len(words) != 256 or any(len(w)!=8 or any(c not in '0123456789abcdefABCDEF' for c in w) for w in words):
    raise SystemExit('ERROR: SELFTEST20.mem must contain 256 32-bit HEX words. Rebuild the ROM first.')
if not backup.exists():
    shutil.copy2(target,backup)
    print('Backup created:',backup)
else:
    print('Keeping existing backup:',backup)
shutil.copy2(source,target)
print('Active ROM:',source,'->',target)
print('REBUILD GOWIN BITSTREAM; test SRAM/JTAG first; leave working Flash intact.')
