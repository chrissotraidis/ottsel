#!/usr/bin/env python3
"""Prove input-driven target movement on the running iPad lane with a controlled A/B.

The route driver shows the frontend accepts the menu edges; this probe shows the *game* reacts to the
pad.  It uses the bounded world-position trace that the target arms at spawn for 2400 frames
(`goal_src/jak1/engine/gfx/shadow/shadow.gc`: `OTTSEL TARGET POS: t=(~f,~f,~f) pad=~f`, one line in
sixteen, after collision has finalized) and compares a held left stick against a neutral pad in the same
run, so no cross-run difference or screenshot judgement is involved.

Jak 1 reads the left analog stick, which the shell derives from A/D/W/S, so the hold triggers are
`ottsel-hold-stick-left/right` (src/shell/main.cpp).  Route evidence only: not playability acceptance.
"""
import argparse
import json
from pathlib import Path
import re
import subprocess
import time

POS = re.compile(r"OTTSEL TARGET POS: t=\((-?[0-9.]+),(-?[0-9.]+),(-?[0-9.]+)\) pad=([0-9.]+)")


def simctl(*args):
    return subprocess.check_output(["xcrun", "simctl", *args], text=True).strip()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("udid")
    parser.add_argument("--route", action="store_true", help="drive title -> New Game first")
    parser.add_argument("--seconds", type=float, default=15.0, help="length of each held/neutral phase")
    parser.add_argument("--screenshots", type=Path,
                        help="capture <prefix>-<phase>-before/mid/after.png around every phase")
    parser.add_argument("--phases", default="neutral-a::15,stick-left:ottsel-hold-stick-left:15,"
                                           "neutral-b::8,stick-right:ottsel-hold-stick-right:15",
                        help="name:trigger:seconds list; an empty trigger is a neutral window")
    args = parser.parse_args()

    devices = json.loads(simctl("list", "devices", "--json"))["devices"]
    booted = [d["udid"] for group in devices.values() for d in group if d["state"] == "Booted"]
    if booted != [args.udid]:
        raise SystemExit(f"Expected only {args.udid} booted; found {booted}")
    data = Path(simctl("get_app_container", args.udid, "com.ottsel.shell", "data"))
    writable = data / "Library/Application Support/local.ottsel/OttselShell"
    log = writable / "ottsel-runtime.log"

    stale = list(writable.glob("ottsel-hold-*")) + list(writable.glob("ottsel-press-*"))
    if stale:
        raise SystemExit(f"Existing input triggers must be reconciled first: {stale}")

    subprocess.run(["xcrun", "simctl", "terminate", args.udid, "com.ottsel.shell"],
                   capture_output=True)
    time.sleep(1)
    import os
    out = subprocess.run(["xcrun", "simctl", "launch", args.udid, "com.ottsel.shell"],
                         env={**os.environ, "SIMCTL_CHILD_OTTSEL_TRACE_INPUT": "1"},
                         check=True, capture_output=True, text=True).stdout.strip()
    pid = out.rsplit(":", 1)[-1].strip()
    print(f"launched {out}", flush=True)

    deadline = time.monotonic() + 90
    while time.monotonic() < deadline:
        text = log.read_text(errors="replace") if log.exists() else ""
        if f"OTTSEL RUNTIME BOOT: pid={pid} " in text and "title-wait-ready" in text:
            break
        time.sleep(0.3)
    else:
        raise SystemExit("No fresh title-wait-ready state within 90 seconds")
    print("title-wait-ready", flush=True)

    if args.route:
        subprocess.run(["python3", str(Path(__file__).with_name("replay-ios-normal-route.py")),
                        args.udid], check=True)

    # The target arms the trace at spawn and prints one sample every sixteen frames.
    deadline = time.monotonic() + 120
    while time.monotonic() < deadline:
        text = log.read_text(errors="replace") if log.exists() else ""
        if "OTTSEL TARGET POS" in text:
            break
        time.sleep(0.5)
    else:
        raise SystemExit("The target-position trace never armed within 120 seconds")

    # Let the level transition and intro settle first: the first samples of a fresh level jump as the
    # target is spawned and reset, and a control window inside that is worthless.
    def all_samples():
        text = log.read_text(errors="replace") if log.exists() else ""
        return [tuple(float(v) for v in m.groups()) for m in POS.finditer(text)]

    settled_since = None
    deadline = time.monotonic() + 120
    while time.monotonic() < deadline:
        points = all_samples()
        if len(points) >= 3 and points[-1] == points[-2] == points[-3] and points[-1][3] == 0.0:
            if settled_since is None:
                settled_since = time.monotonic()
            elif time.monotonic() - settled_since >= 4.0:
                print("target settled (four seconds without movement)", flush=True)
                break
        else:
            settled_since = None
        time.sleep(0.5)
    else:
        print("warning: the target did not report a settled neutral window; measuring anyway", flush=True)

    phases = []
    for spec in args.phases.split(","):
        parts = spec.split(":")
        if len(parts) != 3:
            raise SystemExit(f"bad --phases entry {spec!r}; expected name:trigger:seconds")
        name, trigger, seconds = parts[0].strip(), parts[1].strip() or None, float(parts[2])
        phases.append((name, trigger, seconds))

    def samples(offset):
        with log.open("rb") as stream:
            stream.seek(offset)
            raw = stream.read()
            end = stream.tell()
        return [tuple(float(v) for v in m.groups())
                for m in POS.finditer(raw.decode(errors="replace"))], end

    print(f"\n{'phase':<12} {'n':>4} {'x-range':>13} {'y-range':>11} {'z-range':>13} {'max-step':>10}  pad",
          flush=True)
    for name, trigger, seconds in phases:
        def shot(tag):
            if args.screenshots:
                out = Path(str(args.screenshots) + "-" + name + "-" + tag + ".png")
                out.parent.mkdir(parents=True, exist_ok=True)
                subprocess.run(["xcrun", "simctl", "io", args.udid, "screenshot", str(out)],
                               capture_output=True)

        offset = log.stat().st_size
        held = writable / trigger if trigger else None
        shot("before")
        if held:
            held.touch(exist_ok=False)
        time.sleep(seconds / 2)
        shot("mid")
        time.sleep(seconds / 2)
        if held:
            held.unlink(missing_ok=True)
        shot("after")
        time.sleep(1.5)  # let the release land in the next phase's window, not this one
        points, _ = samples(offset)
        if not points:
            print(f"{name:<12} {0:>4} {'-':>13} {'-':>13} {'-':>10}  (no samples)", flush=True)
            continue
        xs = [p[0] for p in points]
        ys = [p[1] for p in points]
        zs = [p[2] for p in points]
        steps = [max(abs(points[i + 1][0] - points[i][0]), abs(points[i + 1][2] - points[i][2]))
                 for i in range(len(points) - 1)]
        pads = sorted({p[3] for p in points})
        print(f"{name:<12} {len(points):>4} {max(xs) - min(xs):>13.1f} {max(ys) - min(ys):>11.1f} "
              f"{max(zs) - min(zs):>13.1f} {max(steps, default=0.0):>10.1f}  {pads}", flush=True)
        held = [p for p in points if p[3] >= 0.9]
        if len(held) >= 2:
            dx = held[-1][0] - held[0][0]
            dz = held[-1][2] - held[0][2]
            print(f"{'':12} held(pad>=0.9): n={len(held)} displacement=({dx:.1f}, {dz:.1f}) "
                  f"|d|={(dx * dx + dz * dz) ** 0.5:.1f}", flush=True)
    print("\nInterpretation: a held stick must move the target (non-zero x/z range and per-sample step);"
          "\nthe neutral phases must stay constant, and stick-left/stick-right must move it opposite ways.",
          flush=True)


if __name__ == "__main__":
    main()
