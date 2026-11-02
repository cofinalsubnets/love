#include "../impl.h"

static int __env_ours;                       /* environ is our malloc's */
/* kv ("k=v", its key kn long) takes k's place, or joins the end */
int __env_put(char *kv, size_t kn) {
  size_t cnt = 0;
  if (environ)
    for (char **e = environ; *e; e++, cnt++)
      if (memcmp(*e, kv, kn + 1) == 0) {
        *e = kv;                             /* the old one may be the kernel's: leak it */
        return 0; }
  char **ne = malloc((cnt + 2) * sizeof(char *));
  if (!ne) return -1;
  for (size_t i = 0; i < cnt; i++) ne[i] = environ[i];
  ne[cnt] = kv;
  ne[cnt + 1] = 0;
  if (__env_ours) free(environ);
  environ = ne;
  __env_ours = 1;
  return 0; }

int setenv(char const *k, char const *v, int ov) {
  size_t kn = strlen(k), vn = strlen(v);
  if (!ov && getenv(k)) return 0;
  char *kv = malloc(kn + 1 + vn + 1);
  if (!kv) return -1;
  memcpy(kv, k, kn); kv[kn] = '=';
  memcpy(kv + kn + 1, v, vn + 1);
  if (__env_put(kv, kn)) { free(kv); return -1; }
  return 0; }
