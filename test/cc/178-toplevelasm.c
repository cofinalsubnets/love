/* a file-scope asm, held to gcc: gas's sections, labels and data words, the way the
 * kernel's export, initcall and tracepoint rows write them -- a `sym - .` word read back
 * as an offset to a static only the asm names, numeric labels, a pushed section, and a
 * function the asm defines. a target with no template here computes the same. */

static int hits;
static int twice(int x) { hits++; return 2 * x; }
static int thrice(int x) { hits++; return 3 * x; }
int counter = 40;

#if defined(__x86_64__) || defined(__aarch64__) || defined(__riscv)
#define TSM 1
asm(".section \".tsm_calls\", \"a\"\n"
    "\t.balign 4\n"
    "tsm_calls:\n"
    "\t.long twice - .\n"
    "\t.long thrice - (. + 4) + 4\n"
    "\t.previous\n");
asm(".pushsection .tsm_data, \"aw\"\n"
    "\t.globl tsm_name\n"
    "tsm_name: .asciz \"t\\101\\x42\"\n"
    "\t.ascii \"\" \"z\\0\"\n"
    "\t.balign 8\n"
    "tsm_ptr: .quad counter + 4\n"
    "tsm_self: .long tsm_self - ., 2f - .\n"
    "tsm_bytes:\n"
    "2: .byte 1 << 4, -1 ; .short 0x1234\n"
    ".popsection\n");
#if defined(__x86_64__)
asm(".text\n.globl tsm_add7\ntsm_add7:\n\tmovq %rdi, %rax\n\taddq $7, %rax\n\tret\n");
#elif defined(__aarch64__)
asm(".text\n.globl tsm_add7\ntsm_add7:\n\tadd x0, x0, #7\n\tret\n");
#else
asm(".text\n.globl tsm_add7\ntsm_add7:\n\taddi a0, a0, 7\n\tret\n");
#endif
extern const int tsm_calls[2];
extern const char tsm_name[];
extern char *const tsm_ptr;
extern const int tsm_self[2];
extern const unsigned char tsm_bytes[];
extern long tsm_add7(long);
#endif

typedef int (*fn)(int);

int main(void) {
  int bad = 0;
#ifdef TSM
  fn a = (fn)((const char *)&tsm_calls[0] + tsm_calls[0]);
  fn b = (fn)((const char *)&tsm_calls[1] + tsm_calls[1]);
  if (a(5) != 10 || b(5) != 15 || hits != 2) bad |= 1;
  if (tsm_name[0] != 't' || tsm_name[1] != 'A' || tsm_name[2] != 'B' || tsm_name[3] != 0 ||
      tsm_name[4] != 'z' || tsm_name[5] != 0) bad |= 2;
  if (tsm_ptr - (char *)&counter != 4) bad |= 4;
  if (tsm_self[0] != 0 || tsm_self[1] != 4) bad |= 8;
  if (tsm_bytes[0] != 16 || tsm_bytes[1] != 255 || tsm_bytes[2] != 0x34 || tsm_bytes[3] != 0x12) bad |= 16;
  if (tsm_add7(35) != 42) bad |= 32;
#else
  if (twice(5) + thrice(5) != 25 || hits != 2 || counter != 40) bad |= 1;
#endif
  return bad;
}
