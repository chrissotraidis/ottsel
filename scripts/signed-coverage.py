#!/usr/bin/env python3
"""How much of Jak 1's compiled code a signed module list covers.

  python3 scripts/signed-coverage.py [config/signed-game-strict.json]

Counts distinct code modules (container members whose body equals the compiled
out/jak1/obj/<name>.o; same-name art groups do not count) across every CGO/DGO, and
lists per container how many are in the signed list. Anything
unsigned is linked into writable memory and flipped executable at runtime, which a
physical iPhone/iPad refuses. G1 needs "unsigned 0".
"""
import importlib.util, json, pathlib, sys

repo = pathlib.Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("census", repo / "scripts/a11-corpus-census.py")
census = importlib.util.module_from_spec(spec)
spec.loader.exec_module(census)

listing = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "config/signed-game-strict.json")
signed = set(json.loads((repo / listing).read_text())["modules"])
jak1 = repo / "out/jak-project/out/jak1"
objects = {p.stem: p.read_bytes() for p in (jak1 / "obj").glob("*.o")}

seen, rows = set(), []
for container in sorted([*(jak1 / "iso").glob("*.CGO"), *(jak1 / "iso").glob("*.DGO")]):
    data, members, _ = census.read_container(container)
    code = sorted({m["name"] for m in members
                   if data[m["off"]:m["off"] + m["size"]] == objects.get(m["name"])})
    seen.update(code)
    rows.append(f"{container.name}:{sum(n in signed for n in code)}/{len(code)}")

print(f"{listing}: code modules {len(seen)}, signed {len(seen & signed)}, unsigned {len(seen - signed)}")
print(" ".join(rows))
sys.exit(0 if seen <= signed else 1)
