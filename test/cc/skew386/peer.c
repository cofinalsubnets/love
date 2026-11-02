/* gcc's half of the i386 -mstack-alignment=4 check: f(k) called with esp k words off 16, k in
 * eax and on the stack, so either -mregparm finds it */
int skewcall(int (*f)(int), int k)
{
    int r;
    __asm__ volatile("mov %%esp, %%esi\n\t"
                     "and $-16, %%esp\n\t"
                     "sub %3, %%esp\n\t"
                     "push %%eax\n\t"
                     "call *%2\n\t"
                     "mov %%esi, %%esp"
                     : "=a"(r) : "a"(k), "r"(f), "r"(12 - 4 * k) : "esi", "ecx", "edx", "memory");
    return r;
}
