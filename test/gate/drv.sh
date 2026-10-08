#!/bin/sh
# test/gate/drv.sh -- the cc-DRIVER conventions gate: `CC=mooncc` must drive a
# gcc-shaped recipe unchanged. Three laws, each cheap:
#   1. the advisory flag soup (the REAL $(cflags), passed in by make) rides
#      through -c and the link ignored;
#   2. a link owing libc symbols pulls the runtime BY NEED -- moonlibc + the lm
#      math + the sys leaf, compiled from the sources beside us -- and the
#      binary RUNS;
#   3. the loud edges stay loud: -shared refuses (usage, exit 2) and -nostdlib
#      leaves the libc out (exit 1) -- an ignored SEMANTIC flag would be the
#      silent-no-op trap wearing a cc face, and this gate keeps that door shut.
#      And -nostdlib's refusal is pinned by its SENTENCE, not just its exit
#      code: it used to arrive as `;; link-undef "printf"`, a love debug note
#      escaping from inside holo, and an exit-code-only check is exactly what
#      let that stand for as long as it did.
#
# usage: drv.sh OUTDIR CFLAGS..
set -u
ho=$1; shift
d=$ho/drv
mkdir -p "$d"
fail() { echo "FAIL test_drv: $*" >&2; exit 1; }
moonc() { LOVE_NO_IMAGE= "$ho/love" mooncc "$@"; }

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

# 1+2: the flag soup through -c and the link; the runtime pull binds printf/
# strlen/sqrt from nothing but the tree's own sources.
moonc "$@" -c "$d/a.c" -o "$d/a.o" || fail "-c under the cc flag soup"
moonc "$@" -c "$d/b.c" -o "$d/b.o" || fail "-c b.c"
moonc "$@" -o "$d/drv" "$d/a.o" "$d/b.o" || fail "link + runtime pull"
out=$("$d/drv") || fail "the pulled binary did not run"
[ "$out" = 42 ] || fail "answered '$out', wanted 42"

# 2b: -lm -ldl -L ride through. the driver pulls its runtime BY NEED, so the libc
# family a recipe asks for is already in the artifact before it asks -- and lua's own
# Makefile writes LIBS=-lm, which is the whole reason this matters. the object must be
# UNCHANGED by them: a tolerated flag that moved a byte would not be tolerated at all.
moonc "$@" -c "$d/b.c" -o "$d/b2.o" -lm -ldl -L/usr/lib || fail "-l/-L did not ride through"
cmp -s "$d/b.o" "$d/b2.o" || fail "a tolerated -l/-L changed the object"
moonc "$@" -o "$d/drv2" "$d/a.o" "$d/b.o" -lm || fail "link with -lm"
[ "$("$d/drv2")" = 42 ] || fail "the -lm-linked binary did not answer 42"
# ..but a BARE -l is still a refusal: taking it would eat the next word as a library
# name and the word after it as an input, which is the silent no-op wearing a cc face.
moonc -c "$d/b.c" -o "$d/b3.o" -l 2>/dev/null && fail "a bare -l did not refuse"

# 3a: -shared refuses loudly
moonc -shared "$d/b.o" -o "$d/x.so" 2>/dev/null && fail "-shared did not refuse"
[ $? -eq 2 ] || fail "-shared refused with the wrong exit"

# 3b: -nostdlib turns the driver's libc off, and the owed symbols are an
# UNDEFINED REFERENCE -- named, on stderr, with a cc: prefix like every other
# diagnostic. printf is owed by a.c and nothing supplies it under -nostdlib.
msg=$(moonc -nostdlib "$d/a.o" "$d/b.o" -o "$d/no" 2>&1) && fail "-nostdlib still linked"
case $msg in
  "cc: undefined reference to "*"'printf'"*) : ;;
  *) fail "-nostdlib refused, but said: $msg" ;;
esac

# 4: THE CONFIGURE PROBE -- how a build asks a cc anything before trusting it: a source on
# stdin, its language named by -x because there is no suffix left to read. every
# autoconf-shaped build writes some version of this line before it believes a flag, so a cc
# that cannot be ASKED is one that gets answered by the fallback instead.
printf 'int main(void){return 0;}' | moonc -std=gnu23 -x c -c -o /dev/null - \
  || fail "the configure probe (-x c with the source on stdin) did not compile"
printf 'int main(void){return 0;}' | moonc -xc -c -o "$d/in.o" - \
  || fail "glued -xc did not compile"
[ -s "$d/in.o" ] || fail "a source on stdin wrote no object"
# ..and -x stays LOUD on a language we are not: taking c++ for C is -std='s own hazard.
moonc -x c++ -c "$d/b.c" -o "$d/x.o" 2>/dev/null && fail "-x c++ did not refuse"

# 5: -E, the preprocessor alone, gcc's shape: a configure script reads it for every header
# probe, and gnulib finds the header it wraps by the `# N "path"` marker it leaves. a missing
# header fails, as the probe for one must.
mkdir -p "$d/inc"
printf '#define SIDE 7\n' > "$d/inc/side.h"
printf '#include "side.h"\n#define TWICE(x) ((x)*2)\nint v = TWICE(SIDE);\n' > "$d/e.c"
moonc -E -I "$d/inc" "$d/e.c" > "$d/e.i" || fail "-E did not preprocess"
grep -qF 'int v = ((7)*2);' "$d/e.i" || fail "-E did not expand the macros: $(grep 'int v' "$d/e.i")"
grep -q "^# 1 \"$d/inc/side.h\"" "$d/e.i" || fail "-E left no marker for the included header"
printf '#include <no_such_header.h>\n' > "$d/e2.c"
moonc -E "$d/e2.c" > /dev/null 2>&1 && fail "-E did not refuse a missing header"

# 6: the dependency rule beside an object -- -MD / -MMD, and kbuild's -Wp,-MMD,FILE, which
# every kernel hostprog compile passes. -MMD leaves our own headers out, as gcc leaves the
# system's; the user's stay. -MT names the target, -MP adds an empty rule per header.
printf '#include <stdio.h>\n#include "side.h"\nint w = SIDE;\n' > "$d/m.c"
moonc -MMD -I "$d/inc" -c "$d/m.c" -o "$d/m.o" || fail "-MMD did not compile"
grep -q "side.h" "$d/m.d" || fail "-MMD's rule lacks the user's header"
grep -q "stdio.h" "$d/m.d" && fail "-MMD's rule names our own header"
moonc -MD -I "$d/inc" -c "$d/m.c" -o "$d/m.o" && grep -q "stdio.h" "$d/m.d" || fail "-MD's rule lacks the system header"
moonc -Wp,-MMD,"$d/k.d" -I "$d/inc" -c "$d/m.c" -o "$d/m.o" || fail "-Wp,-MMD,FILE did not compile"
head -1 "$d/k.d" | grep -q "^$d/m.o: $d/m.c" || fail "-Wp,-MMD,FILE wrote no rule for the object: $(head -1 "$d/k.d")"
moonc -MMD -MP -MT tgt -MF "$d/p.d" -I "$d/inc" -c "$d/m.c" -o "$d/m.o" || fail "-MP -MT -MF did not compile"
grep -q "^tgt: " "$d/p.d" && grep -q "side.h:$" "$d/p.d" || fail "-MT / -MP not in the rule: $(cat "$d/p.d")"

echo "test_drv: CC=mooncc -- the cc flag soup rides through, the runtime pulls by need, the configure probe answers, -E and -MD speak gcc, -shared/-nostdlib stay loud"
