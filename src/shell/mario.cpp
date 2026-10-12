// The "Play as Mario" mod. See mario.h.
#include "mario.h"

#include <algorithm>
#include <atomic>
#include <chrono>
#include <cmath>
#include <cstdlib>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <thread>
#include <vector>

#include <SDL3/SDL.h>

#include "libsm64.h"
#include "decomp/include/audio_defines.h"
#include "decomp/include/mario_animation_ids.h"

#include "common/log/log.h"
#include "common/symbols.h"
#include "game/graphics/opengl_renderer/BucketRenderer.h"
#include "game/kernel/common/kscheme.h"
#include "game/kernel/jak1/kscheme.h"

namespace {

constexpr float kMetre = 4096.f;          // Jak's world: 4096 units to the metre
constexpr float kScale = kMetre / 100.f;  // Mario's world: 100 units to the metre
constexpr double kTick = 1.0 / 30.0;      // Mario's world runs at 30 Hz, as on the N64

// What Jak is doing, as ottsel-mario-pose numbers it (goal_src/jak1/engine/game/main.gc).
enum Pose {
  kJak, kIdle, kWalk, kJump, kDoubleJump, kHighJump, kFall, kLand, kFlop, kFlopLand, kPunch, kSpin,
  kAirSpin, kUppercut, kDuck, kDuckWalk, kSwimIdle, kSwim, kDive, kLedge, kPole, kPoleFlip, kHit, kDeath,
  kSlide, kLaunch, kRoll, kLongJump, kBlast, kTripleJump, kSideflip
};

struct State {
  std::string dir;
  bool enabled = false;
  bool moves = false;  // Mario's Moves (Mods)
  bool sm64_ready = false;
  std::vector<u8> rom;
  std::vector<u8> texture;
  int id = -1;
  std::vector<float> pos = std::vector<float>(9 * SM64_GEO_MAX_TRIANGLES);
  std::vector<float> nrm = std::vector<float>(9 * SM64_GEO_MAX_TRIANGLES);
  std::vector<float> col = std::vector<float>(9 * SM64_GEO_MAX_TRIANGLES);
  std::vector<float> uv = std::vector<float>(6 * SM64_GEO_MAX_TRIANGLES);
  int tris = 0;
  float at[3] = {};  // Jak's feet, where Mario's (0, 0, 0) is
  // The pose being played.
  int pose = -1;
  int anim_id = -1;
  bool anim_ended = false;
  int idle_step = 0;
  int punches = 0;
  bool running = false;
  bool start_done = false;
  bool was_swimming = false;
  int16_t spin = 0;
  double audio_acc = 0;
  std::chrono::steady_clock::time_point last;
  bool have_last = false;
  // Drawing.
  GLuint prog = 0, vao = 0, vbo = 0, tex = 0;
  GLint u_camera = -1, u_hvdf = -1, u_fog = -1, u_tex = -1, u_flat = -1;
  std::vector<float> verts;
  Ptr<jak1::Symbol> s_on, s_moves, s_jak, s_dir, s_state, s_shadow, s_shadow_n, s_mode, s_game;
  std::atomic<SDL_AudioStream*> audio{nullptr};
  std::atomic<bool> audio_opening{false};
} g;

// ---- ROM ----

std::string find_rom(const std::string& dir) {
  std::error_code ec;
  for (const auto& entry : std::filesystem::directory_iterator(dir, ec)) {
    const auto ext = entry.path().extension().string();
    if (ext == ".z64" || ext == ".v64" || ext == ".n64") {
      return entry.path().string();
    }
  }
  return {};
}

// Any of the three common byte orders; the US release only (libsm64 reads it by address).
bool load_rom(const std::string& path, std::vector<u8>& rom) {
  std::ifstream file(path, std::ios::binary);
  rom.assign(std::istreambuf_iterator<char>(file), {});
  if (rom.size() != 8 * 1024 * 1024) {
    return false;
  }
  const u32 magic = (u32(rom[0]) << 24) | (u32(rom[1]) << 16) | (u32(rom[2]) << 8) | rom[3];
  if (magic == 0x37804012) {  // .v64: 16-bit swapped
    for (size_t i = 0; i < rom.size(); i += 2) std::swap(rom[i], rom[i + 1]);
  } else if (magic == 0x40123780) {  // .n64: 32-bit little-endian
    for (size_t i = 0; i < rom.size(); i += 4) {
      std::swap(rom[i], rom[i + 3]);
      std::swap(rom[i + 1], rom[i + 2]);
    }
  } else if (magic != 0x80371240) {
    return false;
  }
  return std::memcmp(&rom[0x20], "SUPER MARIO 64", 14) == 0 && rom[0x3E] == 'E';
}

// ---- GOAL side (goal_src/jak1/engine/game/main.gc) ----

bool resolve_symbols() {
  if (g.s_on.offset) {
    return true;
  }
  auto on = jak1::find_symbol_from_c("*ottsel-mario-on*");
  if (!on.offset) {
    return false;
  }
  g.s_moves = jak1::find_symbol_from_c("*ottsel-mario-moves*");
  g.s_jak = jak1::find_symbol_from_c("*ottsel-mario-jak*");
  g.s_dir = jak1::find_symbol_from_c("*ottsel-mario-dir*");
  g.s_state = jak1::find_symbol_from_c("*ottsel-mario-state*");
  g.s_shadow = jak1::find_symbol_from_c("*ottsel-mario-shadow*");
  g.s_shadow_n = jak1::find_symbol_from_c("*ottsel-mario-shadow-normal*");
  g.s_mode = jak1::find_symbol_from_c("*master-mode*");
  g.s_game = jak1::find_symbol_from_c("game");
  g.s_on = on;
  return g.s_moves.offset && g.s_jak.offset && g.s_dir.offset && g.s_state.offset && g.s_shadow.offset &&
         g.s_shadow_n.offset && g.s_mode.offset && g.s_game.offset;
}

u32 goal_bool(bool b) {
  return s7.offset + (b ? jak1_symbols::FIX_SYM_TRUE : jak1_symbols::FIX_SYM_FALSE);
}

const float* goal_vector(Ptr<jak1::Symbol> s) {
  return Ptr<float>(s->value).c();
}

// ---- Mario's voice: libsm64 mixes it at 32 kHz; it plays beside the game's own audio ----

void open_audio() {
  if (g.audio.load() || g.audio_opening.exchange(true)) {
    return;
  }
  // Opened off the main thread, as the game's own output is (game/sound/989snd/player.cpp).
  std::thread([] {
    const SDL_AudioSpec spec = {SDL_AUDIO_S16, 2, 32000};
    SDL_AudioStream* stream = nullptr;
    if (SDL_InitSubSystem(SDL_INIT_AUDIO)) {
      stream = SDL_OpenAudioDeviceStream(SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK, &spec, nullptr, nullptr);
    }
    if (stream) {
      SDL_SetAudioStreamGain(stream, 0.7f);
      SDL_ResumeAudioStreamDevice(stream);
      g.audio.store(stream);
      lg::info("OTTSEL MARIO: sound output opened");
    } else {
      lg::warn("OTTSEL MARIO: no sound output: {}", SDL_GetError());
    }
    g.audio_opening.store(false);
  }).detach();
}

void tick_audio() {
  SDL_AudioStream* stream = g.audio.load();
  if (!stream) {
    return;
  }
  static int16_t buffer[544 * 2 * 2];
  const int queued = SDL_GetAudioStreamQueued(stream) / 4;  // stereo s16 frames
  const uint32_t frames = sm64_audio_tick((uint32_t)queued, 1100, buffer);
  if (queued < 6000) {
    SDL_PutAudioStreamData(stream, buffer, (int)(frames * 2 * 4));
  }
}

void say(int32_t sound) {
  sm64_play_sound_global(sound);
}

// ---- Jak's state as Mario's animation ----

struct Anim {
  int id;
  float rate = 1.f;      // animation frames per 30 Hz tick, as Mario's own actions pace them
  bool restart = false;  // start over (a new punch, a new jump)
  bool spin = false;     // turn him round and round (Jak's spin in the air)
};

// speed: Jak's ground speed in Mario's units per tick; rise: his vertical speed, the same units.
Anim choose(int pose, bool entered, float speed, float rise, bool ground) {
  switch (pose) {
    case kIdle:
    default: {
      if (entered) g.idle_step = 0;
      else if (g.anim_ended) g.idle_step++;
      static const int idle[] = {MARIO_ANIM_IDLE_HEAD_LEFT, MARIO_ANIM_IDLE_HEAD_RIGHT,
                                 MARIO_ANIM_IDLE_HEAD_CENTER};
      return {idle[g.idle_step % 3], 1.f, entered || g.anim_ended};
    }
    case kWalk:
      // Mario's own thresholds (mario_actions_moving.c): tiptoe, walk, then run, with some hysteresis.
      g.running = g.running ? speed > 18.f : speed > 22.f;
      if (speed < 1.f) return choose(kIdle, entered, speed, rise, ground);
      if (speed < 5.f) return {MARIO_ANIM_TIPTOE, std::max(speed, 0.25f)};
      return {g.running ? MARIO_ANIM_RUNNING : MARIO_ANIM_WALKING, speed / 4.f};
    case kJump:
      return {MARIO_ANIM_SINGLE_JUMP, 1.f, entered};
    case kDoubleJump:
      return {rise > 0 ? MARIO_ANIM_DOUBLE_JUMP_RISE : MARIO_ANIM_DOUBLE_JUMP_FALL, 1.f, entered};
    case kHighJump:
      return {MARIO_ANIM_BACKFLIP, 1.f, entered};
    case kFall:
      return {MARIO_ANIM_GENERAL_FALL};
    case kLand:
      return {MARIO_ANIM_LAND_FROM_SINGLE_JUMP, 1.f, entered};
    case kFlop:
      if (entered) g.start_done = false;
      else if (g.anim_ended) g.start_done = true;
      return {g.start_done ? MARIO_ANIM_GROUND_POUND : MARIO_ANIM_START_GROUND_POUND, 1.f, entered};
    case kFlopLand:
      return {MARIO_ANIM_GROUND_POUND_LANDING, 1.f, entered};
    case kPunch:
      if (entered) g.punches++;
      return {g.punches % 2 ? MARIO_ANIM_FIRST_PUNCH : MARIO_ANIM_SECOND_PUNCH, 1.f, entered};
    case kSpin:
      return {MARIO_ANIM_BREAKDANCE, 1.f, entered};
    case kAirSpin:
      return {MARIO_ANIM_TWIRL, 1.f, entered, true};
    case kUppercut:
      return {MARIO_ANIM_AIR_KICK, 1.f, entered};
    case kDuck:
      return {MARIO_ANIM_CROUCHING};
    case kDuckWalk:
      return {MARIO_ANIM_CRAWLING, std::clamp(speed * 0.5f, 0.5f, 4.f)};
    case kSwimIdle:
      return {MARIO_ANIM_WATER_IDLE};
    case kSwim:
      return {MARIO_ANIM_FLUTTERKICK, std::clamp(speed / 6.f, 0.5f, 2.f)};
    case kDive:
      return {MARIO_ANIM_SWIM_PART1};
    case kLedge:
      return {MARIO_ANIM_IDLE_ON_LEDGE};
    case kPole:
      return {MARIO_ANIM_HANG_ON_CEILING};
    case kPoleFlip:
      return {MARIO_ANIM_FORWARD_SPINNING_FLIP, 1.f, entered};
    case kHit:
      return {ground ? MARIO_ANIM_BACKWARD_KB : MARIO_ANIM_BACKWARD_AIR_KB, 1.f, entered};
    case kDeath:
      if (g.was_swimming) return {MARIO_ANIM_WATER_DYING, 1.f, entered};
      return {ground ? MARIO_ANIM_DYING_FALL_OVER : MARIO_ANIM_GENERAL_FALL, 1.f, entered};
    case kSlide:
      return {MARIO_ANIM_SLIDE};
    case kLaunch:
      return {MARIO_ANIM_TRIPLE_JUMP, 1.f, entered};
    case kRoll:
      return {MARIO_ANIM_FORWARD_SPINNING, 1.f, entered};
    case kLongJump:
      return {MARIO_ANIM_FAST_LONGJUMP, 1.f, entered};
    case kBlast:
      return {MARIO_ANIM_FIRST_PUNCH_FAST, 1.f, entered};
    case kTripleJump:
      return {MARIO_ANIM_TRIPLE_JUMP, 1.f, entered};
    case kSideflip:
      return {MARIO_ANIM_SLIDEFLIP, 1.f, entered};
  }
}

// His voice on the moves he would call out.
void call_out(int pose, bool ground) {
  switch (pose) {
    case kJump: say(SOUND_MARIO_YAH_WAH_HOO + ((std::rand() % 3) << 16)); break;
    case kDoubleJump: say(SOUND_MARIO_HOOHOO); break;
    case kHighJump:
    case kLongJump: say(SOUND_MARIO_YAHOO); break;
    case kFlop: say(SOUND_MARIO_GROUND_POUND_WAH); break;
    case kPunch:
    case kBlast: say(SOUND_MARIO_PUNCH_YAH); break;
    case kSpin:
    case kAirSpin: say(SOUND_MARIO_PUNCH_HOO); break;
    case kUppercut: say(SOUND_MARIO_PUNCH_WAH); break;
    case kHit: say(SOUND_MARIO_ATTACKED); break;
    case kDeath: say(ground || g.was_swimming ? SOUND_MARIO_DYING : SOUND_MARIO_WAAAOOOW); break;
    case kLaunch: say(SOUND_MARIO_YAHOO_WAHA_YIPPEE); break;
    case kTripleJump: say(SOUND_MARIO_YAHOO_WAHA_YIPPEE + ((std::rand() % 5) << 16)); break;
    case kSideflip: say(SOUND_MARIO_YAH_WAH_HOO + ((std::rand() % 3) << 16)); break;
    default: break;
  }
}

// ---- drawing ----

const char* kVert = R"(#version 300 es
precision highp float;
layout(location = 0) in vec3 position_in;
layout(location = 1) in vec3 normal_in;
layout(location = 2) in vec3 color_in;
layout(location = 3) in vec2 uv_in;
uniform mat4 camera;
uniform vec4 hvdf_offset;
uniform float fog_constant;
out vec3 v_color;
out vec2 v_uv;
out float v_light;
void main() {
  // The game's camera transform (as the collision mesh is drawn).
  vec4 transformed = -camera[3].xyzw;
  transformed += -camera[0] * position_in.x;
  transformed += -camera[1] * position_in.y;
  transformed += -camera[2] * position_in.z;
  float Q = fog_constant / transformed[3];
  transformed.xyz *= Q;
  transformed.xyz += hvdf_offset.xyz;
  transformed.xy -= (2048.);
  transformed.z /= (8388608.);
  transformed.z -= 1.;
  transformed.x /= (256.);
  transformed.y /= -(128.);
  transformed.xyz *= transformed.w;
  gl_Position = transformed;
  v_color = color_in;
  v_uv = uv_in;
  v_light = 0.55 + 0.45 * clamp(dot(normalize(normal_in), normalize(vec3(0.35, 1.0, 0.25))), 0., 1.);
})";

const char* kFrag = R"(#version 300 es
precision mediump float;
uniform sampler2D mario_tex;
uniform vec4 flat_color;
in vec3 v_color;
in vec2 v_uv;
in float v_light;
out vec4 color;
void main() {
  if (flat_color.a > 0.0) {
    color = flat_color;  // his shadow
    return;
  }
  vec4 t = texture(mario_tex, v_uv);
  color = vec4(mix(v_color, t.rgb, t.a) * v_light, 1.0);
})";

GLuint compile(GLenum kind, const char* source) {
  GLuint shader = glCreateShader(kind);
  glShaderSource(shader, 1, &source, nullptr);
  glCompileShader(shader);
  GLint ok = 0;
  glGetShaderiv(shader, GL_COMPILE_STATUS, &ok);
  if (!ok) {
    char log[1024];
    glGetShaderInfoLog(shader, sizeof(log), nullptr, log);
    lg::error("OTTSEL MARIO: shader: {}", log);
  }
  return shader;
}

void ensure_gl() {
  if (g.prog) {
    return;
  }
  g.prog = glCreateProgram();
  glAttachShader(g.prog, compile(GL_VERTEX_SHADER, kVert));
  glAttachShader(g.prog, compile(GL_FRAGMENT_SHADER, kFrag));
  glLinkProgram(g.prog);
  g.u_camera = glGetUniformLocation(g.prog, "camera");
  g.u_hvdf = glGetUniformLocation(g.prog, "hvdf_offset");
  g.u_fog = glGetUniformLocation(g.prog, "fog_constant");
  g.u_tex = glGetUniformLocation(g.prog, "mario_tex");
  g.u_flat = glGetUniformLocation(g.prog, "flat_color");
  glGenVertexArrays(1, &g.vao);
  glGenBuffers(1, &g.vbo);
  glGenTextures(1, &g.tex);
  glBindTexture(GL_TEXTURE_2D, g.tex);
  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, SM64_TEXTURE_WIDTH, SM64_TEXTURE_HEIGHT, 0, GL_RGBA,
               GL_UNSIGNED_BYTE, g.texture.data());
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
  lg::info("OTTSEL MARIO: renderer ready");
}

void put_vertex(float*& out, const float* p, const float* n, const float* c, const float* uv) {
  std::copy(p, p + 3, out);
  std::copy(n, n + 3, out + 3);
  std::copy(c, c + 3, out + 6);
  std::copy(uv, uv + 2, out + 9);
  out += 11;
}

// A round shadow on the ground under him, smaller the higher he is.
int build_shadow(float*& out) {
  const float* ground = goal_vector(g.s_shadow);
  if (ground[3] != 1.f || g.pose == kSwimIdle || g.pose == kSwim || g.pose == kDive) {
    return 0;
  }
  const float* nv = goal_vector(g.s_shadow_n);
  float n[3] = {nv[0], nv[1], nv[2]};
  const float len = std::sqrt(n[0] * n[0] + n[1] * n[1] + n[2] * n[2]);
  if (len < 0.5f) return 0;
  for (float& c : n) c /= len;
  const float height = (g.at[1] - ground[1]) / kMetre;
  const float radius = 0.42f * kMetre * std::clamp(1.f - height / 12.f, 0.4f, 1.f);
  // Two directions along the ground.
  float a[3] = {n[2], 0.f, -n[0]};
  float al = std::sqrt(a[0] * a[0] + a[2] * a[2]);
  if (al < 1e-3f) { a[0] = 1.f; a[2] = 0.f; al = 1.f; }
  for (float& c : a) c /= al;
  const float b[3] = {n[1] * a[2] - n[2] * a[1], n[2] * a[0] - n[0] * a[2], n[0] * a[1] - n[1] * a[0]};
  const float lift = 0.02f * kMetre;
  const float centre[3] = {ground[0] + n[0] * lift, ground[1] + n[1] * lift, ground[2] + n[2] * lift};
  const float zero[3] = {0, 0, 0}, up[3] = {0, 1, 0};
  constexpr int kSides = 20;
  for (int i = 0; i < kSides; i++) {
    float p[2][3];
    for (int k = 0; k < 2; k++) {
      const float t = float(i + k) / kSides * 6.2831853f, c = std::cos(t) * radius, s = std::sin(t) * radius;
      for (int a3 = 0; a3 < 3; a3++) p[k][a3] = centre[a3] + a[a3] * c + b[a3] * s;
    }
    put_vertex(out, centre, up, zero, zero);
    put_vertex(out, p[0], up, zero, zero);
    put_vertex(out, p[1], up, zero, zero);
  }
  return kSides;
}

void draw(SharedRenderState* rs) {
  if (g.tris == 0) {
    return;
  }
  ensure_gl();
  g.verts.resize(size_t(g.tris + 32) * 3 * 11);
  float* out = g.verts.data();
  for (int i = 0; i < g.tris * 3; i++) {
    float p[3];
    for (int a = 0; a < 3; a++) p[a] = g.at[a] + g.pos[i * 3 + a] * kScale;
    put_vertex(out, p, &g.nrm[i * 3], &g.col[i * 3], &g.uv[i * 2]);
  }
  const int shadow = build_shadow(out);

  GLint old_prog = 0, old_vao = 0, old_buf = 0, old_active = 0, old_tex = 0, old_depth_func = 0;
  GLint old_src = 0, old_dst = 0;
  GLboolean old_depth_mask = GL_TRUE;
  glGetIntegerv(GL_CURRENT_PROGRAM, &old_prog);
  glGetIntegerv(GL_VERTEX_ARRAY_BINDING, &old_vao);
  glGetIntegerv(GL_ARRAY_BUFFER_BINDING, &old_buf);
  glGetIntegerv(GL_ACTIVE_TEXTURE, &old_active);
  glActiveTexture(GL_TEXTURE0);
  glGetIntegerv(GL_TEXTURE_BINDING_2D, &old_tex);
  glGetIntegerv(GL_DEPTH_FUNC, &old_depth_func);
  glGetBooleanv(GL_DEPTH_WRITEMASK, &old_depth_mask);
  glGetIntegerv(GL_BLEND_SRC_RGB, &old_src);
  glGetIntegerv(GL_BLEND_DST_RGB, &old_dst);
  const GLboolean blend = glIsEnabled(GL_BLEND), cull = glIsEnabled(GL_CULL_FACE),
                  depth = glIsEnabled(GL_DEPTH_TEST);

  glUseProgram(g.prog);
  glBindVertexArray(g.vao);
  glBindBuffer(GL_ARRAY_BUFFER, g.vbo);
  glBufferData(GL_ARRAY_BUFFER, (out - g.verts.data()) * sizeof(float), g.verts.data(), GL_STREAM_DRAW);
  const GLsizei stride = 11 * sizeof(float);
  const GLint sizes[4] = {3, 3, 3, 2};
  const int offsets[4] = {0, 3, 6, 9};
  for (int a = 0; a < 4; a++) {
    glEnableVertexAttribArray(a);
    glVertexAttribPointer(a, sizes[a], GL_FLOAT, GL_FALSE, stride, (void*)(offsets[a] * sizeof(float)));
  }
  glBindTexture(GL_TEXTURE_2D, g.tex);
  glUniform1i(g.u_tex, 0);
  glUniformMatrix4fv(g.u_camera, 1, GL_FALSE, rs->camera_matrix[0].data());
  glUniform4f(g.u_hvdf, rs->camera_hvdf_off[0], rs->camera_hvdf_off[1], rs->camera_hvdf_off[2],
              rs->camera_hvdf_off[3]);
  glUniform1f(g.u_fog, rs->camera_fog.x());
  glEnable(GL_DEPTH_TEST);
  glDepthFunc(GL_GEQUAL);
  glDisable(GL_CULL_FACE);

  glDepthMask(GL_TRUE);
  glDisable(GL_BLEND);
  glUniform4f(g.u_flat, 0, 0, 0, 0);
  glDrawArrays(GL_TRIANGLES, 0, g.tris * 3);

  if (shadow) {
    glDepthMask(GL_FALSE);
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glUniform4f(g.u_flat, 0.f, 0.f, 0.f, 0.45f);
    glDrawArrays(GL_TRIANGLES, g.tris * 3, shadow * 3);
  }

  // Hand the game's renderers back the state they left.
  if (!depth) glDisable(GL_DEPTH_TEST);
  glDepthFunc(old_depth_func);
  glDepthMask(old_depth_mask);
  glBlendFunc(old_src, old_dst);
  if (blend) glEnable(GL_BLEND);
  else glDisable(GL_BLEND);
  if (cull) glEnable(GL_CULL_FACE);
  glBindTexture(GL_TEXTURE_2D, old_tex);
  glActiveTexture(old_active);
  glBindBuffer(GL_ARRAY_BUFFER, old_buf);
  glBindVertexArray(old_vao);
  glUseProgram(old_prog);
}

// ---- each frame ----

void frame(SharedRenderState* rs) {
  if (!g.enabled || !resolve_symbols()) {
    return;
  }
  g.s_on->value = goal_bool(true);
  g.s_moves->value = goal_bool(g.moves);
  const auto now = std::chrono::steady_clock::now();
  const double dt = g.have_last ? std::min(std::chrono::duration<double>(now - g.last).count(), 0.1) : 0.0;
  g.last = now;
  g.have_last = true;

  const float* jak = goal_vector(g.s_jak);
  if (jak[3] != 1.f) {  // the game draws Jak himself here, or hides him
    g.tris = 0;
    g.pose = -1;
    return;
  }
  if (g.id < 0) {
    // Mario stands on a little floor of his own: libsm64 places him only over ground.
    const SM64Surface floor[2] = {{0, 0, 1, {{-500, 0, -500}, {-500, 0, 500}, {500, 0, 500}}},
                                  {0, 0, 1, {{-500, 0, -500}, {500, 0, 500}, {500, 0, -500}}}};
    sm64_static_surfaces_load(floor, 2);
    g.id = sm64_mario_create(0, 0, 0);
    if (g.id < 0) {
      return;
    }
    lg::info("OTTSEL MARIO: Mario {} stands in for Jak", g.id);
  }
  std::copy(jak, jak + 3, g.at);

  // Paused (or a menu): he holds his pose.
  if (g.s_mode->value == g.s_game.offset) {
    const float* st = goal_vector(g.s_state);
    const int pose = (int)std::lround(st[0]);
    const float speed = st[1] / kScale * float(kTick);  // Mario's units per tick
    const float rise = st[2] / kScale * float(kTick);
    const bool ground = st[3] == 1.f;
    const bool entered = pose != g.pose;
    if (entered) {
      call_out(pose, ground);
    }
    const Anim anim = choose(pose, entered, speed, rise, ground);
    if (entered || anim.id != g.anim_id) {
      lg::info("OTTSEL MARIO: pose {} anim {} speed {:.1f} rise {:.1f} ground {}", pose, anim.id, speed, rise,
               ground);
      g.anim_id = anim.id;
    }
    g.pose = pose;
    if (pose == kSwimIdle || pose == kSwim || pose == kDive) g.was_swimming = true;
    else if (ground) g.was_swimming = false;

    const float* d = goal_vector(g.s_dir);
    g.spin = anim.spin ? int16_t(g.spin + 0xE00) : 0;
    const int16_t yaw = int16_t(int32_t(std::atan2(d[0], d[2]) / 3.14159265f * 32768.f) + g.spin);
    // Drawn every frame (60 Hz): half of Mario's 30 Hz pace per call.
    const int32_t accel = std::max(1, int32_t(anim.rate * 0x10000 * 0.5f));
    SM64MarioGeometryBuffers buffers{g.pos.data(), g.nrm.data(), g.col.data(), g.uv.data(), 0};
    g.anim_ended = sm64_mario_pose(g.id, yaw, anim.id, accel, anim.restart, &buffers);
    g.tris = buffers.numTrianglesUsed;

    g.audio_acc = std::min(g.audio_acc + dt, 4 * kTick);
    while (g.audio_acc >= kTick) {
      tick_audio();
      g.audio_acc -= kTick;
    }
  }
  draw(rs);
}

void debug_print(const char* message) {
  // libsm64 traces every sound request and every mixer pass; keep only its first lines (start-up).
  static int lines = 0;
  if (message[0] == '$' || message[0] == '-' || ++lines > 40) {
    return;
  }
  lg::debug("OTTSEL MARIO: libsm64: {}", message);
}

}  // namespace

void ottsel_mario_install(const std::string& writable_dir) {
  g.dir = writable_dir;
  g_ottsel_world_draw_hook = frame;
}

bool ottsel_mario_rom_present() {
  return !find_rom(g.dir).empty();
}

bool ottsel_mario_enabled() {
  return g.enabled;
}

bool ottsel_mario_moves() {
  return g.moves;
}

void ottsel_mario_set_moves(bool on) {
  g.moves = on;  // written into the game on the next frame
}

void ottsel_mario_set_enabled(bool on) {
  if (on == g.enabled) {
    return;
  }
  if (on) {
    if (!g.sm64_ready) {
      const auto path = find_rom(g.dir);
      if (path.empty() || !load_rom(path, g.rom)) {
        lg::warn("OTTSEL MARIO: no US Super Mario 64 ROM in {}", g.dir);
        return;
      }
      g.texture.resize(4 * SM64_TEXTURE_WIDTH * SM64_TEXTURE_HEIGHT);
      sm64_register_debug_print_function(debug_print);
      sm64_global_init(g.rom.data(), g.texture.data());
      sm64_audio_init(g.rom.data());
      g.sm64_ready = true;
      lg::info("OTTSEL MARIO: libsm64 ready from {}", path);
    }
    open_audio();
    g.enabled = true;
    g.have_last = false;
    g.pose = -1;
    return;
  }
  g.enabled = false;
  if (g.id >= 0) {
    sm64_mario_delete(g.id);
    g.id = -1;
  }
  g.tris = 0;
  if (SDL_AudioStream* stream = g.audio.load()) {
    SDL_ClearAudioStream(stream);
  }
  if (g.s_on.offset) {
    g.s_on->value = goal_bool(false);  // main.gc draws Jak and Daxter again
  }
}
