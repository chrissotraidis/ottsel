"""Genuine-source release-policy fixture; accepts an actual module CLI executable.
Old emitter is expected to fail explicit release emission. No GOAL execution.
"""
import hashlib,json,pathlib,struct,subprocess,sys
cli,source,output=map(pathlib.Path,sys.argv[1:])
output.mkdir(parents=True,exist_ok=False)
b=source.read_bytes()
u=lambda p:struct.unpack_from('<I',b,p)[0]
assert u(52)>0 and u(68)>0, 'fixture must contain genuine nonempty debug'
checks=0

def run(obj,directory,release=True):
    return subprocess.run([str(cli),'--module',str(obj),'gcommon',str(directory),'0x1bfec4','0x3eb4000']+
                          (['--release-no-debug'] if release else []),capture_output=True,text=True)

def check(ok,label):
    global checks
    assert ok,label
    checks+=1
    print('PASS',label)

legacy=run(source,output/'default',False)
check(legacy.returncode!=0 and 'unsupported nonempty debug segment' in legacy.stderr,
      'default retains fail-closed nonempty-debug rejection')
release=run(source,output/'release')
check(release.returncode==0,'explicit release policy accepts genuine gcommon: '+release.stderr)
p=output/'release';m=json.loads((p/'gcommon.json').read_text())
check(m['schema']==2 and m['debug_policy']=='release-omit','explicit release schema/policy')
check(m['source_sha256']==hashlib.sha256(b).hexdigest() and (p/'gcommon.source.o').read_bytes()==b,
      'exact complete source including debug authenticated and preserved')
s=m['segments'][1]
check(s['source_size']==u(52) and s['source_text_size']==u(68) and
      not s['loaded'] and s['size']==s['text_size']==0 and not s['slots'] and not s['distances'],
      'source debug bounds retained separately from empty loaded layout')
check((p/'gcommon-s1-data.bin').read_bytes()==b'','no debug template included')
refs=[r for s in m['segments'] for r in s['distances'] if r['target_segment']==1]
check(len(refs)==3 and {r['target'] for r in refs}=={4,244,676} and
      all(r['target_policy']=='goal-zero' for r in refs),'all three genuine top references explicitly target GOAL0')
assembly=(p/'gcommon.s').read_text()
check(assembly.count('_ottsel_module_arena@PAGE\n')==3 and
      assembly.count('_ottsel_module_arena@PAGEOFF\n')==3,
      'omitted-target native address is arena base, never numeric native null or source offset')
check(m['data_size']%16!=0,'genuine release fixture exercises unaligned final data tail')
# Mutations must fail even though these records would not be loaded.
def reject(label,change):
    mutated=bytearray(b);change(mutated)
    obj=output/(label+'.o');obj.write_bytes(mutated)
    dest=output/(label+'-result');r=run(obj,dest)
    check(r.returncode!=0 and not dest.exists(),label+' rejects before any emitted output')
debug_link=4+u(24)
reject('unknown-omitted-debug-record',lambda data:data.__setitem__(debug_link,255))
reject('truncated-omitted-debug-table',lambda data:struct.pack_into('<I',data,28,u(28)-1))
reject('invalid-omitted-debug-text',lambda data:struct.pack_into('<I',data,68,u(52)+4))
top_base=u(76)+u(56)
reject('unsupported-load-from-omitted-debug',lambda data:struct.pack_into('<I',data,top_base+1632+4,0xbd400042))
print(f'{checks} release source checks PASS; Mach-O link/VM is a separate next gate')
