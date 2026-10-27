#include "../impl.h"

/* the path with every symlink, . and .. resolved, each component checked to exist; rest holds
 * what is left to walk, a link's target spliced in at its head */
char *realpath(char const *path, char *resolved) {
  char out[PATH_MAX], rest[PATH_MAX], lk[PATH_MAX];
  if (!path || !*path) { __errno_v = path ? ENOENT : EINVAL; return 0; }
  size_t rn = strlen(path);
  if (rn >= PATH_MAX) { __errno_v = ENAMETOOLONG; return 0; }
  memcpy(rest, path, rn + 1);
  size_t on = 0;
  if (*rest != '/') {
    if (!getcwd(out, PATH_MAX)) return 0;
    on = strlen(out);
    if (on == 1) on = 0; }                   /* "/": the root is the empty prefix */
  size_t at = 0;
  int hops = 0;
  while (rest[at]) {
    while (rest[at] == '/') at++;
    size_t b = at;
    while (rest[at] && rest[at] != '/') at++;
    size_t cn = at - b;
    if (!cn || (cn == 1 && rest[b] == '.')) continue;
    if (cn == 2 && rest[b] == '.' && rest[b + 1] == '.') {
      while (on && out[on - 1] != '/') on--;
      if (on) on--;
      continue; }
    size_t was = on;
    if (on + 1 + cn >= PATH_MAX) { __errno_v = ENAMETOOLONG; return 0; }
    out[on++] = '/'; memcpy(out + on, rest + b, cn); on += cn; out[on] = 0;
    struct stat st;
    if (lstat(out, &st) < 0) return 0;
    if (S_ISLNK(st.st_mode)) {
      if (++hops > 40) { __errno_v = ELOOP; return 0; }
      long k = readlink(out, lk, PATH_MAX - 1);
      if (k < 0) return 0;
      size_t tail = strlen(rest + at);
      if ((size_t) k + tail + 1 >= PATH_MAX) { __errno_v = ENAMETOOLONG; return 0; }
      memmove(rest + k, rest + at, tail + 1);
      memcpy(rest, lk, (size_t) k);
      at = 0;
      on = lk[0] == '/' ? 0 : was; }
    else if (rest[at] && !S_ISDIR(st.st_mode)) { __errno_v = ENOTDIR; return 0; } }
  if (!on) out[on++] = '/';
  out[on] = 0;
  char *r = resolved ? resolved : malloc(on + 1);
  if (!r) { __errno_v = ENOMEM; return 0; }
  memcpy(r, out, on + 1);
  return r; }
