#!/bin/sh
# test/gate/seat.sh -- the SEAT lane, which nothing else reaches.
#
# An app fires three ways: the verb rail (`love mooncc ..`), argv[0] (a symlink), and the
# one here -- the file IS the program, `love apps/libra/libra.l foo.l`, or its `-l` preload.
# The other two are gated all over (test_kore, test_moon, test_dist); this one was gated
# NOWHERE, and that is how nine apps' seats went dead under a green test_slow: every gate
# reached its app through the rail or a baked image, so a file seat that answered ()
# looked exactly like an app with nothing to say.
#
# usage: sh test/gate/seat.sh LOVE
set -u
love=${1:-out/love}
d=out/.seat && mkdir -p $d
fails=0
bad=$d/broken.l; printf '(: x (foo\n' > $bad

# app-file, args, and a word its output must carry when it FIRES.
try() {
  what=$1 out=$(shift; "$love" "$@" 2>&1)
  case $out in
    *"$want"*) ;;
    "") echo "FAIL seat: $what -- SILENT (the seat did not fire)"; fails=$((fails+1)) ;;
    *)  echo "FAIL seat: $what -- fired but said: $(echo "$out" | head -1)"; fails=$((fails+1)) ;;
  esac
}

want='unclosed ('   ; try "libra (positional)"   apps/libra/libra.l $bad
want='unclosed ('   ; try "libra (-l preload)"   -l apps/libra/libra.l $bad
want='usage'        ; try "ain"                  apps/ain.l
want='not a directory'; try "kiosko"             apps/kiosko/kiosko.l --nope
want='no markdown'  ; try "papel"                apps/papel.l --nope

# and the same seat UNDER A PRIME: `wake IMAGE` is the command line's word, not the
# program's, so core/boot/post.l's `unprime` steps it and the app still seats itself.
# the cat is not optional: a bare `bake` snapshots a fresh egg, which registers the
# core modules and no crew, and libra reads lint and salt. -l CAT is how the shipped
# image is baked too (Makefile's .love.baked), so this wakes the shape love ships.
img=$d/seat.image
if "$love" bake -l out/.dist-cat.l "$img" >/dev/null 2>&1; then
  want='unclosed ('; try "libra (under a wake)" wake "$img" apps/libra/libra.l $bad
else
  echo "FAIL seat: could not bake an image to test the prime lane"; fails=$((fails+1))
fi

[ $fails -eq 0 ] || { echo "FAIL seat ($fails)"; exit 1; }
echo "seat: the file lane fires -- positional, -l preload, and under a prime ok"
