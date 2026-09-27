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
# basenc: every encoding both ways against GNU's, its wrap, and what a decode refuses
be=$ho/.kore-be; head -c 1000 /dev/urandom > "$be.bin"; printf 'hello world!\n' > "$be.txt"; : > "$be.nil"
if command -v basenc >/dev/null 2>&1; then
  for e in --base64 --base64url --base32 --base32hex --base16 --base2msbf --base2lsbf; do
    for f in "$be.bin" "$be.txt" "$be.nil"; do
      both "basenc $e" basenc $e "$f"
      basenc $e "$f" > "$be.enc"; both "basenc -d $e" basenc -d $e "$be.enc"
    done
  done
  both "basenc --z85" basenc --z85 "$be.bin"
  basenc --z85 "$be.bin" > "$be.enc"; both "basenc -d --z85" basenc -d --z85 "$be.enc"
  both "basenc -w 10" basenc --base16 -w 10 "$be.txt"
  both "basenc -w 0" basenc --base64 -w 0 "$be.txt"
  for i in zz AAA 0110100 AB== ABC 'aG*Vs'; do
    for e in --base64 --base32 --base16 --base2msbf; do
      printf '%s\n' "$i" | LC_ALL=C basenc -d $e > "$g" 2>&1; rg=$?
      printf '%s\n' "$i" | korerun basenc -d $e > "$o" 2>&1; ro=$?
      same "basenc -d $e '$i'"; [ $rg -eq $ro ] || fail "kore basenc -d $e '$i' exit ($ro vs $rg)"
    done
  done
  printf 'aG*VsbG8=\n' | basenc -di --base64 > "$g"; printf 'aG*VsbG8=\n' | korerun basenc -di --base64 > "$o"; same "basenc -di"
  LC_ALL=C basenc "$be.txt" > "$g" 2>&1; korerun basenc "$be.txt" > "$o" 2>&1; same "basenc with no encoding"
fi
# uuencode and uudecode: busybox's faces, and each reading the other's
chmod 640 "$be.bin"
if command -v busybox >/dev/null 2>&1; then
  for f in "$be.bin" "$be.txt" "$be.nil"; do
    for mm in "" -m; do
      # shellcheck disable=SC2086
      busybox uuencode $mm "$f" name > "$g"; korerun uuencode $mm "$f" name > "$o"; same "uuencode $mm $f"
      busybox uudecode -o "$be.out" "$o" && cmp -s "$be.out" "$f" || fail "busybox uudecode of ours ($mm $f)"
      korerun uudecode -o - "$g" > "$be.out" && cmp -s "$be.out" "$f" || fail "kore uudecode of busybox's ($mm $f)"
    done
  done
fi
( cd "$HO" && "$K" kore uuencode .kore-be.bin .kore-be.named > .kore-be.uu && rm -f .kore-be.named \
  && "$K" kore uudecode .kore-be.uu && cmp -s .kore-be.named .kore-be.bin ) || fail "kore uudecode to the header's name"
[ "$(stat -c %a "$ho/.kore-be.named" 2>/dev/null || echo 640)" = 640 ] || fail "kore uudecode: the header's mode"
printf 'no armour\n' | korerun uudecode 2>/dev/null; r=$?; [ $r -eq 1 ] || fail "kore uudecode without begin is 1 (got $r)"
# ascii: toybox's table
korerun ascii > "$o"
[ "$(wc -l < "$o")" -eq 17 ] && head -1 "$o" | grep -q '^Dec Hex    Dec Hex    Dec Hex  Dec Hex  Dec Hex  Dec Hex   Dec Hex   Dec Hex  $' \
  && grep -q '^ 15 0F SI   31 1F US   47 2F /  63 3F ?  79 4F O  95 5F _  111 6F o  127 7F DEL$' "$o" || fail "kore ascii's table"
echo "kore: encodings + tsort + factor (base64/base32/basenc GNU-identical, uuencode/uudecode as busybox, ascii) ok"
