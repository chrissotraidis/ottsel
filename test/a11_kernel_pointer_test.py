"""Actual source malformed controls for narrowly supported Gkernel pointers/types."""
import importlib.util,json,pathlib,struct,subprocess,sys
cli,obj,output,generator=map(pathlib.Path,sys.argv[1:]);output.mkdir(parents=True,exist_ok=False)
b=obj.read_bytes();u=lambda p:struct.unpack_from('<I',b,p)[0]
pointers=[];types={};record_offsets=[]
for sid in range(3):
 p=4+u(16+sid*8);end=p+u(20+sid*8)
 while p<end:
  kind=b[p];p+=1
  if kind==0:break
  if kind in (1,2):
   en=b.index(0,p,end);name=b[p:en].decode();p=en+1
   if kind==2:types[name]=p;p+=1
   n=u(p);p+=4+4*n
  elif kind in (3,4):p+=13
  elif kind==5:pointers.append((sid,p,u(p),u(p+4)));p+=8
  else:raise AssertionError('unknown genuine source record')
assert len(pointers)==6 and all(sid==0 and target&7==2 for sid,record,patch,target in pointers)

def emit(source,dest):
 return subprocess.run([str(cli),'--module',str(source),'gkernel',str(dest),'0x1bfec4','0x3eb4000','--release-no-debug'],capture_output=True,text=True)
result=emit(obj,output/'valid');assert result.returncode==0,result.stderr
m=json.loads((output/'valid/gkernel.json').read_text())
assert [(v['patch'],v['target']) for v in m['segments'][0]['pointers']]==[(patch,target) for sid,record,patch,target in pointers]
assert all(v['kind']=='data' and v['goal_offset']&7==2 for v in m['segments'][0]['pointers'])
print('PASS all six genuine pointer records and lowtag2 preserved')
checks=1

# The kept mutable linker writes one same-segment address from the segment's own
# base, so the same record with a code target is the other accepted form. Data
# pointers keep the folded arena offset; code pointers keep the raw target.
text=u(64)
code=bytearray(b);struct.pack_into('<I',code,pointers[0][1]+4,text-4)
source=output/'code-pointer.o';source.write_bytes(code)
result=emit(source,output/'code-pointer');assert result.returncode==0,result.stderr
c=json.loads((output/'code-pointer/gkernel.json').read_text())['segments'][0]['pointers'][0]
assert c['kind']=='code' and c['target']==text-4 and c['target_offset']==text-4 and 'goal_offset' not in c
print('PASS in-text code target accepted with the raw target preserved');checks+=1

def reject(label,mutate):
 global checks
 changed=bytearray(b);mutate(changed);source=output/(label+'.o');source.write_bytes(changed);dest=output/label
 result=emit(source,dest);assert result.returncode!=0 and not dest.exists(),label
 checks+=1;print('PASS reject',label)
record=pointers[0][1];patch=pointers[0][2]
reject('pointer-in-signed-text',lambda data:struct.pack_into('<I',data,record,4))
reject('unaligned-pointer-slot',lambda data:struct.pack_into('<I',data,record,patch+1))
reject('out-of-bounds-pointer-slot',lambda data:struct.pack_into('<I',data,record,u(44)))
reject('out-of-bounds-pointer-target',lambda data:struct.pack_into('<I',data,record+4,u(44)))
reject('unaligned-code-target',lambda data:struct.pack_into('<I',data,record+4,text-2))
# The split is `target < seg.text`, so the first data byte is a data target and
# the unaligned case above is the only reachable code-side rejection.
boundary=bytearray(b);struct.pack_into('<I',boundary,record+4,text)
source=output/'boundary.o';source.write_bytes(boundary)
result=emit(source,output/'data-boundary');assert result.returncode==0,result.stderr
bound=json.loads((output/'data-boundary/gkernel.json').read_text())['segments'][0]['pointers'][0]
assert bound['kind']=='data' and bound['target']==text and bound['goal_offset']&15==0
print('PASS first-data-byte target stays a data record');checks+=1
reject('duplicate-pointer-slot',lambda data:struct.pack_into('<I',data,pointers[1][1],patch))
reject('pointer-overlaps-type-slot',lambda data:struct.pack_into('<I',data,record,next(v['offset'] for v in m['segments'][0]['slots'] if v['kind']=='type_pointer')))
reject('truncated-pointer-record',lambda data:struct.pack_into('<I',data,20,record+7-(4+u(16))))
reject('unknown-pointer-record',lambda data:data.__setitem__(record-1,255))
reject('kernel-context-wrong-method-count',lambda data:data.__setitem__(types['kernel-context'],10))
reject('state-wrong-method-count',lambda data:data.__setitem__(types['state'],10))
spec=importlib.util.spec_from_file_location('arena',generator);a=importlib.util.module_from_spec(spec);spec.loader.exec_module(a)
source=output/'valid/gkernel.json';a.load(source)
m['segments'][0]['pointers'][0]['goal_offset']&=~7
bad=output/'valid/bad-pointer.json';bad.write_text(json.dumps(m))
try:a.load(bad)
except ValueError:print('PASS reject erased lowtag in manifest');checks+=1
else:raise AssertionError('accepted erased pointer tag')
print(f'{checks} pointer/type controls PASS; actual-linker oracle and signed layout remain separate checks')
