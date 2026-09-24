// Ottsel A1.7 / G1.13: read the boolean flag and the on-screen frame buffer slots at
// the fault itself. Post-fault snapshots are not trustworthy here: the gated handler
// holds only the faulting thread while the streamed activation thread keeps mutating
// GOAL state. Fault-path only, bounded to a few log lines.
#ifndef OTTSEL_FAULT_STATE_H
#define OTTSEL_FAULT_STATE_H

#include "game/kernel/jak1/kscheme.h"

struct OttselFaultState {
  u32 debug_segment;
  u32 display;
  u32 on_screen;
  u32 vframe;
  u32 b20;
  u32 b24;
  u32 b28;
  u32 sound_loader_rpc;
  u32 sound_player_rpc;
};

static inline OttselFaultState ottsel_fault_state_read(const unsigned char* ee,
                                                      bool (*read32)(const volatile void*, u32*)) {
  OttselFaultState s = {};
  auto sym_value = [](const char* name) -> u32 {
    auto sym = jak1::find_symbol_from_c(name);
    return sym.offset ? (u32)sym->value : 0xffffffffu;
  };
  s.debug_segment = sym_value("*debug-segment*");
  s.display = sym_value("*display*");
  s.sound_loader_rpc = sym_value("*sound-loader-rpc*");
  s.sound_player_rpc = sym_value("*sound-player-rpc*");
  if (s.display && read32(ee + s.display + 0x22c, &s.on_screen) && s.on_screen < 8) {
    const u32 vfa = s.display + 0x234u + (s.on_screen << 5);
    read32(ee + vfa + 0x10, &s.vframe);
    if (s.vframe) {
      read32(ee + s.vframe + 0x20, &s.b20);
      read32(ee + s.vframe + 0x24, &s.b24);
      read32(ee + s.vframe + 0x28, &s.b28);
    }
  }
  return s;
}

#endif
