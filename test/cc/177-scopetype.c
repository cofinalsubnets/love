/* a name's type while it is in scope, held to gcc: a statement expression's value is
 * typed where its own locals still stand, and a for-init's variable types the rest of
 * the loop -- __auto_type, typeof and sizeof over either. linux's scoped_user_access
 * nests both under a cleanup. */

static int ended;
static void end(const int **p) { if (*p) ended++; }

static int sx(const int *p) {
  __auto_type t = ({ __typeof__(p) r; if (1) { r = p; } r; });
  return *t + (int)sizeof(({ long w = 1; w; }));
}

static int fi(const int *p) {
  int v = 0;
  for (const int *q = p; !v; ) { __auto_type c = q; __typeof__(q) d = c; v = *d + (int)sizeof(q); }
  return v;
}

static int scoped(const int *p) {
  int v = 0;
  for (_Bool done = 0; !done; done = 1)
    for (__auto_type _tmpptr = ({ __typeof__(p) __r; if (1) { __r = p; } __r; }); !done; done = 1)
      for (const __auto_type uaddr __attribute__((__cleanup__(end))) = _tmpptr; !done; done = 1)
        v = *uaddr;
  return v;
}

int main(void) {
  int x = 7, bad = 0;
  if (sx(&x) != 7 + (int)sizeof(long)) bad |= 1;
  if (fi(&x) != 7 + (int)sizeof(const int *)) bad |= 2;
  if (scoped(&x) != 7 || ended != 1) bad |= 4;
  return bad;
}
