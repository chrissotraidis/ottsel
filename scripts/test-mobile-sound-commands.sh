#!/bin/bash
set -eu
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
exec python3 "$repo_root/test/mobile_sound_commands_test.py" "$repo_root/out/jak-project/game/overlord/jak1/srpc.cpp" "$repo_root"
