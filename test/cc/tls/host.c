/* mooncc's half: each thread its own copy of gcc's template, fresh from the image */
#include <pthread.h>

int tls_sum(void);
int *tls_addr(void);
int *ext_addr(void);
long buf_mod(void);

static void *other(void *p) {
  int **a = p;
  a[0] = tls_addr(), a[1] = ext_addr();
  return (void *) (long) (tls_sum() == 6107 && buf_mod() == 0); }

int main(void) {
  if (tls_sum() != 6107 || buf_mod() != 0) return 1;
  int *a[2];
  pthread_t t;
  void *ok;
  if (pthread_create(&t, 0, other, a) || pthread_join(t, &ok) || !ok) return 2;
  if (a[0] == tls_addr() || a[1] == ext_addr() || *ext_addr() != 6) return 3;
  if (tls_sum() != 7214) return 4;
  return 0; }
