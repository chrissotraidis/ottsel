#!/usr/bin/env python3
"""Drive the running iPad lane through the title and menu, one held press at a time.

The maintained route driver's August expectations (title -> Start -> Cross -> Down x4 -> Cross)
no longer match the current frontend, so this probe re-derives one edge per step from the app's own
`ottsel-runtime.log` (`OTTSEL PC PROGRESS: edge/accept screen=<N> index=<I>` plus
`OTTSEL ROUTE STATE`).  It drives the shell's hold triggers, so it never bypasses a GOAL frontend
transition.  Route evidence only: not touch-control, not playability acceptance.
"""
import argparse
import json
from pathlib import Path
import subprocess
import time

STEPS = {
    # step -> (trigger file, substrings that prove the frontend consumed the hold)
    # The title's own wait consumes START (title-obs.gc: "start edge in title-wait"), which
    # activates the PC progress screen; everything after that is logged by progress-pc.gc.
    "start": ("ottsel-hold-start", ("OTTSEL TITLE: start edge in title-wait",
                                    "OTTSEL PC PROGRESS:")),
    "cross": ("ottsel-hold-cross", ("OTTSEL PC PROGRESS:",)),
    "down": ("ottsel-hold-down", ("OTTSEL PC PROGRESS:",)),
    "up": ("ottsel-hold-up", ("OTTSEL PC PROGRESS:",)),
    "left": ("ottsel-hold-left", ("OTTSEL PC PROGRESS:",)),
    "right": ("ottsel-hold-right", ("OTTSEL PC PROGRESS:",)),
}
INTERESTING = ("PC PROGRESS", "ROUTE STATE", "TITLE:", "INPUT: pad0 sample")


def simctl(*args):
    return subprocess.check_output(["xcrun", "simctl", *args], text=True).strip()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("udid", help="the sole booted Simulator")
    parser.add_argument("--launch", action="store_true", help="terminate and relaunch the app first")
    parser.add_argument("--steps", required=True,
                        help="comma-separated holds, e.g. start,down,down,cross")
    parser.add_argument("--prefix", type=Path, help="screenshot prefix; one PNG per step plus -menu")
    parser.add_argument("--hold-seconds", type=float, default=30.0)
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

    pid = None
    if args.launch:
        subprocess.run(["xcrun", "simctl", "terminate", args.udid, "com.ottsel.shell"],
                       capture_output=True)
        time.sleep(1)
        import os
        launched = subprocess.run(["xcrun", "simctl", "launch", args.udid, "com.ottsel.shell"],
                                  env={**os.environ, "SIMCTL_CHILD_OTTSEL_TRACE_INPUT": "1"},
                                  check=True, capture_output=True, text=True).stdout.strip()
        pid = launched.rsplit(":", 1)[-1].strip()
        print(f"launched {launched}", flush=True)

    deadline = time.monotonic() + 90
    while time.monotonic() < deadline:
        text = log.read_text(errors="replace") if log.exists() else ""
        # Freshness: the app truncates the log on every launch, so require this launch's pid.
        fresh = pid is None or f"OTTSEL RUNTIME BOOT: pid={pid} " in text
        if fresh and "title-wait-ready" in text:
            if "PC PROGRESS" in text:
                raise SystemExit("Menu input already exists in this log; use --launch for a fresh log.")
            break
        time.sleep(0.3)
    else:
        raise SystemExit("No fresh title-wait-ready state within 90 seconds")
    print("title-wait-ready", flush=True)

    def capture(name):
        if args.prefix:
            output = Path(str(args.prefix) + "-" + name + ".png")
            output.parent.mkdir(parents=True, exist_ok=True)
            simctl("io", args.udid, "screenshot", str(output))
            print(f"screenshot {output}", flush=True)

    capture("title")
    offset = log.stat().st_size

    def new_lines():
        nonlocal offset
        with log.open("rb") as stream:
            stream.seek(offset)
            raw = stream.read()
            offset = stream.tell()
        return raw.decode(errors="replace")

    for step in args.steps.split(","):
        step = step.strip()
        if step not in STEPS:
            raise SystemExit(f"Unknown step {step!r}; expected one of {sorted(STEPS)}")
        trigger_name, markers = STEPS[step]
        # A hold is what this lane's 5-8 fps frontend reads; a one-frame tap is usually missed.
        trigger = writable / trigger_name
        trigger.touch(exist_ok=False)
        found = False
        try:
            deadline = time.monotonic() + args.hold_seconds
            while time.monotonic() < deadline:
                time.sleep(0.2)
                for line in new_lines().splitlines():
                    if any(token in line for token in INTERESTING):
                        print("   " + line.strip(), flush=True)
                    if any(marker in line for marker in markers):
                        found = True
                if found:
                    break
        finally:
            trigger.unlink(missing_ok=True)
        capture(step)
        if not found:
            raise SystemExit(f"no {markers} within {args.hold_seconds}s while holding {step}")
        print(f"accepted {step}", flush=True)
        time.sleep(2)  # leave the pad neutral so two holds cannot overlap into one 0x1* word
        for line in new_lines().splitlines():
            if any(token in line for token in INTERESTING):
                print("   " + line.strip(), flush=True)
    capture("final")


if __name__ == "__main__":
    main()
