#!/usr/bin/env python3
"""A1.4: audit the bounded GOAL call-trace ring against the emitted modules.

The ring records GOAL->GOAL calls as (site, target, caller-lr, pp).  site and
caller-lr are host addresses truncated to 32 bits; target is a GOAL function
value (an EE offset >= arena_size).  This tool decodes each entry against the
run's own SIGNED MODULE ENTER table and the emitted signed modules, then flags
implausible entries: a target outside every module's signed text, a target that
is not a function entry (word[-4] != function_type), a site/lr outside signed
text, or a caller-lr recorded as an EE value rather than a host address.

Usage:
  a11-goal-ring-audit.py --binary <OttselShell> --modules <emitted dir>
      --runtime-log <ott sel-runtime.log> --fault-log <ottosel-fault.log>
"""
import argparse, json, os, re, struct, subprocess, sys

FUNCTION_TYPE = 0x1BFEC4          # jak1 function Type identity (1834692)
ARENA_SIZE = 128 * 1024 * 1024    # EE_MAIN_MEM_SIZE; signed text starts above it

ENTER_RE = re.compile(
    r"SIGNED (?:MODULE |GSTATE |GSTRING )?ENTER:?\s*(?:name=(\S+)\s+)?entry=0x([0-9a-f]+) main=0x([0-9a-f]+) type=0x([0-9a-f]+)")
RING_RE = re.compile(
    r"site=0x(?:0x)?([0-9a-f]+) target=0x(?:0x)?([0-9a-f]+) "
    r"caller-lr=0x(?:0x)?([0-9a-f]+) pp=0x(?:0x)?([0-9a-f]+)")


def parse_enter(logpath):
    mods = []
    for ln in open(logpath, errors="replace"):
        m = ENTER_RE.search(ln)
        if m:
            name, entry, main = m.group(1), int(m.group(2), 16), int(m.group(3), 16)
            if name is None:
                name = "gstate" if "GSTATE" in ln else "gstring"
            mods.append({"name": name, "entry": entry, "main": main,
                         "type": int(m.group(4), 16)})
    return mods


def nm_symbols(binary):
    out = subprocess.run(["nm", binary], capture_output=True, text=True).stdout
    sym = {}
    for ln in out.splitlines():
        p = ln.split()
        if len(p) >= 3:
            try:
                sym[p[-1]] = int(p[0], 16)
            except ValueError:
                pass
    return sym


HOSTFRAME_RE = re.compile(r"host-frame 0x(?:0x)?([0-9a-f]+) (\S+)\+0x(?:0x)?([0-9a-f]+)")


def sym_addr(sym, name):
    """nm() prefixes C symbols with '_'; the app's own logs print them raw."""
    return sym.get(name, sym.get("_" + name))


def detect_slide(fault_log, sym):
    """nm() reports unslid vmaddrs; the log's host frames carry the runtime
    addresses.  The difference is the process's ASLR slide, and it is the same
    for every symbol, so any resolvable host frame calibrates the whole table."""
    votes = {}
    for ln in open(fault_log, errors="replace"):
        m = HOSTFRAME_RE.search(ln)
        if not m:
            continue
        host, name, off = int(m.group(1), 16), m.group(2), int(m.group(3), 16)
        base = sym_addr(sym, name)
        if base is None:
            continue
        slide = host - (base + off)
        votes[slide] = votes.get(slide, 0) + 1
    if not votes:
        return 0
    best = max(votes.items(), key=lambda kv: (kv[1], kv[0]))
    return best[0]


def text_spans(moddir, name):
    p = os.path.join(moddir, name + ".json")
    if not os.path.exists(p):
        return None
    d = json.load(open(p))
    segs = d["segments"]
    return {"seg0": segs[0]["text_size"], "seg2": segs[2]["text_size"],
            "tags": sorted(sl["offset"] for s in segs if s["id"] == 0
                           for sl in s.get("slots", [])
                           if sl.get("kind") == "immutable_function_tag")}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--binary", required=True)
    ap.add_argument("--modules", required=True, help="emitted/ dir of one modules.* transaction")
    ap.add_argument("--runtime-log", required=True)
    ap.add_argument("--fault-log", required=True)
    ap.add_argument("--tail", type=int, default=40)
    a = ap.parse_args()

    sym = nm_symbols(a.binary)
    arena_nm = sym_addr(sym, "ottsel_module_arena")
    if arena_nm is None:
        sys.exit("binary has no _ottsel_module_arena symbol")
    slide = detect_slide(a.fault_log, sym)
    arena = arena_nm + slide
    mods = parse_enter(a.runtime_log)
    if not mods:
        sys.exit("no SIGNED MODULE ENTER lines in " + a.runtime_log)

    # Every module's range comes from the binary: nm gives the signed-text
    # address of its code, and the run's arena base turns that into an EE
    # offset.  A module the run never entered still has a range, which is what
    # makes a target into a not-yet-entered module decidable.
    names = [m["name"] for m in mods]
    for s in sym:
        if s.startswith("_ottsel_module_") and s.endswith("_s0_code"):
            n = s[len("_ottsel_module_"):-len("_s0_code")]
            if n not in names and n.replace("_", "-") not in names:
                names.append(n)
    enter_base = {m["name"]: m["main"] for m in mods}

    table = []
    verified = [0]
    missing = []
    for name in names:
        sp = text_spans(a.modules, name)
        if (sp is None and name not in enter_base
                and sym_addr(sym, "ottsel_module_%s_s0_code" % name) is None):
            missing.append(name)
            continue
        s0 = sym_addr(sym, "ottsel_module_%s_s0_code" % name)
        s2 = sym_addr(sym, "ottsel_module_%s_s2_code" % name)
        if sp is None:
            sp = text_spans(a.modules, name.replace("_", "-"))
        span = (sp["seg0"] + sp["seg2"]) if sp else None
        if s0 is not None:
            base = s0 + slide - arena
            if s2 is not None and sp is not None:
                verified[0] += 1
                span = (s2 - s0) + sp["seg2"]
        else:
            base = enter_base[name]
            if sp is None:
                continue
        want = enter_base.get(name)
        if want is not None and s0 is not None and want != base:
            print("  note: %s ENTER base 0x%x != binary base 0x%x" % (name, want, base))
        entered = "" if want is not None else " (never entered)"
        table.append({"name": name + entered, "base": base,
                      "end": (base + span) if span else None,
                      "tags": sp["tags"] if sp else None, "host": s0})
    table.sort(key=lambda r: r["base"])
    # Text is packed in link order, so a module whose object was not written
    # into the final emission still ends where its successor begins.
    bank_end = sym_addr(sym, "ottsel_export_bank_begin")
    for i, r in enumerate(table):
        if r["end"] is None:
            if i + 1 < len(table):
                r["end"] = table[i + 1]["base"]
            elif bank_end is not None:
                r["end"] = bank_end + slide - arena
            else:
                r["end"] = r["base"]

    # The signed export banks are executable too: a table of 64-byte stubs, each
    # tagged like a function entry (tag word at +0, callable value at +4), which
    # dispatch through _ottsel_export_bank_targets.  A target there is an entry.
    bank_lo = bank_hi = None
    b0, b1 = sym_addr(sym, "ottsel_export_bank_begin"), sym_addr(sym, "ottsel_export_bank_end")
    if b0 is not None and b1 is not None:
        bank_lo, bank_hi = b0 + slide - arena, b1 + slide - arena

    def bank_stub(ee):
        if bank_lo is None or not (bank_lo <= ee < bank_hi):
            return None
        off = ee - bank_lo
        return off // 64 if off % 64 == 4 else False
    if missing:
        print("  note: no emitted object for %d module(s): %s"
              % (len(missing), ", ".join(sorted(missing)[:6])))

    def lookup(ee):
        hit = None
        for r in table:
            if r["base"] <= ee < r["end"]:
                hit = r
        return hit

    # Host-address halves map back through the arena's own low 32 bits.
    arena_low = arena & 0xFFFFFFFF

    def decode(ee):
        if not ee:
            return None, 0
        m = lookup(ee)
        return (m["name"] if m else None), ee - (m["base"] if m else 0)

    def entry_ok(ee):
        m = lookup(ee)
        if not m or not m["tags"] or (ee - m["base"]) % 4:
            return None
        return (ee - m["base"] - 4) in m["tags"]

    entries = []
    for ln in open(a.fault_log, errors="replace"):
        g = RING_RE.search(ln)
        if g:
            entries.append({"site": int(g.group(1), 16), "target": int(g.group(2), 16),
                            "lr": int(g.group(3), 16), "pp": int(g.group(4), 16),
                            "raw_site": g.group(1), "raw_lr": g.group(3)})
    if not entries:
        sys.exit("no ring entries in " + a.fault_log)
    entries = entries[-a.tail:]

    top = table[-1]
    print("binary slide=0x%x arena=0x%x (low32 0x%x) text=[0x%x,0x%x)"
          % (slide, arena, arena_low, table[0]["base"], top["end"]))
    print("%d modules entered (%d span-checked against the binary); %d ring entries"
          % (len(table), verified[0], len(entries)))
    print("%-3s %-26s %-30s %-26s %s" % ("#", "site", "target", "caller-lr", "flags"))
    bad = 0
    for i, e in enumerate(entries):
        site_ee = (e["site"] - arena_low) & 0xFFFFFFFF
        lr_ee = (e["lr"] - arena_low) & 0xFFFFFFFF
        sm = lookup(site_ee)
        tm = lookup(e["target"])
        stub = bank_stub(e["target"])
        flags = []
        if not sm:
            flags.append("SITE-OFF-CODE")
        if not tm and stub is None:
            flags.append("TARGET-OFF-CODE")
        elif tm:
            ok = entry_ok(e["target"])
            if ok is False:
                flags.append("TARGET-MID-FUNCTION")
            elif ok is None and not tm["tags"]:
                flags.append("ENTRY-UNCHECKED(no emitted object)")
        elif stub is False:
            flags.append("TARGET-IN-BANK-NOT-A-STUB")
        if e["lr"] == 0:
            flags.append("LR-ZERO")
        elif not lookup(lr_ee):
            flags.append("LR-NOT-HOST-ADDRESS(EE-valued?)")
        if flags:
            bad += 1
        s_s = "%s+0x%x" % (sm["name"], site_ee - sm["base"]) if sm else "0x%x" % site_ee
        if tm:
            t_s = "%s+0x%x" % (tm["name"], e["target"] - tm["base"])
        elif stub is not None and stub is not False:
            t_s = "export-bank+0x%x/stub%d" % (e["target"] - bank_lo, stub)
        else:
            t_s = "0x%x" % e["target"]
        lm = lookup(lr_ee)
        if lm:
            l_s = "%s+0x%x" % (lm["name"], lr_ee - lm["base"])
        else:
            l_s = "zero" if e["lr"] == 0 else "0x%x" % lr_ee
        print("%-3d %-26s %-30s %-26s %s" % (i, s_s, t_s, l_s, ",".join(flags) or "ok"))
    print("flagged %d of %d entries" % (bad, len(entries)))


if __name__ == "__main__":
    main()
