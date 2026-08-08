#include <stdio.h>
#include <stdint.h>
extern uint64_t _ottsel_aot_loop(uint64_t n) asm("_ottsel_aot_loop");
int main(void) {
  uint64_t r = _ottsel_aot_loop(10);
  printf("aot_loop(10) = %llu (expected 45)\n", (unsigned long long)r);
  return r == 45 ? 0 : 1;
}
