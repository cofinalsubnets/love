#!/bin/sh
# test/gate/samba.sh -- an image into sram through a uf2 bootloader's sam-ba monitor on its usb
# serial port: binary mode, the bytes a kilobyte a write, read back whole, then go. run on the
# host that holds the board, with stty, head, tail, cmp and timeout
# usage: samba.sh TTY BASE IMAGE
# go loads sp from BASE and jumps to the word after it, and the monitor is gone. every read
# here is timed: a monitor left mid-write by a killed reader stays stuck till a power cycle
tty=$1 base=$2 img=$3
[ -r "$img" ] && [ -e "$tty" ] || { echo "samba: usage: samba.sh TTY BASE IMAGE"; exit 1; }
hx() { printf '%08X' "$1"; }
stty -F "$tty" raw -echo -ixon -ixoff cs8 clocal || exit 1
exec 3<>"$tty"
# whatever was left, and binary mode's answer if the monitor gives one
timeout 0.5 cat <&3 > /dev/null
printf 'N#' >&3
timeout 0.5 cat <&3 > /dev/null
n=$(wc -c < "$img") i=0
while [ $i -lt $n ]; do
  k=$((n - i)); [ $k -gt 1024 ] && k=1024
  printf 'S%s,%s#' "$(hx $((base + i)))" "$(hx $k)" >&3
  sleep 0.02
  tail -c +$((i + 1)) "$img" | head -c $k >&3
  sleep 0.02
  i=$((i + k))
done
printf 'R%s,%s#' "$(hx $base)" "$(hx $n)" >&3
timeout 10 head -c $n <&3 > back.bin
cmp -s back.bin "$img" || { echo "samba: read back $(wc -c < back.bin) of $n bytes, not the image"; exit 1; }
echo "samba: $n bytes at $(hx $base), read back; go"
printf 'G%s#' "$(hx $base)" >&3
