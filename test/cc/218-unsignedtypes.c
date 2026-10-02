/* an unsigned answer stays unsigned: a sum or difference of unsigned operands widened to 64 bits
 * or converted to double (the shuttle's type), an unsigned constant past long's range or wrapped
 * below zero converted to double at compile time, and a literal only unsigned long can hold. each
 * held to the same conversion done at run time through a value the compiler cannot see, and to gcc. */

#include <stdint.h>

__attribute__((noinline)) static uint64_t hide(uint64_t v) { return v; }
__attribute__((noinline)) static double rt(uint64_t v) { return (double) hide(v); }   /* the run-time conversion */

__attribute__((noinline)) static uint64_t wsum(uint32_t u, uint32_t v) { return u + v; }
__attribute__((noinline)) static uint64_t wdif(uint32_t u, uint32_t v) { uint64_t f = u - v; return f; }
__attribute__((noinline)) static double dsum(unsigned long long a, unsigned long long b) { return (double) (a + b); }
__attribute__((noinline)) static double ddif(unsigned long long a, unsigned long long b) { return (double) (a - b); }
__attribute__((noinline)) static double kmax(void) { return (double) 18446744073709551615ull; }
__attribute__((noinline)) static double kwrap(void) { return (double) (1ull - 2ull); }
__attribute__((noinline)) static double kmul(void) { return (double) (0xffffffffffffffffull * 3ull); }
__attribute__((noinline)) static double kuint(void) { return (double) (0u - 1u); }

int main(void) {
  int bad = 0;
  if (wsum(0xfffffff0u, 0x20u) != hide(0x10u)) bad |= 1;
  if (wdif(1u, 2u) != hide(0xffffffffu)) bad |= 2;
  if (dsum(hide(0x8000000000000000ull), hide(5)) != rt(0x8000000000000005ull)) bad |= 4;
  if (ddif(hide(1), hide(2)) != rt(0xffffffffffffffffull)) bad |= 8;
  if (kmax() != rt(0xffffffffffffffffull)) bad |= 16;
  if (kwrap() != rt(0xffffffffffffffffull)) bad |= 32;
  if (kmul() != rt(0xfffffffffffffffdull)) bad |= 64;
  if (kuint() != rt(0xffffffffu)) bad |= 128;
  double a = (double) 18446744073709551615ull;   /* an initialized local folds its own way */
  if (a != rt(0xffffffffffffffffull)) bad |= 256;
  return bad;
}
