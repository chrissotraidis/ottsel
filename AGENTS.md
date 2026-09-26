# Ottsel operating rules

These rules are permanent for this repository's active native Jak 1 work.

1. Simulator recordings use only `xcrun simctl io <udid> recordVideo --codec=h264 <file> & rec=$!`, a bounded sleep of at most 30 seconds, `kill -INT "$rec"; wait "$rec"`, then `ls -lh` and `lsof -c SimRender | grep -E '\\.mov|\\.mp4' || echo "no live recording"`. Never use plain `kill`, `pkill`, SIGTERM, or `set -e` around a recorder. Record only under `/tmp/ottsel-video/`; an open SimRender movie handle blocks further recording.
2. Before product work, run `df -h / | tail -1` and count `.git/objects/pack/tmp_pack_*`. If free space is below 40 GB or any temporary pack exists, report exact paths and sizes and stop. Keep every worktree file below 100 MB, never use `git add -A`, and do not guess about disk causes.
3. Evidence is capped at one concise document per proven gate (60 lines maximum) and at most eight appended STATUS lines. Do not begin a new R-round until the `presentRGBA:`/`_MTLCommandEncoder` crash and the Jak 1 linker SIGABRT have each been root-caused and covered by a regression.

The product goal remains an honestly playable native Ottsel Jak 1 build on iPad first, followed by iPhone parity and physical-device readiness. A Mac boot, blank or partial Simulator frame, counters, logs, title screen, or first frame is not playability proof.
