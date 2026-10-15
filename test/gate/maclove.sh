#!/bin/sh
# test/gate/maclove.sh -- love itself on macos: love's objects linked as a mach-o here
# (love-macos.raw), baked ON the box -- an image is its own binary's, so the bake runs where
# the binary does -- and then asked to wake, name its kernel, run the shell, and compile C
# natively, which on macos lays a mach-o. the box is a host bee knows with the cap macos-x64
# (doc/bee.md, HOSTS), or MAC_SSH; without one the gate skips loudly.
# usage: maclove.sh OUTDIR
. test/gate/skip.sh
set -u

ho=$1
t=test_macos_love
box=${MAC_SSH:-}
[ -n "$box" ] || box=$("$ho/love" bee --on macos-x64 --ssh 2>/dev/null) || box=
[ -n "$box" ] || gate_skip "$t: skipped (no box in the env)"

fail() { echo "FAIL $t: $*" >&2; exit 1; }
rd=/tmp/maclove

$box "rm -rf $rd && mkdir -p $rd && cat > $rd/love.raw && chmod +x $rd/love.raw" < "$ho/love-macos.raw" \
  || fail "the box could not take love-macos.raw"
$box "cat > $rd/dist-cat.l" < "$ho/.dist-cat.l" || fail "the box could not take the cat"
$box "cat > $rd/hot.prof" < src/tools/hot.prof || fail "the box could not take hot.prof"
$box "cd $rd && env LOVE_NO_IMAGE=1 LOVE_BAKE_HOT=$rd/hot.prof ./love.raw bake -o love -l dist-cat.l" \
  || fail "the bake on the box"

out=$($box "cd $rd && ./love -e '(+ 1 2)' && ./love -e '(show love-os)' && ./love kore uname -s \
  && ./love lush -c 'for i in 1 2 3; do echo \$i; done | ./love kore wc -l' \
  && printf '#include <stdio.h>\nint main(void) { puts(\"native\"); return 7; }\n' > h.c \
  && ./love cc h.c -o h && { ./h; echo \"rc=\$?\"; }; od -An -tx1 -N4 h | tr -d \" \"") \
  || fail "the baked love on the box -- got: $out"
$box "rm -rf $rd"
want='3
"macos"
Darwin
3
native
rc=7
cffaedfe'
[ "$out" = "$want" ] || fail "the baked love answered -- got: [$out]"
echo "$t: love woke on macos, named its kernel, ran lush, and compiled a mach-o"
