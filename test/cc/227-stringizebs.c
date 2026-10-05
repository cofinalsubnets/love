/* a stray backslash pair outside a literal stringizes as one backslash once re-lexed (C11
 * 6.10.3.2): gas macro arguments through __stringify, the kernel's mrs_s `\\sreg`. inside a
 * literal the escapes keep their spelling */
#define S(x) #x
#define T(x) S(x)

int main(void) {
  const char *a = T((\\sreg)), *b = T("q\\n"), *c = S(\\ x);
  int bad = 0;
  if (a[0] != '(' || a[1] != '\\' || a[2] != 's' || a[6] != ')' || a[7]) bad |= 1;
  if (b[0] != '"' || b[2] != '\\' || b[3] != '\\' || b[4] != 'n') bad |= 2;
  if (c[0] != '\\' || c[1] != ' ' || c[2] != 'x' || c[3]) bad |= 4;
  return bad;
}
