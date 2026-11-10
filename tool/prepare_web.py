#!/usr/bin/env python3
"""Finalize offline assets after flutter build web. No runtime CDN dependency."""
import hashlib
import json
from pathlib import Path

root = Path('build/web')
files = sorted(p for p in root.rglob('*') if p.is_file() and p.name not in {'sw.js', 'precache.json'} and not p.name.endswith(('.map', '.dart', '.deps', '.symbols')))
digest = hashlib.sha256()
for path in files:
    digest.update(str(path.relative_to(root)).encode())
    digest.update(path.read_bytes())
(root / 'precache.json').write_text(json.dumps(['/' + str(p.relative_to(root)) for p in files]))
(root / 'sw.js').write_text(Path('web/sw.js').read_text().replace('__BUILD_ID__', digest.hexdigest()[:16]))
print(f'Prepared {len(files)} offline assets, build {digest.hexdigest()[:16]}')
