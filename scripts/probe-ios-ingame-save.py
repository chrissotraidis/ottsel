#!/usr/bin/env python3
"""Drive the in-game pause's own save path and prove it writes the memcard (G2.1's last increment).

The pause is not a dead end.  Its rows come from the level task data rather than from
`*options-remap*`, so it has no option rows and prints no `edge screen=` trace, but
`respond-progress` (`progress.gc:1128-1135`) pushes `progress-screen settings` (3) on CIRCLE, and that
screen *is* bound to the main options table whose index 4 is `save-game` (`*main-options*` /
`*main-options-pc*`).  The shell maps Circle to the E key but exposes no hold trigger for it
(`src/shell/main.cpp:353-355`, hold table at 1288-1298); `ottsel-touch-circle` drives the same path a
finger takes, which is also the path an iPad player actually uses, so that is what answers the pause.

Sequence, every step confirmed by the port's own trace:

  gameplay  held left stick -> `OTTSEL TARGET POS ... pad=1.0` and a large target displacement
  start     -> `OTTSEL PROGRESS: entering screen=0`            (pause, progress-screen fuel-cell)
  circle    -> a DOWN probe reads `edge screen=3 index=0`        (settings)
  down x4   -> the CROSS accept reports `accept screen=3 index=4` (the SAVE GAME row)
  cross     -> `accept screen=17 index=0`                       (in-game save-game, slot rows)
  down      -> `edge screen=11`                                 (overwrite dialog, slot present)
  left,cross-> `memcard-saving` (13) and the bank file changes

Usage: python3 scripts/probe-ios-ingame-save.py <udid> [--route] [--screenshots PREFIX]
"""
import argparse
import hashlib
import json
import os
import re
import subprocess
import time
from pathlib import Path


def simctl(*args):
    return subprocess.check_output(["xcrun", "simctl", *args], text=True).strip()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("udid")
    parser.add_argument("--route", action="store_true", help="drive title -> New Game -> Training first")
    parser.add_argument("--stick-seconds", type=float, default=8.0, help="length of the movement phase")
    parser.add_argument("--settle", type=float, default=20.0, help="seconds to let the level settle first")
    parser.add_argument("--screenshots", type=Path, help="optional output filename prefix")
    args = parser.parse_args()

    devices = json.loads(simctl("list", "devices", "--json"))["devices"]
    booted = [d["udid"] for group in devices.values() for d in group if d["state"] == "Booted"]
    if booted != [args.udid]:
        raise SystemExit(f"Expected only {args.udid} booted; found {booted}")
    writable = (Path(simctl("get_app_container", args.udid, "com.ottsel.shell", "data"))
                / "Library/Application Support/local.ottsel/OttselShell")
    log = writable / "ottsel-runtime.log"
    stale = [path for pattern in ("ottsel-hold-*", "ottsel-press-*", "ottsel-touch-*")
             for path in writable.glob(pattern)]
    if stale:
        raise SystemExit(f"Existing input triggers must be reconciled first: {stale}")

    def window(offset):
        if not log.exists():
            return ""
        with log.open("rb") as stream:
            stream.seek(offset)
            return stream.read().decode(errors="replace")

    def wait_for(markers, timeout, offset):
        if isinstance(markers, str):
            markers = (markers,)
        seen = ""
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            time.sleep(0.25)
            seen = window(offset)
            for marker in markers:
                if marker in seen:
                    return marker, seen
        return None, seen

    def hold(button, markers, timeout):
        """The file's existence is the button state; without a marker it is held for the timeout."""
        offset = log.stat().st_size
        trigger = writable / ("ottsel-hold-" + button)
        trigger.touch(exist_ok=False)
        try:
            if markers:
                found, seen = wait_for(markers, timeout, offset)
            else:
                time.sleep(timeout)
                found, seen = None, window(offset)
        finally:
            trigger.unlink(missing_ok=True)
        time.sleep(1.0)
        print(f"  hold {button}: marker={found!r}", flush=True)
        return found, seen

    def touch(region, seconds):
        path = writable / ("ottsel-touch-" + region)
        path.touch(exist_ok=False)
        time.sleep(seconds)
        path.unlink(missing_ok=True)
        time.sleep(1.5)
        print(f"  touch {region}: held {seconds}s then released", flush=True)

    def shot(tag):
        if args.screenshots:
            out = Path(str(args.screenshots) + "-" + tag + ".png")
            out.parent.mkdir(parents=True, exist_ok=True)
            subprocess.run(["xcrun", "simctl", "io", args.udid, "screenshot", str(out)],
                           capture_output=True)

    def memcards():
        root = writable / "OpenGOAL/jak1/saves"
        state = {}
        for path in root.rglob("*.bin"):
            digest = hashlib.sha1(path.read_bytes()).hexdigest()[:12]
            state[path.name] = (path.stat().st_size, digest, int(path.stat().st_mtime))
        return state

    log.unlink(missing_ok=True)
    subprocess.run(["xcrun", "simctl", "terminate", args.udid, "com.ottsel.shell"], capture_output=True)
    time.sleep(1)
    launched = subprocess.run(["xcrun", "simctl", "launch", args.udid, "com.ottsel.shell"],
                              env={**os.environ, "SIMCTL_CHILD_OTTSEL_TRACE_INPUT": "1"}, check=True,
                              capture_output=True, text=True).stdout.strip()
    print(f"launched {launched}", flush=True)
    marker, _ = wait_for(("title-wait-ready",), 90, 0)
    print(f"title-ready: {marker!r}", flush=True)
    if marker is None:
        raise SystemExit("No fresh title-wait-ready state within 90 seconds")
    if args.route:
        subprocess.run(["python3", str(Path(__file__).with_name("replay-ios-normal-route.py")),
                        args.udid], check=False)
    marker, _ = wait_for(("GAMEPLAY: enter training",), 150, 0)
    print(f"training: {marker!r}", flush=True)
    time.sleep(args.settle)

    # Gameplay first, so the save below is a save after real mid-level progress.
    pos = re.compile(r"OTTSEL TARGET POS: t=\((-?[0-9.]+),(-?[0-9.]+),(-?[0-9.]+)\) pad=([0-9.]+)")
    offset = log.stat().st_size
    hold("stick-left", (), args.stick_seconds)
    points = [tuple(float(v) for v in m.groups()) for m in pos.finditer(window(offset))]
    if points:
        dx = points[-1][0] - points[0][0]
        dz = points[-1][2] - points[0][2]
        print(f"  gameplay: n={len(points)} pad-max={max(p[3] for p in points)} "
              f"displacement=({dx:.1f}, {dz:.1f}) length={(dx * dx + dz * dz) ** 0.5:.1f}", flush=True)
    else:
        print("  gameplay: no target samples in the held window", flush=True)
    shot("gameplay")

    before = memcards()
    hold("start", ("OTTSEL PROGRESS: entering screen=0",), 25)
    shot("pause")
    touch("circle", 4.0)
    for index in range(4):
        hold("down", (f"edge screen=3 index={index} transition=#f",), 12)
    shot("settings")
    hold("cross", ("accept screen=3 index=4",), 25)
    shot("save-row")
    # Slot rows on save-game (17) are the same four files; enter! highlights last-slot-saved (0 here).
    marker, seen = hold("cross", ("accept screen=17 index=",), 25)
    found = re.findall(r"accept screen=17 index=([0-9]+)", seen)
    print(f"  slot accepted on the in-game save screen: index={found[-1:] or 'none'}", flush=True)
    shot("slot")
    # A present slot raises the overwrite dialog (11); its single yes/no row cannot be moved by DOWN.
    marker, _ = hold("down", ("edge screen=11 index=0",), 12)
    if marker == "edge screen=11 index=0":
        hold("left", ("edge screen=11 index=0",), 15)
        shot("overwrite")
        hold("cross", ("edge screen=11 index=0",), 15)
    time.sleep(10)
    shot("after-save")

    after = memcards()
    print(f"memcard before={before}", flush=True)
    print(f"memcard after ={after}", flush=True)
    changed = sorted(name for name in set(before) | set(after) if before.get(name) != after.get(name))
    print("IN-GAME SAVE: " + (f"changed {changed}" if changed else "no memcard file changed"),
          flush=True)
    print("Verify the recorded continue point with scripts/verify-ios-save-continue-point.py",
          flush=True)


if __name__ == "__main__":
    main()

