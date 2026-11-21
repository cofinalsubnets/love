#!/bin/sh
# test/gate/mcuboard.sh -- a port's battery on silicon: a host bee knows with the board's cap (doc/bee.md,
# HOSTS) holds the board on a debug probe and its console on a serial port. it flashes the image over
# swd, resets, and reads the battery off the console; green is the battery's own `; all ../.. green`,
# which it prints only when every check passed. a teensy41-usb host instead holds a teensy 4.1 on usb:
# the running image reboots to its loader at 134 baud, src/tools/halfkay.l writes the .bin, and green is
# love's shell answering on the usb console the host's tty fact names. an rp2350-uf2 host holds a pico 2
# on usb, its usb fact the port's by-path name: 134 baud on the port's serial device reboots a running
# image into the rom, the uf2 goes raw onto the port's drive (the rom takes blocks at any sector; the
# drive's model is checked first), and the battery reports to whoever opens the console. without such
# a host the gate skips loudly.
# the cap names the board, so what follows from its chip is here: where flash starts, openocd's
# target, love's flasher. how the host reaches it is the host's facts: probe, `lovswd TTY` (the
# love swd probe, test/boards/rp2040/probe.c), `gpio CHIP SWCLK SWDIO NRST` (love's bit wire on the
# host's own gpio), `dap SERIAL` (a cmsis-dap's hid interface, found by its usb serial) or
# `openocd ARGS` (the interface's), console (its serial port, a glob), and love
# when the host runs a love not this one
# usage: mcuboard.sh OUTDIR LANE CAP IMAGE
. test/gate/skip.sh
set -u

ho=$1 t=$2 cap=$3 img=$4
case $cap in
  rp2040-swd) chip=rp2040 at=0x10000000 tgt='-f target/rp2040.cfg' ;;
  # its firmware may sleep or take the swd pins, so it is reached under reset
  nucleo446-swd) chip=stm32f4 at=0x08000000 tgt='-f target/stm32f4x.cfg -c "reset_config srst_only srst_nogate connect_assert_srst"' ;;
  microbit-swd) chip=nrf52 at=0x00000000 tgt='-f target/nrf52.cfg' ;;
  teensy41-usb) ;;
  rp2350-uf2) model=RP2350 ;;
  *) echo "FAIL $t: no board known for $cap" >&2; exit 1 ;;
esac
"$ho/love" bee --on "$cap" --probe >/dev/null 2>&1 || gate_skip "$t: skipped (no host with $cap answers)"
[ -f "$img" ] || { echo "FAIL $t: no $img" >&2; exit 1; }

sd=$ho/board-$cap
rm -rf "$sd"; mkdir -p "$sd"
if [ "$cap" = teensy41-usb ]; then
  cp "$img" "$sd/firm.bin"
  cp "$ho/love" src/apps/swd.l test/gate/swdpress.l src/tools/halfkay.l "$sd/"
  green='*40002*'
  # the console is the host's tty fact, BEE_TTY under bee --on; a button fact (a probe's line
  # on its program pin, `aux lovswd TTY`) presses it, so an image not ours or hung still loads
  cat > "$sd/run.sh" <<'EOF'
tty=${BEE_TTY:-} button=${BEE_BUTTON:-}
[ -n "$tty" ] || { echo "the host gives no tty fact"; exit 1; }
if [ -n "$button" ]; then
  ./love swdpress.l $button > press.log 2>&1 || { tail -3 press.log; echo "the button press failed"; exit 1; }
else
  stty -F "$tty" 134 2>/dev/null || true
fi
timeout 90 ./love halfkay.l write firm.bin > flash.log 2>&1 \
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
elif [ "$cap" = rp2350-uf2 ]; then
  cp "$img" "$sd/firm.uf2"
  green='*; all * green*'
  printf 'model=%s\n' "$model" > "$sd/run.sh"
  cat >> "$sd/run.sh" <<'EOF'
usb=${BEE_USB:-}
[ -n "$usb" ] || { echo "the host gives no usb fact"; exit 1; }
tty=/dev/serial/by-path/$usb drv=/dev/disk/by-path/$usb-scsi-0:0:0:0
upto() { n=0; until [ -e "$2" ]; do n=$((n + 1)); [ $n -gt $(($1 * 4)) ] && return 1; sleep 0.25; done; }
[ -e "$drv" ] || { [ -e "$tty" ] && stty -F "$tty" 134 2>/dev/null; }
upto 10 "$drv" || { echo "no boot drive on $usb (an image that is not ours, or hung, wants bootsel or swd)"; exit 1; }
dev=$(readlink -f "$drv")
m=$(cat /sys/class/block/${dev##*/}/device/model 2>/dev/null)
case "$m" in "$model"*) ;; *) echo "$dev is a ${m:-nameless} drive, not $model"; exit 1 ;; esac
[ -w "$dev" ] || { echo "no write access to $dev (the host's rule for the boot drive)"; exit 1; }
dd if=firm.uf2 of="$dev" bs=512 oflag=direct conv=fsync status=none || { echo "the write failed"; exit 1; }
upto 15 "$tty" || { echo "the console never came up on $usb"; exit 1; }
sleep 1
stty -F "$tty" raw -echo clocal || exit 1
timeout 5 cat "$tty" | tr -d '\r'
EOF
else
cp "$img" "$sd/firm.bin"
cp "$ho/love" src/apps/swd.l test/gate/swdflash.l "$sd/"
green='*; all * green*'
printf "chip=%s at=%s tgt='%s'\n" "$chip" "$at" "$tgt" > "$sd/run.sh"
cat >> "$sd/run.sh" <<'EOF'
probe=${BEE_PROBE:-} con=${BEE_CONSOLE:-} lv=${BEE_LOVE:-./love}
[ -n "$probe" ] || { echo "the host gives no probe fact"; exit 1; }
[ -n "$con" ] || { echo "the host gives no console fact"; exit 1; }
kind=${probe%% *} pa=${probe#"$kind"}
if [ "$kind" = dap ]; then
  hid=
  for h in /sys/class/hidraw/*; do [ "$(cat "$h/device/../../serial" 2>/dev/null)" = "${pa# }" ] && hid=/dev/${h##*/}; done
  [ -n "$hid" ] || { echo "no hid interface with serial${pa}"; exit 1; }
  probe="dap $hid"
fi
case $kind in
  lovswd|gpio|dap)
    flash() { "$lv" swdflash.l $chip $at firm.bin flash $probe; }
    reset() { "$lv" swdflash.l $chip $at firm.bin run $probe; } ;;
  openocd)
    ocd() { eval "openocd $pa $tgt -c \"\$1\""; }
    flash() { ocd "program firm.bin $at verify exit"; }
    reset() { ocd "init; reset run; exit"; } ;;
  *) echo "no probe known as $kind"; exit 1 ;;
esac
flash > flash.log 2>&1 || { tail -5 flash.log; echo "the flash failed"; exit 1; }
n=0 pids=
listen() {
  for p in $con; do
    [ -r "$p" ] || continue
    q=$(readlink -f "$p")
    [ "$(cat /sys/class/tty/${q##*/}/type 2>/dev/null)" = 0 ] && continue
    stty -F "$p" 115200 cs8 -cstopb -parenb raw -echo -crtscts clocal 2>/dev/null || continue
    n=$((n + 1)); timeout 12 cat "$p" > "got.$n" & pids="$pids $!"
  done
}
listen
sleep 1
reset > reset.log 2>&1 || { tail -5 reset.log; echo "the reset failed"; exit 1; }
# the battery's last line ends the read; 15 s at most, a moment more for the line to finish. a
# console on the board's own usb goes with the old image and comes back with the new one, so
# when every reader has ended the consoles are listened to again
k=0
until grep -Eqs '; (all .* green|FAILED)' got.* || [ $k -ge 150 ]; do
  live=; for q in $pids; do kill -0 $q 2>/dev/null && live="$live $q"; done; pids=$live
  [ -n "$pids" ] || listen
  sleep 0.1; k=$((k + 1))
done
sleep 0.3; kill $pids 2>/dev/null; wait
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
  echo "$t: the .bin written by halfkay.l, love's shell on the usb console answered (+ 40000 2)"
elif [ "$cap" = rp2350-uf2 ]; then
  echo "$out" | while read -r l; do case "$l" in "; mooncc"*|"; core"*|"; all"*) echo "$l" ;; esac; done
  echo "$t: the uf2 written through the rom's drive, the battery green on its usb console"
else
  echo "$out" | while read -r l; do case "$l" in "; mooncc"*|"; core"*|"; all"*) echo "$l" ;; esac; done
  echo "$t: the image flashed over swd, the battery green on the board's console"
fi
