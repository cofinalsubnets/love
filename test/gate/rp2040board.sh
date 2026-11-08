#!/bin/sh
# test/gate/rp2040board.sh -- the pico's battery on silicon: a host bee knows with the cap rp2040-swd
# (doc/bee.md, HOSTS) holds an rp2040 on a cmsis-dap probe's swd and its uart0 on a serial port. it
# flashes love.bin, resets, and reads the battery off whichever port prints it; green is the
# battery's own `; all ../32 green`, which it prints only when every check passed. without such a
# host the gate skips loudly.
# usage: rp2040board.sh OUTDIR BINDIR
. test/gate/skip.sh
set -u

ho=$1 bin=$2
t=test_rp2040_board
"$ho/love" bee --on rp2040-swd --probe >/dev/null 2>&1 || gate_skip "$t: skipped (no host with rp2040-swd answers)"
[ -f "$bin/love.bin" ] || { echo "FAIL $t: no $bin/love.bin" >&2; exit 1; }

sd=$bin/board
rm -rf "$sd"; mkdir -p "$sd"; cp "$bin/love.bin" "$sd/"
# on the host: 1 MHz, as jumper wires to the swd pads hold; the battery prints in about 2 s
cat > "$sd/run.sh" <<'EOF'
ocd() { openocd -f interface/cmsis-dap.cfg -c "adapter speed 1000" -f target/rp2040.cfg "$@"; }
ocd -c "program love.bin 0x10000000 verify exit" > flash.log 2>&1 || { tail -5 flash.log; echo "the flash failed"; exit 1; }
for p in /dev/ttyS* /dev/ttyAMA* /dev/ttyUSB*; do
  [ -r "$p" ] || continue
  [ "$(cat /sys/class/tty/${p##*/}/type 2>/dev/null)" = 0 ] && continue
  stty -F "$p" 115200 cs8 -cstopb -parenb raw -echo -crtscts clocal 2>/dev/null || continue
  timeout 12 cat "$p" > "got.${p##*/}" &
done
sleep 1
ocd -c "init; reset run; exit" > reset.log 2>&1 || { tail -5 reset.log; echo "the reset failed"; exit 1; }
wait
cat got.* 2>/dev/null | tr -d '\r'
EOF

out=$("$ho/love" bee --on rp2040-swd --ship "$sd" -- sh run.sh 2>&1)
rc=$?
rm -rf "$sd"
case "$out" in
  *"; all "*" green"*) ;;
  *) echo "$out"; echo "FAIL $t: no green battery off the board (rc $rc)" >&2; exit 1 ;;
esac
echo "$out" | while read -r l; do case "$l" in "; mooncc"*|"; all"*) echo "$l" ;; esac; done
echo "$t: love.bin flashed over swd, the battery green on the rp2040's uart"
