#!/bin/sh
# test/kore/stat.sh -- stat, du, date, id, mktemp, chown
. "$(dirname "$0")/common.sh"

# TZ=UTC: this love has no tz database (localtime IS gmtime), so `date` and stat's
# %y are UTC and only UTC. GNU reads TZ, so the oracle has to be told.
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
# the device numbers, which only a NODE has any of -- %t and %T split the packed word
# into major and minor and spell them in hex, %d/%r hand the word over whole
for dv in /dev/null /dev/zero; do
  [ -e "$dv" ] && both "stat -c dev $dv" stat -c '%d|%D|%r|%R|%t|%T|%F' "$dv"
done
# the DEFAULT face: GNU's eight-line block, which this tool used to refuse outright for
# want of an access time, a change time and a device number. the stat tuple carries all
# three now and the birth line is statx's own call, answering the dash GNU answers on a
# filesystem that keeps none. compared byte for byte on what holds still.
both "stat block file"  stat "$dt/f1"
both "stat block empty" stat "$dt/a/b/f3"
both "stat block dir"   stat "$dt/a"
both "stat block -L lk" stat -L "$dt/lk"
for dv in /dev/null /dev/zero; do
  [ -e "$dv" ] && both "stat block $dv" stat "$dv"
done
# a link's own block is the one that cannot be compared byte for byte, and the reason is
# not ours: READING a link updates its access time, so GNU run twice disagrees with GNU.
# every other line is compared, the arrow among them.
stat "$dt/lk" 2>/dev/null | grep -v '^Access: 2' > "$g"
korerun stat "$dt/lk" 2>/dev/null | grep -v '^Access: 2' > "$o"
same "stat block link"
# no operand is still usage, and -c still wants its format
korerun stat > /dev/null 2>&1; r=$?
[ $r -eq 2 ] || fail "kore stat no operand (exit $r)"
korerun stat -c > /dev/null 2>&1; r=$?
[ $r -eq 2 ] || fail "kore stat -c with no format (exit $r)"
both "stat dir"      stat -c '%n %F %A %a' "$dt/a"
# the bare face does NOT follow a link and -L does -- one stat call apart, and the
# only check that can tell lstat from stat at all
both "stat link"     stat -c '%n %F %A' "$dt/lk"
both "stat -L link"  stat -L -c '%n %F %A' "$dt/lk"
both "stat many"     stat -c '%s %n' "$dt/f1" "$dt/a/f2"
both "stat empty"    stat -c '%F' "$dt/a/b/f3"
# %N is the name SHELL-QUOTED and, where the stat was the LINK's, an arrow and its
# target -- so -L drops the arrow by following. the plain name was the only one asked
# for above, which is exactly how a link's half of %N went missing.
both "stat %N link"    stat -c '%N' "$dt/lk"
both "stat %N -L link" stat -L -c '%N' "$dt/lk"
# ..and every branch of the quoting: the plain single quotes, a space inside them, the
# quote of its own that turns the whole thing into double quotes, the pair that cannot
# (so the quote splices instead), a byte the shell writes as $'..', and a link whose
# TARGET takes the second face. a stray byte over 127 is the one name left out: GNU
# reads the locale to tell text from rubbish and this quoting does not.
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
# du: the walk hands out readdir order, so the tree comparisons are of the SETS
# (find's honesty, and for the same reason); the single-path ones are byte-identical
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
# a hard link is counted ONCE per run, which is the whole reason du reads inodes
rm -rf "$dt/hl"; mkdir "$dt/hl"; head -c 9000 /dev/urandom > "$dt/hl/one"
ln "$dt/hl/one" "$dt/hl/two"
both "du hard link" du -s "$dt/hl"
# ..and -h's three significant figures, rounded UP, over a scale that reaches G
rm -rf "$dt/hs"; mkdir "$dt/hs"
for sz in 1 5000 11000 100000 1500000 20000000; do head -c $sz /dev/zero > "$dt/hs/f$sz"; done
dusort "-ah over a scale" du -ah "$dt/hs"
# df: the figures MOVE while the gate runs -- something on a build box is always
# writing -- so the comparison is of what does not. the header pins the column names
# and GNU's minimum widths, which is the fussy half; the device, the SIZE (a filesystem
# is resized on purpose, never by accident) and the mount point pin the rest. the
# arithmetic behind used/available/use% is lawed in test/law/kore.l, where nothing moves.
dfstable() { awk '{ print $1, $2, $NF }'; }
if [ -r /proc/self/mounts ]; then
  for fl in '' -k -h -i; do
    # shellcheck disable=SC2086
    df $fl 2>/dev/null | dfstable > "$g"
    # shellcheck disable=SC2086
    korerun df $fl 2>/dev/null | dfstable > "$o"
    same "df $fl"
  done
  # a named path reports the one filesystem holding it, found by the longest mount
  # point its RESOLVED path starts with -- so a bind mount names itself, not its twin
  for p in / "$HO" "$dt/f1"; do
    for fl in -k -h -i; do
      df $fl "$p" 2>/dev/null | dfstable > "$g"
      korerun df $fl "$p" 2>/dev/null | dfstable > "$o"
      same "df $fl $p"
    done
  done
  # -a keeps the filesystems with no blocks at all. the ROWS are what both agree on:
  # GNU dashes a few by TYPE (autofs and the rest of its dummy list) without asking
  # statfs at all, where this one asks and reports the zeroes it hears back
  df -a 2>/dev/null | awk '{ print $1, $NF }' | LC_ALL=C sort > "$g"
  korerun df -a 2>/dev/null | awk '{ print $1, $NF }' | LC_ALL=C sort > "$o"
  same "df -a rows"
  # a missing path costs the status and prints no table at all -- a lone header would
  # say a filesystem was found
  korerun df "$dt/nope" > "$o" 2>/dev/null; r=$?
  [ $r -eq 1 ] || fail "kore df missing file (exit $r)"
  [ -s "$o" ] && fail "kore df laid a table for a missing file"
  korerun df -Z > /dev/null 2>&1; r=$?
  [ $r -eq 2 ] || fail "kore df unknown option (exit $r)"
  echo "kore: df (the three faces, a named path, -a's rows, GNU's columns) ok"
fi
# date: -d @SECONDS is what makes this gateable at all -- `now` differs by the second
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
[ "$(korerun date '+%Y')" = "$(date -u '+%Y')" ] || fail "kore date (now)"
# id: the numeric and named faces byte-identical, groups included -- the supplementary
# list is read out of /etc/group here (no getgroups, no NSS), so it is a real check
for fl in -u -g -un -gn -G ''; do
  # shellcheck disable=SC2086
  both "id $fl" id $fl
done
# mktemp answers a name nobody had, so the SHAPE and the effect are the check
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
# chown: unprivileged, so the honest checks are the no-op and the refusal
korerun chown "$(id -un):$(id -gn)" "$dt/f1" || fail "kore chown to our own ids"
korerun chown nosuchuser000 "$dt/f1" 2>/dev/null; r=$?
[ $r -eq 1 ] || fail "kore chown unknown user (exit $r)"
# date -d reads GNU's common spellings: ISO with a T or a space and a zone, US slashes, a
# month's name either way round, @N, relative items stacked and turned back by ago, a
# signed number after a time as its zone -- and touch -d the same way. under TZ=UTC0
for d in "2024-01-02" "2024-01-02 10:30" "2024-01-02T10:30:15Z" "2024-01-02 10:30:00 +0200" "2024-01-02T10:30:00+02:00" \
         "01/02/2024" "Jan 2 2024" "2 Jan 2024" "January 2, 2024" "@1700000000" "2024-01-31 +1 month" "2024-03-31 -1 month" \
         "2024-01-02 2 weeks ago" "2024-02-29 +1 year" "2024-01-02 next month" "2024-01-02 -2 hours" "2023-12-31 23:59:59 +1 sec" \
         "2024-01-02 3 days ago 2 hours ago"; do
  [ "$(TZ=UTC0 date -d "$d" +%s)" = "$(TZ=UTC0 korerun date -d "$d" +%s)" ] || fail "kore date -d '$d': $(TZ=UTC0 korerun date -d "$d" +%s 2>&1)"
done
g1=$(TZ=UTC0 date -d yesterday +%s); k1=$(TZ=UTC0 korerun date -d yesterday +%s); [ $((g1 - k1)) -le 2 ] && [ $((k1 - g1)) -le 2 ] || fail "kore date -d yesterday"
TZ=UTC0 korerun date -d 'no such date' +%s > /dev/null 2>&1; r=$?; [ $r -eq 1 ] || fail "kore date -d of no date (rc $r)"
TZ=UTC0 korerun touch -d "2024-01-02 10:30" "$ho/.tdd" && [ "$(stat -c %Y "$ho/.tdd")" = 1704191400 ] || fail "kore touch -d DATE"; rm -f "$ho/.tdd"
# du's long names, --max-depth, --exclude, -L through a link out of the tree, -x,
# --apparent-size, -0; rows sorted (the walk is sorted, GNU's is readdir's)
U=$PWD/$ho/.duf; rm -rf "$U"; mkdir -p "$U/t/a/b" "$U/t/c" "$U/outside"
head -c 5000 /dev/zero > "$U/t/a/f.log"; head -c 9000 /dev/zero > "$U/t/a/b/g.txt"; echo x > "$U/t/c/h.log"; head -c 7000 /dev/zero > "$U/outside/z"
ln -s ../../outside "$U/t/c/lo"
for c in "t" "--max-depth=1 t" "-d 0 t" "--exclude=*.log t" "-a --exclude=*.log t" "-L t/c" "-x t" "--apparent-size t" "-b t" "--summarize --total t" "-ah --all t"; do
  # shellcheck disable=SC2086
  (cd "$U" && du $c | sort) > "$g"; (cd "$U" && LOVE_NO_IMAGE= "$PWD/../../$m" kore du $c | sort) > "$o"; same "du $c"
done
(cd "$U" && du -0 t | tr '\0' '\n' | sort) > "$g"; (cd "$U" && LOVE_NO_IMAGE= "$PWD/../../$m" kore du -0 t | tr '\0' '\n' | sort) > "$o"; same "du -0"
rm -rf "$U"
# df's -T (a left-aligned Type column), -H in powers of 1000, -t and -x by type (glued,
# repeated, long), against GNU on this machine's own mounts
# the used and free figures move while the box writes, so a row is held to what does not:
# its name, its size or type, and where it is mounted; the header whole
dfst() { awk 'NR == 1 { print; next } { print $1, $2, $NF }'; }
for c in "-T /" "-H /" "-hT /" "-t tmpfs" "-x tmpfs -x btrfs" "--print-type /" "--si /" "--type=tmpfs" "-ttmpfs"; do
  # shellcheck disable=SC2086
  df $c 2>&1 | dfst > "$g"; korerun df $c 2>&1 | dfst > "$o"; same "df $c"
done
# mktemp's --suffix (after the random run), --tmpdir= and bare, --dry-run: by the name's shape
MT=$PWD/$ho/.mkt; rm -rf "$MT"; mkdir "$MT"
n1=$(korerun mktemp --tmpdir="$MT" --suffix=.txt); case "$n1" in "$MT"/tmp.??????????.txt) [ -f "$n1" ] || fail "kore mktemp --suffix made nothing";; *) fail "kore mktemp --suffix: $n1";; esac
n2=$(TMPDIR="$MT" korerun mktemp --tmpdir -u); case "$n2" in "$MT"/tmp.??????????) [ ! -e "$n2" ] || fail "kore mktemp --dry-run made one";; *) fail "kore mktemp --tmpdir: $n2";; esac
n3=$(cd "$MT" && LOVE_NO_IMAGE= "$PWD/../../$m" kore mktemp --suffix .c fooXXXXXX); case "$n3" in foo??????.c) ;; *) fail "kore mktemp TEMPLATE --suffix: $n3";; esac
rm -rf "$MT"
# stat -f: GNU's face (its first three lines: the free counts move) and a -c of the fields
# that hold still -- id, name length, the type's magic and name, block sizes, totals
for d in / /tmp; do
  stat -f "$d" | head -3 > "$g"; korerun stat -f "$d" | head -3 > "$o"; same "stat -f $d"
  stat -f -c '%n %i %l %t %T %s %S %b %c' "$d" > "$g"; korerun stat -f -c '%n %i %l %t %T %s %S %b %c' "$d" > "$o"; same "stat -f -c $d"
done
echo "kore: stat/du/date/id/mktemp/chown (GNU-identical, the tree sums, the UTC clock) ok"
