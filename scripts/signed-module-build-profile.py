#!/usr/bin/env python3
"""Bounded Simulator signed-module selection and reusable-build identity checks.
These guards establish cache/source agreement, not whole-game signed coverage.
A selected name must be the named container's code member, not the same-named
art member GAME.CGO repeats for it.
"""
import argparse,hashlib,json,pathlib,struct
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('action',choices=['names','preflight','check','record'])
p.add_argument('--repo',type=pathlib.Path,required=True)
p.add_argument('--mode',choices=['0','1','2','3'],default='0')
p.add_argument('--banks',choices=['0','1'],default='0')
p.add_argument('--list',type=pathlib.Path)
p.add_argument('--generation',type=pathlib.Path)
a=p.parse_args();repo=a.repo.resolve();work=repo/'out/jak-project'
full=['gcommon','gstring-h','gkernel-h','gkernel','pskernel','gstring','dgo-h','gstate']
legacy={'0':[],'1':['gstate'],'2':['gstring','gstate'],'3':['gcommon','gstring','gstate']}
def require(ok,message):
 if not ok:raise SystemExit(message+'; full build required')
names=legacy[a.mode]
if a.list:
 require(a.mode=='0','Explicit module list cannot be combined with legacy signed mode')
 selected=json.loads((a.list if a.list.is_absolute() else repo/a.list).read_text())
 require(set(selected)=={'schema','modules'} and selected['schema']==1 and all(type(name)is str for name in selected['modules']) and len(set(selected['modules']))==len(selected['modules']) and bool(selected['modules']),'Invalid signed module list schema')
 names=selected['modules']
require(a.banks=='0' or bool(names),'Signed export banks require a shared signed module arena')
if a.action=='names':print(' '.join(names));raise SystemExit(0)
def digest(path):
 require(path.is_file(),'Missing signed build artifact: '+str(path))
 return hashlib.sha256(path.read_bytes()).hexdigest()
identity={'schema':1,'legacy_mode':a.mode,'explicit_list':bool(a.list),'modules':names,'banks':a.banks,'sources':{}}
def read_container(container):
 iso=work/'out/jak1/iso'
 path=iso/(container+'.CGO')
 if not path.is_file():
  path=iso/(container+'.DGO')
 data=path.read_bytes()
 require(len(data)>=64,'Truncated '+container+' header')
 count=struct.unpack_from('<I',data)[0];offset=64;rows=[]
 for _ in range(count):
  require(offset+64<=len(data),'Truncated '+container+' member header')
  size,raw=struct.unpack_from('<I60s',data,offset);offset+=64
  require(offset+size<=len(data),'Truncated '+container+' member body')
  rows.append((raw.split(b'\0')[0].decode('ascii'),data[offset:offset+size]))
  offset+=(size+15)&~15
 require(offset<=len(data),'Truncated '+container+' trailer')
 if container=='KERNEL':
  require(count==8,'Unexpected KERNEL member count')
  require([row[0] for row in rows]==full,'Changed canonical KERNEL order')
 return rows
cache={}
def container_members(container):
 if container not in cache:cache[container]=read_container(container)
 return cache[container]
def stream_containers():
 iso=work/'out/jak1/iso'
 if not iso.is_dir():
  return []
 return [path.stem for path in sorted(iso.glob('*.DGO'))]
def locate_member(name):
 # One GOAL name can be a code member in KERNEL and GAME, and GAME.CGO repeats
 # sidekick once as code and once as art data. The code member is the one whose
 # body is the loose name.o, so a selection always picks code, never art.
 found=False
 for container in ('KERNEL','GAME',*stream_containers()):
  rows=[body for member,body in container_members(container) if member==name]
  if not rows:continue
  found=True
  path=work/'out/jak1/obj'/(name+'.o')
  if path.is_file():
   source=path.read_bytes()
   if source in rows:return container,source
 if found:require(False,'Signed member has no code object: '+name)
 require(False,'Signed module is not a code member of KERNEL, GAME or a bundled level DGO: '+name)
if names:
 for name in dict.fromkeys(['gcommon',*names]):
  _,source=locate_member(name)
  if name=='gcommon':require(b'ottsel-signed-function-valid?\0' in source,'Regenerate signed valid? Gcommon prerequisite')
  identity['sources'][name]=hashlib.sha256(source).hexdigest()
if a.action=='preflight':raise SystemExit(0)
cache=work/'out/ios/app/signed-module-profile.json'
if a.action=='check':
 if not names and not cache.exists():raise SystemExit(0)  # Preserve unsigned legacy shell-only reuse.
 require(cache.is_file(),'Missing signed module profile')
 previous=json.loads(cache.read_text());require(previous.get('identity')==identity,'Signed module profile/source changed')
 generation=pathlib.Path(previous['generation']) if names else None
else:generation=a.generation.resolve() if names and a.generation else None
artifacts={}
if names:
 require(generation is not None and generation.is_dir(),'Missing signed module generation')
 arena='gstate-arena-layout.s' if names==['gstate'] else 'aggregate-arena-layout.s'
 required=[arena,'manifest.cpp']
 if len(names)>1:
  aggregate=json.loads((generation/'aggregate.json').read_text())
  placement=names if a.list else (['gcommon','gstate','gstring'] if len(names)==3 else ['gstate','gstring'])
  require(aggregate['modules']==placement,'Generated aggregate canonical placement differs')
  required.append('aggregate.json')
 for name in names:
  metadata=json.loads((generation/(name+'.json')).read_text())
  require(metadata['module']==name and metadata['source_sha256']==identity['sources'][name],'Generated source hash changed: '+name)
  require(digest(generation/(name+'.source.o'))==identity['sources'][name],'Generated source bytes changed: '+name)
  required += [name+'.json',name+'.source.o',name+'.s']+[f'{name}-s{i}-data.bin' for i in range(3)]
 for filename in required:
  path=generation/filename
  if filename.endswith('.s') or filename=='manifest.cpp':require(path.is_file() and path.stat().st_size>0,'Empty generated code: '+filename)
  artifacts[filename]=digest(path)
if a.action=='check':
 require(previous.get('artifacts')==artifacts,'Signed generated artifacts changed')
 if generation:print(generation)
else:
 cache.parent.mkdir(parents=True,exist_ok=True)
 temporary=cache.with_suffix('.tmp')
 temporary.write_text(json.dumps({'identity':identity,'generation':str(generation) if generation else '', 'artifacts':artifacts},indent=2)+'\n')
 temporary.replace(cache)
