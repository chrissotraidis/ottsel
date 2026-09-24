#!/usr/bin/env python3
"""Compile validated emitted module metadata; bounded explicit KERNEL module list."""
import argparse
import hashlib
import re
import struct
import json
import pathlib

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('directory',type=pathlib.Path)
parser.add_argument('output',type=pathlib.Path)
parser.add_argument('--aggregate',action='store_true')
parser.add_argument('--module-list',type=pathlib.Path)
args=parser.parse_args()
p=args.directory
kind=dict(symbol_offset='SymbolOffset',symbol_address='SymbolAddress',
          type_pointer='TypePointer',immutable_function_tag='FunctionTag')
full=['gcommon','gstring-h','gkernel-h','gkernel','pskernel','gstring','dgo-h','gstate']
comparison=['gcommon','gstring','gstate']
names=['gstring','gstate'] if args.aggregate else ['gstate']
if args.module_list:
    selected=json.loads(args.module_list.read_text())
    assert args.aggregate and set(selected)=={'schema','modules'} and selected['schema']==1
    names=selected['modules']
    # Any distinct non-empty ordered list is a generated registry: the final
    # entry is the gstate main and the array order is the required load order.
    assert isinstance(names,list) and names and all(
        isinstance(n,str) and re.fullmatch(r'[A-Za-z0-9_-]+',n) for n in names),'invalid module list'
    assert len(set(names))==len(names) and 'gstate' in names,'module list must include gstate'
if args.aggregate:
    a=json.loads((p/'aggregate.json').read_text())
    assert a['schema']==1
    if args.module_list:
        assert a['modules']==names
    else:
        assert a['modules'] in (['gstate','gstring'],['gcommon','gstate','gstring'])
        if a['modules'][0]=='gcommon': names=comparison
    assert a['arena_symbol']=='_ottsel_module_arena' and a['arena_size']==134217728
out=['#include "game/kernel/common/ottsel_signed_gstate.h"',
     'extern "C" unsigned char ottsel_module_arena[];',
     'namespace ottsel::signed_gstate {']
for name in names:
    m=json.loads((p/(name+'.json')).read_text())
    identifier_name=name.replace('-','_')
    original=(p/(name+'.source.o')).read_bytes()
    assert len(original)==m['source_bytes'] and hashlib.sha256(original).hexdigest()==m['source_sha256']
    assert len(original)>=80
    word=lambda pos:struct.unpack_from('<I',original,pos)[0]
    assert (word(4),word(8),word(12))==(1,3,3),'unsupported source version'
    # A module is release-debug exactly when its own source carries a debug
    # segment the emitter omits from the loaded layout; the object is the record.
    release=word(68)!=0
    assert m['schema']==(2 if release else 1) and m['module']==name
    assert m.get('debug_policy','reject-nonempty')==('release-omit' if release else 'reject-nonempty')
    assert m['entry']=={'segment':2,'offset':4}
    assert len(m['segments'])==3 and m['arena_symbol']=='_ottsel_module_arena'
    if args.aggregate:
        assert m['required_function_type']==a['required_function_type']
        assert a['reservation_begin']<=m['data_reservation_offset']
        assert m['data_reservation_offset']+m['data_size']<=a['reservation_begin']+a['data_span_size']
    for i,s in enumerate(m['segments']):
        assert s['id']==i
        source_size=s.get('source_size',s['size']);source_text=s.get('source_text_size',s['text_size'])
        assert source_size==word(44+i*8) and source_text==word(64+i*4)
        assert 0<=source_text<=source_size and source_text%4==0
        omitted=release and i==1
        assert type(s.get('loaded',True)) is bool and s.get('loaded',True)==(not omitted)
        assert (s['size'],s['text_size'])==((0,0) if omitted else (source_size,source_text))
        if omitted:assert not s['slots'] and not s['distances'] and not s.get('pointers',[])
        for field in ('code_label','data_label'):
            expected=f'_ottsel_module_{identifier_name}_s{i}_'+('code' if field=='code_label' else 'data')
            assert s[field]==expected
            out.append(f'extern "C" unsigned char {expected[1:]}[];')
        data=(p/f'{name}-s{i}-data.bin').read_bytes()
        assert len(data)==s['size']-s['text_size']
        base=word(76)+word(40+i*8)
        assert base+source_size<=len(original)
        assert data==(b'' if omitted else original[base+source_text:base+source_size])
        out.append(f'static const uint8_t {identifier_name}_data{i}[]={{'+','.join(map(str,data or b'\0'))+'};')
        slots=[f'{{{v["offset"]},SlotKind::{kind[v["kind"]]},{json.dumps(v["name"])},{v["methods"]}}}' for v in s['slots']]
        out.append(f'static const Slot {identifier_name}_slots{i}[]={{'+','.join(slots or ['{}'])+'};')
        occupied={slot['offset'] for slot in s['slots']}
        pointers=s.get('pointers',[])
        for v in pointers:
            assert v.get('kind','data') in ('data','code') and type(v['patch']) is int and type(v['target']) is int
            assert v['patch']%4==0 and s['text_size']<=v['patch']<=s['size']-4 and v['patch'] not in occupied
            occupied.add(v['patch'])
            if v.get('kind','data')=='code':
                # The code base is a linker-time symbol difference no static
                # initializer can hold; the record carries the raw target only.
                assert set(v)=={'patch','target','kind','target_offset'} and v['target_offset']==v['target']
                assert v['target']%4==0 and v['target']+4<=s['source_text_size']
                value=v['target_offset']
            else:
                assert set(v)=={'patch','target','kind','goal_offset'}
                assert v['goal_offset']==s['data_arena_offset']+v['target']-s['text_size']
                assert s['text_size']<=v['target']<s['size']
                value=v['goal_offset']
            v['_value']=value
        values=[f"{{{v['patch']},{v['_value']},{'true' if v.get('kind','data')=='code' else 'false'}}}" for v in pointers]
        out.append(f'static const Pointer {identifier_name}_pointers{i}[]={{'+','.join(values or ['{}'])+'};')
    identifier='manifest' if name=='gstate' else identifier_name+'_manifest'
    out.append('const Manifest '+identifier+'={'+','.join([
        json.dumps(m['module']),json.dumps(m['source_sha256']),str(m['source_bytes']),
        str(m['required_function_type']),'ottsel_module_arena',str(m['arena_size']),
        str(m['data_reservation_offset']),str(m['data_size'])])+',{')
    for s in m['segments']:
        i=s['id']
        out.append('{'+','.join([s['code_label'][1:],s['data_label'][1:],str(s['text_size']),
            str(s['size']-s['text_size']),str(s['data_arena_offset']),f'{identifier_name}_data{i}',
            f'{identifier_name}_slots{i}',str(len(s['slots'])),str(s.get('source_size',s['size'])),
            str(s.get('source_text_size',s['text_size'])),'true' if s.get('loaded',True) else 'false',f'{identifier_name}_pointers{i}',str(len(s.get('pointers',[])))])+'},')
    out.append('},'+('true' if release else 'false')+'};')
out+=['const Manifest* const modules[]={'+','.join('&manifest' if n=='gstate' else '&'+n.replace('-','_')+'_manifest' for n in names)+'};',
      f'const size_t module_count={len(names)};','}']
args.output.write_text('\n'.join(out)+'\n')
