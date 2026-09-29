#!/bin/sh
# test/net/loopback.sh -- the nc loopback gate (host-only, NOT in the portable
# corpus, so `make test` and the kernel/wasm builds stay socket-free). Drives the
# real binary: a server task and a client over TCP 127.0.0.1, full-duplex, and
# asserts each side received exactly what the other sent. This exercises every
# Stage-1 socket nif (connect/listen/accept/shutdown) plus the two .l pump loops
# and their teardown. both sides pass -N; a second round checks that without it neither
# side half-closes, and a third that -q quits anyway.
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
cli=
trap 'kill "$srv" $cli 2>/dev/null; rm -rf "$tmp"' EXIT

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

[ "$fail" -eq 0 ] && echo "nettest: PASS"
exit "$fail"
