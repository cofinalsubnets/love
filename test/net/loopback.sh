#!/bin/sh
# test/net/loopback.sh -- the nc loopback gate (host-only, NOT in the portable
# corpus, so `make test` and the kernel/wasm builds stay socket-free). Drives the
# real binary: a server task and a client over TCP 127.0.0.1, full-duplex, and
# asserts each side received exactly what the other sent. This exercises every
# Stage-1 socket nif (connect/listen/accept/shutdown) plus the two .l pump loops
# and their teardown. both sides pass -N; the rounds after check that without it neither
# side half-closes, that -q quits anyway, that -w quits when idle,
# what -z and -v say, that -k serves client after client, a -u round trip, and what
# -o writes and -i spaces.
#
#   sh test/net/loopback.sh <love-binary> [port]
#
# Exits 0 + prints "nettest: PASS" on a clean round-trip; nonzero + a diff on any
# mismatch, error, or hang (bounded by a readiness deadline).
set -u

AI="${1:?usage: loopback.sh <love-binary> [port]}"
PORT="${2:-7390}"
AK="apps/nc.l"   # prel is baked into the egg -- no -l love/boot/prel.l preload

tmp="$(mktemp -d "${TMPDIR:-/tmp}/nc.XXXXXX")"
cli= feed=
trap 'kill "$srv" $cli $feed 2>/dev/null; rm -rf "$tmp"' EXIT

printf 'CLIENT-SAYS-HI\nsecond line from the client\n' > "$tmp/cli_in"
printf 'SERVER-SAYS-HELLO\nsecond line from the server\n' > "$tmp/srv_in"
# past one read's worth, so the pump moves several chunks
dd if=/dev/urandom bs=1024 count=300 2>/dev/null >> "$tmp/cli_in"

# server: listen on PORT, pump srv_in -> socket and socket -> srv_got.
"$AI" "$AK" -N -l "$PORT" < "$tmp/srv_in" > "$tmp/srv_got" 2> "$tmp/srv_err" &
srv=$!

# wait until PORT is actually listening, WITHOUT consuming the single accept
# (a connect-probe would eat it). Prefer ss/netstat; fall back to a short sleep.
ready() {
  if command -v ss >/dev/null 2>&1; then ss -ltn 2>/dev/null | grep -q "[:.]$PORT "
  elif command -v netstat >/dev/null 2>&1; then netstat -ltn 2>/dev/null | grep -q "[:.]$PORT "
  else sleep 1; fi
}
i=0
while ! ready; do
  i=$((i + 1))
  if [ "$i" -gt 200 ]; then echo "nettest: FAIL (server never listened on $PORT)"; cat "$tmp/srv_err"; exit 1; fi
  # also bail if the server died early
  kill -0 "$srv" 2>/dev/null || { echo "nettest: FAIL (server exited before listening)"; cat "$tmp/srv_err"; exit 1; }
  sleep 0.05 2>/dev/null || sleep 1
done

# client: connect, pump cli_in -> socket and socket -> cli_got.
"$AI" "$AK" -N 127.0.0.1 "$PORT" < "$tmp/cli_in" > "$tmp/cli_got" 2> "$tmp/cli_err"
crc=$?
wait "$srv"; src=$?

fail=0
[ "$crc" -eq 0 ] || { echo "nettest: FAIL (client exit $crc)"; cat "$tmp/cli_err"; fail=1; }
[ "$src" -eq 0 ] || { echo "nettest: FAIL (server exit $src)"; cat "$tmp/srv_err"; fail=1; }
# the server should have received the client's input; the client the server's.
if ! cmp -s "$tmp/cli_in" "$tmp/srv_got"; then
  echo "nettest: FAIL (server got != client sent)"; echo "--- expected ---"; cat "$tmp/cli_in"; echo "--- got ---"; cat "$tmp/srv_got"; fail=1
fi
if ! cmp -s "$tmp/srv_in" "$tmp/cli_got"; then
  echo "nettest: FAIL (client got != server sent)"; echo "--- expected ---"; cat "$tmp/srv_in"; echo "--- got ---"; cat "$tmp/cli_got"; fail=1
fi

# without -N neither side half-closes: the server has every byte yet no eof, so both are
# still up after their stdins are spent
PORT=$((PORT + 1))
"$AI" "$AK" -l "$PORT" < "$tmp/srv_in" > "$tmp/srv_got2" 2> "$tmp/srv_err" &
srv=$!
i=0
while ! ready; do
  i=$((i + 1))
  if [ "$i" -gt 200 ]; then echo "nettest: FAIL (server never listened on $PORT)"; cat "$tmp/srv_err"; exit 1; fi
  sleep 0.05 2>/dev/null || sleep 1
done
"$AI" "$AK" 127.0.0.1 "$PORT" < "$tmp/cli_in" > "$tmp/cli_got2" 2> "$tmp/cli_err" &
cli=$!
i=0
until cmp -s "$tmp/cli_in" "$tmp/srv_got2"; do
  i=$((i + 1))
  if [ "$i" -gt 200 ]; then echo "nettest: FAIL (no -N: server never got the client's bytes)"; fail=1; break; fi
  sleep 0.05 2>/dev/null || sleep 1
done
sleep 0.3 2>/dev/null || sleep 1
kill -0 "$srv" 2>/dev/null && kill -0 "$cli" 2>/dev/null || { echo "nettest: FAIL (no -N: a side half-closed)"; fail=1; }
kill "$cli" "$srv" 2>/dev/null

# -q 1: the same open peer, but the client quits a second after its stdin's end, and the
# server sees it go
PORT=$((PORT + 1))
"$AI" "$AK" -l "$PORT" < /dev/null > "$tmp/srv_got3" 2> "$tmp/srv_err" &
srv=$!
i=0
while ! ready; do
  i=$((i + 1))
  if [ "$i" -gt 200 ]; then echo "nettest: FAIL (server never listened on $PORT)"; cat "$tmp/srv_err"; exit 1; fi
  sleep 0.05 2>/dev/null || sleep 1
done
"$AI" "$AK" -q 1 127.0.0.1 "$PORT" < "$tmp/cli_in" > /dev/null 2> "$tmp/cli_err" &
cli=$!
i=0
until cmp -s "$tmp/cli_in" "$tmp/srv_got3"; do
  i=$((i + 1))
  if [ "$i" -gt 200 ]; then echo "nettest: FAIL (-q: server never got the client's bytes)"; fail=1; break; fi
  sleep 0.05 2>/dev/null || sleep 1
done
kill -0 "$cli" 2>/dev/null || { echo "nettest: FAIL (-q 1: the client did not wait)"; fail=1; }
i=0
while kill -0 "$cli" 2>/dev/null; do
  i=$((i + 1))
  if [ "$i" -gt 200 ]; then echo "nettest: FAIL (-q 1: the client never quit)"; kill "$cli" "$srv" 2>/dev/null; fail=1; break; fi
  sleep 0.05 2>/dev/null || sleep 1
done
wait "$cli"; crc=$?
[ "$crc" -eq 0 ] || { echo "nettest: FAIL (-q: client exit $crc)"; cat "$tmp/cli_err"; fail=1; }
wait "$srv"; src=$?
[ "$src" -eq 0 ] || { echo "nettest: FAIL (-q: server exit $src)"; cat "$tmp/srv_err"; fail=1; }

# -w 1: chunks 0.6 s apart keep the connection alive, then a second of nothing ends it
# though stdin is still open; the server sees the client go
PORT=$((PORT + 1))
"$AI" "$AK" -l "$PORT" < /dev/null > "$tmp/srv_got4" 2> "$tmp/srv_err" &
srv=$!
i=0
while ! ready; do
  i=$((i + 1))
  if [ "$i" -gt 200 ]; then echo "nettest: FAIL (server never listened on $PORT)"; cat "$tmp/srv_err"; exit 1; fi
  sleep 0.05 2>/dev/null || sleep 1
done
mkfifo "$tmp/feed"
{ echo a; sleep 0.6; echo b; sleep 0.6; echo c; sleep 5; } > "$tmp/feed" 2> /dev/null &
feed=$!
"$AI" "$AK" -w 1 127.0.0.1 "$PORT" < "$tmp/feed" > /dev/null 2> "$tmp/cli_err" &
cli=$!
i=0
while kill -0 "$srv" 2>/dev/null; do
  i=$((i + 1))
  if [ "$i" -gt 70 ]; then echo "nettest: FAIL (-w 1: the client never went idle)"; kill "$cli" "$srv" 2>/dev/null; fail=1; break; fi
  sleep 0.05 2>/dev/null || sleep 1
done
wait "$cli"; crc=$?
[ "$crc" -eq 0 ] || { echo "nettest: FAIL (-w: client exit $crc)"; cat "$tmp/cli_err"; fail=1; }
kill "$feed" 2>/dev/null
printf 'a\nb\nc\n' > "$tmp/abc"
cmp -s "$tmp/abc" "$tmp/srv_got4" || { echo "nettest: FAIL (-w: server got $(tr '\n' ' ' < "$tmp/srv_got4"))"; fail=1; }

# -zv over a listener and the closed port past it: one taken, one refused, exit 0; the
# listener -v names itself and its caller. -z on the closed one alone is quiet and 1
PORT=$((PORT + 2))
"$AI" "$AK" -lv "$PORT" < /dev/null > /dev/null 2> "$tmp/srv_err5" &
srv=$!
i=0
while ! ready; do
  i=$((i + 1))
  if [ "$i" -gt 200 ]; then echo "nettest: FAIL (server never listened on $PORT)"; cat "$tmp/srv_err5"; exit 1; fi
  sleep 0.05 2>/dev/null || sleep 1
done
"$AI" "$AK" -zv 127.0.0.1 "$PORT-$((PORT + 1))" > "$tmp/z_out" 2> "$tmp/z_err"; crc=$?
wait "$srv"; src=$?
[ "$crc" -eq 0 ] || { echo "nettest: FAIL (-zv: exit $crc)"; cat "$tmp/z_err"; fail=1; }
[ "$src" -eq 0 ] || { echo "nettest: FAIL (-lv: server exit $src)"; cat "$tmp/srv_err5"; fail=1; }
[ -s "$tmp/z_out" ] && { echo "nettest: FAIL (-z wrote to stdout)"; fail=1; }
grep -q "^Connection to 127.0.0.1 $PORT port \[tcp/\*\] succeeded!$" "$tmp/z_err" &&
  grep -q "^nc: connect to 127.0.0.1 port $((PORT + 1)) (tcp) failed: Connection refused$" "$tmp/z_err" ||
  { echo "nettest: FAIL (-zv said:)"; cat "$tmp/z_err"; fail=1; }
grep -q "^Listening on 0.0.0.0 $PORT$" "$tmp/srv_err5" &&
  grep -q "^Connection received on 127.0.0.1 [0-9]*$" "$tmp/srv_err5" ||
  { echo "nettest: FAIL (-lv said:)"; cat "$tmp/srv_err5"; fail=1; }
"$AI" "$AK" -z 127.0.0.1 "$((PORT + 1))" > "$tmp/z_out" 2> "$tmp/z_err"; crc=$?
[ "$crc" -eq 1 ] && ! [ -s "$tmp/z_err" ] || { echo "nettest: FAIL (-z on a closed port: exit $crc)"; cat "$tmp/z_err"; fail=1; }

# -k -s -p: one listener on 127.0.0.1 serves two clients in turn and is still up after
PORT=$((PORT + 2))
"$AI" "$AK" -klv -s 127.0.0.1 -p "$PORT" < /dev/null > "$tmp/srv_got6" 2> "$tmp/srv_err6" &
srv=$!
i=0
while ! ready; do
  i=$((i + 1))
  if [ "$i" -gt 200 ]; then echo "nettest: FAIL (server never listened on $PORT)"; cat "$tmp/srv_err6"; exit 1; fi
  sleep 0.05 2>/dev/null || sleep 1
done
echo one | "$AI" "$AK" -N 127.0.0.1 "$PORT" > /dev/null 2> "$tmp/cli_err" || { echo "nettest: FAIL (-k: first client)"; cat "$tmp/cli_err"; fail=1; }
echo two | "$AI" "$AK" -N 127.0.0.1 "$PORT" > /dev/null 2> "$tmp/cli_err" || { echo "nettest: FAIL (-k: second client)"; cat "$tmp/cli_err"; fail=1; }
sleep 0.2 2>/dev/null || sleep 1
kill -0 "$srv" 2>/dev/null || { echo "nettest: FAIL (-k: the listener left)"; fail=1; }
kill "$srv" 2>/dev/null
printf 'one\ntwo\n' > "$tmp/k_want"
cmp -s "$tmp/k_want" "$tmp/srv_got6" || { echo "nettest: FAIL (-k: server got $(tr '\n' ' ' < "$tmp/srv_got6"))"; fail=1; }
grep -q "^Listening on 127.0.0.1 $PORT$" "$tmp/srv_err6" && [ "$(grep -c '^Connection received on ' "$tmp/srv_err6")" -eq 2 ] ||
  { echo "nettest: FAIL (-klv said:)"; cat "$tmp/srv_err6"; fail=1; }

# -u: the first sender is the listener's peer and gets its reply; a stranger's datagram
# in between is dropped; with no eof in udp, -w 1 ends both
PORT=$((PORT + 1))
{ sleep 0.6; echo pong; sleep 3; } 2> /dev/null | "$AI" "$AK" -ul -w 1 "$PORT" > "$tmp/srv_got7" 2> "$tmp/srv_err" &
srv=$!
i=0
until { command -v ss > /dev/null && ss -lun 2>/dev/null | grep -q "[:.]$PORT "; } || [ "$i" -gt 20 ]; do
  i=$((i + 1)); sleep 0.05 2>/dev/null || sleep 1
done
{ echo ping; sleep 3; } 2> /dev/null | "$AI" "$AK" -u -w 1 127.0.0.1 "$PORT" > "$tmp/cli_got7" 2> "$tmp/cli_err" &
cli=$!
sleep 0.3 2>/dev/null || sleep 1
echo stranger | "$AI" "$AK" -u -w 1 127.0.0.1 "$PORT" > /dev/null 2>&1
wait "$cli"; crc=$?
wait "$srv"; src=$?
[ "$crc" -eq 0 ] && [ "$src" -eq 0 ] || { echo "nettest: FAIL (-u: client exit $crc, server exit $src)"; cat "$tmp/cli_err" "$tmp/srv_err"; fail=1; }
[ "$(cat "$tmp/srv_got7")" = ping ] || { echo "nettest: FAIL (-u: server got $(tr '\n' ' ' < "$tmp/srv_got7"))"; fail=1; }
[ "$(cat "$tmp/cli_got7")" = pong ] || { echo "nettest: FAIL (-u: client got $(tr '\n' ' ' < "$tmp/cli_got7"))"; fail=1; }

# -o writes both directions as hex lines; -i 0.3 spaces three lines at least 0.9 s apart.
# the clock is love's own, in ms, so no date(1) dialect is wanted
printf '(say out (show (clock 0)))\n' > "$tmp/clock.l"
ms() { "$AI" "$tmp/clock.l"; }
PORT=$((PORT + 1))
printf 'hi there\n' | "$AI" "$AK" -N -l "$PORT" > /dev/null 2> "$tmp/srv_err" &
srv=$!
i=0
while ! ready; do
  i=$((i + 1))
  if [ "$i" -gt 200 ]; then echo "nettest: FAIL (server never listened on $PORT)"; cat "$tmp/srv_err"; exit 1; fi
  sleep 0.05 2>/dev/null || sleep 1
done
printf 'GET / HTTP/1.0\r\nHost: x\r\n\r\n' | "$AI" "$AK" -N -o "$tmp/dump" 127.0.0.1 "$PORT" > /dev/null 2> "$tmp/cli_err"
wait "$srv"
cat > "$tmp/dump_want" <<'DUMP'
> 00000000 47 45 54 20 2f 20 48 54 54 50 2f 31 2e 30 0d 0a # GET / HTTP/1.0..
> 00000010 48 6f 73 74 3a 20 78 0d 0a 0d 0a                # Host: x....
< 00000000 68 69 20 74 68 65 72 65 0a                      # hi there.
DUMP
cmp -s "$tmp/dump_want" "$tmp/dump" || { echo "nettest: FAIL (-o wrote:)"; cat "$tmp/dump"; fail=1; }
PORT=$((PORT + 1))
"$AI" "$AK" -N -l "$PORT" < /dev/null > "$tmp/srv_got8" 2> "$tmp/srv_err" &
srv=$!
i=0
while ! ready; do
  i=$((i + 1))
  if [ "$i" -gt 200 ]; then echo "nettest: FAIL (server never listened on $PORT)"; cat "$tmp/srv_err"; exit 1; fi
  sleep 0.05 2>/dev/null || sleep 1
done
t0=$(ms)
printf 'a\nb\nc\n' | "$AI" "$AK" -N -i 0.3 127.0.0.1 "$PORT" > /dev/null 2> "$tmp/cli_err"
t1=$(ms)
wait "$srv"
[ "$(tr '\n' ' ' < "$tmp/srv_got8")" = "a b c " ] || { echo "nettest: FAIL (-i: server got $(tr '\n' ' ' < "$tmp/srv_got8"))"; fail=1; }
[ $((t1 - t0)) -ge 900 ] || { echo "nettest: FAIL (-i 0.3: three lines in $((t1 - t0)) ms)"; fail=1; }

[ "$fail" -eq 0 ] && echo "nettest: PASS"
exit "$fail"
