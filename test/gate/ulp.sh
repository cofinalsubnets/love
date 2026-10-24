#!/bin/sh
# test/gate/ulp.sh -- the math floor: lm.c built by mooncc and by the system cc, each
# measured against the host libm, and the two reports must agree byte for byte (float bits
# are where a codegen fault hides). each function also holds its ulp ceiling, the measured
# maximum; lower one when beaten. hosted only: the oracle is the system libm. the arcs are
# held to the nearest double by test/gate/arcs.l's own oracle: glibc's last bit is faithful.
# usage: ulp.sh OUTDIR LOVE
. test/gate/skip.sh
. test/gate/cclib.sh
set -u

ho=$1
m=$2
d=$ho/ulpgate            # NOT $ho/ulp -- that name is `make ulp`'s binary
mkdir -p "$d"

name=test_ulp

arch=$(uname -m)
if [ "$arch" != x64 ] && [ "$arch" != x86_64 ]; then
  gate_skip "test_ulp: x86-64 only (mooncc emits x64), skipped on $arch"
fi
cc_g=$(command -v gcc || command -v cc) || true
if [ -z "${cc_g:-}" ]; then
  gate_skip "test_ulp: no system cc for the oracle, skipped"
fi

lm=src/apps/moon/lib/moonlibc/math/lm.c

# the two objects: one source, two compilers
moonrun -c -o "$d/lm_moon.o" "$lm" > "$d/moon.build" 2>&1 \
  || { cat "$d/moon.build" >&2; fail "mooncc could not build $lm"; }
$cc_g -O2 -c -o "$d/lm_sys.o" "$lm" 2> "$d/sys.build" \
  || { cat "$d/sys.build" >&2; fail "$cc_g could not build $lm"; }

# the harness is always the system cc's, so only lm.c's object differs
for w in moon sys; do
  $cc_g -O2 -o "$d/ulp_$w" src/tools/ulp.c "$d/lm_$w.o" -lm 2> "$d/link_$w" \
    || { cat "$d/link_$w" >&2; fail "could not link the $w harness"; }
done

# `reduce` reaches the Payne-Hanek reduction (|x| up to 2^1020); the sweep stops at 2^8;
# `arcs` lays the arcs' grid; `float` sweeps the binary32 twins
for mode in sweep reduce arcs float; do
  case $mode in sweep) a= ;; *) a=$mode ;; esac
  for w in moon sys; do
    "$d/ulp_$w" $a > "$d/$mode.$w" 2>&1
    st=$?
    [ $st -eq 0 ] || fail "the $w harness died in the $mode run (exit $st)"
  done
  if ! cmp -s "$d/$mode.moon" "$d/$mode.sys"; then
    echo "--- $mode: mooncc's lm.o vs $cc_g's (first 20 differing lines) ---" >&2
    diff "$d/$mode.sys" "$d/$mode.moon" 2>/dev/null | head -20 >&2
    fail "$mode: our compiler and $cc_g build lm.c into different math"
  fi
done

$m test/gate/arcs.l "$d/arcs.sys" > "$d/arcs.out" 2>&1 \
  || { cat "$d/arcs.out" >&2; fail "the arcs are not the nearest double"; }

# the ceilings, against glibc. pow's sweep reaches the representable rim of |y ln x|; powrim sits on it
nf=0
while read -r fn lim; do
  [ -n "$fn" ] || continue
  case $fn in *f|*fneg) rep=float ;; *) rep=sweep ;; esac
  got=$(awk -v f="$fn" '$1 == f { print $3; exit }' "$d/$rep.sys")
  [ -n "$got" ] || fail "no '$fn' line in the report -- src/tools/ulp.c changed shape"
  awk -v g="$got" -v l="$lim" 'BEGIN { exit !(g + 0 <= l + 0) }' \
    || fail "$fn measured $got ulp, over its documented ceiling of $lim"
  nf=$((nf + 1))
done <<'EOF'
sqrt 0
exp 1
exp2 1
log 1
logn1 1
sin 1
cos 1
atan2 1
asin 1
acos 1
pow 7
powrim 37
sqrtf 0
expf 1
logf 1
logn1f 1
sinf 1
cosf 1
powf 1
powfneg 1
EOF

echo "test_ulp: mooncc and $cc_g build lm.c into byte-identical math (4 modes), all $nf functions hold their ulp ceiling; $(cat "$d/arcs.out")"
