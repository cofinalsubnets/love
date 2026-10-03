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
           unsupported="100-complex 102-bigstruct 117-vastruct" ;;
  rv64) name=test_ccrv64 ; qemu=qemu-riscv64 ; pretty=rv64
           ccenv=${RISCV64_CC:-}
           ccnames="riscv64-linux-gnu-gcc riscv64-unknown-linux-gnu-gcc riscv64-unknown-elf-gcc"
           ccglob=""
           ccvar=RISCV64_CC
           unsupported="100-complex 102-bigstruct 111-int128 117-vastruct 151-w128fuzz" ;;
  *) echo "ccarch.sh: unknown target $arch" >&2; exit 1 ;;
esac

# cleared at the start, not the end: the last run stays for a post-mortem, and the pile
# never grows past one run
d=$ho/cc-$arch
rm -rf "$d"
mkdir -p "$d"

fail() { echo "FAIL $name: $*" >&2; exit 1; }
moonrun() { LOVE_NO_IMAGE= "$m" mooncc "$@"; }

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

  moonrun -t "$arch" -o "$r/$b.t" "$f" > "$d/$b.tlog" 2>&1 \
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

a64_run "$r" || fail "the $pretty batch did not come back"

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
