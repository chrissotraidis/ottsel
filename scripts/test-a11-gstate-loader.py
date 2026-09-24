#!/usr/bin/env python3
"""Isolated signed-Gstate host fixture with genuine mixed-runtime prerequisites.

Never builds or launches the app/Simulator. Requires the existing h1 host runtime
archive and regenerates the module through the maintained emitter regression.
"""
import hashlib
import json
import pathlib
import re
import shlex
import struct
import subprocess
import sys

repo = pathlib.Path(__file__).resolve().parents[1]
source = repo / "out/jak-project"
build = source / "build/h1"
output = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else
                      "/tmp/ottsel-recovery-2026-09-12/a11-gstate-loader").resolve()
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


module_list = None
names = None
# Canonical lists the loader governance recognizes by name; the legacy
# --aggregate/--gcommon lanes select the two-module fixture without a JSON list.
full=["gcommon","gstring-h","gkernel-h","gkernel","pskernel","gstring","dgo-h","gstate"]
comparison=["gcommon","gstring","gstate"]
if "--module-list" in sys.argv[2:]:
    index=sys.argv.index("--module-list")
    if index+1==len(sys.argv):raise SystemExit("--module-list requires a path")
    module_list=pathlib.Path(sys.argv[index+1]).resolve()
    selected=json.loads(module_list.read_text())
    if not isinstance(selected,dict) or set(selected)!={"schema","modules"} or selected["schema"]!=1:
        raise SystemExit('Module list must be {"schema":1,"modules":[...]}')
    names=selected["modules"]
    if (not isinstance(names,list) or not names or len(set(names))!=len(names) or "gstate" not in names
            or not all(isinstance(n,str) and re.fullmatch(r"[A-Za-z0-9_-]+",n) for n in names)):
        raise SystemExit("Module list must be distinct non-empty names including gstate")
    if any(v in sys.argv[2:] for v in ("--gcommon","--aggregate")):
        raise SystemExit("Use either explicit module list or legacy fixture option")
with_kernel = names==full
with_ordered = names is not None and names!=full and names!=comparison
with_gcommon = (names is not None and not with_ordered) or "--gcommon" in sys.argv[2:]
aggregate = names is not None or with_gcommon or "--aggregate" in sys.argv[2:]
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
    # Isolate all compiler output and copy only the source being regenerated.
    # Other source/config inputs are read-through links; out is never linked.
    project = output / "regeneration-project"
    project.mkdir(exist_ok=True)
    (project / "out").mkdir(exist_ok=True)
    kernel = project / "goal_src/jak1/kernel"
    kernel.mkdir(parents=True, exist_ok=True)
    (kernel / "gcommon.gc").write_text((source / "goal_src/jak1/kernel/gcommon.gc").read_text())
    def overlay_inputs(original, destination):
        for path in original.iterdir():
            if path.name in (".git", "out", "build"):
                continue
            target = destination / path.name
            if target.is_dir() and not target.is_symlink():
                overlay_inputs(path, target)
            elif not target.exists():
                target.symlink_to(path, target_is_directory=path.is_dir())
    overlay_inputs(source, project)
    active_paths = [source / "out/jak1/obj/gcommon.o", source / "out/jak1/iso/KERNEL.CGO"]
    active_before = {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in active_paths}
    run([build / "goalc/goalc", "--proj-path", project, "--game", "jak1", "--isa", "arm64",
         "--cmd", '(begin (load-project "goal_src/jak1/game.gp") (make "out/jak1/obj/gcommon.o" :force #t))'], log, cwd=project)
    regenerated = project / "out/jak1/obj/gcommon.o"
    if not regenerated.is_file() or active_before != {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in active_paths}:
        raise SystemExit("Isolated regeneration failed or active object/bundle changed")
    object_directory = output / "fixture-objects"
    object_directory.mkdir(exist_ok=True)
    # Every lane keeps the canonical eight objects available: the non-ordered
    # lanes still link those prerequisites. A selected registry adds its own
    # members. gcommon is always the isolated regenerated one.
    for name in dict.fromkeys(list(full) + list(names or [])):
        target = object_directory / (name + ".o")
        if target.is_symlink():
            target.unlink()
        target.symlink_to(regenerated if name == "gcommon" else source / "out/jak1/obj" / (name + ".o"))
    run(["bash", repo / "scripts/test-a11-module.sh", output / "module"], log)
    module_directory = output / "module"
    if aggregate:
        a = json.loads((module_directory / "allocator-reservation.json").read_text())
        if names is not None:
            # Every selected member is emitted from the selected object in list
            # order, so the aggregate order equals the requested load order.
            inputs=[]
            for name in names:
                destination=output/"kernel-modules"/name
                obj=object_directory/(name+".o")
                # The object's own debug-segment text size decides the release
                # policy; no name list is consulted for any generated registry.
                debug_text=struct.unpack_from("<I",obj.read_bytes(),68)[0]
                extra=["--release-no-debug"] if debug_text else []
                run([module_directory/"module_cli","--module",obj,name,destination,
                     "0x1bfec4",str((a["old_heap_end"]-16384)&~16383),*extra],log)
                inputs.append(destination/(name+".json"))
        else:
            inputs = [module_directory / "gstate.json", module_directory / "gstring.json"]
            if with_gcommon:
                # Emit the SAME isolated regenerated valid? object linked below.
                run([module_directory / "module_cli", "--module", regenerated, "gcommon", output / "common-module",
                     "0x1bfec4", str((a["old_heap_end"] - 16384) & ~16383), "--release-no-debug"], log)
                inputs.insert(0, output / "common-module/gcommon.json")
        span = sum((json.loads(path.read_text())["data_size"] + 15) & ~15 for path in inputs)
        run(["python3", repo / "scripts/emit-signed-module-arena.py", "--heap-start", a["heap_start"],
             "--heap-end", a["old_heap_end"], "--reservation-begin", (a["old_heap_end"] - span) & ~16383,
             "--output", output / "aggregate", *inputs], log)
        module_directory = output / "aggregate"
    config = values("game/CMakeFiles/runtime.dir/kernel/jak1/kscheme.cpp.o")
    flags = ["-DOTTSEL_SIGNED_GSTATE_EXPERIMENT", "-I" + str(source)] + config["DEFINES"] + config["FLAGS"] + config["INCLUDES"]
    flags = [flag for flag in flags if flag != "-ggdb"]
    if aggregate: flags.append("-DOTTSEL_SIGNED_AGGREGATE_TEST")
    if aggregate and (names is None or "gstring" in names): flags.append("-DOTTSEL_SIGNED_GSTRING_TEST")
    # A GAME member's init path calls __pc-get-mips2c, so real boot registers the
    # Mips2C stub table before linking anything (kboot.cpp:115); mirror it here.
    if names is not None and any(name not in full for name in names):
        flags.append("-DOTTSEL_SIGNED_GAMEDATA_TEST")
    if with_gcommon: flags.append("-DOTTSEL_SIGNED_GCOMMON_TEST")
    if with_kernel: flags.append("-DOTTSEL_SIGNED_KERNEL_TEST")
    if with_ordered: flags.append("-DOTTSEL_SIGNED_ORDERED_TEST")
    run(["python3", repo / "scripts/emit-signed-gstate-manifest.py", module_directory, output / "manifest.cpp"] +
        (["--aggregate"] if aggregate else []) + (["--module-list",module_list] if module_list else []), log)
    if with_kernel or with_ordered:
        run(["python3",repo/"test/a11_kernel_manifest_test.py",repo/"scripts/emit-signed-gstate-manifest.py",
             module_directory,module_list,output/"manifest-controls"],log)
    objects = []
    fresh = [repo / "test/a11_gstate_loader_test.cpp",
             source / "game/kernel/jak1/kscheme.cpp",
             source / "game/kernel/jak1/klink.cpp",
             source / "game/kernel/common/ottsel_signed_gstate.cpp", output / "manifest.cpp"]
    for index, path in enumerate(fresh):
        obj = output / f"source-{index}.o"
        run(["xcrun", "--sdk", "macosx", "clang++", *flags, "-c", path, "-o", obj], log)
        objects.append(obj)
    # GAME members call sceSifCallRpc. Host libruntime.a uses a live IOP; this
    # fixture never starts one. Compile the product iOS sif path so gsound uses
    # the same no-IOP RPC contract as the app. Do not define OTTSEL_IOS on
    # kscheme/klink: that would change kernel bootstrap.
    if names is not None and any(name not in full for name in names):
        sif = output / "sif_ee.o"
        run(["xcrun", "--sdk", "macosx", "clang++", *flags, "-DOTTSEL_IOS", "-c",
             source / "game/sce/sif_ee.cpp", "-o", sif], log)
        objects.insert(0, sif)
        loader_rpc = output / "sif_loader_rpc.o"
        run(["xcrun", "--sdk", "macosx", "clang++", *flags, "-c",
             repo / "test/a11_gstate_loader_sif_ios.cpp", "-o", loader_rpc], log)
        objects.insert(0, loader_rpc)
    asm = source / "game/kernel/asm_funcs_arm64.s"
    run(["xcrun", "--sdk", "macosx", "clang", "-arch", "arm64", "-c", asm, "-o", output / "helpers.o"], log)
    objects.append(output / "helpers.o")
    linkage = values("game/ottsel-cgolink-dump")
    executable = output / "gstate-activation"
    # Arena FIRST: otherwise ld may place signed __GOAL before its pointer base.
    signed_objects = ([module_directory / "aggregate-arena-layout.s", module_directory / "gstate.s", module_directory / "gstring.s"]
                      if aggregate else [module_directory / "gstate-arena-layout.s", module_directory / "gstate.o"])
    if with_gcommon: signed_objects.append(module_directory / "gcommon.s")
    if with_kernel or with_ordered:
        signed_objects=[module_directory/"aggregate-arena-layout.s"]+[module_directory/(name+".s") for name in names]
    run(["xcrun", "--sdk", "macosx", "clang++", "-arch", "arm64", *objects, *signed_objects,
         repo / "test/a11_gstate_method_driver.s", *linkage["LINK_LIBRARIES"],
         "-Wl,-dead_strip", "-Wl,-segprot,__ARENA,rw,rw", "-Wl,-segprot,__GOAL,rx,rx",
         "-o", executable], log)
    if executable.stat().st_size >= 100_000_000:
        raise SystemExit("Fixture exceeds repository artifact size policy")
    run(["codesign", "--force", "--sign", "-", executable], log)
    run(["codesign", "--verify", "--strict", executable], log)
    if with_kernel:
        linked=module_directory/"aggregate-linked"
        if linked.is_symlink(): linked.unlink()
        linked.symlink_to(executable)
        run(["python3",repo/"test/a11_aggregate_macho_check.py",module_directory],log)
    identities = fresh + [asm, build / "game/libruntime.a", executable, regenerated, kernel / "gcommon.gc"]
    identities += [source / f"out/jak1/obj/{name}.o" for name in
                   (names if names else ["gcommon", "gstring-h", "gkernel-h", "gkernel", "pskernel",
                                         "gstring", "dgo-h", "gstate"])]
    (output / "sha256.json").write_text(json.dumps({str(p): hashlib.sha256(p.read_bytes()).hexdigest()
                                                   for p in identities}, indent=2) + "\n")
with (output / "activation.log").open("w") as log:
    run([executable, object_directory], log, cwd=output)
for line in (output / "activation.log").read_text().splitlines():
    if line.startswith(("SIGNED ", "TYPED METHOD", "REGION ", "PASS wrong", "PASS duplicate", "PASS non-", "PASS registered", "PASS state.new interior", "PASS compiled valid?", "PASS active GOAL", "PASS nonglobal")):
        print(line)
print(f"Evidence: {output / 'activation.log'}")
