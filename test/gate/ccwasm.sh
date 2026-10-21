#!/bin/sh
# test/gate/ccwasm.sh -- the C battery on wasm: every test/cc/*.c built by `mooncc -t wasm`,
# run by node under src/inle/wasm/loader.js, must answer stdout and exit as our x86-64 build
# does, and as emcc's wasm64 does where the box has one (EMCC= names it). $unsupported must
# refuse. skips without node
# usage: ccwasm.sh OUTDIR LOVE
. test/gate/skip.sh
. test/gate/cclib.sh
set -u

ho=$1
m=$2
name=test_ccwasm
# return addresses, frame chains and label values live off linear memory, and a module
# has no symbol table for 294's asm labels
unsupported="100-complex 280-cxf-fuzz 111-int128 117-vastruct 151-w128fuzz 314-u128union 160-rangeinit 229-labelvalue 256-inline-retaddr 266-vaarg-struct 294-asmlabel 297-frameaddr"
# x64 alone for these: clang lacks __builtin_*_overflow_p, emcc's malloc aborts where C
# answers NULL, its aligned_alloc keeps C11's size rule
noemcc="268-overflow-p 298-malloc-wrap 300-aligned-alloc"

d=$ho/cc-wasm
rm -rf "$d"
mkdir -p "$d"


NODE=$(command -v node 2>/dev/null || true)
if [ -z "$NODE" ]; then
  gate_skip "$name: skipped (need node)"
fi
if [ "$(uname -m)" != x86_64 ]; then
  gate_skip "$name: skipped (the reference build is native x86-64)"
fi
# the optional second oracle
EMCC=${EMCC:-$(command -v emcc 2>/dev/null || true)}
[ -n "$EMCC" ] || [ ! -x /usr/lib/emscripten/emcc ] || EMCC=/usr/lib/emscripten/emcc

n=0
nref=0
nemcc=0
for f in test/cc/*.c; do
  b=$(basename "$f" .c)

  case " $unsupported " in
    *" $b "*)
      refused "$d/$b.tlog" "$f" -t wasm -o "$d/$b.wasm" "$f"
      nref=$((nref + 1))
      continue ;;
  esac

  moonrun -o "$d/$b.x" "$f" > "$d/$b.xlog" 2>&1 \
    || { cat "$d/$b.xlog" >&2; fail "$b: mooncc could not build the x86-64 reference"; }
  timeout 60 "$d/$b.x" > "$d/$b.xout" 2>&1; rx=$?

  moonrun -t wasm -o "$d/$b.wasm" "$f" > "$d/$b.tlog" 2>&1 \
    || { cat "$d/$b.tlog" >&2; fail "$b: mooncc -t wasm could not build it"; }
  timeout 60 "$NODE" src/inle/wasm/loader.js "$d/$b.wasm" > "$d/$b.tout" 2>&1; rt=$?

  [ $rt -ne 124 ] || fail "$b: our wasm module timed out under node"
  [ $rt -eq $rx ] || { head -20 "$d/$b.tout" >&2; fail "$b: exit wasm $rt, x86-64 $rx -- the same source, two of our targets"; }
  if ! cmp -s "$d/$b.tout" "$d/$b.xout"; then
    echo "--- $b: our wasm vs our x86-64 (first 20 differing lines) ---" >&2
    diff "$d/$b.xout" "$d/$b.tout" 2>/dev/null | head -20 >&2
    fail "$b: our wasm codegen disagrees with our x86-64"
  fi

  case " $noemcc " in *" $b "*) noe=1 ;; *) noe= ;; esac
  if [ -n "$EMCC" ] && [ -z "$noe" ]; then
    # -w: clang warns about the battery's deliberate edges
    if "$EMCC" -sMEMORY64=1 -O0 -w -o "$d/$b.e.js" "$f" > "$d/$b.elog" 2>&1; then
      timeout 60 "$NODE" "$d/$b.e.js" > "$d/$b.eout" 2>&1; re=$?
      [ $rt -eq $re ] || fail "$b: exit ours $rt, emcc $re (both wasm64 under node)"
      cmp -s "$d/$b.tout" "$d/$b.eout" || {
        echo "--- $b: ours vs emcc's wasm64 (first 20 lines) ---" >&2
        diff "$d/$b.eout" "$d/$b.tout" 2>/dev/null | head -20 >&2
        fail "$b: our wasm codegen and emcc's disagree"; }
      nemcc=$((nemcc + 1))
    else
      cat "$d/$b.elog" >&2
      fail "$b: emcc could not build it"
    fi
  fi

  # a passed case's files go; a failing one keeps them
  rm -f "$d/$b.wasm" "$d/$b.tout" "$d/$b.x" "$d/$b.xout" "$d/$b.xlog" "$d/$b.tlog" \
        "$d/$b.e.js" "$d/$b.e.wasm" "$d/$b.eout" "$d/$b.elog"
  n=$((n + 1))
done

[ $n -gt 0 ] || fail "no programs ran from test/cc/"
if [ -n "$EMCC" ]; then
  echo "$name: $n programs answer on wasm under node exactly as on x86-64, $nemcc of them cross-checked against emcc's wasm64, and $nref unsupported ones refuse cleanly"
else
  echo "$name: $n programs answer on wasm under node exactly as on x86-64 (no emcc here -- x64 is the oracle, and test_moon pins it), and $nref unsupported ones refuse cleanly"
fi
