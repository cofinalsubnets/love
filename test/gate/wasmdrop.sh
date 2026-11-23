#!/bin/sh
# wasmdrop.sh -- the wasm link lays what its exports and its data reach, and nothing else.
#   wasmdrop.sh HO LOVE NODE
# each way a function is reached keeps it, proved by the run: a kind the link missed would
# drop its function and the program would not link or would not answer
set -u
ho=$1 m=$2 node=$3
w=$ho/.wasmdrop
rm -rf "$w"; mkdir -p "$w"
fail() { echo "FAIL wasmdrop: $*"; exit 1; }
cc() { LOVE_NO_IMAGE= "$m" mooncc -t wasm "$@"; }
names() { "$node" test/holo/drop.mjs "$1"; }
has() { names "$1" | grep -qx "$2"; }
inmod() { grep -q "$2" "$1"; }          # the name section carries every function laid

cat > "$w/a.c" <<'XEOF'
#include <stdio.h>
__attribute__((noinline)) int bycall(int x) { return x + 1; }
int byaddr(int x) { return x + 20; }
int bydata(int x) { return x + 300; }
int unreached_fn(int x) { return x * 7; }
int extra_fn(void) { return 77; }
static int (*const tab[])(int) = { bydata };
int (*volatile slot)(int);
int main(void) {
  slot = byaddr;
  printf("%d\n", bycall(1) + slot(0) + tab[0](0));
  return 0; }
XEOF
cc -o "$w/a.wasm" "$w/a.c" || fail "a program does not link under the drop"
o=$("$node" src/inle/wasm/loader.js "$w/a.wasm") || fail "the program does not run"
[ "$o" = 322 ] || fail "a call, an address taken in code and a pointer in data each keep their function (got '$o')"
for f in bycall byaddr bydata; do inmod "$w/a.wasm" "$f" || fail "$f was dropped"; done
inmod "$w/a.wasm" unreached_fn && fail "a function nothing reaches was laid"
# the face: the entry and the heap door where defined, and no more
has "$w/a.wasm" _start || fail "_start is not exported"
has "$w/a.wasm" __love_start || fail "__love_start is not exported"
has "$w/a.wasm" bycall && fail "a reached function is exported unasked"
printf 'int wake(int a, int b) { return a + b; }\nint main(void) { return 0; }\n' > "$w/k.c"
cc -o "$w/k.wasm" "$w/k.c" && has "$w/k.wasm" wake || fail "a wake the program defines is not kept for the loader"
# a name the loader is asked for and the link did not keep is refused by name
o=$("$node" test/holo/drop.mjs "$w/a.wasm" extra_fn)
[ "$o" = "no export extra_fn" ] || fail "a ccall of a dropped function is not refused by name (got '$o')"
# --export roots a name and shows it; one nothing defines fails the link by name
cc -Wl,--export=extra_fn -o "$w/b.wasm" "$w/a.c" || fail "--export does not link"
[ "$("$node" test/holo/drop.mjs "$w/b.wasm" extra_fn)" = 77 ] || fail "an exported function does not answer"
inmod "$w/b.wasm" unreached_fn && fail "--export of one name kept another"
o=$(cc -Wl,--export=no_such_fn -o "$w/c.wasm" "$w/a.c" 2>&1) && fail "an export nothing defines linked"
echo "$o" | grep -q "no_such_fn" || fail "an export nothing defines is not named (got '$o')"
# --export-all, and a module with no main, lay and show every function
cc -Wl,--export-all -o "$w/d.wasm" "$w/a.c" || fail "--export-all does not link"
has "$w/d.wasm" unreached_fn || fail "--export-all dropped a function"
printf 'int lone_fn(int x) { return x + 1; }\nint other_fn(int x) { return x; }\n' > "$w/e.c"
cc -o "$w/e.wasm" "$w/e.c" || fail "a module with no main does not link"
has "$w/e.wasm" lone_fn && has "$w/e.wasm" other_fn || fail "a module with no main lost a function"
# weak: a weak body a strong one stands over is not laid; a weak reference nothing answers is null
cat > "$w/f.c" <<'XEOF'
#include <stdio.h>
__attribute__((weak)) int pick(void) { return 1111; }
__attribute__((weak)) extern int absent(void);
int main(void) { printf("%d %d\n", pick(), absent ? 1 : 0); return 0; }
XEOF
printf 'int pick(void) { return 2; }\n' > "$w/g.c"
cc -o "$w/f.wasm" "$w/f.c" "$w/g.c" || fail "weak under strong does not link"
[ "$("$node" src/inle/wasm/loader.js "$w/f.wasm")" = "2 0" ] || fail "strong over weak, a null weak reference"
inmod "$w/f.wasm" 'pick\.wk\.' && fail "a weak body under a strong one was laid"
echo "  wasmdrop: ok -- calls, addresses and data keep; the unreached, the unexported and the shadowed weak go"
