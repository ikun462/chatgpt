#!/usr/bin/env python3
"""Fetch only the pinned C++ bindings. NASA textures and the font are bundled."""
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'third_party' / 'godot-cpp'
REVISION = 'e4b7c25e721ce3435a029087e3917a30aa73f06b'
if not (DEST / 'CMakeLists.txt').exists():
    subprocess.run(['git', 'clone', '--depth', '1', '--branch', 'godot-4.4.1-stable',
                    'https://github.com/godotengine/godot-cpp.git', str(DEST)], check=True)
if (DEST / '.git').exists():
    actual = subprocess.check_output(['git', '-C', str(DEST), 'rev-parse', 'HEAD'], text=True).strip()
    if actual != REVISION:
        raise SystemExit(f'Unexpected godot-cpp revision: {actual}; expected {REVISION}. Preserve local edits before replacing it.')
print('godot-cpp 4.4.1 is ready. Bundled assets need no download.')
