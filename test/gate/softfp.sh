#!/bin/sh
# test/gate/softfp.sh -- the compiler runtime (a/moon/lib/rt.c) against the hardware.
# Those __aeabi_* entries ARE double arithmetic on a v6-M board, where nothing else can
# check them: the Pico has no second opinion on board, and a wrong low mantissa bit still
# prints "0.1". So they are gated here, on machines that have the instruction, and held to
# BIT equality with it -- see softfp.c for what the sample covers.
#
# Two axes, for the same reason test_ulp has two: the system cc's build asks whether the
# ALGORITHM is right, and mooncc's build of the same source asks whether OUR COMPILER
# builds it -- and float bits are where a codegen fault hides best. The cross legs add the
# other two backends, so a64 and rv64 lay this file too.
#
# make owns the dependency graph; this owns the procedure.
# NOT set -e: each leg reports its own failure with context.
#
# usage: softfp.sh OUTDIR LOVE
set -u

ho=$1
m=$2
d=$ho/softfp
mkdir -p "$d"
rc=0

fail() { echo "FAIL $*" >&2; rc=1; }
# the compiler under test, run from the project root -- rt.c comes in on -I.
moonrun() { LOVE_NO_IMAGE= "$m" mooncc "$@"; }

# the system cc first: it is the reading of the algorithm, and if THIS leg fails the
# mooncc legs are reporting the same bug and not a codegen one.
cc=${CC:-cc}
if command -v "$cc" >/dev/null 2>&1; then
  if "$cc" -O2 -w -I. -o "$d/cc" test/gate/softfp.c 2>"$d/cc.err"; then
    "$d/cc" > "$d/cc.out" 2>&1 || fail "softfp under $cc: $(tail -1 "$d/cc.out")"
    head -11 "$d/cc.out"
  else fail "$cc build of softfp.c"; sed -n 1,5p "$d/cc.err"; fi
else echo "softfp: no system cc, the algorithm leg skipped"; fi

# mooncc for this machine
if moonrun -I. test/gate/softfp.c "$d/native" > "$d/native.err" 2>&1; then
  "$d/native" > "$d/native.out" 2>&1 || fail "softfp under mooncc: $(tail -1 "$d/native.out")"
  head -11 "$d/native.out"
else fail "mooncc build of softfp.c"; sed -n 1,5p "$d/native.err"; fi

# ..and the cross backends, each under its own qemu-user. A missing qemu skips that leg;
# a mooncc that cannot BUILD it does not.
for t in a64 rv64; do
  case $t in a64) q=qemu-aarch64 ;; rv64) q=qemu-riscv64 ;; esac
  moonrun -t $t -I. test/gate/softfp.c "$d/$t" > "$d/$t.err" 2>&1 \
    || { fail "mooncc -t $t build of softfp.c"; sed -n 1,5p "$d/$t.err"; continue; }
  command -v $q >/dev/null 2>&1 || { echo "softfp: no $q, the $t leg skipped"; continue; }
  $q "$d/$t" > "$d/$t.out" 2>&1 || fail "softfp -t $t: $(tail -1 "$d/$t.out")"
  echo "$t: $(tail -1 "$d/$t.out")"
done

[ $rc -eq 0 ] && echo "softfp: rt.c bit-exact against the hardware on every leg built"
exit $rc
