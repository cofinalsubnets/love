/* mooncc's half of ldst64.s: each width reads the template, and a store lands */
void tls_ldst(unsigned long *out);

int main(void) {
  unsigned long o[5];
  tls_ldst(o);
  if (o[0] != 1 || o[1] != 0x0403 || o[2] != 0x08070605 || o[3] != 0x100f0e0d0c0b0a09UL) return 1;
  if (o[4] != 0x100f0e0d0c0b0a09UL) return 2;
  tls_ldst(o);
  return o[0] == 2 ? 0 : 3; }
