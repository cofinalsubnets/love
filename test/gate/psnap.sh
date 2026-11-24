#!/bin/sh
# test/gate/psnap.sh LOVE.. -- the parser's prefix memo: a unit that opens on a header an
# earlier unit of the process opened starts from the kept state, and compiles to the bytes a
# whole parse gives. `$@` is the love that wakes the compiler
set -u
w=${TMPDIR:-/tmp}/psnap.$$; mkdir -p "$w/whole" || exit 1
trap 'rm -r "$w"' EXIT
fail() { echo "  psnap: FAIL -- $1"; exit 1; }
h1='struct fwd; struct pt { int x, y; }; typedef unsigned long ul; enum col { RED, GREEN };
#ifdef W
typedef long wide;
#else
typedef int wide;
#endif
int decl_only(int); extern int gv; int weakable(int);
static inline int hinl(int a) { return a * 3; }
static inline int hinl2(int a) { return hinl(a) + 1; }
'
h2=$(printf '%s' "$h1" | sed 's/a \* 3/a * 5/')
src() {
printf '%s' "$h1" > "$1/h.h"
cat > "$1/a.c" <<'X'
#include "h.h"
struct fwd { struct pt p; struct { int q; } anon; union { int u; char c; }; };
typedef struct fwd fwd_t; enum col2 { BLUE = GREEN + 5 };
#pragma pack(1)
struct pk { char c; int i; };
#pragma pack()
int gv = __LINE__ + __COUNTER__ + __COUNTER__;
__attribute__((weak)) int weakable(int a) { return a + sizeof(struct pk); }
int decl_only(int a) { fwd_t f; f.p.x = a; f.u = hinl2(a); l1: if (a > 9) { a--; goto l1; } return f.p.x + f.u + BLUE + a; }
X
cat > "$1/b.c" <<'X'
#include "h.h"
struct fwd { char z; };
int useb(struct fwd *f, ul n) { struct { int k; } s = { hinl(n) }; return f->z + s.k + RED + sizeof(struct fwd) + sizeof(wide) + __COUNTER__ + __LINE__; }
int decl_only(int a) { return a; }
X
cat > "$1/w.c" <<'X'
#define W 1
#include "h.h"
int usew(void) { return sizeof(wide) + hinl(2); }
X
}
src "$w"; src "$w/whole"
r=$(PSDIR="$w" PSH2="$h2" "$@" test/gate/psnap.l 2>&1) || fail "the driver died: $r"
o=$(PSDIR="$w/whole" PSH2="$h2" MOON_NOSNAP=1 "$@" test/gate/psnap.l 2>&1) || fail "the whole-parse driver died: $o"
# one state kept for a.c and b.c and their second compile; a pre-macro the header reads makes a
# second; a header whose text moved makes a third
echo "$r" | grep -qx 'kept 1 1 1 2 3' || fail "the memo kept other than 1 1 1 2 3: $r"
echo "$o" | grep -qx 'kept 0 0 0 0 0' || fail "MOON_NOSNAP=1 kept a state: $o"
echo "$r" | grep -qx 'again 1' || fail "a unit compiled twice in one process gave two answers"
echo "$r" | grep -qx 'moved 0' || fail "a static inline's body moved in the header and the object did not"
for f in a1 b1 w1 a3; do cmp -s "$w/$f.o" "$w/whole/$f.o" || fail "$f.o from a kept state is not the whole parse's"; done
echo "  psnap: ok -- a kept prefix gives the whole parse's bytes; a pre-macro and a moved header each refuse it"
