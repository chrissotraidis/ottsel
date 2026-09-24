#!/usr/bin/env python3
"""Region mean RGB of a capture, for matched before/after comparisons.

Decodes a PNG through the macOS sips tool (no third-party Python dependency) and
reports the mean RGB and pixel count of one region, given as fractions of the
image.  Used by the G2.2 Sky blend A/B: the same route point is captured before
and after a blend change and the sky band's mean RGB is compared.

Usage: measure-png-region-mean.py <png> [--x0 F] [--y0 F] [--x1 F] [--y1 F]
"""
import argparse
import struct
import subprocess
import sys
import tempfile
from pathlib import Path


def read_region(path, x0f, y0f, x1f, y1f):
    with tempfile.TemporaryDirectory() as tmp:
        bmp = Path(tmp) / "capture.bmp"
        subprocess.run(["sips", "-s", "format", "bmp", str(path), "--out", str(bmp)],
                       check=True, capture_output=True)
        data = bmp.read_bytes()
    if data[:2] != b"BM":
        raise SystemExit("sips did not produce a BMP")
    offset = struct.unpack_from("<I", data, 10)[0]
    width, height = struct.unpack_from("<IiiHH", data, 14)[1:3]
    bpp = struct.unpack_from("<H", data, 28)[0]
    if bpp not in (24, 32):
        raise SystemExit("unsupported BMP depth: %d" % bpp)
    stride = ((width * bpp // 8) + 3) // 4 * 4
    bottom_up = height > 0
    height = abs(height)
    step = bpp // 8
    x0, x1 = int(width * x0f), int(width * x1f)
    y0, y1 = int(height * y0f), int(height * y1f)
    total = [0, 0, 0]
    count = 0
    for y in range(y0, y1):
        row = offset + (height - 1 - y if bottom_up else y) * stride
        for x in range(x0, x1):
            p = row + x * step
            total[2] += data[p]
            total[1] += data[p + 1]
            total[0] += data[p + 2]
            count += 1
    if not count:
        raise SystemExit("empty region")
    return width, height, count, [t / count for t in total]




def read_image(path):
    with tempfile.TemporaryDirectory() as tmp:
        bmp = Path(tmp) / "capture.bmp"
        subprocess.run(["sips", "-s", "format", "bmp", str(path), "--out", str(bmp)],
                       check=True, capture_output=True)
        return bmp.read_bytes()


def decode(data, x0f=0.0, y0f=0.0, x1f=1.0, y1f=1.0):
    offset = struct.unpack_from("<I", data, 10)[0]
    width, height = struct.unpack_from("<IiiHH", data, 14)[1:3]
    bpp = struct.unpack_from("<H", data, 28)[0]
    stride = ((width * bpp // 8) + 3) // 4 * 4
    bottom_up = height > 0
    height = abs(height)
    step = bpp // 8
    return offset, width, height, stride, bottom_up, step


def diff_images(path_a, path_b, threshold, x0f, y0f, x1f, y1f):
    a, b = read_image(path_a), read_image(path_b)
    oa, wa, ha, sa, upa, st = decode(a, x0f, y0f, x1f, y1f)
    ob, wb, hb, sb, upb, _ = decode(b, x0f, y0f, x1f, y1f)
    if (wa, ha) != (wb, hb):
        raise SystemExit("size mismatch: %dx%d vs %dx%d" % (wa, ha, wb, hb))
    x0, x1 = int(wa * x0f), int(wa * x1f)
    y0, y1 = int(ha * y0f), int(ha * y1f)
    changed = 0
    total = 0
    delta = 0
    bx0, by0, bx1, by1 = wa, ha, -1, -1
    for y in range(y0, y1):
        ra = oa + (ha - 1 - y if upa else y) * sa
        rb = ob + (hb - 1 - y if upb else y) * sb
        for x in range(x0, x1):
            pa, pb = ra + x * st, rb + x * st
            da = abs(a[pa] - b[pb]) + abs(a[pa + 1] - b[pb + 1]) + abs(a[pa + 2] - b[pb + 2])
            total += 1
            if da > threshold:
                changed += 1
                delta += da
                bx0, by0 = min(bx0, x), min(by0, y)
                bx1, by1 = max(bx1, x), max(by1, y)
    if not changed:
        return total, 0, 0.0, None
    return total, changed, delta / (changed * 3.0), (bx0, by0, bx1, by1)


def main_diff(path_a, path_b, threshold, x0f, y0f, x1f, y1f):
    total, changed, mean_delta, box = diff_images(path_a, path_b, threshold, x0f, y0f, x1f, y1f)
    print("%s vs %s region=%d px changed>%d=%d (%.3f%%) mean|delta|/channel=%.3f box=%s"
          % (path_a.name, path_b.name, total, threshold, changed,
             100.0 * changed / max(1, total), mean_delta, box))


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("png", type=Path, nargs="+", help="one capture, or two to diff")
    ap.add_argument("--x0", type=float, default=0.0)
    ap.add_argument("--y0", type=float, default=0.0)
    ap.add_argument("--x1", type=float, default=1.0)
    ap.add_argument("--y1", type=float, default=0.35)
    ap.add_argument("--diff-threshold", type=int, default=24)
    args = ap.parse_args()
    if len(args.png) == 2:
        return main_diff(args.png[0], args.png[1], args.diff_threshold, args.x0, args.y0,
                         args.x1, args.y1)
    if len(args.png) != 1:
        raise SystemExit("give one capture to measure or two to diff")
    png = args.png[0]
    width, height, count, mean = read_region(png, args.x0, args.y0, args.x1, args.y1)
    print("%s %dx%d region=%d px meanRGB=(%.3f,%.3f,%.3f) mean=%.3f"
          % (png.name, width, height, count, mean[0], mean[1], mean[2],
             sum(mean) / 3.0))


if __name__ == "__main__":
    sys.exit(main())
