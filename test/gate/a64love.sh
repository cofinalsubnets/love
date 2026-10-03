#!/bin/sh
# test/gate/a64love.sh -- the whole a64 artifact, cross-built here, on a64 hardware: the
# corpus over the egg, then the binary bakes its own image there and the corpus runs again
# on the wake. a 16K-page host is asked for first, since a page size this box never has
# is where a hosted love goes wrong in ways no x64 lane can see; any a64 host next, and
# qemu-user last. coverage beside the x64 lanes, never a stand-in for one.
#
# usage: a64love.sh OUTDIR LOVE XLOVE CAT CORPUS.l ..
. test/gate/skip.sh
. test/gate/a64run.sh
set -u

ho=$1
m=$2
xl=$3
cat=$4
shift 4
name=test_love_a64
fail() { echo "FAIL $name: $*" >&2; exit 1; }

a64_where=page=16384
a64_how "$m"
[ -n "$a64_via" ] || gate_skip "$name: skipped (no a64 host and no qemu-aarch64)"

r=$ho/a64love
a64_jobs "$r"
cp "$xl" "$r/love"
cp "$cat" "$r/cat.l"
cat "$@" > "$r/corpus.l"
a64_tree "$(ls out/dist/love-*.tar.gz | head -1)"
# the egg, the bake, the wake: three jobs, one trip. a bake that fails leaves no love.b,
# and the wake's job answers 127 for it
a64_job egg  "cd tree && LOVE_NO_IMAGE=1 timeout 1200 \$RUN ../love ../corpus.l"
a64_job bake "LOVE_NO_IMAGE=1 timeout 1200 \$RUN ./love bake -o love.b -l cat.l"
a64_job wake "cd tree && timeout 1200 \$RUN ../love.b ../corpus.l"
a64_job verb "timeout 60 \$RUN ./love.b kore echo hi"

a64_run "$r" || fail "the a64 run did not come back"

for j in egg wake; do
  s=$(cat "$r/res/$j.rc")
  [ "$s" -ne 124 ] || fail "$j: timed out"
  tail -1 "$r/res/$j.out"
  [ "$s" -eq 0 ] && grep -q "tests pass" "$r/res/$j.out" || fail "$j: the corpus (exit $s)"
done
[ "$(cat "$r/res/bake.rc")" -eq 0 ] || { tail -5 "$r/res/bake.out" >&2; fail "the bake"; }
[ "$(cat "$r/res/verb.out")" = hi ] || fail "a verb on the wake answered: $(head -3 "$r/res/verb.out")"

how="under qemu-aarch64"
[ "$a64_via" = host ] && how="on an a64 host$([ -f "$r/res/page" ] && echo ", $(cat "$r/res/page")-byte pages")"
echo "$name: the a64 love $how -- the corpus over the egg, its own bake, the corpus on the wake"
