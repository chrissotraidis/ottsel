#!/bin/bash
set -eu
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
exec python3 "$repo_root/test/mobile_merc_frame_test.py" "$repo_root/src/shell/metal_shell.mm"
