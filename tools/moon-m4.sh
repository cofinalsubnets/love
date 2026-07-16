#!/bin/sh
# moon-m4.sh -- build GNU m4 1.4 with mooncc + nolibc + the holo linker (no
# gcc/glibc/ld) and prove it RUNS: the package's OWN check suite (57 checks
# lifted from the m4 manual) green against our binary, plus a direct battery
# (define/eval/divert/esyscmd through popen/format floats). The fourth
# moon-userland rung (doc/moon-userland.md), after bzip2, gzip and tar.
#
# m4's source is the one imported artifact. Point M4SRC at a CONFIGURED
# m4-1.4 tree (./configure already run, so config.h exists). Without one the
# check SKIPS (like moon-tar without TARSRC). To make one:
#   curl -O https://ftp.gnu.org/gnu/m4/m4-1.4.tar.gz
#   tar xzf m4-1.4.tar.gz && (cd m4-1.4 && ./configure)
#   make moon-m4 M4SRC=$PWD/m4-1.4
#
# Nothing here needs gcc EXCEPT the one-time ./configure probe that emits
# config.h (the accepted precedent -- mooncc COMPILES every object). Two of
# configure's answers describe GLIBC, not our target libc, so the build
# corrects them in place (config.h is a generated file; this IS configuration):
#   HAVE_EFGCVT  -- nolibc has no ecvt/fcvt/gcvt; format.c's sprintf branch
#                   is the right lane (and the better code).
#   USE_STACKOVF -- stack-overflow detection needs sigaltstack + sys/resource.h
#                   headers we don't carry yet; a nicety, off.
set -e

ho=out/host
mc=$ho/mooncc
ai=$ho/ai
M4SRC=${M4SRC:-out/dl/m4-1.4}

if [ ! -f "$M4SRC/config.h" ]; then
  echo "moon-m4: no configured m4-1.4 at '$M4SRC' -- skipped."
  echo "         set M4SRC=<a ./configure'd m4-1.4 tree> to run (see tools/moon-m4.sh)."
  exit 0
fi
for bin in "$mc" "$ai"; do
  [ -x "$bin" ] || { echo "moon-m4: missing $bin -- run 'make $ho/mooncc host'"; exit 1; }
done

# the target-libc corrections (idempotent; see the header comment)
sed -i 's|^#define HAVE_EFGCVT 2$|/* #undef HAVE_EFGCVT */|;s|^#define USE_STACKOVF 1$|/* #undef USE_STACKOVF */|' "$M4SRC/config.h"

d=$ho/moonm4
rm -rf "$d"; mkdir -p "$d"

# m4's link set, as its src/Makefile OBJECTS + lib/Makefile OBJECTS chose --
# minus stackovf.o (USE_STACKOVF off) and alloca.o (HAVE_ALLOCA: nolibc's).
SRC="m4 builtin debug eval format freeze input macro output path symtab"
LIB="regex getopt getopt1 error obstack xmalloc xstrdup"
CFLAGS="-DSTDC_HEADERS=1 -DHAVE_CONFIG_H -Icrew/moon/include -I$M4SRC -I$M4SRC/src -I$M4SRC/lib"

echo "MOON-M4  $M4SRC  (mooncc + nolibc + holo, no gcc/glibc/ld)"

objs=""
for b in $SRC; do
  $mc $CFLAGS -c "$M4SRC/src/$b.c" "$d/src_$b.o" || { echo "FAIL mooncc -c src/$b.c"; exit 1; }
  objs="$objs $d/src_$b.o"
done
for b in $LIB; do
  $mc $CFLAGS -c "$M4SRC/lib/$b.c" "$d/lib_$b.o" || { echo "FAIL mooncc -c lib/$b.c"; exit 1; }
  objs="$objs $d/lib_$b.o"
done

# the rung-4 libc floor: nolibc + am math + the syscall leaf (mksys lays sys.o).
$mc -Icrew/moon/include -c crew/moon/lib/nolibc.c "$d/nolibc.o" || { echo "FAIL mooncc -c nolibc.c"; exit 1; }
for f in crew/moon/lib/math/*.c; do
  b=`basename "$f" .c`
  $mc -Icrew/moon/lib/math -Icrew/moon/include -c "$f" "$d/m_$b.o" || { echo "FAIL mooncc -c $f"; exit 1; }
done
{ cat crew/kore/text.l crew/kore/core.l crew/kore/asbook.l crew/holo/elf.l crew/holo/obj.l crew/moon/lib/mksys.l
  echo "(mksys \"$d/sys.o\")"; } | $ai || { echo "FAIL mksys sys.o"; exit 1; }

$mc $objs "$d/nolibc.o" "$d"/m_*.o "$d/sys.o" -o "$d/m4" || { echo "FAIL holo link m4"; exit 1; }
echo "  linked $(wc -c < "$d/m4") bytes -> $d/m4"

# ---- prove it runs (absolute binary path -- the checks cd into work dirs) ----
m4bin=$(cd "$d" && pwd)/m4
"$m4bin" --version >/dev/null 2>&1 || { echo "FAIL m4 --version"; exit 1; }

# the direct battery: expansion, eval, diversions (tmpfile/rewind), esyscmd
# (popen), integer + float format
t=$(printf 'define(foo, bar)foo eval(7*6)\n' | "$m4bin")
[ "$t" = "bar 42" ] || { echo "FAIL define/eval: '$t'"; exit 1; }
t=$(printf 'divert(1)w\ndivert(0)h\ndivert\nundivert(1)' | "$m4bin" | tr -d '\n')
[ "$t" = "hw" ] || { echo "FAIL divert: '$t'"; exit 1; }
t=$(printf "esyscmd(\`echo pipe-ok')" | "$m4bin")
[ "$t" = "pipe-ok" ] || { echo "FAIL esyscmd: '$t'"; exit 1; }
t=$(printf "format(\`%%05d %%.2f %%e', 7, 3.14159, 12345.678)\n" | "$m4bin")
[ "$t" = "00007 3.14 1.234568e+04" ] || { echo "FAIL format: '$t'"; exit 1; }
echo "  OK define/eval + divert + esyscmd + format"

# the package's own check suite: 57 manual-derived checks, stdout AND stderr
# compared (the stderr legs read strerror texts -- nolibc's table matters)
( cd "$M4SRC/checks" && PATH="$(dirname "$m4bin"):$PATH" sh ./check-them [0-9]* ) | tail -1 | grep -q "All checks successful" \
  || { echo "FAIL m4's own check suite"; exit 1; }
echo "  OK m4's own check suite (57 checks from the manual)"

echo "moon-m4: GNU m4 1.4 built by mooncc + nolibc + holo, runs + full check suite -- ok"
