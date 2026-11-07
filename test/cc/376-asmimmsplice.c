/* an "i" operand a spliced param carries, held to gcc: rip_rel_ptr's `"=r"(p) : "i"(p)`, the asm
 * writing its own immediate's name, at an array, a 2-d array, a function, a member's address and a
 * block static's, and in a brace's designated item. each lays sym+k as a relocation. targets
 * without the template compute the same. x86-64's %a of an address is rip-relative: testb's modrm 05 */
struct gp { long pad; int cell[4]; };
struct dp { unsigned short size; unsigned long address; } __attribute__((packed));
struct gp gdt;
long tbl[2][8];
char text[16];
static int tick(void) { return 7; }
unsigned char caps[8];

#if defined(__x86_64__)
void probe(void) { asm volatile(".globl capprobe\ncapprobe: testb $1, %a0" : : "i"(&caps[3])); }
extern const unsigned char capprobe[];
static int modrm(void) { return capprobe[1]; }
#else
static int modrm(void) { return 5; }
#endif

#if defined(__x86_64__) && (defined(__OPTIMIZE__) || defined(__mooncc__))   /* the splice is the premise: gcc -O0 keeps the call */
static inline __attribute__((always_inline)) void *rip(void *p) { asm("leaq %c1(%%rip), %0" : "=r"(p) : "i"(p)); return p; }
#else
static void *rip(void *p) { return p; }
#endif

int main(void) {
  static int st[3];
  int bad = 0;
  long (*t)[8] = rip(tbl);
  if (t != tbl || rip(tbl[1]) != &tbl[1][0]) bad |= 1;
  if ((char *) rip(text) != text) bad |= 2;
  if (rip(&gdt.cell[2]) != &gdt.cell[2]) bad |= 4;
  int (*f)(void) = (int (*)(void)) rip((void *) tick);
  if (f() != 7) bad |= 8;
  if (rip(&st[1]) != &st[1]) bad |= 16;
  struct dp d = { .address = (unsigned long) rip(text), .size = sizeof(text) - 1 };
  if (d.address != (unsigned long) text || d.size != 15) bad |= 32;
  if (modrm() != 5) bad |= 64;
  return bad;
}
