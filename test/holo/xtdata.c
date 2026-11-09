/* moon -t xtensa under -Tdata: constants run with the data, since the esp32's instruction
 * memory takes words alone; strings, a const table, a pointer table and .bss read there.
 * exits 42 when all hold. */
static const char msg[] = "strings from data";
static const short primes[] = { 2, 3, 5, 7, 11, 13, 17, 19, 23, 29 };
static const char *const names[] = { "zero", "one", "two" };
static char buf[8] = "dat";
static int zero[4];
extern char __data_start__[];
static int len(const char *s) { int n = 0; while (s[n]) n++; return n; }
static int check(void) {
  int sum = 0;
  if ((unsigned)msg < (unsigned)__data_start__ || (unsigned)primes < (unsigned)__data_start__) return 1;
  if (len(msg) != 17 || msg[8] != 'f') return 2;
  for (int i = 0; i < 10; i++) sum += primes[i];
  if (sum != 129) return 3;
  if (len(names[2]) != 3 || names[1][2] != 'e') return 4;
  if (buf[2] != 't' || zero[3] != 0) return 5;
  return 0;
}
void _start(void) {
  int r = check(); r = r ? 100 + r : 42;
  __attribute__((holo)) asm volatile("mov r4, %0\n\tli r0, 119\n\tsys" :: "r"(r) : "r0");
  for (;;) ;
}
