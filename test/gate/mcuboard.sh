#!/bin/sh
# test/gate/mcuboard.sh -- a port's battery on silicon: a host bee knows with the board's cap (doc/bee.md,
# HOSTS) holds the board on a debug probe and its console on a serial port. it flashes the image over
# swd, resets, and reads the battery off the console; green is the battery's own `; all ../.. green`,
# which it prints only when every check passed. without such a host the gate skips loudly.
# usage: mcuboard.sh OUTDIR LANE CAP IMAGE
. test/gate/skip.sh
set -u

ho=$1 t=$2 cap=$3 img=$4
# a board: its probe and chip for openocd, where its flash starts, and the ports its console may be on
case $cap in
  rp2040-swd)
    ocd='-f interface/cmsis-dap.cfg -c "adapter speed 1000" -f target/rp2040.cfg'   # 1 MHz holds over jumper wires
    at=0x10000000 con='/dev/serial/by-id/*Debug_Probe*-if01*' ;;   # the probe's own uart, on the pico's gp0/gp1
  nucleo446-swd)
    # its firmware may sleep or take the swd pins, so it is reached under reset
    ocd='-f interface/stlink.cfg -c "transport select hla_swd" -f target/stm32f4x.cfg -c "reset_config srst_only srst_nogate connect_assert_srst"'
    at=0x08000000 con='/dev/serial/by-id/*STLink*' ;;
  *) echo "FAIL $t: no board known for $cap" >&2; exit 1 ;;
esac
"$ho/love" bee --on "$cap" --probe >/dev/null 2>&1 || gate_skip "$t: skipped (no host with $cap answers)"
[ -f "$img" ] || { echo "FAIL $t: no $img" >&2; exit 1; }

sd=$ho/board-$cap
rm -rf "$sd"; mkdir -p "$sd"; cp "$img" "$sd/firm.bin"
echo "ocd() { openocd $ocd \"\$@\"; }" > "$sd/run.sh"
echo "at=$at con='$con'" >> "$sd/run.sh"
cat >> "$sd/run.sh" <<'EOF'
ocd -c "program firm.bin $at verify exit" > flash.log 2>&1 || { tail -5 flash.log; echo "the flash failed"; exit 1; }
n=0
for p in $con; do
  [ -r "$p" ] || continue
  q=$(readlink -f "$p")
  [ "$(cat /sys/class/tty/${q##*/}/type 2>/dev/null)" = 0 ] && continue
  stty -F "$p" 115200 cs8 -cstopb -parenb raw -echo -crtscts clocal 2>/dev/null || continue
  n=$((n + 1)); timeout 12 cat "$p" > "got.$n" &
done
sleep 1
ocd -c "init; reset run; exit" > reset.log 2>&1 || { tail -5 reset.log; echo "the reset failed"; exit 1; }
wait
cat got.* 2>/dev/null | tr -d '\r'
EOF

out=$("$ho/love" bee --on "$cap" --ship "$sd" -- sh run.sh 2>&1)
rc=$?
rm -rf "$sd"
case "$out" in
  *"; all "*" green"*) ;;
  *) echo "$out"; echo "FAIL $t: no green battery off the board (rc $rc)" >&2; exit 1 ;;
esac
echo "$out" | while read -r l; do case "$l" in "; mooncc"*|"; core"*|"; all"*) echo "$l" ;; esac; done
echo "$t: the image flashed over swd, the battery green on the board's console"
