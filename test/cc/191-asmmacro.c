/* gas's macro language, held to gcc: the kernel's exception-table macro finds the error
 * register's number by name -- `.macro` with :req parameters, `.set` symbols counting through
 * `.irp` loops, `.ifc` against each register's spelling, `.if` over `!=` guarding an `.error`,
 * a keyword call and `.purgem`. which register the compiler picks is its own, so the entry is
 * read as a type and a register number. a target with no template here computes the same. */

extern const int __start_tai_ex[], __stop_tai_ex[];
#if defined(__x86_64__)
static int rd(void) {
  int err = 5;
  asm volatile("xor %[err],%[err]\n"
               ".pushsection tai_ex, \"a\"\n"
               ".macro extable_type_reg type:req reg:req\n"
               ".set .Lfound, 0\n"
               ".set .Lregnr, 0\n"
               ".irp rs,rax,rcx,rdx,rbx,rsp,rbp,rsi,rdi,r8,r9,r10,r11,r12,r13,r14,r15\n"
               ".ifc \\reg, %%\\rs\n"
               ".set .Lfound, .Lfound+1\n"
               ".long \\type + (.Lregnr << 8)\n"
               ".endif\n"
               ".set .Lregnr, .Lregnr+1\n"
               ".endr\n"
               ".set .Lregnr, 0\n"
               ".irp rs,eax,ecx,edx,ebx,esp,ebp,esi,edi,r8d,r9d,r10d,r11d,r12d,r13d,r14d,r15d\n"
               ".ifc \\reg, %%\\rs\n"
               ".set .Lfound, .Lfound+1\n"
               ".long \\type + (.Lregnr << 8)\n"
               ".endif\n"
               ".set .Lregnr, .Lregnr+1\n"
               ".endr\n"
               ".if (.Lfound != 1)\n"
               ".error \"extable_type_reg: bad register argument\"\n"
               ".endif\n"
               ".endm\n"
               "extable_type_reg reg=%[err], type=11\n"
               ".purgem extable_type_reg\n"
               ".popsection\n"
               : [err] "=r"(err));
  return err;
}
#endif
int main(void) {
#if defined(__x86_64__)
  int e = rd();
  int n = (int)(__stop_tai_ex - __start_tai_ex);
  int v = __start_tai_ex[0], ty = v & 255, reg = v >> 8;
  return (e != 0) | (n != 1) << 1 | (ty != 11) << 2 | (reg < 0 || reg > 15) << 3;
#else
  return 0;
#endif
}
