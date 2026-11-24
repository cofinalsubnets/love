#!/bin/sh
# test/gate/esp32board.sh -- the esp32 classic's lx6 on its silicon: holo's xtensa law, test/holo/xtrun.l
# laid for the board, then test/boards/esp32's battery, each loaded into ram by src/tools/esprom.l
# on a host with the esp32-uart cap and read off uart0 through the board's usb bridge. ram only,
# the flash never written; the board is reset into its own app after. the host's tty fact gives
# BEE_TTY; a love of the host's own machine goes along to run esprom.
# usage: esp32board.sh LOVE IMAGE OUTDIR
. test/gate/skip.sh
. test/gate/shiplove.sh
set -u

t=test_esp32_board love=$1 img=$2 d=$3/esp32board
fail() { echo "FAIL $t: $*" >&2; exit 1; }
"$love" bee --on esp32-uart --probe >/dev/null 2>&1 || gate_skip "$t: skipped (no host with esp32-uart answers)"
[ -f "$img" ] || fail "no $img"

rm -rf "$d"; mkdir -p "$d/ship"
cat src/love/holo/holo.l src/love/holo/xtensa.l test/holo/xtrun.l \
  | XT_BOARD=esp32 XT_OUT="$d/ship/law.elf" "$love" > "$d/law.log" 2>&1 || { cat "$d/law.log"; fail "love could not lay xtrun.l"; }
there=$(ship_love "$love" esp32-uart) || fail "no love to run on the host"
cp "$there" "$d/ship/love"
cp "$img" "$d/ship/firm.elf"
cp src/tools/esprom.l "$d/ship/"
cat > "$d/ship/run.sh" <<'EOF'
[ -n "${BEE_TTY:-}" ] || { echo "the host names no tty"; exit 1; }
./love esprom.l -p "$BEE_TTY" run law.elf 4; r=$?
[ $r = 0 ] && { ./love esprom.l -p "$BEE_TTY" run firm.elf 6; r=$?; }
./love esprom.l -p "$BEE_TTY" reset >/dev/null 2>&1
exit $r
EOF

out=$("$love" bee --on esp32-uart --ship "$d/ship" -- sh run.sh 2>&1)
rc=$?
rm -rf "$d"
case "$out" in
  *"xtensa: all "*" checks held"*"; all 28/28 green"*) ;;
  *) echo "$out"; fail "no held law and green battery off the board (rc $rc)" ;;
esac
echo "$out" | tr -d '\r' | while read -r l; do case "$l" in "; mooncc"*|"; lx"*|"; all"*) echo "$l" ;; esac; done
echo "$t: $(echo "$out" | tr -d '\r' | sed -n 's/^xtensa: //p'), the battery green, from iram on the esp32"
