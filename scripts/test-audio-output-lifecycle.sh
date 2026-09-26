#!/bin/bash
set -eu
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
exec python3 "$repo_root/test/audio_output_lifecycle_test.py" "$repo_root/out/jak-project/game/sound/989snd/player.cpp"
