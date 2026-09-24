#!/usr/bin/env python3
"""Run actual Player output lifecycle methods with deterministic SDL open gates."""
from pathlib import Path
import subprocess,sys,tempfile
root=Path(__file__).resolve().parents[1]
s=Path(sys.argv[1] if len(sys.argv)>1 else root/'out/jak-project/game/sound/989snd/player.cpp').read_text()
a=s.index('struct ApplePlaybackState {'); b=s.index('ApplePlaybackState g_apple_playback;',a)+len('ApplePlaybackState g_apple_playback;')
state=s[a:b]
a=s.index('void Player::InitOutput()'); b=s.index('#if !defined(__APPLE__)',s.index('void Player::ResumeOutput()',a))
methods=s[a:b]
pre='''#include <algorithm>
#include <atomic>
#include <chrono>
#include <condition_variable>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <mutex>
#include <string>
#include <thread>
using namespace std::chrono_literals;
namespace lg {template<class...A> void info(A...){} template<class...A> void warn(A...){} template<class...A> void error(A...){} }
using SDL_AudioDeviceID=int;
struct SDL_AudioStream{}; struct SDL_AudioSpec{int format,channels,freq;};
constexpr int SDL_AUDIO_S16=1, SDL_INIT_AUDIO=1,SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK=1;
constexpr const char* SDL_HINT_AUDIO_CATEGORY="category";
std::mutex gate_mutex; std::condition_variable gate_cv;
bool open_entered=false, release_open=false;
std::atomic<int> resumes{0},pauses{0},destroys{0};
void SDL_SetHint(const char*,const char*){} bool SDL_InitSubSystem(int){return true;}
const char* SDL_GetError(){return "mock";}
SDL_AudioDeviceID* SDL_GetAudioPlaybackDevices(int* count){*count=0;return nullptr;}
const char* SDL_GetAudioDeviceName(int){return "mock output";}
void SDL_free(void*){}
SDL_AudioStream* SDL_OpenAudioDeviceStream(int,const SDL_AudioSpec*,void(*)(void*,SDL_AudioStream*,int,int),void*){
 std::unique_lock lock(gate_mutex);open_entered=true;gate_cv.notify_all();
 gate_cv.wait(lock,[]{return release_open;});return new SDL_AudioStream;
}
int SDL_GetAudioStreamDevice(SDL_AudioStream*){return 2;}
bool SDL_ResumeAudioDevice(int){++resumes;return true;}
bool SDL_ResumeAudioStreamDevice(SDL_AudioStream*){++resumes;return true;}
bool SDL_PauseAudioStreamDevice(SDL_AudioStream*){++pauses;return true;}
void SDL_DestroyAudioStream(SDL_AudioStream* stream){++destroys;delete stream;}
void SDL_QuitSubSystem(int){}
struct Player {void InitOutput();void DestroyOutput();void PauseOutput();void ResumeOutput();
static void sdl_sound_callback(void*,SDL_AudioStream*,int,int){} };
'''
tests='''
int failures=0;
void check(bool ok,const char* what){printf("%s %s\\n",ok?"PASS":"FAIL",what);failures+=!ok;}
void reset(){std::lock_guard lock(gate_mutex);open_entered=false;release_open=false;resumes=0;pauses=0;destroys=0;}
void await_open(){std::unique_lock lock(gate_mutex);if(!gate_cv.wait_for(lock,2s,[]{return open_entered;})) std::abort();}
void release(){std::lock_guard lock(gate_mutex);release_open=true;gate_cv.notify_all();}
void join_open(){if(g_apple_playback.opening_thread.joinable())g_apple_playback.opening_thread.join();}
int main(){
 Player p;
 reset();p.PauseOutput();p.InitOutput();await_open();release();join_open();
 check(resumes==0 && g_apple_playback.stream,"pause before open publishes paused stream");
 p.ResumeOutput();check(resumes==1,"foreground resumes paused published stream");
 p.PauseOutput();check(pauses==1,"background pauses existing stream");
 p.DestroyOutput();check(destroys==1 && !g_apple_playback.stream,"close removes published stream");
 reset();p.InitOutput();await_open();p.PauseOutput();release();join_open();
 check(resumes==0,"pause during open prevents implicit resume");p.DestroyOutput();
 reset();p.InitOutput();await_open();p.PauseOutput();p.ResumeOutput();release();join_open();
 check(resumes==1 && g_apple_playback.stream,"resume during open starts exactly once");p.DestroyOutput();
 reset();p.InitOutput();await_open();
 std::thread closer([&]{p.DestroyOutput();});
 bool closing=false;
 for(int i=0;i<2000&&!closing;++i){
 {std::lock_guard lock(g_apple_playback.player_mutex);closing=g_apple_playback.shutting_down;}
 if(!closing)std::this_thread::sleep_for(1ms);
 }
 if(!closing)std::abort();release();closer.join();
 check(resumes==0 && destroys==1 && !g_apple_playback.stream,"close during open destroys without resuming");
 check(!g_apple_playback.player && !g_apple_playback.opening,"close leaves no live owner or opener");
 reset();p.InitOutput();await_open();release();join_open();
 check(resumes==1 && g_apple_playback.stream,"reopen after close resets stale pause intent");p.DestroyOutput();
 return failures?1:0;
}
'''
with tempfile.TemporaryDirectory(prefix='ottsel-audio-lifecycle-') as out:
    cpp=Path(out)/'test.cpp';exe=Path(out)/'test';cpp.write_text(pre+state+methods+tests)
    subprocess.run(['xcrun','clang++','-std=c++17','-pthread',str(cpp),'-o',str(exe)],check=True)
    sys.exit(subprocess.run([str(exe)],timeout=10).returncode)
