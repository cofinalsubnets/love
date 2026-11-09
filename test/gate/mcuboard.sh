#!/bin/sh
# test/gate/mcuboard.sh -- a port's battery on silicon: a host bee knows with the board's cap (doc/bee.md,
# HOSTS) holds the board on a debug probe and its console on a serial port. it flashes the image over
# swd, resets, and reads the battery off the console; green is the battery's own `; all ../.. green`,
# which it prints only when every check passed. a teensy41-usb host instead holds a teensy 4.1 on usb:
# the running image reboots to its loader at 134 baud, teensy_loader_cli flashes the .hex, and green is
# love's shell answering on the usb console the host's tty fact names. without such a host the gate
# skips loudly.
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
  teensy41-usb) ;;
  *) echo "FAIL $t: no board known for $cap" >&2; exit 1 ;;
esac
"$ho/love" bee --on "$cap" --probe >/dev/null 2>&1 || gate_skip "$t: skipped (no host with $cap answers)"
[ -f "$img" ] || { echo "FAIL $t: no $img" >&2; exit 1; }

sd=$ho/board-$cap
rm -rf "$sd"; mkdir -p "$sd"
if [ "$cap" = teensy41-usb ]; then
  cp "$img" "$sd/firm.hex"
  green='*40002*'
  # the console is the host's tty fact, BEE_TTY under bee --on
  cat > "$sd/run.sh" <<'EOF'
tty=${BEE_TTY:-}
[ -n "$tty" ] || { echo "the host gives no tty fact"; exit 1; }
command -v teensy_loader_cli >/dev/null || { echo "no teensy_loader_cli on the host"; exit 1; }
stty -F "$tty" 134 2>/dev/null || true
timeout 90 teensy_loader_cli --mcu=TEENSY41 -w -v firm.hex > flash.log 2>&1 \
  || { tail -5 flash.log; echo "the flash failed (an image that is not ours, or hung, wants the button)"; exit 1; }
n=0
until [ -e "$tty" ]; do n=$((n + 1)); [ $n -gt 60 ] && { echo "the usb console never came up"; exit 1; }; sleep 1; done
sleep 3
stty -F "$tty" 115200 cs8 -cstopb -parenb raw -echo -crtscts clocal || exit 1
exec 3<>"$tty"
timeout 10 cat <&3 > got.1 &
sleep 1
printf '(+ 40000 2)\r' >&3
wait
tr -d '\r' < got.1
EOF
else
cp "$img" "$sd/firm.bin"
green='*"; all "*" green"*'
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
fi

out=$("$ho/love" bee --on "$cap" --ship "$sd" -- sh run.sh 2>&1)
rc=$?
rm -rf "$sd"
case "$out" in
  $green) ;;
  *) echo "$out"; echo "FAIL $t: no green off the board (rc $rc)" >&2; exit 1 ;;
esac
if [ "$cap" = teensy41-usb ]; then
  echo "$t: the .hex flashed through the loader, love's shell on the usb console answered (+ 40000 2)"
else
  echo "$out" | while read -r l; do case "$l" in "; mooncc"*|"; core"*|"; all"*) echo "$l" ;; esac; done
  echo "$t: the image flashed over swd, the battery green on the board's console"
fi
