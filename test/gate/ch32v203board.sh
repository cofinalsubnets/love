#!/bin/sh
# test/gate/ch32v203board.sh -- test/boards/ch32v203's blink written into the qt py's flash by
# src/tools/wchisp.l on a host with the ch32v203-isp cap: erase, write, verify through the mask
# rom's usb isp, then the chip booted into it. the rom shows only with BOOT held over a reset,
# so the run waits for it; the rom has no flash read, so what was there is gone.
# usage: ch32v203board.sh LOVE IMAGE OUTDIR
. test/gate/skip.sh
set -u

t=test_ch32v203_board love=$1 img=$2 d=$3/ch32v203board
fail() { echo "FAIL $t: $*" >&2; exit 1; }
"$love" bee --on ch32v203-isp --probe >/dev/null 2>&1 || gate_skip "$t: skipped (no host with ch32v203-isp answers)"
[ -f "$img" ] || fail "no $img"

rm -rf "$d"; mkdir -p "$d/ship"
cp "$love" "$d/ship/love"
cp "$img" "$d/ship/firm.bin"
cp src/tools/wchisp.l "$d/ship/"
cat > "$d/ship/run.sh" <<'RUN'
n=0
until ./love wchisp.l info >/dev/null 2>&1; do
  [ $n = 0 ] && echo "hold BOOT over a reset: waiting 90 s for the bootloader"
  n=$((n + 1)); [ $n -gt 90 ] && { echo "no bootloader"; exit 1; }
  sleep 1
done
./love wchisp.l flash firm.bin
RUN

out=$("$love" bee --on ch32v203-isp --ship "$d/ship" -- sh run.sh 2>&1)
rc=$?
rm -rf "$d"
case "$out" in
  *"wrote and verified"*) ;;
  *) echo "$out"; fail "not written (rc $rc)" ;;
esac
echo "$out" | tr -d '\r' | while read -r l; do case "$l" in "chip type"*|"erased"*|"wrote"*) echo "$l" ;; esac; done
echo "$t: the blink written and verified through the usb isp, the chip booted into it"
