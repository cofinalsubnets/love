#!/bin/sh
# test/gate/esp32c6board.sh -- the boards' battery on the esp32-c6's silicon: test/boards/esp32c6's
# image loaded into hp sram by src/tools/esprom.l on a host with the esp32c6-usb cap, and read off
# the chip's usb serial. ram only, the flash never written; the chip is reset into its own app after.
# the host's tty fact gives BEE_TTY; tau is x64, so this love goes along to run esprom.
# usage: esp32c6board.sh LOVE IMAGE OUTDIR
. test/gate/skip.sh
set -u

t=test_esp32c6_board love=$1 img=$2 d=$3/esp32c6board
fail() { echo "FAIL $t: $*" >&2; exit 1; }
"$love" bee --on esp32c6-usb --probe >/dev/null 2>&1 || gate_skip "$t: skipped (no host with esp32c6-usb answers)"
[ -f "$img" ] || fail "no $img"

rm -rf "$d"; mkdir -p "$d/ship"
cp "$love" "$d/ship/love"
cp "$img" "$d/ship/firm.elf"
cp src/tools/esprom.l "$d/ship/"
cat > "$d/ship/run.sh" <<'EOF'
[ -n "${BEE_TTY:-}" ] || { echo "the host names no tty"; exit 1; }
./love esprom.l -p "$BEE_TTY" run firm.elf 4; r=$?
./love esprom.l -p "$BEE_TTY" reset >/dev/null 2>&1
exit $r
EOF

out=$("$love" bee --on esp32c6-usb --ship "$d/ship" -- sh run.sh 2>&1)
rc=$?
rm -rf "$d"
case "$out" in
  *"; all 28/28 green"*) ;;
  *) echo "$out"; fail "no green off the board (rc $rc)" ;;
esac
echo "$out" | tr -d '\r' | while read -r l; do case "$l" in "; mooncc"*|"; rv32"*|"; all"*) echo "$l" ;; esac; done
echo "$t: the image ran from hp sram, the battery green on the chip's usb serial"
