#!/bin/sh
# test/kore/encode.sh -- base64, base32, tsort, factor
. "$(dirname "$0")/common.sh"

# the encodings ride a BINARY file, which is the only input that says anything:
# text agrees under any bug that only mangles the high bit
head -c 5000 /dev/urandom > "$ho/.b64src" 2>/dev/null || dd if=/dev/random of="$ho/.b64src" bs=1 count=5000 2>/dev/null
both "base64"      base64 "$ho/.b64src"
both "base64 -w 0" base64 -w 0 "$ho/.b64src"
both "base64 -w 20" base64 -w 20 "$ho/.b64src"
both "base32"      base32 "$ho/.b64src"
base64 "$ho/.b64src" > "$ho/.b64txt"
korerun base64 -d "$ho/.b64txt" > "$o"; cmp -s "$ho/.b64src" "$o" || fail "kore base64 -d"
base32 "$ho/.b64src" > "$ho/.b32txt"
korerun base32 -d "$ho/.b32txt" > "$o"; cmp -s "$ho/.b64src" "$o" || fail "kore base32 -d"
printf 'aG!s\n' | korerun base64 -d > /dev/null 2>&1; r=$?
[ $r -eq 1 ] || fail "kore base64 bad input (rc $r)"
# tsort: OUR order is a topological one and not GNU's, so the input pins one -- a
# chain has exactly one answer, and then both tools owe the same lines
pipe "tsort chain" 'a b
b c
c d
'                  tsort
printf 'a b\nb a\n' | korerun tsort > "$o" 2>/dev/null; r=$?
[ $r -eq 1 ] && [ "$(LC_ALL=C sort "$o" | tr -d '\n')" = ab ] || fail "kore tsort loop (rc $r)"
printf 'a b c\n' | korerun tsort > /dev/null 2>&1; r=$?
[ $r -eq 1 ] || fail "kore tsort odd words (rc $r)"
both "factor"      factor 97 100 1234567 65537 2 1 0
pipe "factor stdin" '12 13
17
'                   factor
echo "kore: encodings + tsort + factor (base64/base32 over a binary file, GNU-identical) ok"
