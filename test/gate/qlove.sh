#!/bin/sh
# test/gate/qlove.sh -- a cross-built artifact under qemu-user: the corpus over the egg, its
# own bake, the corpus on the wake, the hook's laws, and the glaze against the interpreter.
#
# usage: qlove.sh ARCH OUTDIR XLOVE CAT CORPUS.l ..   (ARCH: rv64 arm)
. test/gate/skip.sh
set -u

xa=$1
ho=$2
xl=$3
cat=$4
shift 4
name=test_love_$xa
fail() { echo "FAIL $name: $*" >&2; exit 1; }
case $xa in rv64) qe=qemu-riscv64 t=1800 ;; arm) qe=qemu-arm t=5400 ;; *) fail "no qemu for $xa" ;; esac   # arm's corpus runs about an hour
command -v $qe >/dev/null || gate_skip "$name: skipped (no $qe)"

r=$ho/${xa}love
mkdir -p "$r"
ulimit -c 0
cat "$@" > "$r/corpus.l"
q="timeout $t $qe"

LOVE_NO_IMAGE=1 $q "$xl" "$r/corpus.l" > "$r/egg.out" 2>&1 || fail "the egg's corpus (exit $?)"
tail -1 "$r/egg.out"
LOVE_NO_IMAGE=1 $q "$xl" bake -o "$r/love.b" -l "$cat" > "$r/bake.out" 2>&1 || { tail -5 "$r/bake.out" >&2; fail "the bake"; }
$q "$r/love.b" "$r/corpus.l" > "$r/wake.out" 2>&1 || fail "the wake's corpus (exit $?)"
tail -1 "$r/wake.out"
[ "$($q "$r/love.b" echo hi)" = hi ] || fail "a verb on the wake"
$q "$r/love.b" test/glaze-hook.l 2>&1 | grep -q "glaze-hook: ok" || fail "glaze-hook"
LOVE_BUDGET_MB=64 $q "$r/love.b" test/glaze-tail.l 2>&1 | grep -q "glaze-tail: ok" || fail "glaze-tail"

LOVE_NO_IMAGE=1 LOVE_BUDGET_MB=400 $q "$xl" test/gate/glazefuzz.l > "$r/on" 2>/dev/null || fail "the glazed fuzz died"
LOVE_NO_IMAGE=1 LOVE_NO_GLAZE=1 LOVE_BUDGET_MB=400 $q "$xl" test/gate/glazefuzz.l > "$r/off" 2>/dev/null || fail "the interpreted fuzz died"
[ "$(sed -n 's/^fires=//p' "$r/on")" -gt 0 ] || fail "the fuzz native-backed nothing"
sed '$d' "$r/on" > "$r/on.b"; sed '$d' "$r/off" > "$r/off.b"
cmp -s "$r/on.b" "$r/off.b" || fail "the glaze disagrees with the interpreter"
echo "$name: the $xa love under $qe -- corpus, bake, wake, hook, fuzz"
