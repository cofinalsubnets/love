#!/bin/sh
# test/gate/standalone.sh -- zstd.c, bz2.c and xz.c built outside love (each one's _STANDALONE
# guard leaves the nifs out) by mooncc: a stream each packs it unpacks, love unpacks, and a
# stream love packs it unpacks. the includer gives alloc and the driver, nothing else
# usage: standalone.sh LOVE
set -e

love=${1:-b/love}
[ -x "$love" ] || { echo "standalone: no $love -- run 'make host'"; exit 1; }
w=$(mktemp -d)
trap 'rm -rf "$w"' EXIT
fail() { echo "FAIL standalone: $*" >&2; exit 1; }

cat > "$w/pre.h" <<'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stddef.h>
void *alloc(void *p, size_t n) { if (!n) { free(p); return 0; } return realloc(p, n); }
static uint8_t s[1 << 22];
EOF
cat > "$w/zstd.c" <<'EOF'
#include "pre.h"
#define ZS_STANDALONE
#include "src/love/compress/zstd.c"
int main(int argc, char **argv) {
 uintptr_t n = fread(s, 1, sizeof s, stdin), on;
 if (argv[1][0] == 'c') {
  uintptr_t cap = ze_cap(n); uint8_t *o = malloc(cap);
  uintptr_t k = ze_frame(s, n, 19, o, cap);
  if (!k) return 2;
  fwrite(o, 1, k, stdout); return 0; }
 uint8_t *u = zs_whole(s, n, &on);
 if (!u) return 3;
 fwrite(u, 1, on, stdout); return 0; }
EOF
cat > "$w/bz2.c" <<'EOF'
#include "pre.h"
#define BZ_STANDALONE
#include "src/love/compress/bz2.c"
int main(int argc, char **argv) {
 uintptr_t n = fread(s, 1, sizeof s, stdin);
 struct bz_w o = {0};
 if (argv[1][0] == 'c' ? bz_enc(s, n, 1, &o) : bz_dec(s, n, &o)) return 2;
 fwrite(o.p, 1, o.n, stdout); return 0; }
EOF
# the coder's buffers as host_lzma2e lays them, a 1 MB dict
cat > "$w/xz.c" <<'EOF'
#include "pre.h"
#define XZ_STANDALONE
#include "src/love/compress/xz.c"
int main(int argc, char **argv) {
 uintptr_t n = fread(s, 1, sizeof s, stdin), end, cap = xe_cap(n), sz = 1;
 uint32_t dict = 1 << 20, wmask = ~(uint32_t) 0;
 if (argv[1][0] == 'c') {
  if (n > dict) { while (sz < dict) sz <<= 1; wmask = (uint32_t) (sz - 1); } else sz = n ? n : 1;
  struct xe_arena *a = alloc(NULL, sizeof *a);
  uint32_t *son = alloc(NULL, 2 * sz * sizeof *son);
  uint8_t *o = alloc(NULL, cap);
  int64_t k = xe_go(s, n, dict, o, cap, a, son, wmask, 0);
  if (k < 0) return 2;
  fwrite(o, 1, (size_t) k, stdout); return 0; }
 int64_t want = l2_walk(s, n, &end);
 if (want < 0) return 3;
 uint8_t *o = malloc(want ? (size_t) want : 1);
 struct lz_model *m = lz_new(4);
 if (!m || l2_dec(s, o, (uintptr_t) want, m, 0)) return 4;
 fwrite(o, 1, (size_t) want, stdout); return 0; }
EOF
# love's side of a raw LZMA2 stream: the container verb takes only .xz and .lzma
cat > "$w/xz.l" <<'EOF'
(borrow 'posix)
(: m (cmdline @ l (l 2)) s (uread (cmdline @ l (l 3)) @ r <>r)
   (puts (? (m = "c") ((cite 'xz 'lzma2e) s 1048576) ((cite 'xz 'lzma2d) s))))
EOF
cat src/love/compress/*.c > "$w/in"
lz() { case $1 in zstd) "$love" zstd "$2" ;; bz2) "$love" bzip2 "$2" ;; xz) "$love" "$w/xz.l" "${2#-}" /dev/stdin ;; esac; }
for c in zstd bz2 xz; do
  "$love" mooncc -I . -I src/love -o "$w/$c" "$w/$c.c" > "$w/log" 2>&1 \
    || { cat "$w/log" >&2; fail "$c: mooncc could not build it"; }
  "$w/$c" c < "$w/in" > "$w/z" || fail "$c: it packed nothing"
  "$w/$c" d < "$w/z" | cmp -s - "$w/in" || fail "$c: its own stream came back wrong"
  lz $c -dc < "$w/z" | cmp -s - "$w/in" || fail "$c: love read its stream wrong"
  lz $c -c < "$w/in" > "$w/z"
  "$w/$c" d < "$w/z" | cmp -s - "$w/in" || fail "$c: love's stream came back wrong"
done
echo "standalone: zstd.c, bz2.c and xz.c stand alone under mooncc, their streams and love's both ways"
