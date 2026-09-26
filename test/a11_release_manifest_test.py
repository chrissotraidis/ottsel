"""Reject ambiguous omitted-debug metadata against a genuine emitted module."""
import copy,importlib.util,json,pathlib,sys,tempfile
repo=pathlib.Path(__file__).resolve().parents[1]
source=pathlib.Path(sys.argv[1])
spec=importlib.util.spec_from_file_location('arena',sys.argv[2] if len(sys.argv)>2 else repo/'scripts/emit-signed-module-arena.py')
a=importlib.util.module_from_spec(spec);spec.loader.exec_module(a)
a.load(source/'gcommon.json')
original=json.loads((source/'gcommon.json').read_text())
with tempfile.TemporaryDirectory(prefix='release-manifest-') as tmp:
    p=pathlib.Path(tmp)
    for name in ['gcommon.s','gcommon.source.o']+[f'gcommon-s{i}-data.bin' for i in range(3)]:
        (p/name).symlink_to((source/name).resolve())
    def reject(label,change):
        m=copy.deepcopy(original);change(m);f=p/'gcommon.json';f.write_text(json.dumps(m))
        try:a.load(f)
        except ValueError:print('PASS reject',label);return
        raise AssertionError(label)
    reject('unknown policy',lambda m:m.update(debug_policy='discard-anything'))
    reject('unmarked omission',lambda m:m.update(schema=1,debug_policy='reject-nonempty'))
    reject('debug still loaded',lambda m:m['segments'][1].update(loaded=True))
    reject('nonboolean loaded marker',lambda m:m['segments'][1].update(loaded=0))
    reject('rewritten debug source bound',lambda m:m['segments'][1].update(source_size=0))
    reject('main omission',lambda m:m['segments'][0].update(loaded=False,size=0,text_size=0))
    reject('absent target offset retained as segment',lambda m:next(r for r in m['segments'][2]['distances'] if r['target_segment']==1).update(target_policy='segment'))
    reject('live target falsely nulled',lambda m:next(r for r in m['segments'][0]['distances'] if r['target_segment']==0).update(target_policy='goal-zero'))
print('PASS genuine schema2 and 8 fail-closed manifest controls')
