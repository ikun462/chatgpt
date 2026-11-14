#!/usr/bin/env bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
python3 "$PROJECT_ROOT/tools/bootstrap.py"
cmake -S "$PROJECT_ROOT" -B "$PROJECT_ROOT/build/linux" -DCMAKE_BUILD_TYPE=Release
cmake --build "$PROJECT_ROOT/build/linux" --parallel 4
ctest --test-dir "$PROJECT_ROOT/build/linux" --output-on-failure -V
if [ -n "${GODOT_EXE:-}" ]; then
  "$GODOT_EXE" --headless --path "$PROJECT_ROOT/godot" --editor --import
  "$GODOT_EXE" --headless --path "$PROJECT_ROOT/godot" --script res://scripts/test_extension.gd
fi
