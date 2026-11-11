#!/bin/sh
# test/gate/rv64love.sh -- the whole rv64 artifact under qemu-user: the corpus over the egg, its
# own bake, the corpus on the wake, the hook's laws, and the glaze against the interpreter.
#
# usage: rv64love.sh OUTDIR XLOVE CAT CORPUS.l ..
. test/gate/skip.sh
set -u

ho=$1
xl=$2
cat=$3
shift 3
name=test_love_rv64
fail() { echo "FAIL $name: $*" >&2; exit 1; }
command -v qemu-riscv64 >/dev/null || gate_skip "$name: skipped (no qemu-riscv64)"

r=$ho/rv64love
mkdir -p "$r"
ulimit -c 0
cat "$@" > "$r/corpus.l"
q="timeout 1800 qemu-riscv64"

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
echo "$name: the rv64 love under qemu-riscv64 -- corpus, bake, wake, hook, fuzz"
