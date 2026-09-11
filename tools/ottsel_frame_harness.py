#!/usr/bin/env python3
"""Camera-free comparison harness for the Ottsel iPad Simulator lane.

BOT40 finding 2 proved the iPad camera is live: two launches of the same
installed binary differ on ~40% of pixels at the same wall-clock time, and five
shots inside one launch differ pairwise by 36-79%.  Any single-screenshot A/B is
therefore meaningless.  This tool compares *distributions* instead.

Two subcommands:

  capture  Launch the app once and take N screenshots across a fixed wall-clock
           window, then write per-shot statistics plus a downsampled signature.
  compare  Compare two capture directories and report whether their
           distributions are separable, or inside the noise floor.

Statistics are palette-free and cheap: non-background pixel fraction, mean
luminance, an upper-band ("sky") fraction, and a 32x32 signature grid used for
per-pixel distribution distance.  PNG decoding uses only zlib/struct so it runs
on the system python3 (no PIL, no numpy).
"""

import argparse
import json
import os
import shutil
import struct
import subprocess
import sys
import time
import zlib

DEFAULT_UDID = "08636791-2675-4675-8335-EF72EF954DCF"
DEFAULT_BUNDLE = "com.ottsel.shell"
RAW_W, RAW_H = 2420, 1668          # Simulator iPad Pro 11-inch (M4) framebuffer
SCALE_W = 900                      # normalised width every capture is resized to
SIG = 32                           # signature grid is SIG x SIG
NONBLACK_THRESHOLD = 40            # max(r,g,b) above this counts as content
SKY_BAND_FRACTION = 0.18           # top fraction of the frame treated as "sky"
SIGNATURE_LEVELS = 16              # signature is quantised to this many levels


# --------------------------------------------------------------------------
# PNG decode (RGBA8 / RGB8, filters 0-4)
# --------------------------------------------------------------------------

def read_png(path):
    data = open(path, "rb").read()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("%s is not a PNG" % path)
    pos = 8
    width = height = bitdepth = colortype = None
    idat = bytearray()
    while pos < len(data):
        (length,) = struct.unpack(">I", data[pos:pos + 4])
        ctype = data[pos + 4:pos + 8]
        chunk = data[pos + 8:pos + 8 + length]
        pos += 12 + length
        if ctype == b"IHDR":
            width, height, bitdepth, colortype = struct.unpack(">IIBB", chunk[:10])
        elif ctype == b"IDAT":
            idat += chunk
        elif ctype == b"IEND":
            break
    if bitdepth != 8:
        raise ValueError("unsupported bit depth %r" % bitdepth)
    bpp = {0: 1, 2: 3, 4: 2, 6: 4}[colortype]
    raw = zlib.decompress(bytes(idat))
    stride = width * bpp
    out = bytearray()
    prev = bytearray(stride)
    p = 0
    for _ in range(height):
        filt = raw[p]
        p += 1
        line = bytearray(raw[p:p + stride])
        p += stride
        if filt:
            for x in range(stride):
                a = line[x - bpp] if x >= bpp else 0
                b = prev[x]
                c = prev[x - bpp] if x >= bpp else 0
                if filt == 1:
                    line[x] = (line[x] + a) & 255
                elif filt == 2:
                    line[x] = (line[x] + b) & 255
                elif filt == 3:
                    line[x] = (line[x] + (a + b) // 2) & 255
                elif filt == 4:
                    pp = a + b - c
                    pa, pb, pc = abs(pp - a), abs(pp - b), abs(pp - c)
                    pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                    line[x] = (line[x] + pr) & 255
                else:
                    raise ValueError("bad PNG filter %r" % filt)
        out += line
        prev = line
    return width, height, bpp, bytes(out)


def frame_stats(path):
    width, height, bpp, px = read_png(path)
    total = width * height
    content = 0
    luma_sum = 0
    sky_total = 0
    sky_content = 0
    sky_rows = max(1, int(height * SKY_BAND_FRACTION))
    sig = [[0] * SIG for _ in range(SIG)]
    sig_count = [[0] * SIG for _ in range(SIG)]
    step = SIGNATURE_LEVELS / 256.0
    for y in range(height):
        row = y * width * bpp
        in_sky = y < sky_rows
        sy = min(SIG - 1, y * SIG // height)
        for x in range(width):
            i = row + x * bpp
            r, g, b = px[i], px[i + 1], px[i + 2]
            mx = r if r > g else g
            if b > mx:
                mx = b
            if mx > NONBLACK_THRESHOLD:
                content += 1
                if in_sky:
                    sky_content += 1
            luma_sum += (r * 299 + g * 587 + b * 114) // 1000
            if in_sky:
                sky_total += 1
            sx = min(SIG - 1, x * SIG // width)
            sig[sy][sx] += int(mx * step)
            sig_count[sy][sx] += 1
    grid = [sig[y][x] / sig_count[y][x] / max(1, SIGNATURE_LEVELS - 1)
            for y in range(SIG) for x in range(SIG)]
    return {
        "file": os.path.basename(path),
        "width": width,
        "height": height,
        "content_fraction": content / total,
        "mean_luma": luma_sum / total,
        "sky_fraction": (sky_content / sky_total) if sky_total else 0.0,
        "signature": [round(v, 4) for v in grid],
    }


# --------------------------------------------------------------------------
# capture
# --------------------------------------------------------------------------

def sh(cmd, check=True):
    proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    out = proc.stdout.decode("utf-8", "replace").strip()
    if check and proc.returncode != 0:
        raise RuntimeError("%s failed (%d): %s" % (" ".join(cmd), proc.returncode, out))
    return out


def disk_gate():
    line = sh(["bash", "-lc", "df -h / | tail -1"])
    packs = sh(["bash", "-lc",
                "ls .git/objects/pack/ 2>/dev/null | grep -c tmp_pack || true"])
    return line, int(packs or 0)


def capture(args):
    outdir = os.path.abspath(args.out)
    if os.path.exists(outdir):
        if not args.reuse:
            raise SystemExit("output dir exists: %s (pass --reuse to append)" % outdir)
    else:
        os.makedirs(outdir)
    shots_dir = os.path.join(outdir, "shots")
    os.makedirs(shots_dir, exist_ok=True)

    df_line, packs = disk_gate()
    print("disk: %s | tmp_pack=%d" % (df_line, packs))

    if args.trigger:
        container = sh(["xcrun", "simctl", "get_app_container", args.udid, args.bundle, "data"])
        writable = os.path.join(container, "Library", "Application Support", "local.ottsel",
                                "OttselShell")
        for name in args.trigger:
            path = os.path.join(writable, name)
            open(path, "w").close()
            print("armed trigger: %s" % path)

    if not args.no_launch:
        sh(["xcrun", "simctl", "terminate", args.udid, args.bundle], check=False)
        time.sleep(2)
        pid = sh(["xcrun", "simctl", "launch", args.udid, args.bundle])
        print("launched: %s" % pid)

    if args.start_delay:
        print("start delay %.1fs" % args.start_delay)
        time.sleep(args.start_delay)

    shots = []
    for i in range(args.shots):
        raw = os.path.join(shots_dir, "raw-%02d.png" % i)
        norm = os.path.join(shots_dir, "shot-%02d.png" % i)
        sh(["xcrun", "simctl", "io", args.udid, "screenshot", raw])
        sh(["sips", "-r", "-90", raw, "--out", norm], check=False)
        sh(["sips", "-Z", str(SCALE_W), norm], check=False)
        if os.path.exists(raw):
            os.remove(raw)
        stamp = time.strftime("%H:%M:%S")
        entry = frame_stats(norm)
        entry["t"] = stamp
        entry["index"] = i
        entry["sha256"] = sh(["shasum", "-a", "256", norm]).split()[0]
        shots.append(entry)
        print("shot %02d t=%s content=%.4f sky=%.4f luma=%.1f %s"
              % (i, stamp, entry["content_fraction"], entry["sky_fraction"],
                 entry["mean_luma"], entry["sha256"][:16]))
        if i + 1 < args.shots:
            time.sleep(args.interval)

    summary = {
        "label": args.label or os.path.basename(outdir),
        "udid": args.udid,
        "bundle": args.bundle,
        "shots": len(shots),
        "interval_s": args.interval,
        "start_delay_s": args.start_delay,
        "disk": df_line,
        "captured_at": time.strftime("%Y-%m-%d %H:%M:%S"),
        "frames": shots,
    }
    with open(os.path.join(outdir, "summary.json"), "w") as fh:
        json.dump(summary, fh, indent=2)
    spread(shots)
    print("wrote %s" % os.path.join(outdir, "summary.json"))


def spread(shots):
    for key in ("content_fraction", "sky_fraction", "mean_luma"):
        vals = [s[key] for s in shots]
        lo, hi = min(vals), max(vals)
        mean = sum(vals) / len(vals)
        var = sum((v - mean) ** 2 for v in vals) / len(vals)
        print("  %-16s mean=%.4f min=%.4f max=%.4f spread=%.4f sd=%.4f"
              % (key, mean, lo, hi, hi - lo, var ** 0.5))


# --------------------------------------------------------------------------
# compare
# --------------------------------------------------------------------------

def load_summary(path):
    if os.path.isdir(path):
        path = os.path.join(path, "summary.json")
    with open(path) as fh:
        return json.load(fh)


def compare(args):
    a = load_summary(args.a)
    b = load_summary(args.b)
    print("A=%s (n=%d)  B=%s (n=%d)" % (a["label"], len(a["frames"]),
                                        b["label"], len(b["frames"])))
    for key in ("content_fraction", "sky_fraction", "mean_luma"):
        va = [s[key] for s in a["frames"]]
        vb = [s[key] for s in b["frames"]]
        ma, mb = sum(va) / len(va), sum(vb) / len(vb)
        ra = max(va) - min(va)
        rb = max(vb) - min(vb)
        gap = abs(ma - mb)
        noise = max(ra, rb)
        verdict = "SEPARABLE" if gap > noise else "INSIDE NOISE FLOOR"
        print("  %-16s A=%.4f B=%.4f gap=%.4f within-run-spread=%.4f  -> %s"
              % (key, ma, mb, gap, noise, verdict))
    # signature distance, averaged over shot pairs
    if args.pairwise:
        tot = 0.0
        n = 0
        for sa in a["frames"]:
            for sb in b["frames"]:
                d = sum(abs(x - y) for x, y in zip(sa["signature"], sb["signature"]))
                tot += d / len(sa["signature"])
                n += 1
        print("  mean signature distance (A x B, %d pairs) = %.4f" % (n, tot / n))
        # baseline: within-A distances
        tot = 0.0
        n = 0
        fa = a["frames"]
        for i in range(len(fa)):
            for j in range(i + 1, len(fa)):
                d = sum(abs(x - y) for x, y in zip(fa[i]["signature"], fa[j]["signature"]))
                tot += d / len(fa[i]["signature"])
                n += 1
        if n:
            print("  within-A signature distance        (%d pairs) = %.4f" % (n, tot / n))


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)

    c = sub.add_parser("capture", help="launch once and capture a shot distribution")
    c.add_argument("--out", required=True, help="output directory")
    c.add_argument("--label", default=None)
    c.add_argument("--shots", type=int, default=6)
    c.add_argument("--interval", type=float, default=4.0)
    c.add_argument("--start-delay", type=float, default=45.0)
    c.add_argument("--trigger", action="append", default=[],
                   help="probe trigger filename in the app's writable dir (repeatable)")
    c.add_argument("--udid", default=DEFAULT_UDID)
    c.add_argument("--bundle", default=DEFAULT_BUNDLE)
    c.add_argument("--no-launch", action="store_true",
                   help="capture from the already-running app")
    c.add_argument("--reuse", action="store_true", help="allow an existing output dir")
    c.set_defaults(func=capture)

    p = sub.add_parser("compare", help="compare two capture directories")
    p.add_argument("a")
    p.add_argument("b")
    p.add_argument("--pairwise", action="store_true",
                   help="also report signature-grid distances")
    p.set_defaults(func=compare)

    args = ap.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()

