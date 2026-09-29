#!/bin/sh
# test/kore/misc.sh -- dd, xxd, strings, cal, timeout, which, tty, clear, hostname,
# hexdump, getopt
. "$(dirname "$0")/common.sh"

# dd: the data AND the two record lines. a partial block is the +1 column, which is
# the half of dd's report that a `bs=` a file does not divide by is the only way to see
for c in "bs=1 count=5" "bs=6 skip=1" "bs=7" "bs=1000" "bs=3 count=2"; do
  # shellcheck disable=SC2086
  dd if="$ho/.arc1" $c > "$g" 2>/dev/null
  # shellcheck disable=SC2086
  korerun dd if="$ho/.arc1" $c > "$o" 2>/dev/null
  same "dd $c"
  # shellcheck disable=SC2086
  dd if="$ho/.arc1" $c of=/dev/null 2>&1 | head -2 > "$g"
  # shellcheck disable=SC2086
  korerun dd if="$ho/.arc1" $c of=/dev/null 2>&1 | head -2 > "$o"
  same "dd records $c"
done
korerun dd if="$ho/.arc1" of="$ho/.ddout" bs=2 2>/dev/null || fail "kore dd of="
cmp -s "$ho/.arc1" "$ho/.ddout" || fail "kore dd if=/of= is a copy"
korerun dd if="$ho/.arc1" of=/dev/null status=none > "$o" 2>&1
[ -s "$o" ] && fail "kore dd status=none still spoke" || true
# xxd: vim's, where the box has it; the -r round trip stands on its own either way
dd if=/dev/urandom of="$ho/.xxbin" bs=311 count=1 2>/dev/null
# ..and one FIXED input whose ascii gutter opens on two hex charms ("ab.."), which is
# where -r used to read the gutter as data. random bytes hit it about one run in eight,
# so the row that catches it cannot be left to the fixture's luck.
printf 'ab\0hello\0\1\2cd\0xyz\n' > "$ho/.xxgut"
if command -v xxd >/dev/null 2>&1; then
  for f in .arc1 .xxbin .gs4 .gs5; do
    xxd "$ho/$f" > "$g" 2>/dev/null; korerun xxd "$ho/$f" > "$o" 2>/dev/null
    same "xxd $f"
  done
  for f in .xxbin .xxgut; do
    xxd "$ho/$f" | korerun xxd -r > "$o" 2>/dev/null
    cmp -s "$ho/$f" "$o" || fail "kore xxd -r over GNU's dump ($f)"
  done
fi
korerun xxd "$ho/.xxbin" | korerun xxd -r > "$o" 2>/dev/null
cmp -s "$ho/.xxbin" "$o" || fail "kore xxd | xxd -r round trip"
# strings: the printable runs, the floor moving, and a real binary
printf 'ab\0hello world\0\1\2cd\0longenough\n' > "$ho/.strbin"
if command -v strings >/dev/null 2>&1; then
  for n in "" "-n 2" "-n10"; do
    # shellcheck disable=SC2086
    strings $n "$ho/.strbin" > "$g" 2>/dev/null
    # shellcheck disable=SC2086
    korerun strings $n "$ho/.strbin" > "$o" 2>/dev/null
    same "strings $n"
  done
  strings -n 12 "$m" > "$g" 2>/dev/null; korerun strings -n 12 "$m" > "$o" 2>/dev/null
  same "strings over love itself"
  # a run still open at end of input ends its line too
  printf 'hello' | strings > "$g" 2>/dev/null; printf 'hello' | korerun strings > "$o" 2>/dev/null
  same "strings, a run at eof"
fi
# cal: SIX week rows always, each padded to 20, and the year three abreast -- the
# leap years come off epoch-days and want no table, so february is where a wrong one shows
if command -v cal >/dev/null 2>&1 && cal 9 2026 >/dev/null 2>&1; then
  for d in "9 2026" "2 2024" "2 2100" "2 2000" "2 2021" "12 1999" "1 1970" "8 2027" "5 2026"; do
    # shellcheck disable=SC2086
    cal $d > "$g" 2>/dev/null
    # shellcheck disable=SC2086
    korerun cal $d > "$o" 2>/dev/null
    same "cal $d"
  done
  cal 2026 > "$g" 2>/dev/null; korerun cal 2026 > "$o" 2>/dev/null; same "cal 2026 (the year)"
fi
# timeout: 124 when the clock wins, the command's own status when it does not, and
# the whole point -- that it comes back at the deadline and not at the command's end
t0=$(date +%s)
korerun timeout 1 sleep 20 > /dev/null 2>&1; r=$?
t1=$(date +%s)
[ $r -eq 124 ] || fail "kore timeout: want 124 for a command the clock ended (got $r)"
[ $((t1 - t0)) -le 5 ] || fail "kore timeout waited $((t1 - t0))s for a 1s limit"
korerun timeout 9 sh -c 'exit 7' > /dev/null 2>&1; r=$?
[ $r -eq 7 ] || fail "kore timeout: a command that finishes keeps its status (got $r)"
[ "$(korerun timeout 9 echo hi 2>/dev/null)" = hi ] || fail "kore timeout: the output passes"
[ "$(korerun timeout 0 echo hi 2>/dev/null)" = hi ] || fail "kore timeout 0 is no limit"
korerun timeout -s KILL 1 sleep 20 > /dev/null 2>&1; r=$?
[ $r -eq 124 ] || fail "kore timeout -s KILL (got $r)"
korerun timeout -k 1 1 sleep 20 > /dev/null 2>&1; r=$?
[ $r -eq 124 ] || fail "kore timeout -k (got $r)"
korerun timeout 9 /nonexistent-xyzzy > /dev/null 2>&1; r=$?
[ $r -eq 127 ] || fail "kore timeout: a command that will not start is 127 (got $r)"
# which, tty, clear, hostname
if command -v which >/dev/null 2>&1; then
  both "which sh"    which sh
  both "which -a sh" which -a sh
fi
korerun which no-such-tool-xyzzy > /dev/null 2>&1; r=$?
[ $r -eq 1 ] || fail "kore which: an unfound name exits 1 (got $r)"
[ "$(korerun which /bin/sh 2>/dev/null)" = /bin/sh ] || fail "kore which: a path answers itself"
[ "$(korerun hostname 2>/dev/null)" = "$(korerun uname -n 2>/dev/null)" ] \
  || fail "kore hostname and uname -n read the one file"
[ "$(korerun tty < /dev/null 2>/dev/null)" = "not a tty" ] || fail "kore tty off a pipe"
korerun tty < /dev/null > /dev/null 2>&1; r=$?
[ $r -eq 1 ] || fail "kore tty: not a terminal is exit 1 (got $r)"
[ "$(korerun clear 2>/dev/null | wc -c)" = 11 ] || fail "kore clear: home, 2J and 3J"
# the three read no options at all, so a dash word is refused and not ignored
korerun tty -Z > "$o" 2>&1; r=$?
[ $r -eq 2 ] && grep -q 'unknown option' "$o" || fail "kore tty -Z must be refused"
# hexdump to the byte against the system's where there is one: both faces, the `*` a
# repeated row folds to, a short last row padded out, -s landing past the end still
# naming the offset it reached
if command -v hexdump > /dev/null 2>&1; then
  printf 'hello\n' > "$ho/.hx1"; printf 'abc' > "$ho/.hx2"; : > "$ho/.hx3"
  { dd if=/dev/zero bs=48 count=1 2>/dev/null; printf 'x'; } > "$ho/.hx4"
  for f in .hx1 .hx2 .hx3 .hx4 .arc1; do
    for fl in "" "-C" "-v" "-n 5" "-s 3" "-C -s 17 -n 20" "-s 1000"; do
      # shellcheck disable=SC2086
      hexdump $fl "$ho/$f" > "$g" 2>/dev/null; korerun hexdump $fl "$ho/$f" > "$o" 2>/dev/null
      same "hexdump $fl $f"
    done
  done
  hexdump -C "$ho/.arc1" > "$g"; korerun hd "$ho/.arc1" > "$o"; same "hd"
fi
# getopt against util-linux's where it is the enhanced one (-T answers 4): the quoting
# for eval, abbreviated longs, the three operand modes, -a's one-dash longs, and the
# parse errors -- stderr and the exit ride along
if getopt -T > /dev/null 2>&1; [ $? -eq 4 ]; then
  while IFS= read -r c; do
    eval "getopt $c" > "$g" 2>&1; rg=$?
    eval "korerun getopt $c" > "$o" 2>&1; ro=$?
    cmp -s "$g" "$o" && [ $rg -eq $ro ] || fail "kore getopt $c (rc $ro vs $rg)"
  done <<'EOF_GETOPT'
-o ab:c:: --long alpha,beta:,gamma:: -n prog -- -a -b x file --alp -c
-o ab:c:: -l alpha,beta: -- -a -bval -cval -c rest1 -- -a
-o ab: -- -b
-o a -- -z -a
-o a -- --nope
-o a -l alpha,also -- --al
-o a -l alpha -- --alpha=3
-o a -l beta: -- --beta
-o a -l gamma:: -- --gamma --gamma=v
-o +ab -- -a file -b
-o -ab -- -a file -b
-q -o a -- -z -a
-Q -o a -- -a x
-a -o ab -l alpha,beta: -- -alp -b -beta x -beta=y -a
-o a -- "it's" -a
-u -o ab: -- -b "x y" z
ab: -a -b x y
-n x ab: -a -b q
-o x: -- -x ''
EOF_GETOPT
fi
korerun getopt -T; [ $? -eq 4 ] || fail "kore getopt -T must answer 4"
# printf against GNU's (env reaches the binary, not the shell's builtin): stdout and
# status over flags, widths, precisions, the bases, the reals exactly rounded, the
# escapes, %b %q %c, a word that is not a number (said, and the status 1), missing
# arguments (0 and "", silently) and the format reused while arguments remain
if env printf %q x > /dev/null 2>&1; then
  pf() { LC_ALL=C env printf "$@" > "$g" 2>/dev/null; r1=$?
         korerun printf "$@" > "$o" 2>/dev/null; r2=$?
         same "printf $1"; [ $r1 -eq $r2 ] || fail "kore printf $1: status $r2, GNU's $r1"; }
  pf '%d|%i|%5d|%-5d|%05d|%+d|% d|%.3d|%.0d\n' 42 -7 3 3 -3 3 3 7 0
  pf '%o|%x|%X|%#o|%#x|%#X|%u|%x\n' 8 255 48879 8 255 0 -1 -1
  pf '%d %d %d %d\n' 0x1f 010 "'a" ' 12'
  pf '%f|%.2f|%10.4f|%-10.2e|%+.1g|%g|%g|%G|%#.0f|%08.3f\n' 1.5 2.675 3.14159265 -12345 0.05 100000 1000000 1e-10 3 -3.5
  pf '%.2g|%.2g|%e|%.0e|%.3e\n' 255 99.995 0 15 0x10
  pf '%f|%F|%f\n' inf -inf nan
  pf '%s|%5s|%-5s|%.2s|%c|%c|%5c|\n' abc x y hello hello '' z
  pf '%*d|%-*d|%.*f|%*s|\n' 4 1 4 2 2 3.14159 -4 x
  pf '\e\101\x41\\\a\b\f\vé\n'
  pf 'a\cb'
  pf '%b|%b\n' 'a\tb\0101\101' '\x41\c.z'
  pf '%q %q %q %q %q\n' 'a b' abc '' "it's" 'tab	here'
  pf '%s-%s|' a b c
  pf '%d %f %s|\n' 1
  pf '%ld %hd %%\n' 1 2
  pf '%d\n' abc
  pf '%d\n' 1.5
  pf '%x\n'
  pf '%z'
  pf '%5b' x
  pf '%#d' 1
fi
# every tool refuses a flag it does not know with 2 (env with GNU's 125), before it does
# anything -- these read one as a file, a user, a name to kill, or said nothing at all
: > "$ho/.rfq"
for c in "stat -Q" "cmp -l" "install -v" "chown -v gwen" "chgrp -v gwen" "readlink -Q" "md5sum -Q" "sha256sum -c --nosuch" \
         "cksum -Q" "killall -q" "which -Q" "time -v" "printenv -Q" "pidof -x" "basename -Q" "dirname -Q" "ls --nosuch" \
         "realpath --foo" "users -Q" "fsync -Q" "umount -Q" "chroot -Q" "tsort -Q" "rev -Q" "link -Q" "unlink -Q" "yes -Q" \
         "hostid -Q" "reset -Q" "dnsdomainname -Q" "du --foo" "comm --foo"; do
  # shellcheck disable=SC2086
  korerun $c "$ho/.rfq" < /dev/null > /dev/null 2>&1; r=$?; [ $r -eq 2 ] || fail "kore $c must refuse (rc $r)"
done
korerun env -Q > /dev/null 2>&1; r=$?; [ $r -eq 125 ] || fail "kore env -Q (rc $r)"
korerun rev -ba "$ho/.rfq" 2>&1 | grep -q "unknown option -b" || fail "kore's refusal names the letter typed first"
[ "$(korerun printenv -0 HOME | tr '\0' '|')" = "$HOME|" ] || fail "kore printenv -0"
# dd's seek= (onto a file, zeros past its end), conv= ucase lcase swab sync notrunc,
# oflag=append (cut first unless notrunc), ibs=/obs= records, iflag/oflag's byte counts,
# status=none; the file left and the two record lines, against GNU
printf 'Hello World abcdefghij\n' > "$ho/.ddi"; printf '0123456789ABCDEFGHIJ' > "$ho/.ddb"
for c in "bs=4 count=2" "bs=4 skip=1 count=2" "conv=ucase" "conv=lcase" "conv=swab" "bs=5 conv=sync count=1" "bs=4 seek=2 count=1" \
         "bs=4 seek=2 count=1 conv=notrunc" "oflag=append" "oflag=append conv=notrunc" "bs=1 seek=30 count=2 conv=notrunc" "ibs=3 obs=5" \
         "iflag=skip_bytes,count_bytes skip=3 count=5" "oflag=seek_bytes seek=3 conv=notrunc bs=2 count=2" "status=none bs=4"; do
  cp "$ho/.ddb" "$ho/.ddg"; cp "$ho/.ddb" "$ho/.ddk"
  # shellcheck disable=SC2086
  dd $c of="$ho/.ddg" < "$ho/.ddi" 2> "$g"; korerun dd $c of="$ho/.ddk" < "$ho/.ddi" 2> "$o"
  sed -i '/copied/d' "$g" "$o"; same "dd $c (report)"; cmp -s "$ho/.ddg" "$ho/.ddk" || fail "kore dd $c (the file)"
done
korerun dd conv=block < /dev/null > /dev/null 2>&1; r=$?; [ $r -eq 1 ] || fail "kore dd conv=block must refuse ($r)"
rm -f "$ho"/.dd?
echo "kore: dd, xxd, strings, cal, timeout, which, tty, clear, hostname, hexdump, getopt ok"
