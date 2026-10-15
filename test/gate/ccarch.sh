#!/bin/sh
# test/gate/ccarch.sh -- the C battery on a cross target: every test/cc/*.c built by
# `mooncc -t ARCH`, run under qemu-user or on an a64 host, must answer stdout and exit as
# our x86-64 build does; a cross gcc, where the box has one, is a second oracle.
# $unsupported must refuse, by name, without a signal. skips with no host and no qemu
# usage: ccarch.sh ARCH OUTDIR LOVE     (ARCH: a64 | rv64)
. test/gate/skip.sh
. test/gate/a64run.sh
. test/gate/cclib.sh
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
           unsupported="117-vastruct" ;;
  rv64) name=test_ccrv64 ; qemu=qemu-riscv64 ; pretty=rv64
           ccenv=${RISCV64_CC:-}
           ccnames="riscv64-linux-gnu-gcc riscv64-unknown-linux-gnu-gcc riscv64-unknown-elf-gcc"
           ccglob=""
           ccvar=RISCV64_CC
           unsupported="100-complex 280-cxf-fuzz 111-int128 117-vastruct 151-w128fuzz 266-vaarg-struct 297-frameaddr" ;;
  *) echo "ccarch.sh: unknown target $arch" >&2; exit 1 ;;
esac

# cleared at the start: the last run stays for a post-mortem
d=$ho/cc-$arch
rm -rf "$d"
mkdir -p "$d"

# a program's own flags, off its first line: /* mooncc -t ARCH: FLAGS */; x64 builds without
tflags() { sed -n "1s|^/\* mooncc -t $arch: \(.*\) \*/\$|\1|p" "$1"; }

# a64 runs on a host where one answers; rv64 only ever under its qemu
if [ "$arch" = a64 ]; then a64_how "$m"
else a64_qemu=$(command -v "$qemu" 2>/dev/null || true); a64_via=${a64_qemu:+qemu}; fi
[ -n "$a64_via" ] || gate_skip "$name: skipped (need $qemu or an a64 host)"
where=$([ "$a64_via" = host ] && echo "on an a64 host" || echo "under qemu")
if [ "$(uname -m)" != x86_64 ]; then
  gate_skip "$name: skipped (the reference build is native x86-64)"
fi

# the optional second oracle: a cross gcc with a static libc
GCC="$ccenv"
for c in $ccnames; do
  [ -n "$GCC" ] && break
  GCC=$(command -v "$c" 2>/dev/null || true)
done
if [ -z "$GCC" ] && [ -n "$ccglob" ]; then
  GCC=$(ls $ccglob 2>/dev/null | head -1)
fi

# build all (running the x64 reference here), run the target binaries as one batch, compare
r=$d/run
a64_jobs "$r"
nref=0
progs=
for f in test/cc/*.c; do
  b=$(basename "$f" .c)

  case " $unsupported " in
    *" $b "*)
      refused "$d/$b.tlog" "$f" -t "$arch" -o "$d/$b.t" "$f"
      nref=$((nref + 1))
      continue ;;
  esac

  moonrun -o "$d/$b.x" "$f" > "$d/$b.xlog" 2>&1 \
    || { cat "$d/$b.xlog" >&2; fail "$b: mooncc could not build the x86-64 reference"; }
  timeout 60 "$d/$b.x" > "$d/$b.xout" 2>&1; echo $? > "$d/$b.xrc"

  moonrun -t "$arch" $(tflags "$f") -o "$r/$b.t" "$f" > "$d/$b.tlog" 2>&1 \
    || { cat "$d/$b.tlog" >&2; fail "$b: mooncc -t $arch could not build it"; }
  a64_job "$b.t" "timeout 60 \$RUN ./$b.t"

  # -w: gcc warns about the battery's deliberate edges
  if [ -n "$GCC" ]; then
    $GCC -O0 -w -static -o "$r/$b.g" "$f" 2> "$d/$b.glog" \
      || { cat "$d/$b.glog" >&2; fail "$b: the cross gcc could not build it"; }
    a64_job "$b.g" "timeout 60 \$RUN ./$b.g"
  fi
  progs="$progs $b"
done

# a64: the packed program again under -mstrict-align
if [ "$arch" = a64 ]; then
  moonrun -t a64 -mstrict-align -o "$r/sa279.t" test/cc/279-packed-bitfield.c > "$d/sa279.log" 2>&1 \
    || { cat "$d/sa279.log" >&2; fail "strict-align: mooncc could not build 279-packed-bitfield.c"; }
  a64_job sa279.t "timeout 60 \$RUN ./sa279.t"
fi

# a64: abi64/host.c by mooncc linked with clang's peer.c, each calling the other
if [ "$arch" = a64 ]; then
  command -v clang > /dev/null 2>&1 || gate_skip "$name: no clang for the abi64 half"
  clang --target=aarch64-linux-gnu -O2 -ffreestanding -fno-stack-protector -c -o "$d/peer.o" test/cc/abi64/peer.c 2> "$d/peer.log" \
    || { cat "$d/peer.log" >&2; fail "abi64: clang could not build peer.c"; }
  moonrun -t a64 -o "$r/abi64.t" test/cc/abi64/host.c "$d/peer.o" > "$d/abi64.log" 2>&1 \
    || { cat "$d/abi64.log" >&2; fail "abi64: mooncc could not build or link host.c"; }
  a64_job abi64.t "timeout 60 \$RUN ./abi64.t"
  # __int128 across them: the even register pair, the 16-aligned stack pair
  clang --target=aarch64-linux-gnu -O2 -ffreestanding -fno-stack-protector -c -o "$d/peer128.o" test/cc/abi128/peer.c 2> "$d/peer128.log" \
    || { cat "$d/peer128.log" >&2; fail "abi128: clang could not build peer.c"; }
  moonrun -t a64 -o "$r/abi128.t" test/cc/abi128/host.c "$d/peer128.o" > "$d/abi128.log" 2>&1 \
    || { cat "$d/abi128.log" >&2; fail "abi128: mooncc could not build or link host.c"; }
  a64_job abi128.t "timeout 60 \$RUN ./abi128.t"

  # the landing law, against clang on protect/units.c: each fn's landing, autiasp before
  # every exit and after every frame record's ldp, no packed access wider, the notes equal
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
  [ "$(cat "$r/res/sa279.t.rc")" -eq 0 ] || { cat "$r/res/sa279.t.out" >&2; fail "strict-align: 279-packed-bitfield.c answers wrong under -mstrict-align"; }
  [ "$(cat "$r/res/abi64.t.rc")" -eq 0 ] || { cat "$r/res/abi64.t.out" >&2; fail "abi64: mooncc and clang disagree on AAPCS64"; }
  tail -1 "$r/res/abi64.t.out"
  [ "$(cat "$r/res/abi128.t.rc")" -eq 0 ] || { cat "$r/res/abi128.t.out" >&2; fail "abi128: mooncc and clang disagree on AAPCS64's __int128"; }
  tail -1 "$r/res/abi128.t.out"
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

  # a passed case's files go (a static .g is ~3 MB); a failing one keeps them
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
