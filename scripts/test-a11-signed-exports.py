#!/usr/bin/env python3
"""Host-only signed export bank test; reuse a completed maintained Gstate fixture.
Usage: script OUTPUT PREPARED_GSTATE_FIXTURE [SOURCE_REPO]
Never regenerates active GOAL output or starts an app/Simulator.
"""
import hashlib,json,pathlib,shlex,subprocess,sys
repo=pathlib.Path(__file__).resolve().parents[1]
original=pathlib.Path(sys.argv[3]).resolve() if len(sys.argv)>3 else repo
source=original/'out/jak-project'; staged=repo/'out/jak-project'; build=source/'build/h1'
output=pathlib.Path(sys.argv[1]).resolve(); prepared=pathlib.Path(sys.argv[2]).resolve()
output.mkdir(parents=True,exist_ok=True)
text=(build/'build.ninja').read_text()
def values(target):
 start=text.index('build '+target+':');end=text.find('\nbuild ',start+1)
 return {line.strip().split(' = ',1)[0]:shlex.split(line.strip().split(' = ',1)[1]) for line in text[start:end].splitlines() if line.startswith('  ') and ' = ' in line}
def src(rel):
 path=staged/rel
 return path if path.exists() else source/rel
commands=[]
with (output/'build.log').open('w') as log:
 def run(args,cwd=build):
  args=list(map(str,args));commands.append(args);(output/'commands.json').write_text(json.dumps(commands,indent=2)+'\n')
  log.write(shlex.join(args)+'\n');log.flush();subprocess.run(args,cwd=cwd,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=60)
 config=values('game/CMakeFiles/runtime.dir/kernel/jak1/kscheme.cpp.o')
 flags=['-DOTTSEL_SIGNED_EXPORT_BANKS','-DOTTSEL_SIGNED_GSTATE_EXPERIMENT','-I'+str(staged),'-I'+str(source)]+config['DEFINES']+config['FLAGS']+config['INCLUDES']
 flags=[v for v in flags if v!='-ggdb']
 aggregate=(prepared/'aggregate/aggregate-arena-layout.s').exists()
 if aggregate:flags.append('-DOTTSEL_SIGNED_AGGREGATE_TEST')
 if (prepared/'aggregate/gstring.json').exists():flags.append('-DOTTSEL_SIGNED_GSTRING_TEST')
 with_gcommon=(prepared/'aggregate/gcommon.json').exists()
 if with_gcommon:flags.append('-DOTTSEL_SIGNED_GCOMMON_TEST')
 with_kernel=(prepared/'aggregate/gkernel.json').exists()
 if with_kernel:flags.append('-DOTTSEL_SIGNED_KERNEL_TEST')
 fresh=[repo/'test/a11_gstate_loader_test.cpp',src('game/kernel/jak1/kscheme.cpp'),src('game/kernel/jak1/klink.cpp'),src('game/mips2c/mips2c_table.cpp'),src('game/kernel/common/ottsel_signed_exports.cpp'),src('game/kernel/common/ottsel_signed_gstate.cpp'),prepared/'manifest.cpp']
 objects=[]
 for i,p in enumerate(fresh):
  out=output/f'source-{i}.o'
  local_source_parent=source/p.relative_to(staged).parent if p.is_relative_to(staged) else p.parent
  run(['clang++',*flags,'-I'+str(local_source_parent),'-c',p,'-o',out]);objects.append(out)
 run(['python3',repo/'scripts/emit-signed-export-banks.py',output/'export-banks.s'])
 run(['clang','-arch','arm64','-c',src('game/kernel/asm_funcs_arm64.s'),'-o',output/'helpers.o'])
 linkage=values('game/ottsel-cgolink-dump');executable=output/'signed-exports'
 signed_objects=[prepared/'aggregate/aggregate-arena-layout.s',prepared/'aggregate/gstate.s',prepared/'aggregate/gstring.s'] if aggregate else [prepared/'module/gstate-arena-layout.s',prepared/'module/gstate.o']
 if with_gcommon:signed_objects.append(prepared/'aggregate/gcommon.s')
 if with_kernel:
  names=json.loads((prepared/'aggregate/aggregate.json').read_text())['modules']
  assert names==['gcommon','gstring-h','gkernel-h','gkernel','pskernel','gstring','dgo-h','gstate']
  signed_objects=[prepared/'aggregate/aggregate-arena-layout.s']+[prepared/'aggregate'/(name+'.s') for name in names]
 # Preserve one arena first, then existing module code, then new signed banks.
 run(['clang++','-arch','arm64',*objects,output/'helpers.o',*signed_objects,output/'export-banks.s',original/'test/a11_gstate_method_driver.s',*linkage['LINK_LIBRARIES'],'-Wl,-dead_strip','-Wl,-segprot,__ARENA,rw,rw','-Wl,-segprot,__GOAL,rx,rx','-o',executable])
 if executable.stat().st_size>=100_000_000:raise SystemExit('Fixture exceeds artifact size policy')
 run(['codesign','--force','--sign','-',executable]);run(['codesign','--verify','--strict',executable])
 (output/'sha256.json').write_text(json.dumps({str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in fresh+[executable,source/'game/kernel/asm_funcs_arm64.s',build/'game/libruntime.a',repo/'scripts/emit-signed-export-banks.py',src('game/kernel/common/ottsel_signed_exports.h'),output/'export-banks.s',*signed_objects]+list((prepared/'fixture-objects').glob('*.o'))},indent=2)+'\n')
with (output/'runtime.log').open('w') as log:
 subprocess.run([str(executable),str(prepared/'fixture-objects')],cwd=output,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=60)
print(output/'runtime.log')
