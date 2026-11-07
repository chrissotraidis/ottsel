#pragma once

#include <cerrno>
#include <cstdio>
#include <string>

// Keep one previous session for Share Logs after a crash and relaunch. If
// rotation fails, the caller must append instead of destroying the old log.
inline bool ottsel_preserve_previous_log(const std::string& current,
                                         const std::string& previous) {
  return std::rename(current.c_str(), previous.c_str()) == 0 || errno == ENOENT;
}
