#!/bin/sh
# test/gate/playdate.sh -- the Playdate build gate.
#
# The device half is ours end to end: mooncc -t thumb2sp compiles every object,
# pdglue.c (the one file that includes pd_api.h) included, and ldbare32 binds them
# -- no arm-none-eabi-gcc, no ld, no linker script. The SDK is wanted for its C_API
# headers and for pdc, which bundles the .pdx.
#
# The probe runs FIRST and never skips: main.c reaches the SDK through pdglue's
# word-only seam, so mooncc compiles the device main anywhere. Without it the whole
# lane exits 0 on a machine with no SDK -- which is how main.c once spent three days
# as invalid C.
#
# What the built pdex.elf is then held to:
#   - no undefined symbol (a bare image resolves or it is not one)
#   - eventHandlerShim exported, and e_entry carrying the thumb bit
#   - ZERO movw/movt relocations: the loader slides ABS32 WORDS, and a split-immediate
#     pair is an absolute no base-adding loader can touch
#   - and the table is exactly the words that move -- the same objects linked at a
#     second base, diffed word for word (test/gate/pdreloc.l)
#
# usage: playdate.sh MAKE LOVE
set -u

mk=$1
lv=$2
fail() { echo "FAIL playdate: $*" >&2; exit 1; }

echo "TEST out/playdate/main.o (the device main, no SDK)"
$mk -C i/playdate probe || fail "the device main does not compile"

echo "TEST out/playdate/love.pdx"
if [ -z "${PLAYDATE_SDK_PATH:-}" ]; then
  echo "test_playdate: the device main compiles; no PLAYDATE_SDK_PATH, the pdx half skipped"
  exit 0
fi

$mk -C i/playdate || fail "build"
$mk -C i/playdate alt || fail "the second-base link"

e=out/playdate/pdex.elf
u=$(llvm-readelf -s $e | grep -c "UND [a-zA-Z_]")
[ "$u" -eq 0 ] || fail "pdex.elf has $u undefined symbols"
llvm-readelf -s $e | grep -qw eventHandlerShim || fail "no eventHandlerShim"
m=$(llvm-readelf -r $e | grep -c "MOVW\|MOVT")
[ "$m" -eq 0 ] || fail "$m movw/movt relocs (the loader cannot slide them)"
# e_entry is odd or the core enters ARM state, which an M-profile part does not have
ent=$(llvm-readelf -h $e | sed -n 's/.*Entry point address: *//p')
case $ent in *[13579bdf]) ;; *) fail "entry $ent has no thumb bit" ;; esac

# uread is kore's, so the reader rides in ahead of the check -- the same lay
# test/gate/ld32.l takes to read an object back through our own linker's front half
{ cat apps/kore/text.l apps/kore/u.l
  echo "(borrow 'kore)"
  cat test/gate/pdreloc.l
  echo '(pdbin-check "out/playdate/love.pdx/pdex.bin"'
  echo '  (pdreloc-check "out/playdate/pdex.elf" "out/playdate/pdex-alt.elf" 1048576))'
} | "$lv" || fail "the relocation table is not exactly the words that move, or pdc dropped some"

echo "test_playdate: love.pdx -- every device object and the LINK are mooncc's, no foreign tool; resolved, thumb entry, ABS32 words only, and the table proven against a second base"
