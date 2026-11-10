#!/bin/sh
# test/gate/esp32board.sh -- holo's xtensa law on the esp32's silicon: test/holo/xtrun.l laid for
# the board, loaded into iram by src/tools/esprom.l on a host with the esp32-uart cap, and read
# off uart0. ram only, the flash never written; the board is reset into its own app after.
# the host's facts give the tty (BEE_TTY) and the love that runs esprom there (BEE_LOVE).
# usage: esp32board.sh LOVE OUTDIR
. test/gate/skip.sh
set -u

t=test_esp32_board love=$1 d=$2/esp32board
fail() { echo "FAIL $t: $*" >&2; exit 1; }
"$love" bee --on esp32-uart --probe >/dev/null 2>&1 || gate_skip "$t: skipped (no host with esp32-uart answers)"

rm -rf "$d"; mkdir -p "$d/ship"
cat src/love/holo/holo.l src/love/holo/xtensa.l test/holo/xtrun.l \
  | XT_BOARD=esp32 XT_OUT="$d/ship/law.elf" "$love" > "$d/law.log" 2>&1 || { cat "$d/law.log"; fail "love could not lay xtrun.l"; }
cp src/tools/esprom.l "$d/ship/"
cat > "$d/ship/run.sh" <<'EOF'
[ -n "${BEE_TTY:-}" ] || { echo "the host names no tty"; exit 1; }
l=${BEE_LOVE:-love}
command -v "$l" >/dev/null 2>&1 || { echo "no love at $l"; exit 1; }
"$l" esprom.l -p "$BEE_TTY" run law.elf 4; r=$?
"$l" esprom.l -p "$BEE_TTY" reset >/dev/null 2>&1
exit $r
EOF

out=$("$love" bee --on esp32-uart --ship "$d/ship" -- sh run.sh 2>&1)
rc=$?
case "$out" in
  *"xtensa: all "*" checks held"*) ;;
  *) echo "$out"; fail "no held law off the board (rc $rc)" ;;
esac
echo "$t: $(echo "$out" | tr -d '\r' | sed -n 's/^xtensa: //p'), from iram on the esp32"
