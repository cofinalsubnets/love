/* an eight-byte word measured from its own place, `.quad sym+k - .`, in a function's asm: the
 * jump table's key on x86-64 and a64 (static_branch). read back through the section's bracket
 * it is the key's address; a target with no template here computes the same. */
static long key[2];

#if defined(__x86_64__) || defined(__aarch64__)
static void lay(void) {
  asm volatile(".pushsection kq_tab, \"a\"\n.balign 8\n.quad %c0 - .\n.quad %c1 - .\n.popsection\n"
               : : "i"(&key[1]), "i"(&key[0]));
}
extern const long __start_kq_tab[], __stop_kq_tab[];
#endif

int main(void) {
  int bad = 0;
#if defined(__x86_64__) || defined(__aarch64__)
  lay();
  if (__stop_kq_tab - __start_kq_tab != 2) bad |= 1;
  if ((const char *)&__start_kq_tab[0] + __start_kq_tab[0] != (const char *)&key[1]) bad |= 2;
  if ((const char *)&__start_kq_tab[1] + __start_kq_tab[1] != (const char *)&key[0]) bad |= 4;
#endif
  key[1] = 5;
  return bad + key[1] - 5;
}
