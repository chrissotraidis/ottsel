#!/usr/bin/env python3
"""Report the iOS lane's memory-card state and its own load sequence.

Ottsel I2 (2026-09-22).  A Jak 1 save records a *continue point* plus the run's
clock counters, not the player's world transform, so state fidelity is checked by
comparing the continue point a bank records against the continue point the lane
itself reports after that slot is loaded (its own `OTTSEL CAMERA START: cp "X"`).

Usage:
  python3 scripts/verify-ios-save-continue-point.py <writable-dir> [--log <ottsel-runtime.log>]
  python3 scripts/verify-ios-save-continue-point.py <writable-dir> --slot 1 --expect-cp training-start

Measured layout (each file holds two copies of one block; block = McHeader 0x400 + bank 0x10000):
  +0x000 byte0       slot/valid marker written by the port
  +0x004 u32         clock field that tracks the lane's own `game-base`
  +0x020 byte        date field, low byte
  +0x4c0 char[..]    continue-point name
  +0x470/+0x480/+0x490/+0x4a0 u32  run counters
Measured 2026-09-23 (bank0 then bank1 changed across two saves of the same slot): each save *file* has two
banks, so UI slot index N uses bank<2N>.bin and bank<2N+1>.bin, and a save writes the one that was saved
least recently with an incremented save_count (`game/kernel/common/kmemcard.cpp:240-282`).  The earlier
"UI slot N maps to bank<N+1>.bin; bank0.bin is the auto-save card" reading was a misreading of this.
"""
import argparse
import os
import re
import struct
import sys
import time

BLOCK = 0x10400
CP_OFF = 0x4C0
COUNTERS = (0x470, 0x480, 0x490, 0x4A0)
BANK_RE = re.compile(r"bank(\d+)\.bin")


def banks(writable):
    saves = os.path.join(writable, "OpenGOAL", "jak1", "saves")
    found = []
    for root, _dirs, files in os.walk(saves):
        for name in files:
            m = BANK_RE.fullmatch(name)
            if m:
                found.append((int(m.group(1)), os.path.join(root, name)))
    return sorted(found)


def describe(path):
    with open(path, "rb") as fh:
        buf = fh.read()
    if len(buf) < BLOCK:
        return None
    cp = buf[CP_OFF:CP_OFF + 24].split(b"\x00")[0].decode("ascii", "replace")
    return {
        "size": len(buf),
        "marker": buf[0],
        "clock": struct.unpack_from("<I", buf, 4)[0],
        "date": buf[0x20],
        "cp": cp,
        "counters": [struct.unpack_from("<I", buf, off)[0] for off in COUNTERS],
    }


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("writable", help="the app's writable dir (contains OpenGOAL/jak1/saves)")
    ap.add_argument("--log", help="ottsel-runtime.log to print that lane's load sequence from")
    ap.add_argument("--slot", type=int, help="UI slot to check (maps to bank<slot+1>.bin)")
    ap.add_argument("--expect-cp", help="continue point the checked slot must record")
    args = ap.parse_args()

    found = banks(args.writable)
    if not found:
        raise SystemExit("no bank*.bin under %s" % os.path.join(args.writable, "OpenGOAL"))

    print("%-11s %-9s %6s %9s %5s %-16s %s" %
          ("bank", "mtime", "marker", "clock", "date", "continue-point", "counters"))
    for n, path in found:
        d = describe(path)
        if d is None:
            print("bank%-6d unreadable (%d bytes)" % (n, os.path.getsize(path)))
            continue
        print("bank%-6d %-9s %6d %9d %5d %-16s %s" % (
            n, time.strftime("%H:%M:%S", time.localtime(os.path.getmtime(path))),
            d["marker"], d["clock"], d["date"], d["cp"] or "-",
            " ".join(str(c) for c in d["counters"])))

    if args.log:
        print("\n--- lane load sequence (%s) ---" % args.log)
        with open(args.log, "r", errors="replace") as fh:
            for line in fh:
                if "OTTSEL CAMERA START: cp" in line or "GAMEPLAY: enter" in line:
                    print("   " + line.strip())

    if args.slot is not None:
        want = "bank%d.bin" % (args.slot + 1)
        hit = None
        for n, path in found:
            if os.path.basename(path) == want:
                hit = describe(path)
        if hit is None:
            raise SystemExit("no %s for UI slot %d" % (want, args.slot))
        print("\nUI slot %d -> %s records continue point %r" % (args.slot, want, hit["cp"]))
        if args.expect_cp:
            if hit["cp"] != args.expect_cp:
                raise SystemExit("MISMATCH: slot %d records %r, expected %r"
                                 % (args.slot, hit["cp"], args.expect_cp))
            print("OK: slot %d records %r" % (args.slot, args.expect_cp))
    return 0


if __name__ == "__main__":
    sys.exit(main())
