"""Actual CLI fixture for declaration-only modules and normalized-label collisions."""
import hashlib,importlib.util,json,pathlib,struct,subprocess,sys
cli,obj,output,generator=map(pathlib.Path,sys.argv[1:])
output.mkdir(parents=True,exist_ok=False)
raw=obj.read_bytes();word=lambda p:struct.unpack_from('<I',raw,p)[0]
assert [word(44+i*8) for i in range(3)]==[0,0,16384]
checks=0

def check(ok,label):
    global checks
    assert ok,label
    checks+=1;print('PASS',label)

def emit(source,name,dest):
    return subprocess.run([str(cli),'--module',str(source),name,str(dest),'0x1bfec4','0x3eb4000'],capture_output=True,text=True)

result=emit(obj,'gstring-h',output/'module')
check(result.returncode==0,'genuine declaration-only module accepted: '+result.stderr)
p=output/'module';m=json.loads((p/'gstring-h.json').read_text())
check(m['module']=='gstring-h' and m['source_sha256']==hashlib.sha256(raw).hexdigest(),
      'exact original module identity/source preserved')
check(m['data_size']==0 and all((p/f'gstring-h-s{i}-data.bin').read_bytes()==b'' for i in range(3)),
      'declaration-only module reserves no runtime data')
check([s['text_size'] for s in m['segments']]==[0,0,16384] and
      len(m['segments'][2]['slots'])==1 and m['segments'][2]['slots'][0]['kind']=='immutable_function_tag',
      'one genuine signed top tag, no invented main function')
check(all(s['code_label']==f'_ottsel_module_gstring_h_s{i}_code' for i,s in enumerate(m['segments'])),
      'hyphenated GOAL name uses legal separate Mach-O labels')
spec=importlib.util.spec_from_file_location('arena',generator)
a=importlib.util.module_from_spec(spec);spec.loader.exec_module(a)
files=a.aggregate([p/'gstring-h.json'],0x13fd20,0x3eb82e0,0x3eb4000)
check(json.loads(files['aggregate.json'])['data_span_size']==0,'aggregate handles zero-data module')
alias=emit(obj,'gstring_h',output/'alias');check(alias.returncode==0,'collision fixture emitted')
try:a.aggregate([p/'gstring-h.json',output/'alias/gstring_h.json'],0x13fd20,0x3eb82e0,0x3eb4000)
except ValueError as e:check('alias identical' in str(e),'normalized module-label collision rejects')
else:raise AssertionError('accepted colliding labels')
# The single top link table contains a function Type record and one patch0.
link=4+word(32);assert raw[link]==2
name_end=raw.index(0,link+1);methods=name_end+1;count=methods+1
assert word(count)==1 and word(count+4)==0

def reject(name,mutate):
    b=bytearray(raw);mutate(b);source=output/(name+'.o');source.write_bytes(b);dest=output/name
    r=emit(source,'gstring-h',dest)
    check(r.returncode!=0 and not dest.exists(),name+' rejects before output')
reject('missing-top-tag',lambda b:struct.pack_into('<I',b,count+4,4))
reject('missing-top-code',lambda b:struct.pack_into('<I',b,72,0))
reject('short-top-header',lambda b:struct.pack_into('<I',b,72,4))
reject('unknown-empty-debug-record',lambda b:b.__setitem__(4+word(24),255))
reject('invalid-method-count',lambda b:b.__setitem__(methods,8))
check(emit(obj,'../gstring-h',output/'bad-name').returncode!=0,'unsafe module name rejects')
print(f'{checks} top-only checks PASS; actual signed top execution remains separate')
