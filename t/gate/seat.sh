#!/bin/sh
# t/gate/seat.sh -- the SEAT lane, which nothing else reaches.
#
# An app fires three ways: the verb rail (`love mooncc ..`), argv[0] (a symlink), and the
# one here -- the file IS the program, `love a/libra/libra.l foo.l`, or its `-l` preload.
# The other two are gated all over (test_kore, test_moon, test_dist); this one was gated
# NOWHERE, and that is how nine apps' seats went dead under a green test_slow: every gate
# reached its app through the rail or a baked image, so a file seat that answered ()
# looked exactly like an app with nothing to say.
#
# usage: sh t/gate/seat.sh LOVE
set -u
love=${1:-b/love}
d=b/.seat && mkdir -p $d
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

want='unclosed ('   ; try "libra (positional)"   a/libra/libra.l $bad
want='unclosed ('   ; try "libra (-l preload)"   -l a/libra/libra.l $bad
want='usage'        ; try "ain"                  a/ain.l
# a PATH neither can use, not a flag: both refuse an unknown option now, and this
# lane is about the seat firing at all -- so the word has to reach the app's own walk
want='not a directory'; try "kiosko"             a/kiosko/kiosko.l /nope
want='no markdown'  ; try "papel"                a/papel.l /nope

# and the same seat UNDER A PRIME: `wake IMAGE` is the command line's word, not the
# program's, so l/boot/post.l's `unprime` steps it and the app still seats itself.
# the cat is not optional: a bare `bake` snapshots a fresh egg, which registers the
# core modules and no crew, and libra reads lint and salt. -l CAT is how the shipped
# image is baked too (the Makefile lays b/love from b/love.raw), so this wakes the shape love ships.
img=$d/seat.image
if "$love" bake -l b/.dist-cat.l "$img" >/dev/null 2>&1; then
  want='unclosed ('; try "libra (under a wake)" wake "$img" a/libra/libra.l $bad
else
  echo "FAIL seat: could not bake an image to test the prime lane"; fails=$((fails+1))
fi

[ $fails -eq 0 ] || { echo "FAIL seat ($fails)"; exit 1; }
echo "seat: the file lane fires -- positional, -l preload, and under a prime ok"
