#!/usr/bin/env python3
"""Isolated signed-Gstate host fixture with genuine mixed-runtime prerequisites.

Never builds or launches the app/Simulator. Requires the existing h1 host runtime
archive and regenerates the module through the maintained emitter regression.
"""
import hashlib
import json
import pathlib
import shlex
import subprocess
import sys

repo = pathlib.Path(__file__).resolve().parents[1]
source = repo / "out/jak-project"
build = source / "build/h1"
output = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else
                      "/tmp/ottsel-recovery-2026-09-12/a11-gstate-activation").resolve()
output.mkdir(parents=True, exist_ok=True)
if not (build / "game/libruntime.a").is_file():
    raise SystemExit("Missing existing host runtime archive; build host runtime first")
text = (build / "build.ninja").read_text()


def values(target):
    start = text.index("build " + target + ":")
    end = text.find("\nbuild ", start + 1)
    result = {}
    for line in text[start:end].splitlines():
        if line.startswith("  ") and " = " in line:
            key, value = line.strip().split(" = ", 1)
            result[key] = shlex.split(value)
    return result


commands = []


def run(args, log, cwd=build):
    args = [str(a) for a in args]
    commands.append(args)
    (output / "commands.json").write_text(json.dumps(commands, indent=2) + "\n")
    log.write(shlex.join(args) + "\n")
    log.flush()
    subprocess.run(args, cwd=cwd, stdout=log, stderr=subprocess.STDOUT,
                   check=True, timeout=60)


with (output / "build.log").open("w") as log:
    run(["bash", repo / "scripts/test-a11-module.sh", output / "module"], log)
    config = values("game/CMakeFiles/runtime.dir/kernel/jak1/kscheme.cpp.o")
    flags = config["DEFINES"] + config["FLAGS"] + config["INCLUDES"]
    flags = [flag for flag in flags if flag != "-ggdb"]
    objects = []
    fresh = [repo / "test/a11_gstate_activation_test.cpp",
             source / "game/kernel/jak1/kscheme.cpp",
             source / "game/kernel/jak1/klink.cpp"]
    for index, path in enumerate(fresh):
        obj = output / f"source-{index}.o"
        # The signed module must come from the gstate.o this fixture loads; pass its current hash.
        gstate_sha = hashlib.sha256((source / "out/jak1/obj/gstate.o").read_bytes()).hexdigest()
        run(["xcrun", "--sdk", "macosx", "clang++", *flags,
             f'-DOTTSEL_EXPECTED_GSTATE_SHA256="{gstate_sha}"', "-c", path, "-o", obj], log)
        objects.append(obj)
    asm = source / "game/kernel/asm_funcs_arm64.s"
    run(["xcrun", "--sdk", "macosx", "clang", "-arch", "arm64", "-c", asm, "-o", output / "helpers.o"], log)
    objects.append(output / "helpers.o")
    linkage = values("game/ottsel-cgolink-dump")
    executable = output / "gstate-activation"
    # Arena FIRST: otherwise ld may place signed __GOAL before its pointer base.
    run(["xcrun", "--sdk", "macosx", "clang++", "-arch", "arm64", *objects,
         output / "module/gstate-arena-layout.s", output / "module/gstate.o",
         repo / "test/a11_gstate_method_driver.s", *linkage["LINK_LIBRARIES"],
         "-Wl,-dead_strip", "-Wl,-segprot,__ARENA,rw,rw", "-Wl,-segprot,__GOAL,rx,rx",
         "-o", executable], log)
    if executable.stat().st_size >= 100_000_000:
        raise SystemExit("Fixture exceeds repository artifact size policy")
    run(["codesign", "--force", "--sign", "-", executable], log)
    run(["codesign", "--verify", "--strict", executable], log)
    identities = fresh + [asm, build / "game/libruntime.a", executable]
    identities += [source / f"out/jak1/obj/{name}.o" for name in
                   ("gcommon", "gstring-h", "gkernel-h", "gkernel", "pskernel",
                    "gstring", "dgo-h", "gstate")]
    (output / "sha256.json").write_text(json.dumps({str(p): hashlib.sha256(p.read_bytes()).hexdigest()
                                                   for p in identities}, indent=2) + "\n")
with (output / "activation.log").open("w") as log:
    run([executable, source / "out/jak1/obj"], log, cwd=output)
for line in (output / "activation.log").read_text().splitlines():
    if line.startswith(("SIGNED ", "TYPED METHOD", "REGION ")):
        print(line)
print(f"Evidence: {output / 'activation.log'}")
