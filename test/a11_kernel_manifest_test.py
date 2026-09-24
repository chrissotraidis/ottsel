#!/usr/bin/env python3
"""Source/metadata guard controls over freshly emitted genuine signed module input.
Usage: test EMIT_MANIFEST_SCRIPT AGGREGATE_DIRECTORY MODULE_LIST OUTPUT_DIRECTORY
This does not prove arbitrary hand-written assembly; the caller freshly emits and
links with the actual emitter before the executable codeword/layout regression.
The registry under test is read from MODULE_LIST, so the same guards cover the
canonical KERNEL list and any generated ordered registry.
"""
import json,pathlib,shutil,subprocess,sys
script,aggregate,selection,output=map(lambda v:pathlib.Path(v).resolve(),sys.argv[1:])
modules=json.loads(selection.read_text())['modules'];count=len(modules)
output.mkdir(parents=True,exist_ok=True)
def case(name,mutate=None,accept=False):
 directory=output/name;directory.mkdir()
 for source in aggregate.iterdir():
  if source.suffix=='.json' or source.name.endswith(('.source.o','-data.bin')):
   shutil.copyfile(source,directory/source.name)
 chosen=directory/'selected.json';shutil.copyfile(selection,chosen)
 def edit(filename,fn):
  path=directory/filename;value=json.loads(path.read_text());fn(value);path.write_text(json.dumps(value))
 if mutate:mutate(directory,edit)
 manifest=directory/'manifest.cpp'
 result=subprocess.run([sys.executable,str(script),str(directory),str(manifest),'--aggregate','--module-list',str(chosen)],capture_output=True,text=True)
 (directory/'result.log').write_text(result.stdout+result.stderr)
 if mutate and not accept:
  assert result.returncode!=0 and not manifest.exists(),name+' did not reject before output'
 else:
  assert result.returncode==0,result.stderr
  text=manifest.read_text();assert f'const size_t module_count={count};' in text
 print('PASS',name)
case(f'accepted-registry-{count}')
case('wrong-order',lambda p,e:e('selected.json',lambda m:m['modules'].reverse()))
case('missing-module',lambda p,e:e('selected.json',lambda m:m['modules'].pop()))
case('duplicate-module',lambda p,e:e('selected.json',lambda m:m['modules'].__setitem__(2,modules[1])))
# Member-shape controls run only when the selected registry emits that member,
# so one test covers the canonical KERNEL list and any ordered list.
if (aggregate/'gkernel.json').exists():
 case('wrong-debug-policy',lambda p,e:e('gkernel.json',lambda m:m.__setitem__('debug_policy','reject-nonempty')))
 case('wrong-source-hash',lambda p,e:e('gkernel.json',lambda m:m.__setitem__('source_sha256','0'*64)))
 def pointer_change(fn):
  return lambda p,e:e('gkernel.json',lambda m:fn(m['segments'][0]))
 case('pointer-in-text',pointer_change(lambda s:s['pointers'][0].__setitem__('patch',4)))
 case('pointer-unaligned',pointer_change(lambda s:s['pointers'][0].__setitem__('patch',s['pointers'][0]['patch']+1)))
 case('pointer-duplicate',pointer_change(lambda s:s['pointers'].append(dict(s['pointers'][0]))))
 def code_record(s,target,offset=None):
  r=s['pointers'][0];r.pop('goal_offset',None)
  r.update({'target':target,'kind':'code','target_offset':target if offset is None else offset})
 def code_pointer(value):
  return pointer_change(lambda s:code_record(s,value(s) if callable(value) else value))
 # A code target is the same record with the signed code label as its base, so a
 # 4-aligned in-text function entry is accepted while an out-of-text or
 # unaligned target still fails closed.
 case('pointer-code-target-entry',code_pointer(4),accept=True)
 case('pointer-code-target-at-text',code_pointer(0x1000),accept=True)
 case('pointer-code-target-past-text',code_pointer(lambda s:s['source_text_size']))
 case('pointer-code-target-unaligned',code_pointer(2))
 case('pointer-code-target-tag-mismatch',pointer_change(lambda s:code_record(s,4,8)))
 case('pointer-erased-goal-tag',pointer_change(lambda s:s['pointers'][0].__setitem__('goal_offset',s['pointers'][0]['goal_offset']&~7)))
 case('pointer-end-target',pointer_change(lambda s:s['pointers'][0].__setitem__('target',s['size'])))
if (aggregate/'gkernel-h.json').exists():
 case('wrong-label',lambda p,e:e('gkernel-h.json',lambda m:m['segments'][0].__setitem__('code_label','_ottsel_module_gkernel_s0_code')))
print('PASS signed module metadata guard controls; no GOAL execution in this test')
