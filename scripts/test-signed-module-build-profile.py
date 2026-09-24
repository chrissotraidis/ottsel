#!/usr/bin/env python3
"""Run the actual build-ios pre-SDK shell branch against real emitted inputs.
Usage: script SOURCE_REPO PREPARED_FULL_KERNEL_HOST_FIXTURE NEW_OUTPUT
Only cache/profile validation runs; compiler, SDK and app commands are excluded.
Archive/slice placeholders test existence only and are never passed to a compiler.
"""
import json,os,pathlib,shutil,struct,subprocess,sys
repo,prepared,output=map(lambda s:pathlib.Path(s).resolve(),sys.argv[1:])
output.mkdir(parents=True,exist_ok=False)
full=['gcommon','gstring-h','gkernel-h','gkernel','pskernel','gstring','dgo-h','gstate']
root=output/'repo';scripts=root/'scripts';scripts.mkdir(parents=True)
helper=scripts/'signed-module-build-profile.py';shutil.copyfile(repo/'scripts'/helper.name,helper)
actual=(repo/'scripts/build-ios.sh').read_text();prefix=actual[:actual.index('\nSDK=')]
(scripts/'build-ios.sh').write_text(prefix+'\necho VALIDATED_BEFORE_SDK\n')
work=root/'out/jak-project';objects=work/'out/jak1/obj';objects.mkdir(parents=True)
iso=work/'out/jak1/iso';iso.mkdir(parents=True)
for name in full:shutil.copyfile(prepared/'fixture-objects'/(name+'.o'),objects/(name+'.o'))
def container():
 data=struct.pack('<I60s',8,b'KERNEL')
 for name in full:
  member=(objects/(name+'.o')).read_bytes()
  data+=struct.pack('<I60s',len(member),name.encode())+member+b'\0'*((-len(member))&15)
 (iso/'KERNEL.CGO').write_bytes(data)
container();app=work/'out/ios/app';app.mkdir(parents=True)
for relative in ['out/ios/sdl/libSDL3.a','out/ios/zstd-build/zstd/liblibzstd_static.a','out/ios/app/libottsel-runtime.a','out/ios/app/obj/a11_slice.o','out/ios/app/a11-slice/a11_slice_map.h','out/jak1/iso/GAME.CGO']:
 path=work/relative;path.parent.mkdir(parents=True,exist_ok=True);path.write_text('existence-only prerequisite\n')
(app/'signed-gstate-mode').write_text('0\n');(app/'signed-export-bank-mode').write_text('0\n')
selection=root/'config/signed-kernel-full.json';selection.parent.mkdir();selection.write_text(json.dumps({'schema':1,'modules':full}))
generation=app/'signed-gstate/modules.fixture/modules';generation.parent.mkdir(parents=True)
shutil.copytree(prepared/'aggregate',generation,ignore=shutil.ignore_patterns('aggregate-linked'))
shutil.copyfile(prepared/'manifest.cpp',generation/'manifest.cpp')
profile_args=['--repo',str(root),'--mode','0','--banks','0','--list',str(selection)]
subprocess.run([sys.executable,str(helper),'record',*profile_args,'--generation',str(generation)],check=True)
cache=app/'signed-module-profile.json';baseline_cache=cache.read_bytes()
environment=os.environ.copy()
for key in ('OTTSEL_SIGNED_MODULE_LIST','OTTSEL_SIGNED_GSTATE_EXPERIMENT','OTTSEL_SIGNED_EXPORT_BANKS'):environment.pop(key,None)
environment['OTTSEL_SIGNED_MODULE_LIST']='config/signed-kernel-full.json'
def run(name,success=False,changes=None):
 env=environment.copy();env.update(changes or {})
 result=subprocess.run(['bash',str(scripts/'build-ios.sh'),'--shell-only'],env=env,capture_output=True,text=True)
 (output/(name+'.log')).write_text(result.stdout+result.stderr)
 assert (result.returncode==0)==success,(name,result.stdout,result.stderr)
 assert ('VALIDATED_BEFORE_SDK' in result.stdout)==success,name
 print('PASS',name)
run('exact-full-profile',True)
# Also reject a wrong aggregate at profile creation, not merely by cached hash.
path=generation/'aggregate.json';saved=path.read_bytes();aggregate=json.loads(saved)
aggregate['modules'].reverse();path.write_text(json.dumps(aggregate))
result=subprocess.run([sys.executable,str(helper),'record',*profile_args,'--generation',str(generation)],capture_output=True,text=True)
assert result.returncode!=0 and cache.read_bytes()==baseline_cache
(output/'wrong-aggregate-record.log').write_text(result.stdout+result.stderr)
path.write_bytes(saved);print('PASS wrong aggregate placement cannot publish profile')
run('legacy-list-conflict',changes={'OTTSEL_SIGNED_GSTATE_EXPERIMENT':'3'})
run('changed-bank-profile',changes={'OTTSEL_SIGNED_EXPORT_BANKS':'1'})
run('changed-to-unsigned',changes={'OTTSEL_SIGNED_MODULE_LIST':''})
selection.write_text(json.dumps({'schema':1,'modules':list(reversed(full))}));run('changed-canonical-order')
selection.write_text(json.dumps({'schema':1,'modules':full}))
for name in full:
 path=generation/(name+'.s');saved=path.read_bytes();path.unlink();run('missing-'+name+'-assembly');path.write_bytes(saved)
path=generation/'gkernel.s';saved=path.read_bytes();path.write_bytes(saved+b'\n');run('changed-generated-assembly');path.write_bytes(saved)
path=objects/'gkernel.o';saved=path.read_bytes();path.write_bytes(saved[:-1]+bytes([saved[-1]^1]));run('kernel-member-mismatch')
container();run('changed-source-with-matching-kernel');path.write_bytes(saved);container()
cache.unlink();run('missing-profile');cache.write_bytes(baseline_cache)
path=app/'libottsel-runtime.a';saved=path.read_bytes();path.unlink();run('missing-runtime-archive');path.write_bytes(saved)
run('restored-full-profile',True)
for mode,names in {'0':[],'1':['gstate'],'2':['gstring','gstate'],'3':['gcommon','gstring','gstate']}.items():
 result=subprocess.run([sys.executable,str(helper),'names','--repo',str(root),'--mode',mode],capture_output=True,text=True,check=True)
 assert result.stdout.split()==names
 print('PASS legacy selection',mode)
# Cover mode0 with an existing recorded cache; no signed generation is needed.
subprocess.run([sys.executable,str(helper),'record','--repo',str(root),'--mode','0'],check=True)
run('unsigned-existing-profile',True,{'OTTSEL_SIGNED_MODULE_LIST':''})
cache.write_bytes(baseline_cache)
# Container membership identity beyond KERNEL, and the GAME code/art duplicate.
def write_selection(modules):
 selection=root/'config/game-selection.json'
 selection.write_text(json.dumps({'schema':1,'modules':modules}));return str(selection)
def game_container(members):
 data=struct.pack('<I60s',len(members),b'GAME')
 for name,body in members:
  data+=struct.pack('<I60s',len(body),name.encode())+body+b'\0'*((-len(body))&15)
 (iso/'GAME.CGO').write_bytes(data)
def preflight(modules):
 return subprocess.run([sys.executable,str(helper),'preflight','--repo',str(root),'--mode','0','--banks','0','--list',write_selection(modules)],capture_output=True,text=True)
code=b'GAME-code-member-body';art=b'ART-'+b'A'*4096
code_path=objects/'sidekick.o';code_path.write_bytes(b'CODE-SIDEKICK-member')
game_path=objects/'badvillager.o';game_path.write_bytes(code)
game_container([('badvillager',code)])
assert preflight(['badvillager']).returncode==0;print('PASS game-member-resolves')
game_container([('sidekick',art),('sidekick',code_path.read_bytes())])
assert preflight(['sidekick']).returncode==0;print('PASS sidekick-code-member-beats-art')
game_container([('sidekick',art)])
result=preflight(['sidekick']);assert result.returncode!=0 and 'Signed member has no code object: sidekick' in result.stderr
print('PASS sidekick-art-only-rejected')
game_container([('badvillager',code)]);game_path.unlink()
result=preflight(['badvillager']);assert result.returncode!=0 and 'Signed member has no code object: badvillager' in result.stderr
print('PASS missing-loose-object-rejected');game_path.write_bytes(code)
rejected=preflight(['ghost']);assert rejected.returncode!=0 and 'not a code member of KERNEL, GAME or a bundled level DGO: ghost' in rejected.stderr
print('PASS unknown-member-rejected')
def tit_container(members):
 data=struct.pack('<I60s',len(members),b'TIT')
 for name,body in members:
  data+=struct.pack('<I60s',len(body),name.encode())+body+b'\0'*((-len(body))&15)
 (iso/'TIT.DGO').write_bytes(data)
title=b'TIT-code-member-body'
title_path=objects/'title-obs.o';title_path.write_bytes(title)
tit_container([('title-obs',title),('tpage-1609',b'ART-'+b'T'*4096)])
assert preflight(['title-obs']).returncode==0;print('PASS tit-code-member-resolves')
assert preflight(['gcommon','title-obs']).returncode==0;print('PASS mixed-kernel-and-tit-list')
result=preflight(['tpage-1609']);assert result.returncode!=0 and 'Signed member has no code object: tpage-1609' in result.stderr
print('PASS tit-art-only-rejected')
rejected=preflight(['ghost']);assert rejected.returncode!=0 and 'not a code member of KERNEL, GAME or a bundled level DGO: ghost' in rejected.stderr
print('PASS unknown-member-rejected-after-tit')
assert preflight(['gcommon','badvillager']).returncode==0;print('PASS mixed-kernel-and-game-list')
assert preflight(list(full)).returncode==0;print('PASS kernel-list-unaffected-by-game-container')
print('PASS actual pre-SDK shell branch; no compiler or app execution')
