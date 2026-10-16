#!/bin/sh
# test/kore/stat.sh -- stat, du, date, id, mktemp, chown
. "$(dirname "$0")/common.sh"

# our stat's %y is utc only, so gnu is told TZ=UTC too
export TZ=UTC
dt=$ho/.kore-dt
rm -rf "$dt"; mkdir -p "$dt/a/b" "$dt/c"
printf '0123456789' > "$dt/f1"
head -c 9000 /dev/urandom > "$dt/a/f2"
: > "$dt/a/b/f3"
ln -sf f1 "$dt/lk"
for f in '%n' '%s' '%a' '%A' '%F' '%u' '%U' '%g' '%G' '%h' '%i' '%Y' '%b' '%B' '%f' \
         '%N' '%y' '%x' '%X' '%z' '%Z' '%w' '%W' '%d' '%D' '%r' '%R' '%t' '%T' '%o' \
         '%m' '%n|%s|%a' 'x%%y' 'a\tb\n' 'a%Qb'; do
  both "stat -c $f" stat -c "$f" "$dt/f1"
done
# a node's device numbers: %t/%T major and minor in hex, %d/%r the whole word
for dv in /dev/null /dev/zero; do
  [ -e "$dv" ] && both "stat -c dev $dv" stat -c '%d|%D|%r|%R|%t|%T|%F' "$dv"
done
# the default face, gnu's eight-line block, compared on the lines that hold still
both "stat block file"  stat "$dt/f1"
both "stat block empty" stat "$dt/a/b/f3"
both "stat block dir"   stat "$dt/a"
both "stat block -L lk" stat -L "$dt/lk"
for dv in /dev/null /dev/zero; do
  [ -e "$dv" ] && both "stat block $dv" stat "$dv"
done
# a link's block: reading a link moves its atime, so that line differs even gnu to gnu
stat "$dt/lk" 2>/dev/null | grep -v '^Access: 2' > "$g"
korerun stat "$dt/lk" 2>/dev/null | grep -v '^Access: 2' > "$o"
same "stat block link"
# no operand is still usage, and -c still wants its format
korerun stat > /dev/null 2>&1; r=$?
[ $r -eq 2 ] || fail "kore stat no operand (exit $r)"
korerun stat -c > /dev/null 2>&1; r=$?
[ $r -eq 2 ] || fail "kore stat -c with no format (exit $r)"
both "stat dir"      stat -c '%n %F %A %a' "$dt/a"
# the bare face reads the link itself, -L what it names
both "stat link"     stat -c '%n %F %A' "$dt/lk"
both "stat -L link"  stat -L -c '%n %F %A' "$dt/lk"
both "stat many"     stat -c '%s %n' "$dt/f1" "$dt/a/f2"
both "stat empty"    stat -c '%F' "$dt/a/b/f3"
# %N quotes the name and adds a link's arrow and target; -L drops the arrow
both "stat %N link"    stat -c '%N' "$dt/lk"
both "stat %N -L link" stat -L -c '%N' "$dt/lk"
# each quoting branch: plain, a space, an inner quote, both quotes, a $'..' byte, a quoted
# target. a byte over 127 is left out: gnu reads the locale for it
qd=$ho/.kore-q; rm -rf "$qd"; mkdir -p "$qd"   # outside $dt: du walks that tree below
: > "$qd/plain"; : > "$qd/with space"; : > "$qd/sq'ote"; : > "$qd/dq\"ote"
: > "$qd/both'and\"q"; : > "$qd/back\\slash"; : > "$qd/dollar\$x"; : > "$qd/back\`tick"
: > "$qd/$(printf 'tab\there')"; : > "$qd/$(printf 'a\001b')"
ln -sf "sq'ote" "$qd/lkq"
i=0
for n in "$qd"/*; do i=$((i + 1)); both "stat %N q$i" stat -c '%N' "$n"; done
# -c adds a newline and reads no escapes; --printf reads them and adds none
both "stat --printf" stat --printf='a\t%s\n' "$dt/f1"
korerun stat -c %s "$dt/nope" > /dev/null 2>&1; r=$?
[ $r -eq 1 ] || fail "kore stat missing file (exit $r)"
# du: tree walks compare as sets (readdir order); single paths byte for byte
dusort() { n=$1; shift
           "$@" 2>/dev/null | LC_ALL=C sort > "$g"
           korerun "$@" 2>/dev/null | LC_ALL=C sort > "$o"
           same "du $n"; }
dusort "plain" du "$dt"
dusort "-a"    du -a "$dt"
dusort "-d 1"  du -d 1 "$dt"
dusort "-ab"   du -ab "$dt"
both "du -s"   du -s "$dt"
both "du file" du "$dt/f1"
both "du -c"   du -c "$dt/f1" "$dt/a/f2"
both "du -sb"  du -sb "$dt"
both "du -sh"  du -sh "$dt"
both "du -sk"  du -sk "$dt"
both "du -h"   du -h "$dt/a/f2"
# a hard link counts once per run
rm -rf "$dt/hl"; mkdir "$dt/hl"; head -c 9000 /dev/urandom > "$dt/hl/one"
ln "$dt/hl/one" "$dt/hl/two"
both "du hard link" du -s "$dt/hl"
# -h: three significant figures, rounded up, through G
rm -rf "$dt/hs"; mkdir "$dt/hs"
for sz in 1 5000 11000 100000 1500000 20000000; do head -c $sz /dev/zero > "$dt/hs/f$sz"; done
dusort "-ah over a scale" du -ah "$dt/hs"
# df: the figures move under a busy box, so the check holds the header (names, widths),
# the device, the size and the mount point
dfstable() { awk '{ print $1, $2, $NF }'; }
if [ -r /proc/self/mounts ]; then
  for fl in '' -k -h -i; do
    # shellcheck disable=SC2086
    df $fl 2>/dev/null | dfstable > "$g"
    # shellcheck disable=SC2086
    korerun df $fl 2>/dev/null | dfstable > "$o"
    same "df $fl"
  done
  # a path names the mount its resolved path lies under, so a bind mount names itself
  for p in / "$HO" "$dt/f1"; do
    for fl in -k -h -i; do
      df $fl "$p" 2>/dev/null | dfstable > "$g"
      korerun df $fl "$p" 2>/dev/null | dfstable > "$o"
      same "df $fl $p"
    done
  done
  # -a: the rows both list; gnu dashes some types without asking statfs, we report zeroes
  df -a 2>/dev/null | awk '{ print $1, $NF }' | LC_ALL=C sort > "$g"
  korerun df -a 2>/dev/null | awk '{ print $1, $NF }' | LC_ALL=C sort > "$o"
  same "df -a rows"
  # a missing path costs the status and prints no table
  korerun df "$dt/nope" > "$o" 2>/dev/null; r=$?
  [ $r -eq 1 ] || fail "kore df missing file (exit $r)"
  [ -s "$o" ] && fail "kore df laid a table for a missing file"
  korerun df -Z > /dev/null 2>&1; r=$?
  [ $r -eq 2 ] || fail "kore df unknown option (exit $r)"
  echo "kore: df (the three faces, a named path, -a's rows, GNU's columns) ok"
fi
# date -d @SECONDS: the only face that holds still
for s in 0 1 1000000000 1700000000 1234567890 951782400 2147483647 4102444800; do
  for f in '' '+%Y-%m-%d %H:%M:%S' \
           '+%a %A %b %B %j %y %C %e %F %T %D %s %H %I %p %u %w %Z %z' '+%%|%n|%t|'; do
    if [ -n "$f" ]; then
      LC_ALL=C date -u -d @$s "$f" > "$g"; korerun date -u -d @$s "$f" > "$o"
    else
      LC_ALL=C date -u -d @$s > "$g"; korerun date -u -d @$s > "$o"
    fi
    same "date -d @$s '$f'"
  done
done
LC_ALL=C date -u -r "$dt/f1" '+%Y-%m-%d %H:%M:%S' > "$g"
korerun date -u -r "$dt/f1" '+%Y-%m-%d %H:%M:%S' > "$o"; same "date -r FILE"
# date's zones: tzif files (both hemispheres, odd offsets, past the last transition), posix
# rules, an empty TZ. a missing zone is skipped; a posix rule only after 1970, as glibc
for z in America/New_York Australia/Sydney Europe/London America/St_Johns Asia/Kolkata \
         Pacific/Chatham "" "JST-9" "<+0330>-3:30" "EST5EDT,M3.2.0,M11.1.0" \
         "NZST-12NZDT,M9.5.0,M4.1.0/3" "CET-1CEST,J60/2,J300/3"; do
  case $z in */*) [ -f "/usr/share/zoneinfo/$z" ] || continue ;; esac
  for s in 0 1000000000 1710053940 1710054060 1730613600 1730617200 2250000000 4102444800 -100000000; do
    case $z,$s in *,*,-*) continue ;; esac
    TZ=$z LC_ALL=C date -d @$s '+%F %T %Z %z' > "$g"; TZ=$z korerun date -d @$s '+%F %T %Z %z' > "$o"
    same "TZ='$z' date -d @$s"
  done
done
[ "$(korerun date '+%Y')" = "$(date -u '+%Y')" ] || fail "kore date (now)"
# id: numeric and named faces, groups read from /etc/group
for fl in -u -g -un -gn -G ''; do
  # shellcheck disable=SC2086
  both "id $fl" id $fl
done
# mktemp: the name's shape and its effect
t=$(korerun mktemp) || fail "kore mktemp"
case $t in /tmp/tmp.??????????) [ -f "$t" ] || fail "kore mktemp made no file";;
           *) fail "kore mktemp name: $t";; esac
[ "$(stat -c %a "$t")" = 600 ] || fail "kore mktemp mode: $(stat -c %a "$t")"
rm -f "$t"
t=$(korerun mktemp -d); [ -d "$t" ] || fail "kore mktemp -d"; rmdir "$t"
t=$(korerun mktemp -p "$dt" wooXXXXXX)
case $t in "$dt"/woo??????) [ -f "$t" ] || fail "kore mktemp -p made no file";;
           *) fail "kore mktemp -p name: $t";; esac
rm -f "$t"
t=$(korerun mktemp -u); [ -e "$t" ] && fail "kore mktemp -u left the file behind"
# chown unprivileged: the no-op and the refusal
korerun chown "$(id -un):$(id -gn)" "$dt/f1" || fail "kore chown to our own ids"
korerun chown nosuchuser000 "$dt/f1" 2>/dev/null; r=$?
[ $r -eq 1 ] || fail "kore chown unknown user (exit $r)"
# date -d and touch -d over gnu's common spellings: iso, us slashes, month names, @N,
# stacked relative items and ago, a trailing zone, -R, midnight. under TZ=UTC0
for d in "2024-01-02" "2024-01-02 10:30" "2024-01-02T10:30:15Z" "2024-01-02 10:30:00 +0200" "2024-01-02T10:30:00+02:00" \
         "01/02/2024" "Jan 2 2024" "2 Jan 2024" "January 2, 2024" "@1700000000" "2024-01-31 +1 month" "2024-03-31 -1 month" \
         "2024-01-02 2 weeks ago" "2024-02-29 +1 year" "2024-01-02 next month" "2024-01-02 -2 hours" "2023-12-31 23:59:59 +1 sec" \
         "2024-01-02 3 days ago 2 hours ago" "Thu Jan  1 00:00:00 UTC 2026" "Thu, 01 Jan 2026 00:00:00 +0000" \
         "Wed, 31 Dec 2025 19:00:00 -0500" "Mar 7 00:00 2020" "2024-01-02 00:00:00"; do
  [ "$(TZ=UTC0 date -d "$d" +%s)" = "$(TZ=UTC0 korerun date -d "$d" +%s)" ] || fail "kore date -d '$d': $(TZ=UTC0 korerun date -d "$d" +%s 2>&1)"
done
g1=$(TZ=UTC0 date -d yesterday +%s); k1=$(TZ=UTC0 korerun date -d yesterday +%s); [ $((g1 - k1)) -le 2 ] && [ $((k1 - g1)) -le 2 ] || fail "kore date -d yesterday"
TZ=UTC0 korerun date -d 'no such date' +%s > /dev/null 2>&1; r=$?; [ $r -eq 1 ] || fail "kore date -d of no date (rc $r)"
# date's own spelling read back, -d glued; a lone weekday is refused
[ "$(TZ=UTC0 korerun date "-dThu Jan  1 00:00:00 UTC 2026" +%s)" = 1767225600 ] || fail "kore date -dDATE glued"
TZ=UTC0 korerun date -d thu +%s > /dev/null 2>&1; r=$?; [ $r -eq 1 ] || fail "kore date -d of a weekday alone (rc $r)"
TZ=UTC0 korerun touch -d "2024-01-02 10:30" "$ho/.tdd" && [ "$(stat -c %Y "$ho/.tdd")" = 1704191400 ] || fail "kore touch -d DATE"; rm -f "$ho/.tdd"
# du's long options, -L, -x, --apparent-size, -0; rows sorted (gnu walks readdir order)
U=$PWD/$ho/.duf; rm -rf "$U"; mkdir -p "$U/t/a/b" "$U/t/c" "$U/outside"
head -c 5000 /dev/zero > "$U/t/a/f.log"; head -c 9000 /dev/zero > "$U/t/a/b/g.txt"; echo x > "$U/t/c/h.log"; head -c 7000 /dev/zero > "$U/outside/z"
ln -s ../../outside "$U/t/c/lo"
for c in "t" "--max-depth=1 t" "-d 0 t" "--exclude=*.log t" "-a --exclude=*.log t" "-L t/c" "-x t" "--apparent-size t" "-b t" "--summarize --total t" "-ah --all t"; do
  # shellcheck disable=SC2086
  (cd "$U" && du $c | sort) > "$g"; (cd "$U" && LOVE_NO_IMAGE= "$PWD/../../$m" kore du $c | sort) > "$o"; same "du $c"
done
(cd "$U" && du -0 t | tr '\0' '\n' | sort) > "$g"; (cd "$U" && LOVE_NO_IMAGE= "$PWD/../../$m" kore du -0 t | tr '\0' '\n' | sort) > "$o"; same "du -0"
rm -rf "$U"
# df -T, -H, -t and -x by type, against gnu on this box's mounts; a row holds its name,
# size or type, and mount point, the header whole
dfst() { awk 'NR == 1 { print; next } { print $1, $2, $NF }'; }
for c in "-T /" "-H /" "-hT /" "-t tmpfs" "-x tmpfs -x btrfs" "--print-type /" "--si /" "--type=tmpfs" "-ttmpfs"; do
  # shellcheck disable=SC2086
  df $c 2>&1 | dfst > "$g"; korerun df $c 2>&1 | dfst > "$o"; same "df $c"
done
# mktemp --suffix, --tmpdir, --dry-run: by the name's shape
MT=$PWD/$ho/.mkt; rm -rf "$MT"; mkdir "$MT"
n1=$(korerun mktemp --tmpdir="$MT" --suffix=.txt); case "$n1" in "$MT"/tmp.??????????.txt) [ -f "$n1" ] || fail "kore mktemp --suffix made nothing";; *) fail "kore mktemp --suffix: $n1";; esac
n2=$(TMPDIR="$MT" korerun mktemp --tmpdir -u); case "$n2" in "$MT"/tmp.??????????) [ ! -e "$n2" ] || fail "kore mktemp --dry-run made one";; *) fail "kore mktemp --tmpdir: $n2";; esac
n3=$(cd "$MT" && LOVE_NO_IMAGE= "$PWD/../../$m" kore mktemp --suffix .c fooXXXXXX); case "$n3" in foo??????.c) ;; *) fail "kore mktemp TEMPLATE --suffix: $n3";; esac
rm -rf "$MT"
# stat -f: gnu's first three lines, and a -c of the fields that hold still
for d in / /tmp; do
  stat -f "$d" | head -3 > "$g"; korerun stat -f "$d" | head -3 > "$o"; same "stat -f $d"
  stat -f -c '%n %i %l %t %T %s %S %b %c' "$d" > "$g"; korerun stat -f -c '%n %i %l %t %T %s %S %b %c' "$d" > "$o"; same "stat -f -c $d"
done
# chown/chgrp -v -c -R -h --reference against gnu: what is said and the groups left.
# a link met in -R changes itself, not its target. needs a second group of our own
G1=$(id -gn); G2=$(id -Gn | tr ' ' '\n' | grep -v "^$G1\$" | head -1)
if [ -n "$G2" ]; then
  CH=$PWD/$ho/.chg
  chreset() { rm -rf "$CH"; mkdir -p "$CH/t/d" "$CH/out"; : > "$CH/t/f"; : > "$CH/t/d/g"; : > "$CH/out/o"; ln -s ../out "$CH/t/lo"; ln -s f "$CH/t/lf"; chgrp -R -h "$G1" "$CH/t" "$CH/out"; }
  chlay() { (cd "$CH" && find t out -printf '%p %g\n' | sort); }
  for c in "chgrp -v $G2 t/f" "chgrp -c $G2 t/f" "chgrp -v $G1 t/f" "chgrp -R $G2 t" "chgrp -h $G2 t/lf" "chgrp $G2 t/lf" \
           "chown -v $(id -un):$G2 t/f" "chgrp --reference=out/o t/f" "chgrp -Rv $G2 t/d"; do
    # shellcheck disable=SC2086
    chreset; { (cd "$CH" && $c; echo "rc=$?"); chlay; } > "$g" 2>&1
    # shellcheck disable=SC2086
    chreset; { (cd "$CH" && LOVE_NO_IMAGE= "$PWD/../../$m" kore $c; echo "rc=$?"); chlay; } > "$o" 2>&1
    same "$c"
  done
  rm -rf "$CH"
fi
echo "kore: stat/du/date/id/mktemp/chown (GNU-identical, the tree sums, date's zones) ok"
