#!/usr/bin/env python3
"""Verify the checked-in SQLite runtime and self-hosted fonts before building."""
import hashlib
import json
from pathlib import Path

for name, expected in json.loads(Path('tool/asset-checksums.json').read_text()).items():
    actual = hashlib.sha256(Path(name).read_bytes()).hexdigest()
    if actual != expected:
        raise SystemExit(f'Asset checksum mismatch: {name}')
print('Browser database and font asset checksums verified.')
