#pragma once

#include <cstdint>

// GOAL-relative code addresses observed in the iOS Jak 1 image. Values below
// this interval are data/heap, and values above it are not generated code.
constexpr std::uint32_t kOttselIosGoalCodeOffsetMin = 0x03ebc000;
constexpr std::uint32_t kOttselIosGoalCodeOffsetMax = 0x04ee0000;

constexpr bool ottsel_ios_goal_code_offset_is_valid(std::uint32_t offset) {
  return offset >= kOttselIosGoalCodeOffsetMin && offset < kOttselIosGoalCodeOffsetMax;
}

constexpr bool ottsel_ios_pc_is_in_spu_memory(std::uintptr_t pc,
                                               std::uintptr_t spu_begin,
                                               std::uintptr_t spu_size) {
  return pc >= spu_begin && pc - spu_begin < spu_size;
}
