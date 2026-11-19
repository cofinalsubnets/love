#!/bin/sh
# test/gate/x64codec.sh -- the x86-64 table both ways (test/holo/x64codec.l) over decode.sh's gcc
# objects: each instruction decoded by its row and laid again by x64-enc must decode the same.
# run after decode.sh.
# usage: x64codec.sh LOVE OUTDIR      (from the repo root; LOVE is a word list, not a path)
. test/gate/skip.sh
set -u
love=$1 ho=$2
d=$ho/.decode
[ -s $d/pairs ] || gate_skip "test/holo/x64codec: no decode objects, skipped"
{ cat src/love/holo/holo.l src/love/holo/x64.l src/love/holo/dialect.l src/love/holo/decode.l
  sed "s|@PAIRS@|$d/pairs|" test/holo/x64codec.l
} | $love
