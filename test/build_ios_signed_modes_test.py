"""Execute actual staged shell-only mode/selection branches with compiler mocks."""
import pathlib,subprocess,tempfile,sys
script=(pathlib.Path(sys.argv[1]) if len(sys.argv)>1 else pathlib.Path(__file__).resolve().parents[1]/'scripts/build-ios.sh').read_text()
start=script.index('case "$SIGNED_GSTATE" in')
end=script.index('if [ "$SIGNED_GSTATE" != 0 ]; then',start)
mode=script[start:end]
start=script.index('if [ "$SIGNED_GSTATE" != 0 ]; then',script.index('echo "== [3/4]'))
end=script.index('\ncompile "$REPO_DIR/src/shell/main.cpp"',start)
selection=script[start:end]
checks=0
with tempfile.TemporaryDirectory(prefix='ottsel-build-modes-') as tmp:
 p=pathlib.Path(tmp)
 for cached in range(4):
  (p/'signed-gstate-mode').write_text(str(cached))
  for requested in range(4):
   r=subprocess.run(['bash','-c',f'SIGNED_GSTATE={requested}; SHELL_ONLY=true; APP_BUILD="$1";\n'+mode,'fixture',tmp],capture_output=True)
   assert (r.returncode==0)==(requested==cached),(requested,cached,r.stderr)
   checks+=1
 for requested in ('bad','4','-1'):
  r=subprocess.run(['bash','-c',f'SIGNED_GSTATE={requested}; SHELL_ONLY=false; APP_BUILD="$1";\n'+mode,'fixture',tmp],capture_output=True)
  assert r.returncode==2;checks+=1
 signed=p/'signed';signed.mkdir()
 aggregate=p/'generation';aggregate.mkdir()
 for d in (signed,aggregate):
  for name in ('gcommon.s','gstate.s','gstring.s','manifest.cpp','gstate-arena-layout.s','aggregate-arena-layout.s'):
   (d/name).write_text('fixture')
 (signed/'aggregate-path').write_text(str(aggregate))
 setup='''set -euo pipefail
SIGNED_GSTATE="$1"; SIGNED_DIR="$2"; OBJ="$2/obj"; WORKTREE="$2/source"
SIGNED_EXPORT_BANKS=0; SHELL_ONLY=true; SDK=iphonesimulator; COMMON_FLAGS=(-arch arm64); SIGNED_OBJECTS=()
compile() { printf 'COMPILE %s\\n' "$*"; }
xcrun() { printf 'COMPILER %s\\n' "$*"; }
'''
 for requested in range(4):
  r=subprocess.run(['bash','-c',setup+selection+'\nprintf "OBJECT %s\\n" ${SIGNED_OBJECTS[@]+"${SIGNED_OBJECTS[@]}"}\n','fixture',str(requested),str(signed)],capture_output=True,text=True)
  assert r.returncode==0,r.stderr
  assert r.stdout.count('OBJECT '+str(signed)+'/obj/signed_arena.o')==(requested!=0)
  assert ('signed_gstring_code.o' in r.stdout)==(requested>=2)
  assert ('aggregate-arena-layout.s' in r.stdout)==(requested>=2)
  assert ('gstate-arena-layout.s' in r.stdout)==(requested==1)
  assert ('signed_gcommon_code.o' in r.stdout)==(requested==3)
  checks+=1
 (signed/'aggregate-path').unlink()
 r=subprocess.run(['bash','-c',setup+selection,'fixture','2',str(signed)],capture_output=True,text=True)
 assert r.returncode!=0 and 'full build required' in r.stderr;checks+=1
print(f'{checks} actual shell branch checks PASS; compiler calls mocked, no app/runtime build')
