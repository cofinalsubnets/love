/* gcc's half of the tls law: a template with file bytes, zeros and a wide alignment, read
 * local-exec, and one defined elsewhere read initial-exec (relaxed by the link) */
__thread int tl_init = 7;
__thread long tl_zero;
__thread char tl_buf[24] __attribute__((aligned(32)));
extern __thread int tl_ext;

int tls_sum(void) {
  tl_zero += tl_init;
  tl_buf[3]++;
  tl_ext++;
  return (int) tl_zero + tl_buf[3] * 100 + tl_ext * 1000; }

int *tls_addr(void) { return &tl_init; }
int *ext_addr(void) { return &tl_ext; }
long buf_mod(void) { return (long) tl_buf % 32; }
