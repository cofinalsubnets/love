#!/bin/sh
# test/gate/ch32v203board.sh -- test/boards/ch32v203's blink written into the qt py's flash by
# src/tools/wchisp.l on this box's usb: erase, write, verify through the mask rom's usb isp,
# then the chip booted into it. the rom shows only with BOOT held over a reset, so the run
# waits for it; the rom has no flash read, so what was there is gone.
# usage: ch32v203board.sh LOVE IMAGE OUTDIR
. test/gate/skip.sh
set -u

t=test_ch32v203_board love=$1 img=$2
fail() { echo "FAIL $t: $*" >&2; exit 1; }
[ -f "$img" ] || fail "no $img"

n=0
until "$love" src/tools/wchisp.l info >/dev/null 2>&1; do
  [ $n = 0 ] && echo "hold BOOT over a reset: waiting 90 s for the bootloader"
  n=$((n + 1)); [ $n -gt 90 ] && gate_skip "$t: skipped (no ch32v203 bootloader on this box's usb)"
  sleep 1
done

out=$("$love" src/tools/wchisp.l flash "$img" 2>&1)
rc=$?
case "$out" in
  *"wrote and verified"*) ;;
  *) echo "$out"; fail "not written (rc $rc)" ;;
esac
echo "$out" | while read -r l; do case "$l" in "chip type"*|"erased"*|"wrote"*) echo "$l" ;; esac; done
echo "$t: the blink written and verified through the usb isp, the chip booted into it"
