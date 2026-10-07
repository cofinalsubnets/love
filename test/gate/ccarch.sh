#!/bin/sh
# test/gate/ccarch.sh -- the C battery on a cross target: every test/cc/*.c built by
# `mooncc -t <arch>`, run under qemu-user or on an a64 host (test/gate/a64run.sh), must
# answer what the same source answers on x86-64. the targets share mooncc's front end and most of gen.l, so a fault in the
# shared model can hide behind a lane one target has and another lacks.
#
# the reference is the x86-64 build, which test_moon pins against gcc: gcc pins x64 and
# x64 pins the rest, with no cross gcc needed. where one exists (a64, via AARCH64_CC or
# the local nerves toolchain) it is an extra oracle, since agreeing with x64 cannot
# catch a fault both share. stdout is compared, not just the exit code.
#
# the exclusions are per target and asserted: a program using a feature the target has
# no lane for must be refused (nonzero exit, no signal, a diagnostic naming the file).
# the day the target grows the lane this fails, and the name comes off its list.
#
# skips whole with neither a host nor the target's qemu. not set -e: the checks report their own failures.
# usage: ccarch.sh ARCH OUTDIR LOVE     (ARCH: a64 | rv64)
. test/gate/skip.sh
. test/gate/a64run.sh
set -u

arch=$1
ho=$2
m=$3

case $arch in
  a64)   name=test_cca64 ; qemu=qemu-aarch64 ; pretty=a64
           ccenv=${AARCH64_CC:-}
           ccnames="aarch64-linux-gnu-gcc a64-nerves-linux-gnu-gcc"
           ccglob="/usr/local/data/*/.nerves/artifacts/nerves_toolchain_a64*/bin/a64-nerves-linux-gnu-gcc"
           ccvar=AARCH64_CC
           unsupported="100-complex 117-vastruct" ;;
  rv64) name=test_ccrv64 ; qemu=qemu-riscv64 ; pretty=rv64
           ccenv=${RISCV64_CC:-}
           ccnames="riscv64-linux-gnu-gcc riscv64-unknown-linux-gnu-gcc riscv64-unknown-elf-gcc"
           ccglob=""
           ccvar=RISCV64_CC
           unsupported="100-complex 111-int128 117-vastruct 151-w128fuzz 266-vaarg-struct" ;;
  *) echo "ccarch.sh: unknown target $arch" >&2; exit 1 ;;
esac

# cleared at the start, not the end: the last run stays for a post-mortem, and the pile
# never grows past one run
d=$ho/cc-$arch
rm -rf "$d"
mkdir -p "$d"

fail() { echo "FAIL $name: $*" >&2; exit 1; }
moonrun() { LOVE_NO_IMAGE= "$m" mooncc "$@"; }
# a law's own flags for this target, off its first line: /* mooncc -t ARCH: FLAGS */. the x86-64
# reference builds without them, so a flagged build must answer what the plain one does
tflags() { sed -n "1s|^/\* mooncc -t $arch: \(.*\) \*/\$|\1|p" "$1"; }

# $unsupported comes from the case above: the features THIS target has no lane
# for yet -- refusal is the asserted behaviour, per target, not per gate.

# a64 runs on a host where one answers; rv64 only ever under its qemu
if [ "$arch" = a64 ]; then a64_how "$m"
else a64_qemu=$(command -v "$qemu" 2>/dev/null || true); a64_via=${a64_qemu:+qemu}; fi
[ -n "$a64_via" ] || gate_skip "$name: skipped (need $qemu or an a64 host)"
where=$([ "$a64_via" = host ] && echo "on an a64 host" || echo "under qemu")
if [ "$(uname -m)" != x86_64 ]; then
  gate_skip "$name: skipped (the reference build is native x86-64)"
fi

# the OPTIONAL extra oracle: a cross gcc with a static libc, if this box has one
GCC="$ccenv"
for c in $ccnames; do
  [ -n "$GCC" ] && break
  GCC=$(command -v "$c" 2>/dev/null || true)
done
if [ -z "$GCC" ] && [ -n "$ccglob" ]; then
  GCC=$(ls $ccglob 2>/dev/null | head -1)
fi

# three passes: build every program (and run the x86-64 reference here), run the target
# binaries as one batch, then compare. a batch is one ssh on a host, not one per program
r=$d/run
a64_jobs "$r"
nref=0
progs=
for f in test/cc/*.c; do
  b=$(basename "$f" .c)

  case " $unsupported " in
    *" $b "*)
      if moonrun -t "$arch" -o "$d/$b.t" "$f" > "$d/$b.tlog" 2>&1; then
        fail "$b: mooncc -t $arch BUILT a program listed as unsupported -- take it off the list in this script"
      fi
      st=$?
      [ $st -lt 128 ] || fail "$b: mooncc died on a signal ($st) where a refusal was expected"
      grep -q "$f" "$d/$b.tlog" \
        || { cat "$d/$b.tlog" >&2; fail "$b: the refusal does not name the file"; }
      nref=$((nref + 1))
      continue ;;
  esac

  # the reference: the SAME source on x86-64, which test_moon pins against gcc
  moonrun -o "$d/$b.x" "$f" > "$d/$b.xlog" 2>&1 \
    || { cat "$d/$b.xlog" >&2; fail "$b: mooncc could not build the x86-64 reference"; }
  timeout 60 "$d/$b.x" > "$d/$b.xout" 2>&1; echo $? > "$d/$b.xrc"

  moonrun -t "$arch" $(tflags "$f") -o "$r/$b.t" "$f" > "$d/$b.tlog" 2>&1 \
    || { cat "$d/$b.tlog" >&2; fail "$b: mooncc -t $arch could not build it"; }
  a64_job "$b.t" "timeout 60 \$RUN ./$b.t"

  # and a real cross gcc where the box has one (catches a shared fault, which agreeing
  # with x64 cannot). -w: the battery is about the ANSWERS, and gcc warns about deliberate edges
  if [ -n "$GCC" ]; then
    $GCC -O0 -w -static -o "$r/$b.g" "$f" 2> "$d/$b.glog" \
      || { cat "$d/$b.glog" >&2; fail "$b: the cross gcc could not build it"; }
    a64_job "$b.g" "timeout 60 \$RUN ./$b.g"
  fi
  progs="$progs $b"
done

# a64: the ABI across compilers -- mooncc's half (test/cc/abi64/host.c) linked with clang's
# (peer.c), each calling the other with AAPCS64's memory-class composites
if [ "$arch" = a64 ]; then
  command -v clang > /dev/null 2>&1 || gate_skip "$name: no clang for the abi64 half"
  clang --target=aarch64-linux-gnu -O2 -ffreestanding -fno-stack-protector -c -o "$d/peer.o" test/cc/abi64/peer.c 2> "$d/peer.log" \
    || { cat "$d/peer.log" >&2; fail "abi64: clang could not build peer.c"; }
  moonrun -t a64 -o "$r/abi64.t" test/cc/abi64/host.c "$d/peer.o" > "$d/abi64.log" 2>&1 \
    || { cat "$d/abi64.log" >&2; fail "abi64: mooncc could not build or link host.c"; }
  a64_job abi64.t "timeout 60 \$RUN ./abi64.t"

  # the landing law: -mbranch-protection and -mstrict-align held to clang's objects for the
  # same units (test/cc/protect/units.c) -- each fn's landing (bti c, paciasp or neither),
  # autiasp right before every exit of a pac-ret fn and after every frame record's ldp, no
  # packed access wider than clang's, and the property note and build attributes byte for
  # byte. the clang the hearts lanes pin where this box has it, else the one on PATH
  hc=${HEARTS_CLANG:-$HOME/.cache/hearts/llvm-22.1.8}/bin/clang
  [ -x "$hc" ] || hc=clang
  command -v llvm-objdump > /dev/null 2>&1 && command -v llvm-readelf > /dev/null 2>&1 \
    || gate_skip "$name: no llvm-objdump or llvm-readelf for the landing law"
  bp="-mbranch-protection=pac-ret+bti -mstrict-align"
  "$hc" --target=aarch64-linux-gnu -O2 $bp -c -o "$d/land.c.o" test/cc/protect/units.c 2> "$d/land.log" \
    || { cat "$d/land.log" >&2; fail "landing: clang could not build units.c"; }
  moonrun -t a64 -c $bp -o "$d/land.m.o" test/cc/protect/units.c > "$d/land.log" 2>&1 \
    || { cat "$d/land.log" >&2; fail "landing: mooncc could not build units.c"; }
  # L fn landing | W fn widest-packed-access | BAD fn why
  land() {
    llvm-objdump -dr --no-show-raw-insn "$1" | awk '
      function wd(m, ops,   r) {
        if (m ~ /^(ld|st)(u?r|ur)s?b$/ || m ~ /^ldu?rsb$/) return 1
        if (m ~ /^(ld|st)(u?r|ur)s?h$/ || m ~ /^ldu?rsh$/) return 2
        if (m ~ /^ldu?rsw$/) return 4
        r = substr(ops, 1, 1)
        return r == "x" || r == "d" ? 8 : r == "q" ? 16 : r == "h" ? 2 : r == "b" ? 1 : 4
      }
      function out() { if (fn ~ /^pk_/) print "W", fn, w }
      /^[0-9a-f]+ </ { if (fn != "") out(); fn = $2; gsub(/[<>:]/, "", fn); first = 1; pac = 0; w = 0; prev = ""; pprev = ""; ldp = 0; next }
      /R_AARCH64_JUMP26/ { if (pac && prev ~ /^b\t/ && pprev != "autiasp") print "BAD", fn, "a tail branch without autiasp"; next }
      /^ +[0-9a-f]+:/ {
        l = $0; sub(/^ +[0-9a-f]+:[ \t]+/, "", l); sub(/[ \t]*(\/\/|<).*$/, "", l)
        if (first) { c = l == "bti\tc" ? "btic" : l == "paciasp" ? "pac" : "-"; print "L", fn, c; pac = c == "pac"; first = 0 }
        if (pac && (l == "ret" || l ~ /^br\t/) && prev != "autiasp") print "BAD", fn, "an exit without autiasp: " l
        if (ldp && l != "autiasp") print "BAD", fn, "a frame record restored without autiasp"
        ldp = l ~ /^ldp\tx29, x30/
        split(l, f, "\t"); m = f[1]
        if (m ~ /^(ld|st)(u?r|p)/ && m !~ /x(r|p)$/ && match(l, /\[[a-z0-9]+/)) {
          b = substr(l, RSTART + 1, RLENGTH - 1)
          if (b != "sp" && b != "x29") { k = wd(m, f[2]); if (k > w) w = k }
        }
        pprev = prev; prev = l
      }
      END { if (fn != "") out() }'
  }
  land "$d/land.c.o" > "$d/land.c"
  land "$d/land.m.o" > "$d/land.m"
  grep '^BAD' "$d/land.m" >&2 && fail "landing: mooncc's exits (above)"
  grep '^L' "$d/land.c" | sort > "$d/land.cl"
  grep '^L' "$d/land.m" | sort > "$d/land.ml"
  cmp -s "$d/land.cl" "$d/land.ml" || { diff "$d/land.cl" "$d/land.ml" >&2; fail "landing: a fn lands where clang's does not (clang <, mooncc >)"; }
  grep '^W' "$d/land.m" | while read -r _ fn k; do
    kc=$(grep "^W $fn " "$d/land.c" | cut -d' ' -f3)
    [ "$k" -le "${kc:-0}" ] || { echo "landing: $fn reads $k bytes at once where clang reads $kc" >&2; exit 1; }
  done || fail "landing: a packed access wider than clang's"
  for s in .note.gnu.property .ARM.attributes; do
    llvm-readelf -x $s "$d/land.c.o" | grep '^ *0x' > "$d/land.cs"
    llvm-readelf -x $s "$d/land.m.o" | grep '^ *0x' > "$d/land.ms"
    [ -s "$d/land.cs" ] && cmp -s "$d/land.cs" "$d/land.ms" \
      || { diff "$d/land.cs" "$d/land.ms" >&2; fail "landing: $s differs from clang's"; }
  done
  echo "landing: $(grep -c '^L' "$d/land.m") fns land as clang $("$hc" --version | sed -n '1s/.*version //p')'s do, their exits authenticate, packed reads go by its widths, the notes match"
fi

a64_run "$r" || fail "the $pretty batch did not come back"
if [ "$arch" = a64 ]; then
  [ "$(cat "$r/res/abi64.t.rc")" -eq 0 ] || { cat "$r/res/abi64.t.out" >&2; fail "abi64: mooncc and clang disagree on AAPCS64"; }
  tail -1 "$r/res/abi64.t.out"
fi

n=0
ngcc=0
for b in $progs; do
  rx=$(cat "$d/$b.xrc")
  rt=$(cat "$r/res/$b.t.rc" 2>/dev/null) || fail "$b: no answer from the $pretty batch"
  cp "$r/res/$b.t.out" "$d/$b.tout"
  [ "$rt" -ne 124 ] || fail "$b: our $pretty binary timed out $where"
  [ "$rt" -eq "$rx" ] || fail "$b: exit $pretty $rt, x86-64 $rx -- the same source, two of our targets"
  if ! cmp -s "$d/$b.tout" "$d/$b.xout"; then
    echo "--- $b: our $pretty vs our x86-64 (first 20 differing lines) ---" >&2
    diff "$d/$b.xout" "$d/$b.tout" 2>/dev/null | head -20 >&2
    fail "$b: our $pretty codegen disagrees with our x86-64"
  fi
  if [ -n "$GCC" ]; then
    rg=$(cat "$r/res/$b.g.rc")
    [ "$rt" -eq "$rg" ] || fail "$b: exit ours $rt, $GCC $rg (on $pretty)"
    cmp -s "$d/$b.tout" "$r/res/$b.g.out" || {
      echo "--- $b: ours vs the cross gcc on $pretty (first 20 lines) ---" >&2
      diff "$r/res/$b.g.out" "$d/$b.tout" 2>/dev/null | head -20 >&2
      fail "$b: our $pretty codegen and the cross gcc's disagree"; }
    ngcc=$((ngcc + 1))
  fi

  # a passed case agreed on every leg and its diffs were never needed; its static .g
  # binaries are ~3 MB each. a failing case keeps everything
  rm -f "$r/$b.g" "$r/$b.t" "$r/res/$b".* "$d/$b.tout" "$d/$b.glog" \
        "$d/$b.x" "$d/$b.xout" "$d/$b.xrc" "$d/$b.xlog" "$d/$b.tlog"
  n=$((n + 1))
done

[ $n -gt 0 ] || fail "no programs ran from test/cc/"

if [ -n "$GCC" ]; then
  echo "$name: $n programs answer on $pretty ($where) exactly as on x86-64, $ngcc of them cross-checked against $(basename "$GCC"), and $nref unsupported ones refuse cleanly"
else
  echo "$name: $n programs answer on $pretty ($where) exactly as on x86-64 (no cross gcc here -- x64 is the oracle, and test_moon pins it), and $nref unsupported ones refuse cleanly"
fi
