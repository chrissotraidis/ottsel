#!/usr/bin/env python3
"""Drive an already-running fresh diagnostic iPad app through the normal menus.

Uses the app's SDL input triggers; does not bypass GOAL frontend transitions.
This is route evidence only, not touch-control or playability acceptance.
"""
import argparse
import json
import re
from pathlib import Path
import subprocess
import time


def simctl(*args):
    return subprocess.check_output(["xcrun", "simctl", *args], text=True).strip()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("udid", help="the sole booted Simulator, with Ottsel already launched")
    parser.add_argument("--screenshots", type=Path, help="optional output filename prefix for title and menus")
    parser.add_argument("--stop-at", choices=["title", "main-menu", "save-menu"], help="stop at a menu for a bounded rendering diagnosis")
    parser.add_argument("--accept-slot", type=int, metavar="SLOT",
                        help="accept slot SLOT in the continue screen instead of \"Continue Without Saving\", and drive the frontend save to completion: the slot row opens the overwrite dialog (screen 11) when that slot already holds a save, the dialog is a yes/no row whose default is NO, so LEFT answers it and a second Cross enters `memcard-saving` (13), which is where `enter!` issues `auto-save-command 'save`")
    parser.add_argument("--load-slot", type=int, metavar="SLOT",
                        help="drive the title's LOAD GAME row (`*title*` index 1) and accept slot SLOT on the load screen (16), then report the continue point the lane loads (`OTTSEL CAMERA START: cp ...`) - the read-back half of the same save path")
    args = parser.parse_args()
    devices = json.loads(simctl("list", "devices", "--json"))["devices"]
    booted = [d["udid"] for group in devices.values() for d in group if d["state"] == "Booted"]
    if booted != [args.udid]:
        raise SystemExit(f"Expected only {args.udid} booted; found {booted}")
    data = Path(simctl("get_app_container", args.udid, "com.ottsel.shell", "data"))
    writable = data / "Library/Application Support/local.ottsel/OttselShell"
    pending = list(writable.glob("ottsel-hold-*")) + list(writable.glob("ottsel-press-*"))
    if pending:
        raise SystemExit(f"Existing input triggers must be reconciled first: {pending}")
    log = writable / "ottsel-runtime.log"
    deadline = time.monotonic() + 30
    while time.monotonic() < deadline:
        text = log.read_text(errors="replace") if log.exists() else ""
        if "title-wait-ready" in text:
            if "OTTSEL PC PROGRESS: accept screen=" in text:
                raise SystemExit("Menu input already exists in this log; use a fresh launch/log.")
            break
        time.sleep(0.3)
    else:
        raise SystemExit("No fresh title-ready state within 30 seconds")

    def press(button, expected):
        markers = (expected,) if isinstance(expected, str) else tuple(expected)
        offset = log.stat().st_size
        text = ""
        # BOT59/L5: a press file is one frame of button state, and this lane presents at
        # 5-8 fps, so a tap is usually missed.  The port documents the hold trigger as what
        # the game actually reads (src/shell/main.cpp, "a tap above is one frame; a hold is
        # what the game's own camera and movement code actually reads"), so hold the button
        # until the frontend's own edge appears, release *then*, and only afterwards require
        # the neutral pad sample that proves the release was delivered.  Waiting for the
        # neutral sample before releasing can never be satisfied by a hold (the pad is still
        # held), which is why this driver could not pass with hold semantics.
        trigger = writable / ("ottsel-hold-" + button)
        trigger.touch(exist_ok=False)
        edge = -1
        try:
            deadline = time.monotonic() + 30
            while time.monotonic() < deadline:
                time.sleep(0.2)
                with log.open("rb") as stream:
                    stream.seek(offset)
                    text = stream.read().decode(errors="replace")
                if edge < 0:
                    found = [index for index in (text.find(marker) for marker in markers) if index >= 0]
                    edge = min(found) if found else -1
                    if edge >= 0:
                        trigger.unlink(missing_ok=True)
                        print(f"released {button} on edge: {markers}", flush=True)
                        continue
                elif "OTTSEL INPUT: pad0 sample buttons=0x0 " in text[edge:]:
                    print(f"accepted and released {button}: {markers}", flush=True)
                    time.sleep(1)
                    return text
            print(f"no edge for {button} / {markers} within 30s; released anyway", flush=True)
            return text
        finally:
            trigger.unlink(missing_ok=True)

    def progress_since(offset):
        with log.open("rb") as stream:
            stream.seek(offset)
            return stream.read().decode(errors="replace")

    def memcard_files():
        root = writable / "OpenGOAL/jak1/saves"
        return sorted((path.name, path.stat().st_size, int(path.stat().st_mtime))
                      for path in root.rglob("*.bin"))

    def screen_probe():
        """Ask the port which screen it is on.  A D-pad-down press is harmless on a one-row
        yes/no list and on the slot lists' header rows, and the frame the button lands on is
        the only frame the menu traces (`OTTSEL PC PROGRESS: edge screen=...`, `progress-pc.gc:2208`),
        so the press doubles as the screen read."""
        text = press("down", "OTTSEL PC PROGRESS: edge screen=") or ""
        found = re.findall(r"edge screen=(\d+) index=(\d+)", text)
        return int(found[-1][0]) if found else None

    def capture(stage):
        if args.screenshots:
            output = Path(str(args.screenshots) + "-" + stage + ".png")
            output.parent.mkdir(parents=True, exist_ok=True)
            if output.exists():
                raise SystemExit(f"Refusing to overwrite evidence: {output}")
            simctl("io", args.udid, "screenshot", str(output))

    capture("title")
    if args.stop_at == "title": return
    # The current frontend proves the title consumed START with its own marker; the "screen=27"
    # form this driver used in August is not printed until the menu answers a later input.
    press("start", "OTTSEL TITLE: start edge in title-wait")
    capture("main-menu")
    if args.stop_at == "main-menu": return
    if args.load_slot is not None:
        # `*title*` is 0 new-game, 1 load-game, 2 options, 3 back (`progress-pc.gc:747`); the load screen
        # (16) rows are the same four slots plus `back`, so accepting a present slot sets
        # `memcard-loading` and the lane reports the continue point it restores.
        # A press frame logs the index it lands on *before* the handler moves it (the marker the route
        # driver's own `range(4)` loop relies on), so the DOWN is confirmed by index=0 and the following
        # Cross is confirmed by the accept carrying index=1.
        press("down", "edge screen=27 index=0 transition=#f")
        press("cross", "accept screen=27 index=1")
        # `enter!` puts the load screen's highlight on `last-slot-saved` (`progress.gc:279-287`), which is
        # 0 for a fresh process, so slot N is N DOWN presses later (each confirmed by the pre-press index).
        for index in range(args.load_slot):
            press("down", f"edge screen=16 index={index} transition=#f")
        offset = log.stat().st_size  # only the lines this accept produces count as load evidence
        press("cross", f"accept screen=16 index={args.load_slot}")
        deadline = time.monotonic() + 60
        while time.monotonic() < deadline:
            seen = progress_since(offset)
            if "OTTSEL CAMERA START: cp" in seen or "GAMEPLAY: enter" in seen:
                break
            time.sleep(1)
        seen = progress_since(offset)
        loaded = re.findall(r"OTTSEL CAMERA START: cp \"([^\"]+)\"", seen)
        levels = re.findall(r"GAMEPLAY: enter (\w+)", seen)
        print(f"LOAD slot {args.load_slot}: continue point(s) after the accept = {loaded or '(none)'}; "
              f"levels entered = {levels or '(none)'}", flush=True)
        return
    press("cross", "accept screen=27 index=0")
    capture("save-menu")
    if args.stop_at == "save-menu": return
    if args.accept_slot is not None:
        # Select a slot row on `save-game-title` (18) and drive the whole frontend save.
        # `progress-pc.gc:2833-2841` sends a present slot to `memcard-data-exists` (11) and a
        # free one straight to `memcard-saving` (13); the dialog row is a `yes-no` option
        # bound to `*progress-state* yes-no-choice` whose default is NO and which only the
        # LEFT/RIGHT handlers answer (`progress-pc.gc:2247/2339`), so LEFT is the YES answer.
        # Entering 13 is what issues `auto-save-command 'save` (`progress.gc:279-287`), so the
        # write happens after the second accept, not the first.
        before = memcard_files()
        offset = log.stat().st_size
        press("cross", f"accept screen=18 index={args.accept_slot}")
        time.sleep(4)  # a screen change has to run ~512 frames of game time before it settles
        screen = screen_probe()
        print(f"the port reports screen={screen} after the slot accept", flush=True)
        if screen == 11:
            print("Overwrite dialog: answering YES with a D-pad LEFT hold", flush=True)
            press("left", "edge screen=11 index=0")
            time.sleep(1)
            capture("save-dialog")
            press("cross", "edge screen=11 index=0")
            time.sleep(4)
            capture("save-result")
            print(f"the port reports screen={screen_probe()} after the YES accept", flush=True)
        elif screen == 13:
            print("Slot read as free; the accept entered memcard-saving directly", flush=True)
        else:
            print("No save-screen transition after the slot accept", flush=True)
        deadline = time.monotonic() + 20
        after = memcard_files()
        while time.monotonic() < deadline and after == before:
            time.sleep(1)
            after = memcard_files()
        trace = [line for line in progress_since(offset).splitlines()
                 if "PROGRESS" in line or "NOTIFY" in line or "emcard" in line]
        print("menu trace for this window:", flush=True)
        print("\n".join("  " + line for line in trace[-16:]) or "  (none)", flush=True)
        print(f"memcard before={before}", flush=True)
        print(f"memcard after ={after}", flush=True)
        print("SAVE WRITE: " + ("a memcard file changed" if after != before else
                                "no memcard file changed"), flush=True)
        return
    for index in range(4):
        press("down", f"edge screen=18 index={index} transition=#f")
    press("cross", "accept screen=18 index=4")
    print("Continue Without Saving accepted; verify intro completion and Training separately.")


if __name__ == "__main__":
    main()
