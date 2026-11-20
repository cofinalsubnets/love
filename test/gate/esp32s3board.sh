#!/bin/sh
# test/gate/esp32s3board.sh -- holo's xtensa law on the esp32-s3's lx7: test/holo/xtrun.l laid for
# the s3, loaded into iram by src/tools/esprom.l on a host with the esp32s3-usb cap, and read off
# the chip's USB-Serial-JTAG. ram only, the flash never written; the chip is reset into its own
# app after. the host's facts give the rom's tty (BEE_TTY) and the app's (BEE_APP), whose 1200
# baud touch reboots into the rom; this love goes along to run esprom.
# usage: esp32s3board.sh LOVE OUTDIR
. test/gate/skip.sh
set -u

t=test_esp32s3_board love=$1 d=$2/esp32s3board
fail() { echo "FAIL $t: $*" >&2; exit 1; }
"$love" bee --on esp32s3-usb --probe >/dev/null 2>&1 || gate_skip "$t: skipped (no host with esp32s3-usb answers)"

rm -rf "$d"; mkdir -p "$d/ship"
cat src/love/holo/holo.l src/love/holo/xtensa.l test/holo/xtrun.l \
  | XT_BOARD=esp32s3 XT_OUT="$d/ship/law.elf" "$love" > "$d/law.log" 2>&1 || { cat "$d/law.log"; fail "love could not lay xtrun.l"; }
cp "$love" "$d/ship/love"
cp src/tools/esprom.l "$d/ship/"
cat > "$d/ship/run.sh" <<'EOF'
[ -n "${BEE_TTY:-}" ] || { echo "the host names no tty"; exit 1; }
esp() { if [ -n "${BEE_APP:-}" ]; then ./love esprom.l -p "$BEE_TTY" -t "$BEE_APP" "$@"; else ./love esprom.l -p "$BEE_TTY" "$@"; fi; }
esp run law.elf 4; r=$?
esp reset >/dev/null 2>&1
exit $r
EOF

out=$("$love" bee --on esp32s3-usb --ship "$d/ship" -- sh run.sh 2>&1)
rc=$?
rm -rf "$d"
case "$out" in
  *"xtensa: all "*" checks held"*) ;;
  *) echo "$out"; fail "no held law off the board (rc $rc)" ;;
esac
echo "$t: $(echo "$out" | tr -d '\r' | sed -n 's/^xtensa: //p'), from iram on the esp32-s3"
