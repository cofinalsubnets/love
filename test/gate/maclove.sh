#!/bin/sh
# test/gate/maclove.sh -- love itself on macos: love's objects linked as a mach-o here
# (love-macos.raw), baked ON the box -- an image is its own binary's, so the bake runs where
# the binary does -- and then asked to wake, name its kernel, run the shell, and compile C
# natively, which on macos lays a mach-o, and against a framework, which lays dyld's; then two
# seconds of tone through the horn, love's own AudioQueue, which must take them at the rate it
# plays. the box is a host bee knows with the cap macos-x64
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

out=$($box "cd $rd && ./love -e '(+ 1 2)' && ./love -e '(show love-os)' && ./love uname -s \
  && ./love lush -c 'for i in 1 2 3; do echo \$i; done | ./love wc -l' \
  && printf '#include <stdio.h>\nint main(void) { puts(\"native\"); return 7; }\n' > h.c \
  && ./love cc h.c -o h && { ./h; echo \"rc=\$?\"; }; od -An -tx1 -N4 h | tr -d \" \" | head -1 \
  && printf 'double CFAbsoluteTimeGetCurrent(void);\nint main(void) { return CFAbsoluteTimeGetCurrent() > 7e8 ? 9 : 1; }\n' > cf.c \
  && ./love cc -framework CoreFoundation cf.c -o cf && { ./cf; echo \"cf=\$?\"; }") \
  || fail "the baked love on the box -- got: $out"
cat > "$ho/maclove-tone.l" <<'EOF'
(: (s16 v) (: u (v < 0 ? (v + 65536) v) (string [(u & 255) (u >> 8)]))
   per (join "" (map (k \ (: v (int (6000.0 * sin (6.283185307179586 * k / 100.0))) (s16 v + s16 v))) ^100))
   h (horn 48000 2)
   (go n) (n = 0 ? () (: _ (say h per) (go (n - 1))))
   (? (nom? h) (puts ("no horn " + show h + "\n"))
      (: t0 (clock 0) _ (go 960) _ (flush h) (puts (show (clock t0) + "\n")))))
EOF
$box "cat > $rd/tone.l" < "$ho/maclove-tone.l" || fail "the box could not take the tone"
# eio is AudioQueueStart refused: the queue was made, so the door reached AudioToolbox, but
# coreaudio plays only for the user holding the console, and the box's may be another's
hout=$($box "cd $rd && env -u HORN ./love tone.l") || fail "the horn on the box -- got: $hout"
case "$hout" in
  "no horn eio") horn="the horn reached AudioToolbox, the speakers another user's" ;;
  *[!0-9]*|'') fail "the horn's tone -- got: $hout" ;;
  *) [ "$hout" -ge 1000 ] || fail "two seconds of tone went in ${hout} ms: nothing played them"
     horn="played its horn through AudioToolbox" ;;
esac
$box "rm -rf $rd"
want='3
"macos"
Darwin
3
native
rc=7
cffaedfe
cf=9'
[ "$out" = "$want" ] || fail "the baked love answered -- got: [$out]"
echo "$t: love woke on macos, named its kernel, ran lush, compiled a mach-o and dyld's; $horn"
