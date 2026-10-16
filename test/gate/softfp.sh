#!/bin/sh
# test/gate/softfp.sh -- rt.c's soft-float __aeabi_* entries held bit-equal to the hardware,
# built by the system cc (the algorithm) and by mooncc for x64, a64 and rv64 (the compiler)
# usage: softfp.sh OUTDIR LOVE
. test/gate/skip.sh
. test/gate/a64run.sh
. test/gate/cclib.sh
set -u

ho=$1
m=$2
d=$ho/softfp
mkdir -p "$d"
rc=0

fail() { echo "FAIL $*" >&2; rc=1; }

# the system cc first: if it fails, the mooncc legs share the bug
cc=${CC:-cc}
if command -v "$cc" >/dev/null 2>&1; then
  if "$cc" -O2 -w -I. -o "$d/cc" test/gate/softfp.c 2>"$d/cc.err"; then
    "$d/cc" > "$d/cc.out" 2>&1 || fail "softfp under $cc: $(tail -1 "$d/cc.out")"
    head -11 "$d/cc.out"
  else fail "$cc build of softfp.c"; sed -n 1,5p "$d/cc.err"; fi
else gate_partly "softfp: no system cc, the algorithm leg skipped"; fi

# mooncc for this machine
if moonrun -I. test/gate/softfp.c "$d/native" > "$d/native.err" 2>&1; then
  "$d/native" > "$d/native.out" 2>&1 || fail "softfp under mooncc: $(tail -1 "$d/native.out")"
  head -11 "$d/native.out"
else fail "mooncc build of softfp.c"; sed -n 1,5p "$d/native.err"; fi

# the cross backends on an a64 host or qemu-user; a missing runner skips, a failed build does not
a64_how "$m"
for t in a64 rv64; do
  case $t in a64) q=qemu-aarch64 ;; rv64) q=qemu-riscv64 ;; esac
  moonrun -t $t -I. test/gate/softfp.c "$d/$t" > "$d/$t.err" 2>&1 \
    || { fail "mooncc -t $t build of softfp.c"; sed -n 1,5p "$d/$t.err"; continue; }
  if [ $t = a64 ]; then
    [ -n "$a64_via" ] || { gate_partly "softfp: no $q and no a64 host, the a64 leg skipped"; continue; }
    a64_one "$m" "$d/$t" > "$d/$t.out" 2>&1 || fail "softfp -t $t ($a64_via): $(tail -1 "$d/$t.out")"
  else
    command -v $q >/dev/null 2>&1 || { gate_partly "softfp: no $q, the $t leg skipped"; continue; }
    $q "$d/$t" > "$d/$t.out" 2>&1 || fail "softfp -t $t: $(tail -1 "$d/$t.out")"
  fi
  echo "$t: $(tail -1 "$d/$t.out")"
done

[ $rc -eq 0 ] && echo "softfp: rt.c bit-exact against the hardware on every leg built"
exit $rc
