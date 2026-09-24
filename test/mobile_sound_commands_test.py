#!/usr/bin/env python3
from pathlib import Path
import re,subprocess,sys,tempfile
root=Path(sys.argv[2]) if len(sys.argv)>2 else Path(__file__).resolve().parents[1]
nested=root/'out/jak-project';s=Path(sys.argv[1] if len(sys.argv)>1 else nested/'game/overlord/jak1/srpc.cpp').read_text()
a=s.index('static bool mobile_sound_banks_ready()' if 'static bool mobile_sound_banks_ready()' in s else 'void* RPC_Player(',s.index('#ifdef OTTSEL_IOS'));b=s.index('\n#else',a)
rpc=s[a:b]
ssound=(nested/'game/overlord/common/ssound.cpp').read_text()
ssound=re.sub(r'^#include.*\n','',ssound,flags=re.M)
sif=Path(sys.argv[4]).read_text() if len(sys.argv)>4 else (nested/'game/sce/sif_ee.cpp').read_text()
kdgo=Path(sys.argv[5]).read_text() if len(sys.argv)>5 else (nested/'game/kernel/common/kdgo.cpp').read_text()
pointer_line='\n'.join(line for line in kdgo.splitlines() if line.startswith('ee::sceSifClientData* g_ottsel_player_rpc_bd =') or line.startswith('ee::sceSifClientData* g_ottsel_loader_rpc_bd ='))
a=sif.index('  if (bd == g_ottsel_player_rpc_bd');b=sif.index('\n  }',a)+4
dispatch=sif[a:b]
if '  if (bd == g_ottsel_loader_rpc_bd' in sif:
    a=sif.index('  if (bd == g_ottsel_loader_rpc_bd');b=sif.index('\n  }',a)+4
    dispatch+='\n'+sif[a:b]
route='namespace ee {struct sceSifClientData {int unused;};}\nee::sceSifClientData cd[6];\n'+pointer_line+'\n'
route+='int call_player_route(ee::sceSifClientData* bd,void* send,int ssize){unsigned int fno=0;'+dispatch+'\nreturn 0;}\n'
spatial_source=Path(sys.argv[3]).read_text() if len(sys.argv)>3 else (nested/'game/overlord/jak1/ssound.cpp').read_text()
def function(name):
    a=spatial_source.index('void '+name+'(');start=spatial_source.index('{',a);depth=1;b=start+1
    while depth:
        depth+=(spatial_source[b]=='{')-(spatial_source[b]=='}');b+=1
    return spatial_source[a:b]
spatial='namespace jak1 { VolumePair gPanTable[361];\n'
for name in ['InitSoundFalloff','InitSoundPan','UpdateLocation','SetEarTrans']:
    if 'void '+name+'(' in spatial_source: spatial+=function(name)+'\n'
spatial+='}\n'
pre='''#define OTTSEL_IOS 1
#include <cstdio>
#include "game/common/player_rpc_types.h"
#include "game/common/loader_rpc_types.h"
#include "game/overlord/common/soundcommon.h"
#include "game/common/play_rpc_types.h"
#include <cstring>
#include <filesystem>
#include <map>
#include "game/overlord/jak1/srpc.h"
#include "common/versions/versions.h"
GameVersion g_game_version=GameVersion::Jak1;
namespace fs=std::filesystem;
namespace lg {template<class...A> void info(A...){} template<class...A> void warn(A...){} }
namespace ee {const char* ottsel_iso_data_dir(){return "/fixture";} }
void fake_iso_set_root(std::string){} void fake_iso_init_globals(){} int fake_iso_FS_Init(){return 0;}
namespace jak1 {void fake_iso_init_globals(){} }
int bankLoads=0,bankUnloads=0;uintptr_t nextBank=0;
int FS_LoadSoundBank(char* name,SoundBank* bank){
 std::string lower=name;for(auto& c:lower)c=tolower(c);name=lower.data();
 ++bankLoads;if(strcmp(name,"missing")==0){bank->bank_handle=nullptr;return 0;}
 bank->bank_handle=reinterpret_cast<snd::BankHandle>(++nextBank);bank->name={};strncpy(bank->name.data(),name,16);
 SoundRecord rec{};strcpy(rec.name.data(),strcmp(name,"common")==0?"fly7":"village");bank->sound={rec};
 if(strcmp(name,"common")==0){strcpy(rec.name.data(),"spatial");rec.fallof_params=(1u<<28)|(10u<<14);bank->sound.push_back(rec);}
 if(strcmp(name,"training")==0){bank->sound.clear();for(const char* n:{"training-amb","water-lap-cls"}){SoundRecord r{};strcpy(r.name.data(),n);bank->sound.push_back(r);}}
 bank->sound_count=bank->sound.size();return 0;
}
void ReadBankSoundInfo(SoundBank*,SoundBank*,s32){}
bool failNextPlay=false;int autoPitchCalls=0,autoBendCalls=0;
int soundTick=0; s16 panTable[722]={};int playbackMode=-1,streamVolumeCalls=0;
s32 snd_GetTick(){return soundTick;}
void snd_SetPanTable(s16* p){memcpy(panTable,p,sizeof panTable);}
void snd_SetPlayBackMode(s32 m){playbackMode=m;}
namespace jak1 {void SetVAGVol(){++streamVolumeCalls;} }
struct Native {int volume=0,pan=0,pitch=0,bend=0;bool paused=false;snd::BankHandle bank=nullptr;};
std::map<int,Native> native;int plays=0,nextHandle=0,stops=0,pauses=0,continues=0;
s32 snd_PlaySoundVolPanPMPB(snd::BankHandle bank,s32,s32 v,s32 p,s32 pm,s32 pb){
 if(failNextPlay){failNextPlay=false;return 0;}
 ++plays;int h=++nextHandle;native[h]={v,p,pm,pb,false,bank};return h;}
s32 snd_SoundIsStillPlaying(s32 h){return native.count(h)?h:0;}
u32 snd_GetSoundID(s32 h){return h;}
void snd_UnloadBank(snd::BankHandle bank){++bankUnloads;for(auto it=native.begin();it!=native.end();){if(it->second.bank==bank)it=native.erase(it);else ++it;}}
void snd_ResolveBankXREFS(){}
void snd_StopSound(s32 h){++stops;native.erase(h);}
void snd_SetSoundVolPan(s32 h,s32 v,s32 p){native[h].volume=v;if(p!=-2)native[h].pan=p;}
void snd_SetSoundPitchModifier(s32 h,s32 p){native[h].pitch=p;}
void snd_SetSoundPitchBend(s32 h,s32 p){native[h].bend=p;}
void snd_AutoPitch(s32,s32,s32,s32){++autoPitchCalls;}
void snd_AutoPitchBend(s32,s32,s32,s32){++autoBendCalls;}
void snd_PauseSound(s32 h){++pauses;native[h].paused=true;}
void snd_ContinueSound(s32 h){++continues;native[h].paused=false;}
'''
test='''
int failures=0;void check(bool p,const char* s){printf("%s %s\\n",p?"PASS":"FAIL",s);failures+=!p;}
using namespace jak1;
void send(SoundRpcCommand& c){call_player_route(&cd[PLAYER_RPC_CHANNEL],&c,sizeof c);}
SoundRpcCommand play(int id){SoundRpcCommand c{};c.j1command=Jak1SoundCommand::PLAY;c.play.sound_id=id;strcpy(c.play.name,"fly7");c.play.parms.volume=100;return c;}
void bankCommand(const char* name,bool unload=false){SoundRpcCommand c{};c.j1command=unload?Jak1SoundCommand::UNLOAD_BANK:Jak1SoundCommand::LOAD_BANK;strncpy(c.load_bank.bank_name,name,16);call_player_route(&cd[LOADER_RPC_CHANNEL],&c,sizeof c);}
int main(){
 bankCommand("common");bankCommand("village1");
 auto p=play(65613);send(p);int h=nextHandle;
 check(plays==1 && native.size()==1,"initial PLAY creates one native handle");
 p.play.parms.volume=200;p.play.parms.pitch_mod=7;p.play.parms.bend=8;send(p);
 check(plays==1 && native.size()==1 && native[h].volume==200 && native[h].pitch==7 && native[h].bend==8,"repeated PLAY updates same handle");
 SoundRpcCommand c{};c.sound_id.sound_id=65613;c.j1command=Jak1SoundCommand::PAUSE_SOUND;send(c);
 check(pauses==1 && native[h].paused,"PAUSE maps GOAL id to native handle");
 c.j1command=Jak1SoundCommand::CONTINUE_SOUND;send(c);
 check(continues==1 && !native[h].paused,"CONTINUE resumes owned handle");
 c={};c.j1command=Jak1SoundCommand::SET_PARAM;c.param.sound_id=65613;c.param.parms.mask=0x27;
 c.param.parms.volume=300;c.param.parms.pitch_mod=9;c.param.parms.bend=10;c.param.parms.trans={10,20,30};send(c);
 auto* owned=LookupSound(65613);
 check(owned && owned->params.trans.x==10 && native[h].volume==300 && native[h].pitch==9 && native[h].bend==10,"SET_PARAM applies actual engine mask and position state");
 c.param.parms.mask=1;c.param.parms.volume=350;c.param.parms.pitch_mod=99;send(c);
 check(native[h].volume==350 && native[h].pitch==9,"unset parameter bits preserve existing pitch");
 c.param.parms.mask=0x11;c.param.parms.volume=900;send(c);
 check(native[h].volume==350,"timed volume request does not become an immediate change");
 c={};c.j1command=Jak1SoundCommand::STOP_SOUND;c.sound_id.sound_id=65613;send(c);
 check(stops==1 && native.empty() && !LookupSound(65613),"STOP releases owned sound");
 send(p);check(plays==2 && native.size()==1,"PLAY after stop gets fresh handle");
 native.clear();send(p);check(plays==3 && native.size()==1,"naturally finished sound can replay");
 int before=plays;auto invalid=play(0);send(invalid);check(plays==before,"zero GOAL id cannot create unowned voice");
 c={};c.j1command=Jak1SoundCommand::STOP_SOUND;c.sound_id.sound_id=123;int oldstops=stops;send(c);
 check(stops==oldstops,"unknown id cannot stop another sound");
 // Exercise actual AllocateSound's fixed engine capacity, without stealing voices.
 native.clear();memset(gSounds,0,sizeof gSounds);
 for(int i=1;i<=65;++i){auto q=play(i);send(q);}
 check(native.size()==64,"engine registry bounds ownership at 64 active sounds");
 // Real spatial initialization, distance, listener, pan, and volume-ramp routes.
 native.clear();memset(gSounds,0,sizeof gSounds);
 check(gCurves[1].unk3==-4096 && gCurves[1].unk4==4096,"actual Jak1 falloff initializer installed linear curve");
 check(playbackMode==2 && panTable[2*90]>panTable[2*270],"actual Jak1 pan table reaches native player");
 SoundRpcCommand ear{};ear.j1command=Jak1SoundCommand::SET_EAR_TRANS;send(ear);
 auto spatialPlay=play(700);strcpy(spatialPlay.play.name,"spatial");spatialPlay.play.parms.volume=1000;
 spatialPlay.play.parms.trans={5*256,0,0};send(spatialPlay);int spatialHandle=nextHandle;
 check(native[spatialHandle].volume==500 && native[spatialHandle].pan==270,"real distance attenuation and right-side pan");
 ear.ear_trans.cam_angle=90;send(ear);
 check(native[spatialHandle].volume==500 && native[spatialHandle].pan==180,"camera rotation updates active sound pan");
 ear.ear_trans.ear_trans={5*256,0,0};send(ear);
 check(native[spatialHandle].volume==1000,"listener moves to source with full volume");
 ear.ear_trans.ear_trans={-5*256,0,0};send(ear);
 check(!native.count(spatialHandle),"far listener stops inaudible owned spatial sound");
 ear.ear_trans.ear_trans={0,0,0};ear.ear_trans.cam_angle=0;send(ear);
 spatialPlay.play.sound_id=701;spatialPlay.play.parms.trans={-5*256,0,0};send(spatialPlay);
 check(native[nextHandle].volume==500 && native[nextHandle].pan==90,"opposite position reverses pan without fake attenuation");
 auto volumePlay=play(702);strcpy(volumePlay.play.name,"spatial");volumePlay.play.parms.volume=100;send(volumePlay);int rampHandle=nextHandle;
 c={};c.j1command=Jak1SoundCommand::SET_PARAM;c.param.sound_id=702;c.param.parms.mask=0x11;c.param.parms.volume=200;c.param.auto_time=10;send(c);
 soundTick+=5;send(ear);
 check(native[rampHandle].volume==150,"existing SetEarTrans tick advances real UpdateAutoVol halfway");
 soundTick+=5;send(ear);
 check(native[rampHandle].volume==200,"existing timed volume reaches target");
 check(streamVolumeCalls==0,"mobile bank spatial update avoids unowned IOP VAG voice");
 // Desktop treats volume, position, pitch and bend bits independently.
 c={};c.j1command=Jak1SoundCommand::SET_PARAM;c.param.sound_id=702;
 c.param.parms.mask=0x37;c.param.parms.volume=400;c.param.parms.pitch_mod=70;c.param.parms.bend=80;
 c.param.parms.trans={0,0,0};c.param.auto_time=10;send(c);
 auto* mixed=LookupSound(702);
 check(mixed && mixed->new_volume==400 && mixed->auto_time==10 && mixed->params.pitch_mod==70 && mixed->params.bend==80,"mixed timed mask preserves desktop per-field state updates");
 check(autoPitchCalls==1 && autoBendCalls==1 && native[rampHandle].pitch==0 && native[rampHandle].bend==0,"unsupported native ramps do not become immediate pitch changes");
 soundTick+=5;send(ear);
 check(native[rampHandle].volume==300,"unsupported pitch cannot suppress supported timed volume");
 failNextPlay=true;auto failed=play(900);auto oldNative=native.size();send(failed);
 check(!LookupSound(900) && native.size()==oldNative,"failed native allocation leaves no GOAL ownership");
 send(failed);check(LookupSound(900) && native.size()==oldNative+1,"failed allocation slot is reusable");
 native.clear();memset(gSounds,0,sizeof gSounds);int beforeRoute=plays;
 auto routePlay=play(12345);
 call_player_route(&cd[PLAY_RPC_CHANNEL],&routePlay,sizeof routePlay);
 check(plays==beforeRoute,"PLAY channel5 never enters PLAYER channel0 bank dispatch");
 call_player_route(nullptr,&routePlay,sizeof routePlay);
 check(plays==beforeRoute,"unrecognized client cannot play sound");
 call_player_route(&cd[PLAYER_RPC_CHANNEL],nullptr,sizeof routePlay);
 call_player_route(&cd[PLAYER_RPC_CHANNEL],&routePlay,0);
 call_player_route(&cd[PLAYER_RPC_CHANNEL],&routePlay,-1);
 call_player_route(&cd[PLAYER_RPC_CHANNEL],&routePlay,sizeof routePlay-1);
 check(plays==beforeRoute,"null zero negative and short payloads never play");
 SoundRpcCommand commands[2]={play(12345),play(12346)};
 auto result=call_player_route(&cd[PLAYER_RPC_CHANNEL],commands,sizeof commands);
 check(result==0 && plays==beforeRoute+2,"complete two-command batch reaches real registry via actual SIF gate");
 auto firstHandle=LookupSound(12345)->sound_handle;
 commands[0].play.parms.volume=400;commands[1]=play(12347);
 call_player_route(&cd[PLAYER_RPC_CHANNEL],commands,sizeof commands-1);
 check(native[firstHandle].volume==400 && !LookupSound(12347),"trailing partial command ignored as in desktop count contract");
 bankCommand("training");char trainingName[16]={};strcpy(trainingName,"training");auto* training=LookupBank(trainingName);
 check(training && training->bank_handle,"loader channel1 loads requested training bank");
 int previousLoads=bankLoads;bankCommand("training");check(bankLoads==previousLoads,"duplicate LOAD_BANK reuses resident bank");
 auto ambience=play(9090);strcpy(ambience.play.name,"training-amb");send(ambience);auto* ambienceSound=LookupSound(9090);
 check(ambienceSound && ambienceSound->bank_entry,"newly loaded training sound resolves through actual bank registry");
 int unloads=bankUnloads;bankCommand("training",true);
 check(bankUnloads==unloads+1 && !LookupSound(9090) && training->bank_handle==nullptr,"unload stops bank audio and retires registry references");
 bankCommand("training",true);check(bankUnloads==unloads+1,"duplicate UNLOAD_BANK has no native side effects");
 bankCommand("training");send(ambience);check(LookupSound(9090),"reloaded bank supports sound playback again");
 bankCommand("missing");char missingName[16]={};strcpy(missingName,"missing");check(!LookupBank(missingName),"failed bank load cannot become resident");
 previousLoads=bankLoads;bankCommand("1234567890123456");check(bankLoads==previousLoads,"unsafe nonterminated 16-byte bank name rejected");
 bankCommand("extra1");bankCommand("extra2");bankCommand("extra3");previousLoads=bankLoads;bankCommand("overflow");
 check(bankLoads==previousLoads,"existing six-bank capacity bounds loading");
 return failures?1:0;
}
'''
sbank=re.sub(r'^#include.*\n','',(nested/'game/overlord/common/sbank.cpp').read_text(),flags=re.M)
with tempfile.TemporaryDirectory(prefix='ottsel-audio-commands-') as out:
 cpp=Path(out)/'test.cpp';exe=Path(out)/'test';cpp.write_text(pre+ssound+sbank+spatial+'\nnamespace jak1 {\n'+rpc+'\n}\n'+route+test)
 subprocess.run(['xcrun','clang++','-std=c++20','-I'+str(nested),str(cpp),'-o',str(exe)],check=True)
 sys.exit(subprocess.run([str(exe)],timeout=10).returncode)
