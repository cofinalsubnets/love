#!/bin/sh
# test/gate/ccport.sh -- mooncc builds outside compilers, and they must agree with gcc's build.
# tcc: mooncc lays tcc, which lays itself twice (tcc2 = tcc3), tcc2 byte-identical to the
# tcc2 a gcc-built tcc lays, and tests2's misses the roster's, both builds. chibicc: every .c
# through mooncc, then its own make test (driver.sh too) and its stage2 self-compile, the
# assembly it lays identical to a gcc-built chibicc's. pinned sources fetched into dl/;
# without gcc, tcc's half runs alone, held to the roster.
# usage: ccport.sh OUTDIR LOVE
. test/gate/skip.sh
. test/gate/dl.sh
set -u
name=test_ccport
ho=$1
m=$2
case $m in /*) ;; *) m=$PWD/$m ;; esac
fail() { echo "FAIL $name: $*" >&2; exit 1; }

[ "$(uname -s)-$(uname -m)" = Linux-x86_64 ] || gate_skip "$name: x86-64 linux only, skipped"
make --version 2>/dev/null | grep -q '^GNU Make' || gate_skip "$name: no GNU make (tcc's and chibicc's own makefiles), skipped"
dl_need tinycc
dl_need chibicc
ref=1
command -v gcc > /dev/null 2>&1 || { ref=0; gate_partly "$name: no gcc, the comparisons with gcc's builds skipped"; }

# tests2 that miss on both builds, and why: each wants -run, which a static tcc cannot give
# (it loads no shared libc), and mooncc lays only static programs
roster='
60_errors_and_warnings -dt runs each snippet with -run
96_nodata_wanted -dt
112_backtrace -dt -b
117_builtins its own line runs -run, -b -run
125_atomic_misc -dt
128_run_atexit -dt
'
# and the ones only mooncc's tcc misses: mooncc's gaps, each to close
roster_moon='
146_tls_extern links tcc objects by the configured CC: mooncc refuses -no-pie and -Wl,-z,noexecstack, and holo links no foreign .tdata (link-tls)
'

t2='$1 -o $*.exe 2>$*.cerr; sh -c '\''cat $$0.cerr; rm -f $$0.cerr; [ ! -x ./$$0.exe ] || exec ./$$0.exe "$$@"'\'' $*'
w=$ho/ccport
rm -rf "$w"; mkdir -p "$w/bin" || exit 1
w=$(cd "$w" && pwd)
mcc=$w/bin/mooncc
printf '#!/bin/sh\nLOVE_NO_IMAGE= exec %s cc "$@"\n' "$m" > "$mcc" && chmod +x "$mcc"

# tcc_lay KIND CC: configure and make a tree with CC, then the one-source tcc and its two
# self-builds; tests2's misses into $w/tcc-KIND.miss
tcc_lay() {
  t=$w/tcc-$1 cc=$2
  cp -R "$DL/tinycc" "$t" || fail "cannot copy $DL/tinycc"
  (cd "$t" && sh ./configure --cc="$cc" --extra-cflags=-DCONFIG_TCC_STATIC > configure.log 2>&1) || { tail -5 "$t/configure.log"; fail "tcc-$1: configure"; }
  (cd "$t" && make GITHASH=no > make.log 2>&1) || { tail -10 "$t/make.log"; fail "tcc-$1: make"; }
  (cd "$t" && "$cc" -DONE_SOURCE=1 -DCONFIG_TCC_STATIC -DTCC_TARGET_X86_64 -I. -o tcc1 tcc.c -lm -lpthread > one.log 2>&1) \
    || { tail -10 "$t/one.log"; fail "tcc-$1: $cc does not build tcc.c as one source"; }
  (cd "$t" && ./tcc1 -B. -I. -DONE_SOURCE=1 -DCONFIG_TCC_STATIC -o tcc2 tcc.c -lm -lpthread > self.log 2>&1) \
    || { tail -10 "$t/self.log"; fail "tcc-$1: its tcc does not build tcc"; }
  (cd "$t" && ./tcc2 -B. -I. -DONE_SOURCE=1 -DCONFIG_TCC_STATIC -o tcc3 tcc.c -lm -lpthread >> self.log 2>&1) \
    || { tail -10 "$t/self.log"; fail "tcc-$1: tcc2 does not build tcc"; }
  cmp -s "$t/tcc2" "$t/tcc3" || fail "tcc-$1: tcc2 and tcc3 differ -- no fixpoint"
  # tests2 by its own makefile, the tcc CC laid as the tcc under test; each test a program
  # rather than -run, its compile's warnings ahead of its output as -run gives them
  cp "$t/tcc1" "$t/tcc" && touch "$t/tcc"
  (cd "$t/tests/tests2" && make -k "T2=$t2" all > ../../tests2.log 2>&1)
  sed -n 's/.*\*\*\* \[[^]]*: \([0-9a-z_+-]*\)\.test\] Error.*/\1/p' "$t/tests2.log" | sort > "$t.miss"
  n=$(grep -c '^Test: ' "$t/tests2.log")
  echo "  tcc-$1: tcc2 = tcc3; tests2 $n run, $(wc -l < "$t.miss" | tr -d ' ') miss"
}

echo "$name  tcc $(cat "$DL/tinycc/VERSION") (mooncc)"
tcc_lay moon "$mcc"
rnames() { printf '%s' "$1" | sed -n 's/^\([^ ]*\) .*/\1/p' | sort; }
rnames "$roster" > "$w/tcc-gcc.roster"
rnames "$roster$roster_moon" > "$w/tcc-moon.roster"
diff "$w/tcc-moon.roster" "$w/tcc-moon.miss" > "$w/tcc.rosterdiff" \
  || { cat "$w/tcc.rosterdiff"; fail "tests2: mooncc's tcc misses are not the roster's (< roster, > missed)"; }
if [ $ref = 1 ]; then
  echo "$name  tcc (gcc)"
  tcc_lay gcc gcc
  cmp -s "$w/tcc-moon/tcc2" "$w/tcc-gcc/tcc2" || fail "the tcc2 mooncc's tcc lays differs from the one gcc's lays"
  diff "$w/tcc-gcc.roster" "$w/tcc-gcc.miss" > "$w/tcc.rosterdiff" \
    || { cat "$w/tcc.rosterdiff"; fail "tests2: gcc's tcc misses are not the roster's (< roster, > missed)"; }
  echo "  tcc: mooncc's and gcc's lay tcc2 byte-identical, and miss the same tests2 but mooncc's own"
fi

# chibi_lay KIND CC: every .c through CC, linked by CC; then its own make test and stage2,
# which link by gcc as upstream's makefile does (chibicc runs the host's as and ld itself)
chibi_lay() {
  t=$w/chibi-$1 cc=$2
  cp -R "$DL/chibicc" "$t" || fail "cannot copy $DL/chibicc"
  for f in "$t"/*.c; do
    "$cc" -std=c11 -g -fno-common -c -o "${f%.c}.o" "$f" >> "$t/build.log" 2>&1 || { tail -5 "$t/build.log"; fail "chibi-$1: $cc refuses $(basename "$f")"; }
  done
  "$cc" -o "$t/chibicc" "$t"/*.o >> "$t/build.log" 2>&1 || { tail -5 "$t/build.log"; fail "chibi-$1: $cc does not link chibicc"; }
  touch "$t/chibicc"
  (cd "$t" && make CC=gcc test > test.log 2>&1) || { tail -10 "$t/test.log"; fail "chibi-$1: make test"; }
  (cd "$t" && make CC=gcc test-stage2 > stage2.log 2>&1) || { tail -10 "$t/stage2.log"; fail "chibi-$1: make test-stage2"; }
  echo "  chibi-$1: make test and test-stage2 pass"
}

if [ $ref = 1 ]; then
  echo "$name  chibicc (mooncc)"
  chibi_lay moon "$mcc"
  echo "$name  chibicc (gcc)"
  chibi_lay gcc gcc
  # what each stage1 lays, as assembly: an object carries the temp name chibicc assembled from
  n=0
  for f in "$w"/chibi-gcc/*.c "$w"/chibi-gcc/test/*.c; do
    r=${f#"$w"/chibi-gcc/}
    [ "$r" = test/macro.c ] && continue          # it lays __TIME__
    for k in moon gcc; do
      (cd "$w/chibi-$k" && ./chibicc -Iinclude -Itest -S -o "$w/chibi-$k.s" "$r") || fail "chibi-$k: chibicc -S $r"
    done
    cmp -s "$w/chibi-moon.s" "$w/chibi-gcc.s" || fail "$r: mooncc's chibicc and gcc's lay it differently"
    n=$((n + 1))
  done
  echo "  chibicc: mooncc's and gcc's lay the same assembly for its $n sources and tests"
else
  gate_partly "$name: no gcc, chibicc (its tests link by the host's cc) skipped"
fi
echo "$name: ok -- tcc and chibicc built by mooncc agree with their gcc builds"
