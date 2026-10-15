#!/bin/sh
# test/gate/drv.sh -- `CC=mooncc` drives a gcc-shaped recipe unchanged: the real $(cflags)
# ride through, a link pulls the runtime by need, and the semantic flags (-shared,
# -nostdlib, -x, -E, -MD) do what gcc's do
# usage: drv.sh OUTDIR CFLAGS..
set -u
ho=$1; shift
d=$ho/drv
mkdir -p "$d"
. test/gate/cclib.sh
name=test_drv

cat > "$d/a.c" <<'EOF'
#include <stdio.h>
#include <string.h>
#include <math.h>
int side(void);
int main(void) { printf("%d\n", (int)sqrt(16.0) + (int)strlen("abc") + side()); return 0; }
EOF
cat > "$d/b.c" <<'EOF'
int side(void) { return 35; }
EOF

# 1+2: the flag soup through -c and the link; the runtime binds printf, strlen, sqrt
moonc "$@" -c "$d/a.c" -o "$d/a.o" || fail "-c under the cc flag soup"
moonc "$@" -c "$d/b.c" -o "$d/b.o" || fail "-c b.c"
moonc "$@" -o "$d/drv" "$d/a.o" "$d/b.o" || fail "link + runtime pull"
out=$("$d/drv") || fail "the pulled binary did not run"
[ "$out" = 42 ] || fail "answered '$out', wanted 42"

# 2b: -lm -ldl -L ride through and leave the object unchanged
moonc "$@" -c "$d/b.c" -o "$d/b2.o" -lm -ldl -L/usr/lib || fail "-l/-L did not ride through"
cmp -s "$d/b.o" "$d/b2.o" || fail "a tolerated -l/-L changed the object"
moonc "$@" -o "$d/drv2" "$d/a.o" "$d/b.o" -lm || fail "link with -lm"
[ "$("$d/drv2")" = 42 ] || fail "the -lm-linked binary did not answer 42"
# ..but a bare -l refuses: it would eat the next word as a library
moonc -c "$d/b.c" -o "$d/b3.o" -l 2>/dev/null && fail "a bare -l did not refuse"

# 3a: -shared lays a shared object: e_type 3, ET_DYN
moonc -shared "$d/b.o" -o "$d/x.so" || fail "-shared did not link"
[ "$(od -An -tu1 -j16 -N1 "$d/x.so" | tr -d ' ')" = 3 ] || fail "-shared laid no shared object"

# 3b: -nostdlib leaves printf undefined, named on stderr with a cc: prefix
msg=$(moonc -nostdlib "$d/a.o" "$d/b.o" -o "$d/no" 2>&1) && fail "-nostdlib still linked"
case $msg in
  "cc: undefined reference to "*"'printf'"*) : ;;
  *) fail "-nostdlib refused, but said: $msg" ;;
esac

# 4: the configure probe: a source on stdin, its language named by -x
printf 'int main(void){return 0;}' | moonc -std=gnu23 -x c -c -o /dev/null - \
  || fail "the configure probe (-x c with the source on stdin) did not compile"
printf 'int main(void){return 0;}' | moonc -xc -c -o "$d/in.o" - \
  || fail "glued -xc did not compile"
[ -s "$d/in.o" ] || fail "a source on stdin wrote no object"
# ..and -x refuses a language we are not
moonc -x c++ -c "$d/b.c" -o "$d/x.o" 2>/dev/null && fail "-x c++ did not refuse"

# 5: -E alone, with gcc's `# N "path"` markers; a missing header fails
mkdir -p "$d/inc"
printf '#define SIDE 7\n' > "$d/inc/side.h"
printf '#include "side.h"\n#define TWICE(x) ((x)*2)\nint v = TWICE(SIDE);\n' > "$d/e.c"
moonc -E -I "$d/inc" "$d/e.c" > "$d/e.i" || fail "-E did not preprocess"
grep -qF 'int v = ((7)*2);' "$d/e.i" || fail "-E did not expand the macros: $(grep 'int v' "$d/e.i")"
grep -q "^# 1 \"$d/inc/side.h\"" "$d/e.i" || fail "-E left no marker for the included header"
printf '#include <no_such_header.h>\n' > "$d/e2.c"
moonc -E "$d/e2.c" > /dev/null 2>&1 && fail "-E did not refuse a missing header"

# 6: -MD, -MMD and -Wp,-MMD,FILE lay a dependency rule; -MMD leaves our headers out,
# -MT names the target, -MP adds an empty rule per header
printf '#include <stdio.h>\n#include "side.h"\nint w = SIDE;\n' > "$d/m.c"
moonc -MMD -I "$d/inc" -c "$d/m.c" -o "$d/m.o" || fail "-MMD did not compile"
grep -q "side.h" "$d/m.d" || fail "-MMD's rule lacks the user's header"
grep -q "stdio.h" "$d/m.d" && fail "-MMD's rule names our own header"
moonc -MD -I "$d/inc" -c "$d/m.c" -o "$d/m.o" && grep -q "stdio.h" "$d/m.d" || fail "-MD's rule lacks the system header"
moonc -Wp,-MMD,"$d/k.d" -I "$d/inc" -c "$d/m.c" -o "$d/m.o" || fail "-Wp,-MMD,FILE did not compile"
head -1 "$d/k.d" | grep -q "^$d/m.o: $d/m.c" || fail "-Wp,-MMD,FILE wrote no rule for the object: $(head -1 "$d/k.d")"
moonc -MMD -MP -MT tgt -MF "$d/p.d" -I "$d/inc" -c "$d/m.c" -o "$d/m.o" || fail "-MP -MT -MF did not compile"
grep -q "^tgt: " "$d/p.d" && grep -q "side.h:$" "$d/p.d" || fail "-MT / -MP not in the rule: $(cat "$d/p.d")"

echo "test_drv: CC=mooncc -- the cc flag soup rides through, the runtime pulls by need, the configure probe answers, -E and -MD speak gcc, -shared lays a .so, -nostdlib stays loud"
