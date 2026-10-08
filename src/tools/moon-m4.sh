#!/bin/sh
# moon-m4.sh -- build GNU m4 1.4 with mooncc + moonlibc + the holo linker (no
# gcc/glibc/ld) and prove it runs: the package's own check suite (57 checks from the
# m4 manual) and a direct battery (define/eval/divert/esyscmd through popen/format floats).
#
# point M4SRC at a configured m4-1.4 tree (config.h exists), or let it find `m4-1.4*`
# under dl/ then $MOONSRC (~/src when unset); a missing tree skips. to make one:
#   curl -O https://ftp.gnu.org/gnu/m4/m4-1.4.tar.gz
#   tar xzf m4-1.4.tar.gz && (cd m4-1.4 && ./configure)
#   make moon-m4       M4SRC=$PWD/m4-1.4
#   make moon-m4-a64 M4SRC=$PWD/m4-1.4
#
# `moon-m4.sh a64` cross-compiles with `mooncc -t a64` and runs under qemu-aarch64,
# skipping without it. config.h serves both targets: both are little-endian LP64, and
# the answers that differ are the ones corrected by hand below. an a64 binary cannot
# exec here, so the cross lane puts a one-line `m4` on PATH that runs qemu, and
# check-them runs unmodified.
#
# gcc runs only in the one-time ./configure; mooncc compiles every object. two of
# configure's answers describe glibc, so the build corrects config.h in place:
#   have_efgcvt  -- moonlibc has no ecvt/fcvt/gcvt; format.c's sprintf branch serves.
#   use_stackovf -- stack-overflow detection needs sigaltstack + sys/resource.h
#                   headers we don't carry; off.
set -e

target=${1:-x64}
case $target in
  x64)   name=moon-m4       ; tflag=""         ; sub=moonm4
         mksys=mksys-x64   ; backend=""              ; run=""            ; need="" ;;
  a64) name=moon-m4-a64 ; tflag="-t a64" ; sub=moonm4-a64
         mksys=mksys-a64 ; backend=src/love/holo/a64.l ; run=qemu-aarch64 ; need=qemu-aarch64 ;;
  rv64) name=moon-m4-rv64 ; tflag="-t rv64" ; sub=moonm4-rv
         mksys=mksys-rv64 ; backend=src/love/holo/rv64.l ; run=qemu-riscv64 ; need=qemu-riscv64 ;;
  *) echo "moon-m4.sh: unknown target $target (x64 | a64 | rv64)" >&2; exit 1 ;;
esac

# where a package's sources may live, first hit wins: the tree-local dl,
# then the cache -- $moonsrc, or ~/src when that is unset. An explicit *SRC=
# on the make line still outranks both. Answers empty when nothing matches,
# which is what the skip branch below reads, so a missing tree is never an
# error and never a `set -e` abort.
pkgfind() {                        # pkgfind <dir-glob> <witness-file>
  for c in dl/$1 "${MOONSRC:-$HOME/src}"/$1; do
    [ -f "$c/$2" ] && { printf '%s\n' "$c"; return 0; }
  done
  return 0
}

ho=out
mc="$ho/love mooncc"
love=$ho/love
M4SRC=${M4SRC:-$(pkgfind 'm4-1.4*' config.h)}

if [ -n "$need" ] && ! command -v "$need" > /dev/null 2>&1; then
  echo "$name: no $need, skipped"
  exit 0
fi
if [ ! -f "$M4SRC/config.h" ]; then
  echo "$name: no configured m4-1.4 found (looked in dl and ${MOONSRC:-$HOME/src}) -- skipped."
  echo "         set M4SRC=<a ./configure'd m4-1.4 tree> to run (see src/tools/moon-m4.sh)."
  exit 0
fi
[ -x "$love" ] || { echo "$name: missing $love -- run 'make host'"; exit 1; }

# the target-libc corrections (idempotent; see the header comment)
sed -i 's|^#define HAVE_EFGCVT 2$|/* #undef HAVE_EFGCVT */|;s|^#define USE_STACKOVF 1$|/* #undef USE_STACKOVF */|' "$M4SRC/config.h"

d=$ho/$sub
rm -rf "$d"; mkdir -p "$d"

# m4's link set, as its src/Makefile objects + lib/Makefile objects chose --
# minus stackovf.o (USE_STACKOVF off) and alloca.o (HAVE_ALLOCA: moonlibc's).
SRC="m4 builtin debug eval format freeze input macro output path symtab"
LIB="regex getopt getopt1 error obstack xmalloc xstrdup"
# m4's own directories ahead of the libc's, as its Makefile orders them: lib/regex.h is the
# regex its builtins and lib/regex.c share, not moonlibc's
CFLAGS="-DSTDC_HEADERS=1 -DHAVE_CONFIG_H -I$M4SRC -I$M4SRC/src -I$M4SRC/lib -Isrc/apps/moon/include"

echo "MOON-M4  $M4SRC  ($target: mooncc + moonlibc + holo, no gcc/glibc/ld)"

objs=""
for b in $SRC; do
  $mc $tflag $CFLAGS -c "$M4SRC/src/$b.c" "$d/src_$b.o" || { echo "FAIL mooncc -c src/$b.c"; exit 1; }
  objs="$objs $d/src_$b.o"
done
for b in $LIB; do
  $mc $tflag $CFLAGS -c "$M4SRC/lib/$b.c" "$d/lib_$b.o" || { echo "FAIL mooncc -c lib/$b.c"; exit 1; }
  objs="$objs $d/lib_$b.o"
done

# the rung-4 libc floor: lm math + the syscall leaf (mksys lays sys.o). no moonlibc
# object -- the link owes its symbols and the driver's runtime table pulls
# src/apps/moon/lib/moonlibc/ member by need (the Makefile says the same of love itself).
# Naming an object would take every member instead.
for f in src/apps/moon/lib/moonlibc/math/*.c; do
  b=`basename "$f" .c`
  $mc $tflag -Isrc/apps/moon/lib/moonlibc/math -Isrc/apps/moon/include -c "$f" "$d/m_$b.o" || { echo "FAIL mooncc -c $f"; exit 1; }
done
# sys.o is laid, not compiled -- and a cross lay needs holo's backend loaded
# first (the host bake carries only the native one), exactly as raw.sh does it.
{ if [ -n "$backend" ]; then echo "(borrow 'holo)"; cat "$backend"; fi
  cat src/apps/kore/text.l src/apps/kore/u.l src/apps/kore/asbook.l src/love/holo/elf.l src/love/holo/obj.l src/apps/moon/lib/mksys.l
  echo "((cite 'moon '$mksys) \"$d/sys.o\")"; } | $love || { echo "FAIL $mksys sys.o"; exit 1; }

$mc $tflag $objs "$d"/m_*.o "$d/sys.o" -o "$d/m4" || { echo "FAIL holo link m4"; exit 1; }
echo "  linked $(wc -c < "$d/m4") bytes -> $d/m4"

# ---- prove it runs (absolute binary path -- the checks cd into work dirs) ----
m4bin=$(cd "$d" && pwd)/m4
# the name the check suite must find on PATH: the binary itself natively, or a
# wrapper that hands it to qemu (see the header -- check-them execs `m4`).
m4dir=$(cd "$d" && pwd)
if [ -n "$run" ]; then
  m4dir=$(cd "$d" && pwd)/bin
  mkdir -p "$m4dir"
  # -0 m4 matters: m4 prints its own argv[0] in every error message, and two
  # of the suite's checks compare stderr against a text that names it. without
  # it the wrapper's full path lands there and those two fail for a reason that
  # has nothing to do with the compiler.
  printf '#!/bin/sh\nexec %s -0 m4 %s "$@"\n' "$run" "$m4bin" > "$m4dir/m4"
  chmod +x "$m4dir/m4"
fi
$run "$m4bin" --version >/dev/null 2>&1 || { echo "FAIL m4 --version"; exit 1; }

# the direct battery: expansion, eval, diversions (tmpfile/rewind), esyscmd
# (popen), integer + float format
t=$(printf 'define(foo, bar)foo eval(7*6)\n' | $run "$m4bin")
[ "$t" = "bar 42" ] || { echo "FAIL define/eval: '$t'"; exit 1; }
t=$(printf 'divert(1)w\ndivert(0)h\ndivert\nundivert(1)' | $run "$m4bin" | tr -d '\n')
[ "$t" = "hw" ] || { echo "FAIL divert: '$t'"; exit 1; }
t=$(printf "esyscmd(\`echo pipe-ok')" | $run "$m4bin")
[ "$t" = "pipe-ok" ] || { echo "FAIL esyscmd: '$t'"; exit 1; }
t=$(printf "format(\`%%05d %%.2f %%e', 7, 3.14159, 12345.678)\n" | $run "$m4bin")
[ "$t" = "00007 3.14 1.234568e+04" ] || { echo "FAIL format: '$t'"; exit 1; }
echo "  OK define/eval + divert + esyscmd + format"

# the package's own check suite: 57 manual-derived checks, stdout and stderr
# compared (the stderr legs read strerror texts -- moonlibc's table matters)
( cd "$M4SRC/checks" && PATH="$m4dir:$PATH" sh ./check-them [0-9]* ) | tail -1 | grep -q "All checks successful" \
  || { echo "FAIL m4's own check suite"; exit 1; }
echo "  OK m4's own check suite (57 checks from the manual)"

echo "$name: GNU m4 1.4 built by mooncc + moonlibc + holo$([ -n "$run" ] && echo " for $target"), runs + full check suite -- ok"
