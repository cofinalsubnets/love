#!/bin/sh
# ccwasm.sh -- ccnif's shape on the WASM target: the nif floors (bench/nif/sum.c, gz.c)
# built by `mooncc -t wasm` and by emcc (clang + musl, wasm64 so long and pointers are
# ours), every lane run by the same node. Three readings: answers (a divergence is a
# miscompile), the module's bytes, wall clock. Where ccnif gauges gen.l's x64 lane against
# gcc, this gauges the wasm lowering against the one other compiler that reaches the seat.
# Not cached and not a gate: a development instrument for the wasm arc.
#
# the drivers read their row off argv, and our loader hands a program none -- so a
# wrapper main bakes the row in, and every lane compiles the same wrapper.
# usage: ./ccwasm.sh [reps] [samples]      (make -C bench ccwasm REPS=64 SAMPLES=5)
set -u
R=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
REPS=${1:-24}
SAMPLES=${2:-5}
W=$R/out/bench/ccwasm
m=$R/out/love
export CCACHE_DISABLE=1

[ -x "$m" ] || { echo "ccwasm: no $m -- run \`make host\` first" >&2; exit 1; }
NODE=$(command -v node 2>/dev/null || true)
[ -n "$NODE" ] || { echo "ccwasm: no node -- nothing runs a module here" >&2; exit 1; }
EMCC=${EMCC:-$(command -v emcc 2>/dev/null || true)}
[ -n "$EMCC" ] || [ ! -x /usr/lib/emscripten/emcc ] || EMCC=/usr/lib/emscripten/emcc
RUN=$R/src/port/wasm/run.mjs

rm -rf "$W"; mkdir -p "$W"
inc="-I$R/src/core -I$R/src/host -I$R/src/inle -I$R/test/libc -I$R/bench/nif"
lanes="mooncc emcc-O2 emcc-O0"
have=mooncc; [ -z "$EMCC" ] || have="$have emcc-O2 emcc-O0"
echo "ccwasm: lanes: $have   reps=$REPS samples=$SAMPLES   (emcc: ${EMCC:-none})"
echo

# the wrapper: the driver with its main renamed, the row and the reps baked into ours
wrap() {   # wrap DRIVER SEL OUT.c
  { sed -e 's|^int main(int argc, char \*\*argv)|int nif_main(int argc, char **argv)|' \
        -e "s|#include \"\.\./\.\./|#include \"$R/|" "$R/bench/nif/$1.c"
    echo "int main(void) { char *av[] = {\"nif\", \"$2\", \"$REPS\", 0}; return nif_main(3, av); }"; } > "$3"
}
build() {  # build LANE SRC.c OUT (the runnable: a .wasm for ours, a .js for emcc's)
  case $1 in
    mooncc)  LOVE_NO_IMAGE= "$m" mooncc -t wasm $inc -o "$3.wasm" "$2" ;;
    emcc-O2) "$EMCC" -O2 -w -sMEMORY64=1 $inc -o "$3.js" "$2" ;;
    emcc-O0) "$EMCC" -O0 -w -sMEMORY64=1 $inc -o "$3.js" "$2" ;;
  esac
}
run() {    # run LANE OUT -> the program's stdout
  case $1 in mooncc) "$NODE" "$RUN" "$2.wasm" ;; *) "$NODE" "$2.js" ;; esac
}
bytes() {  # the module's bytes: ours whole, emcc's the .wasm beside its .js
  case $1 in mooncc) stat -c %s "$2.wasm" ;; *) stat -c %s "$2.wasm" ;; esac
}
ms() {     # median wall-clock ms of SAMPLES runs
  i=0
  while [ $i -lt "$SAMPLES" ]; do
    s=$(date +%s%N); run "$1" "$2" > /dev/null 2>&1 || { echo dnf; return; }; e=$(date +%s%N)
    echo $(( (e - s) / 1000000 )); i=$((i + 1))
  done | sort -n | awk -v n="$SAMPLES" 'NR == int((n+1)/2) { print }'
}

rows="sum:s:sha256 sum:m:md5 sum:c:crc32 sum:k:cksum gz:d:deflate gz:i:inflate"
# ---------------------------------------------------------------- build + answers
echo "== answers (every lane's stdout against mooncc's; a divergence is a miscompile) =="
for row in $rows; do
  b=${row%%:*}; rest=${row#*:}; sel=${rest%%:*}; lbl=${rest#*:}
  wrap "$b" "$sel" "$W/$lbl.c"
  for l in $have; do
    build "$l" "$W/$lbl.c" "$W/$lbl.$l" > "$W/$lbl.$l.build" 2>&1 \
      || { echo "  $lbl $l: DID NOT BUILD"; sed -n 1,3p "$W/$lbl.$l.build"; continue; }
    run "$l" "$W/$lbl.$l" > "$W/$lbl.$l.out" 2>&1 || echo "  $lbl $l: died (exit $?)"
  done
  same=; for l in $have; do
    [ "$l" = mooncc ] && continue
    [ -f "$W/$lbl.$l.out" ] || continue
    if cmp -s "$W/$lbl.mooncc.out" "$W/$lbl.$l.out"; then same="$same $l"
    else echo "  $lbl: mooncc DIVERGES from $l:"; diff "$W/$lbl.$l.out" "$W/$lbl.mooncc.out" | head -6; fi
  done
  echo "  $lbl: $(wc -l < "$W/$lbl.mooncc.out") lines, mooncc ==$same"
done
echo

# ---------------------------------------------------------------- bytes
echo "== module bytes, per driver (whole: code, data and the libc it pulled; ratio against mooncc) =="
printf '%-12s' file; for l in $have; do printf '%14s' "$l"; done; echo
for row in sum:s:sha256 gz:d:deflate; do
  lbl=${row##*:}; printf '%-12s' "${row%%:*}.c"; base=
  for l in $have; do
    v=$(bytes "$l" "$W/$lbl.$l" 2>/dev/null || echo dnf)
    [ -n "$base" ] || base=$v
    if [ "$l" = mooncc ] || [ "$v" = dnf ]; then printf '%14s' "$v"
    else printf '%14s' "$v($(awk -v a="$base" -v b="$v" 'BEGIN{printf "%.1fx", a/b}'))"; fi
  done; echo
done
echo

# ---------------------------------------------------------------- time
echo "== time, ms (median of $SAMPLES, $REPS reps, node's start included; lower is better) =="
printf '%-12s' row; for l in $have; do printf '%14s' "$l"; done; echo
for row in $rows; do
  lbl=${row##*:}; printf '%-12s' "$lbl"; base=
  for l in $have; do
    v=$(ms "$l" "$W/$lbl.$l")
    [ -n "$base" ] || base=$v
    if [ "$l" = mooncc ] || [ "$v" = dnf ] || [ "$base" = dnf ] || [ "$v" = 0 ]; then printf '%14s' "$v"
    else printf '%14s' "$v($(awk -v a="$base" -v b="$v" 'BEGIN{printf "%.2fx", a/b}'))"; fi
  done; echo
done
echo
echo "ccwasm: the ratio in a cell is mooncc/that lane -- 1.00x is parity. the corpus row lives in"
echo "        the gates: \`make test_wasm\` times the module, \`make -C src/port/wasm gate\` lays emcc's"
echo "        out/wasm/love.js and test.mjs --love takes either."
