#!/bin/sh
# test/gate/ccwasm.sh -- the C battery on the WASM target, ccarch.sh's procedure with node
# as the machine: every test/cc/*.c built by `mooncc -t wasm`, run under node through
# src/port/wasm/run.mjs (the loader is the kernel), and required to answer exactly what the
# same source answers on x86-64 -- stdout and the exit status both. the programs this
# target has no lane for must REFUSE, not skip, and the list is asserted (ccarch.sh says why).
# skips whole without node. NOT set -e: the checks report their own failures with context.
#
# usage: ccwasm.sh OUTDIR LOVE
set -u

ho=$1
m=$2
name=test_ccwasm
# the 128-bit lane (rv64's own refusals, since the lane is rv64's), plus whatever else
# the wasm machine cannot yet carry
unsupported="100-complex 102-bigstruct 111-int128 117-vastruct 151-w128fuzz"

d=$ho/cc-wasm
rm -rf "$d"
mkdir -p "$d"

fail() { echo "FAIL $name: $*" >&2; exit 1; }
moonrun() { LOVE_NO_IMAGE= "$m" mooncc "$@"; }

NODE=$(command -v node 2>/dev/null || true)
if [ -z "$NODE" ]; then
  echo "$name: skipped (need node)"
  exit 0
fi
if [ "$(uname -m)" != x86_64 ]; then
  echo "$name: skipped (the reference build is native x86-64)"
  exit 0
fi

n=0
nref=0
for f in test/cc/*.c; do
  b=$(basename "$f" .c)

  case " $unsupported " in
    *" $b "*)
      if moonrun -t wasm -o "$d/$b.wasm" "$f" > "$d/$b.tlog" 2>&1; then
        fail "$b: mooncc -t wasm BUILT a program listed as unsupported -- take it off the list in this script"
      fi
      st=$?
      [ $st -lt 128 ] || fail "$b: mooncc died on a signal ($st) where a refusal was expected"
      grep -q "$f" "$d/$b.tlog" \
        || { cat "$d/$b.tlog" >&2; fail "$b: the refusal does not name the file"; }
      nref=$((nref + 1))
      continue ;;
  esac

  moonrun -o "$d/$b.x" "$f" > "$d/$b.xlog" 2>&1 \
    || { cat "$d/$b.xlog" >&2; fail "$b: mooncc could not build the x86-64 reference"; }
  timeout 60 "$d/$b.x" > "$d/$b.xout" 2>&1; rx=$?

  moonrun -t wasm -o "$d/$b.wasm" "$f" > "$d/$b.tlog" 2>&1 \
    || { cat "$d/$b.tlog" >&2; fail "$b: mooncc -t wasm could not build it"; }
  timeout 60 "$NODE" src/port/wasm/run.mjs "$d/$b.wasm" > "$d/$b.tout" 2>&1; rt=$?

  [ $rt -ne 124 ] || fail "$b: our wasm module timed out under node"
  [ $rt -eq $rx ] || { head -20 "$d/$b.tout" >&2; fail "$b: exit wasm $rt, x86-64 $rx -- the same source, two of our targets"; }
  if ! cmp -s "$d/$b.tout" "$d/$b.xout"; then
    echo "--- $b: our wasm vs our x86-64 (first 20 differing lines) ---" >&2
    diff "$d/$b.xout" "$d/$b.tout" 2>/dev/null | head -20 >&2
    fail "$b: our wasm codegen disagrees with our x86-64"
  fi

  rm -f "$d/$b.wasm" "$d/$b.tout" "$d/$b.x" "$d/$b.xout" "$d/$b.xlog" "$d/$b.tlog"
  n=$((n + 1))
done

[ $n -gt 0 ] || fail "no programs ran from test/cc/"
echo "$name: $n programs answer on wasm under node exactly as on x86-64, and $nref unsupported ones refuse cleanly"
