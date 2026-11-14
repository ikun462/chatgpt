#!/usr/bin/env python3
from pathlib import Path
import hashlib, json
root = Path(__file__).resolve().parents[1]
manifest = json.loads((root / 'docs/assets-manifest.json').read_text(encoding='utf-8'))
for entry in manifest:
    path = root / entry['path']
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    if digest != entry['sha256']:
        raise SystemExit(f'Asset verification failed: {path}')
    print('OK', entry['path'])
