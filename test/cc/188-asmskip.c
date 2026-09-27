/* the alternatives' padding, held to gcc: `.skip` over label arithmetic, forward and back and
 * across sections, grows the original to the replacement's size, and `.byte 773b-771b` records
 * it -- the count reads once the whole template has, gas's `>` answering -1 for true. a target
 * with no template here computes the same. */

extern const unsigned char __start_tai_rep[], __stop_tai_rep[];
extern const unsigned char __start_tai_len[];

#if defined(__x86_64__)
static int alt(void) {
  int r;
  asm volatile("771:\n\tmovl $1, %0\n772:\n"
               ".skip -(((775f-774f)-(772b-771b)) > 0) * ((775f-774f)-(772b-771b)),0x90\n"
               "773:\n"
               ".pushsection tai_rep, \"ax\"\n"
               "774:\n\tnop\n\tnop\n\tnop\n\tnop\n\tnop\n\tnop\n\tnop\n\tnop\n\tnop\n775:\n"
               ".popsection\n"
               ".pushsection tai_len, \"a\"\n.byte 773b-771b\n.byte 775b-774b\n.popsection\n"
               : "=r"(r));
  return r;
}
#endif

int main(void) {
  int bad = 0;
#if defined(__x86_64__)
  int rep = (int)(__stop_tai_rep - __start_tai_rep);          /* nine nops */
  if (alt() != 1) bad |= 1;
  if (rep != 9) bad |= 2;
  if (__start_tai_len[0] != rep || __start_tai_len[1] != rep) bad |= 4;
#endif
  return bad;
}
