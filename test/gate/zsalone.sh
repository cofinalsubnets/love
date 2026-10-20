#!/bin/sh
# test/gate/zsalone.sh -- src/love/compress/zstd.c built outside love (its ZS_STANDALONE guard)
# by mooncc: a frame it packs it unpacks, love's zstd unpacks, and a frame love packs it unpacks.
# the includer gives alloc and nothing else
# usage: zsalone.sh LOVE
set -e

love=${1:-b/love}
[ -x "$love" ] || { echo "zsalone: no $love -- run 'make host'"; exit 1; }
w=$(mktemp -d)
trap 'rm -rf "$w"' EXIT
fail() { echo "FAIL zsalone: $*" >&2; exit 1; }

cat > "$w/d.c" <<'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
static void *alloc(void *p, uintptr_t n) { if (!n) { free(p); return 0; } return realloc(p, n); }
#define ZS_STANDALONE
#include "zstd.c"
int main(int argc, char **argv) {
 static uint8_t s[1 << 22];
 uintptr_t n = fread(s, 1, sizeof s, stdin), on;
 if (argv[1][0] == 'c') {
  uintptr_t cap = ze_cap(n); uint8_t *o = malloc(cap);
  uintptr_t k = ze_frame(s, n, atoi(argv[2]), o, cap);
  if (!k) return 2;
  fwrite(o, 1, k, stdout); return 0; }
 uint8_t *u = zs_whole(s, n, &on);
 if (!u) return 3;
 fwrite(u, 1, on, stdout); return 0; }
EOF
"$love" mooncc -I src/love/compress -o "$w/d" "$w/d.c" > "$w/log" 2>&1 || { cat "$w/log" >&2; fail "mooncc could not build it"; }

cat src/love/compress/*.c > "$w/in"
for lv in 3 19; do
  "$w/d" c $lv < "$w/in" > "$w/z" || fail "level $lv: it packed nothing"
  "$w/d" d < "$w/z" | cmp -s - "$w/in" || fail "level $lv: its own frame came back wrong"
  "$love" zstd -dc < "$w/z" | cmp -s - "$w/in" || fail "level $lv: love's zstd read its frame wrong"
done
"$love" zstd -c < "$w/in" > "$w/z"
"$w/d" d < "$w/z" | cmp -s - "$w/in" || fail "love's frame came back wrong"
echo "zsalone: zstd.c stands alone under mooncc, its frames and love's both ways"
