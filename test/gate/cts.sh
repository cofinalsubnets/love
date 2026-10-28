#!/bin/sh
# test/gate/cts.sh -- mooncc against c-testsuite, an outside corpus whose oracle is each
# program's own .expected. the failures are rostered with a cause, both ways: a program off
# the roster must pass, one on it must still fail, and its kind (refuses or wrong) holds.
# the corpus is fetched into dl/ (or CTSSRC); skips without it or the target's runner.
# usage: cts.sh ARCH OUTDIR LOVE     (ARCH: x64 | a64 | rv64 | wasm)
. test/gate/skip.sh
. test/gate/a64run.sh
. test/gate/cclib.sh
. test/gate/dl.sh
set -u

arch=$1
ho=$2
m=$3

case $arch in
  x64)     name=test_cts       ; tflag=""           ; QEMU= ; qemu= ; pretty=x86-64 ;;
  a64)   name=test_cts_a64 ; tflag="-t a64"   ; qemu=qemu-aarch64 ; pretty=a64 ;;
  rv64) name=test_cts_rv64 ; tflag="-t rv64" ; qemu=qemu-riscv64 ; pretty=rv64 ;;
  wasm) name=test_cts_wasm ; tflag="-t wasm" ; qemu= ; pretty=wasm ;;
  *) echo "cts.sh: unknown target $arch" >&2; exit 1 ;;
esac

# the roster, one line each: <number> <cause>. these hold on every target
roster_refuses='
00201 a ## paste that MAKES a macro name, which is then invoked with arguments
00204 a register-exhausted SSE-class by-value argument -- five float HFAs (the gp twin landed, this one did not)
00216 designated RANGE initializers -- [1 ... 5] = v
'
# compiled clean and answered wrong: none on every target
roster_wrong=''
# a lane x64 and a64 have and the others lack
if [ "$arch" != x64 ] && [ "$arch" != a64 ]; then
  roster_refuses="$roster_refuses
00140 no lane for a by-value composite argument on $arch (x64 carries it, named and anonymous)
"
fi
# the wasm machine's line, not the compiler's: the loader has no filesystem
if [ "$arch" = wasm ]; then
  roster_wrong="$roster_wrong
00187 no filesystem under the loader's kernel: fopen answers NULL, and a NULL FILE does not trap on wasm
"
fi
# a number's kind, and its cause
kindof() {
  case "$roster_refuses" in *"
$1 "*) echo refuses; return;; esac
  case "$roster_wrong" in *"
$1 "*) echo wrong; return;; esac
  echo pass
}
causeof() { printf '%s\n%s\n' "$roster_refuses" "$roster_wrong" | grep "^$1 " | cut -d' ' -f2-; }

# the runner: native x64, an a64 host or qemu-user, node for wasm
if [ "$arch" = a64 ]; then
  a64_how "$m"
  [ -n "$a64_via" ] || gate_skip "$name: skipped (need $qemu or an a64 host)"
elif [ -n "$qemu" ]; then
  a64_qemu=$(command -v "$qemu" 2>/dev/null || true); a64_via=qemu
  [ -n "$a64_qemu" ] || gate_skip "$name: skipped (need $qemu)"
else a64_qemu=; a64_via=qemu; fi
if [ "$arch" = wasm ]; then
  NODE=$(command -v node 2>/dev/null || true)
  [ -n "$NODE" ] || gate_skip "$name: skipped (need node)"
  a64_qemu="$NODE $PWD/src/inle/wasm/loader.js"
fi

# the corpus: CTSSRC, else the pinned one, fetched into dl/ once
if [ -n "${CTSSRC:-}" ]; then
  cts=$CTSSRC
  [ -f "$cts/tests/single-exec/00001.c" ] || fail "CTSSRC=$cts holds no c-testsuite"
else
  dl_need c-testsuite
  cts=$DL/c-testsuite
fi

d=$ho/cts-$arch
rm -rf "$d"; mkdir -p "$d"

# build all, run the built as one batch (one ssh on a host), then judge each
a64_jobs "$d/run"
npass=0; nref=0; nwrong=0
built=
for f in "$cts"/tests/single-exec/*.c; do
  b=$(basename "$f" .c)
  want=$(kindof "$b")
  [ -f "$f.expected" ] || fail "$b: the corpus has no .expected for it"

  moonrun $tflag -o "$d/run/$b.bin" "$f" > "$d/$b.cclog" 2>&1; st=$?
  if [ $st -ne 0 ]; then
    case $want in
      pass)  fail "$b: mooncc refused a program that must pass -- $(head -1 "$d/$b.cclog")" ;;
      wrong) fail "$b: mooncc refuses a program rostered as compiling and answering WRONG ($(causeof "$b")) -- a gap and a defect are not the same news, so move its line" ;;
    esac
    refusal $st "$d/$b.cclog" "$f"
    nref=$((nref + 1)); continue
  fi
  [ "$want" != refuses ] \
    || fail "$b: mooncc BUILT a program rostered as refusing ($(causeof "$b")) -- take its line out of this script"

  # run in the batch's dir: 00187 writes a file beside itself
  a64_job "$b" "timeout 60 \$RUN ./$b.bin"
  built="$built $b"
done

a64_run "$d/run" || fail "the $pretty batch did not come back"

for b in $built; do
  f=$cts/tests/single-exec/$b.c
  want=$(kindof "$b")
  r=$(cat "$d/run/res/$b.rc" 2>/dev/null) || fail "$b: no answer from the batch"
  [ "$r" -ne 124 ] || fail "$b: timed out"
  if [ "$r" -eq 0 ] && cmp -s "$f.expected" "$d/run/res/$b.out"; then
    [ "$want" != wrong ] \
      || fail "$b: now answers right, but is rostered wrong ($(causeof "$b")) -- take its line out of this script"
    npass=$((npass + 1)); continue
  fi

  [ "$want" = wrong ] || {
    echo "--- $b: exit $r, and ours vs the corpus's own .expected ---" >&2
    diff "$f.expected" "$d/run/res/$b.out" 2>/dev/null | head -20 >&2
    fail "$b: compiled clean and answered wrong -- a MISCOMPILE, not a gap"; }
  nwrong=$((nwrong + 1))
done

n=$((npass + nref + nwrong))
[ $n -gt 0 ] || fail "no programs ran from $cts"
echo "$name: $npass of $n c-testsuite programs answer exactly what the corpus says on $pretty; $nref refuse cleanly and $nwrong compile clean and answer WRONG, each named in this script and in doc/misc/moon-c-gaps"
