#!/bin/sh
# test/kore/fs.sh -- the fs tools, and the failure lane where an effect nif answers -errno
. "$(dirname "$0")/common.sh"

P=$ho/.fsplay
rm -rf "$P"; mkdir "$P"
korerun mkdir -p "$P/a/b/c" && [ -d "$P/a/b/c" ] || fail "kore mkdir -p"
printf 'hi there\n' > "$P/f1"
korerun cp "$P/f1" "$P/f2" && cmp -s "$P/f1" "$P/f2" || fail "kore cp"
korerun cp "$P/f1" "$P/a" && cmp -s "$P/f1" "$P/a/f1" || fail "kore cp into dir"
korerun cp -r "$P/a" "$P/copy" && cmp -s "$P/f1" "$P/copy/f1" && [ -d "$P/copy/b/c" ] || fail "kore cp -r"
korerun cp "$P/a" "$P/nope" > /dev/null 2>&1; r=$?; [ $r -eq 1 ] && [ ! -e "$P/nope" ] || fail "kore cp of a dir without -r (rc $r)"
korerun mv "$P/f2" "$P/f3" && [ ! -e "$P/f2" ] && cmp -s "$P/f1" "$P/f3" || fail "kore mv"
# SRC.. DST: every source lands in the directory, and a target that is not one refuses
# before anything moves. read as two operands, the second source was overwritten, exit 0
mkdir "$P/many"; printf 'two\n' > "$P/g2"
korerun cp "$P/f1" "$P/g2" "$P/many" && cmp -s "$P/f1" "$P/many/f1" && cmp -s "$P/g2" "$P/many/g2" \
  && [ "$(cat "$P/g2")" = two ] || fail "kore cp SRC.. DIR"
korerun cp "$P/f1" "$P/g2" "$P/f3" > /dev/null 2>&1; r=$?
[ $r -eq 1 ] && [ "$(cat "$P/g2")" = two ] || fail "kore cp SRC.. FILE must refuse (rc $r)"
korerun cp "$P/nosuch" "$P/g2" "$P/many/" > /dev/null 2>&1; r=$?
[ $r -eq 1 ] && [ -f "$P/many/g2" ] || fail "kore cp: a missing source costs the status, not the rest (rc $r)"
mkdir "$P/mdst"; printf 'a\n' > "$P/m1"; printf 'b\n' > "$P/m2"
korerun mv "$P/m1" "$P/m2" "$P/mdst" && [ -f "$P/mdst/m1" ] && [ -f "$P/mdst/m2" ] \
  && [ ! -e "$P/m1" ] && [ ! -e "$P/m2" ] || fail "kore mv SRC.. DIR"
printf 'c\n' > "$P/m3"; korerun mv "$P/m3" "$P/f3" "$P/f1" > /dev/null 2>&1; r=$?
[ $r -eq 1 ] && [ -f "$P/m3" ] && [ -f "$P/f3" ] || fail "kore mv SRC.. FILE must refuse (rc $r)"
korerun ln -s f1 "$P/l1" && [ "$(readlink "$P/l1")" = f1 ] || fail "kore ln -s"
korerun ln "$P/f1" "$P/h1" && [ "$P/h1" -ef "$P/f1" ] || fail "kore ln"
korerun touch "$P/new" "$P/.hidden" && [ -f "$P/new" ] && [ -f "$P/.hidden" ] || fail "kore touch"
korerun chmod 600 "$P/f1" && [ "$(stat -c %a "$P/f1")" = 600 ] || fail "kore chmod"
LC_ALL=C ls -1 "$P" > "$g"; korerun ls "$P" > "$o"; same "ls"
# -a carries . and .. the way GNU's does; -A is the one that leaves them out
LC_ALL=C ls -a -1 "$P" > "$g"; korerun ls -a "$P" > "$o"; same "ls -a"
LC_ALL=C ls -A -1 "$P" > "$g"; korerun ls -A "$P" > "$o"; same "ls -A"
[ "$(korerun pwd)" = "$(pwd)" ] || fail "kore pwd"
korerun rm "$P/f3" && [ ! -e "$P/f3" ] || fail "kore rm"
korerun rm -r "$P/a" && [ ! -e "$P/a" ] || fail "kore rm -r"
korerun mkdir "$P/empty" && korerun rmdir "$P/empty" && [ ! -e "$P/empty" ] || fail "kore rmdir"
korerun rm "$P/nope" > /dev/null 2>&1; r=$?; [ $r -eq 1 ] || fail "kore rm miss exit"
korerun rm -f "$P/nope" > /dev/null 2>&1; r=$?; [ $r -eq 0 ] || fail "kore rm -f quiet"
# the build's fs verbs: install lays parents + mode, cmp answers 0/1/2, readlink
# chases -f to GNU's canonical answer
korerun install -D -m 644 "$P/f1" "$P/i/n/dst" && [ "$(stat -c %a "$P/i/n/dst")" = 644 ] \
  && cmp -s "$P/f1" "$P/i/n/dst" || fail "kore install -D -m"
korerun install -d "$P/i/d1/d2" && [ -d "$P/i/d1/d2" ] || fail "kore install -d"
korerun cmp -s "$P/f1" "$P/i/n/dst"; [ $? -eq 0 ] || fail "kore cmp same"
printf 'other\n' > "$P/i/o"
korerun cmp -s "$P/f1" "$P/i/o"; [ $? -eq 1 ] || fail "kore cmp differ"
korerun cmp -s "$P/f1" "$P/i/nope" 2> /dev/null; [ $? -eq 2 ] || fail "kore cmp trouble"
[ "$(korerun readlink "$P/l1")" = "$(readlink "$P/l1")" ] || fail "kore readlink"
ln -sf l1 "$P/l2"
[ "$(korerun readlink -f "$P/l2")" = "$(readlink -f "$P/l2")" ] || fail "kore readlink -f"
# realpath: the message on a miss is GNU's to the byte as well as the answer, and a
# LAST component that is not there yet still answers -- GNU's default, and the case
# a resolver written around stat gets wrong
for q in "$P/l2" "$P/../$(basename "$P")/f1" "$P/i/../i/n" "$P/nosuch"; do
  [ "$(korerun realpath "$q")" = "$(realpath "$q")" ] || fail "kore realpath $q"
done
korerun realpath "$P/nope/x" > "$o" 2> "$ho/.rp-e"; r=$?
realpath "$P/nope/x" > "$g" 2> "$ho/.rp-g"; rg=$?
[ $r -eq $rg ] && cmp -s "$ho/.rp-e" "$ho/.rp-g" || fail "kore realpath miss (rc $r vs $rg)"
[ "$(korerun realpath -m "$P/nope/x")" = "$(realpath -m "$P/nope/x")" ] || fail "kore realpath -m"
korerun realpath -e "$P/nosuch" > /dev/null 2>&1; r=$?; [ $r -eq 1 ] || fail "kore realpath -e"
korerun link "$P/f1" "$P/hard1" && [ "$(stat -c %h "$P/hard1")" -ge 2 ] || fail "kore link"
korerun unlink "$P/hard1" && [ ! -e "$P/hard1" ] || fail "kore unlink"
korerun unlink "$P/hard1" 2>/dev/null; r=$?; [ $r -eq 1 ] || fail "kore unlink miss (rc $r)"
# the failure lane. an effect nif answers () or -errno and BOTH net falsey, so a tool
# that truth-tests its answer instead of asking the kind reports success on every miss.
# one row per tool, because the mistake is per call site.
korerun mkdir "$P/f1/x" > /dev/null 2>&1; r=$?; [ $r -eq 1 ] || fail "kore mkdir under a file (rc $r)"
korerun rmdir "$P/nosuchdir" > /dev/null 2>&1; r=$?; [ $r -eq 1 ] || fail "kore rmdir miss (rc $r)"
korerun chmod 600 "$P/nosuchfile" > /dev/null 2>&1; r=$?; [ $r -eq 1 ] || fail "kore chmod miss (rc $r)"
korerun touch "$P/f1/x" > /dev/null 2>&1; r=$?; [ $r -eq 1 ] || fail "kore touch under a file (rc $r)"
korerun ln -s a "$P/f1/x" > /dev/null 2>&1; r=$?; [ $r -eq 1 ] || fail "kore ln -s under a file (rc $r)"
korerun link "$P/nosuchfile" "$P/n2" > /dev/null 2>&1; r=$?; [ $r -eq 1 ] || fail "kore link miss (rc $r)"
korerun mv "$P/nosuchfile" "$P/n2" > /dev/null 2>&1; r=$?; [ $r -eq 1 ] || fail "kore mv miss (rc $r)"
# mv's cross-device leg: rename answers -EXDEV and mv copies then unlinks instead. only
# where /tmp is a filesystem of its own, which is the only place the leg exists.
if [ "$(stat -c %d /tmp 2>/dev/null)" != "$(stat -c %d "$P" 2>/dev/null)" ]; then
  printf 'xdev\n' > /tmp/.kore-xdev
  korerun mv /tmp/.kore-xdev "$P/xdev" && [ -f "$P/xdev" ] && [ ! -e /tmp/.kore-xdev ] \
    || fail "kore mv cross-device"
fi
# chgrp is chown's :GROUP -- a group we are in by name and by number, and a name the
# group file does not carry is refused before any file is touched
printf 'g\n' > "$P/cg"
korerun chgrp "$(id -gn)" "$P/cg" && [ "$(stat -c %G "$P/cg")" = "$(id -gn)" ] || fail "kore chgrp NAME"
korerun chgrp -R "$(id -g)" "$P/many" || fail "kore chgrp -R GID"
korerun chgrp no-such-group-here "$P/cg" > /dev/null 2>&1; r=$?; [ $r -eq 1 ] || fail "kore chgrp bad group (rc $r)"
# test's file relations: -ef is one file through a hard or a soft link, -nt/-ot the
# mtime, and a file that is not there the older of the two. the answers are GNU's, spelled
# out, since under lush the `test` beside this one may be kore's own
T=$P/rel; mkdir "$T"; : > "$T/old"; sleep 1; printf 'a\n' > "$T/a"; printf 'b\n' > "$T/b"
ln "$T/a" "$T/h"; ln -s a "$T/s"
for c in "0 a -ef h" "0 a -ef s" "1 a -ef b" "1 a -ef none" "0 a -nt old" "1 old -nt a" \
         "0 a -nt none" "1 none -nt a" "0 old -ot a" "1 a -ot old" "0 none -ot a" \
         "1 a -ot none" "0 ! a -ef b" "0 -h s" "0 -L s" "1 -h a" "1 -h none" "0 -c /dev/null" \
         "1 -b /dev/null" "1 -p a" "1 -S a" "1 -u a" "1 -k a"; do
  (cd "$T" && eval "$K kore test ${c#? }"); k=$?
  [ "$k" = "${c%% *}" ] || fail "kore test ${c#? } (got $k, want ${c%% *})"
done
(cd "$T" && "$K" kore [ a -ef h ]) || fail "kore [ a -ef h ]"
# the connectives, POSIX's count rules to four words and the grammar past them (-o
# under -a under ! and parens), GNU's == < >, owner and group, and -t on an fd that
# is no terminal. each answer is GNU's
for c in "0 \\( x \\)" "1 \\( '' \\)" "0 ! ''" "1 ! x" "0 x -a y" "1 x -a ''" "0 '' -o y" \
         "0 ! \\( a = b \\)" "0 \\( a = a \\) -a \\( b = b \\)" "0 a = a -o b = c -a c = d" \
         "1 ! a = b -a c = d" "0 1 -eq 1 -a 2 -eq 3 -o 4 -eq 4" "0 a == a" "0 a \\< b" \
         "1 a \\> b" "0 -f a -a -s a" "1 -f old -a -s old" "1 -e none -o -d none" \
         "0 -O a" "0 -G a" "1 -O none" "1 -t 0" "1 -t 9" "2 -t x" "2 \\( x" "2 a = a -a"; do
  (cd "$T" && eval "$K kore test ${c#? }" < /dev/null); k=$?
  [ "$k" = "${c%% *}" ] || fail "kore test ${c#? } (got $k, want ${c%% *})"
done
# truncate: each size form against GNU's where there is one, else the sizes written out;
# -c makes no file, and GNU's refusals come back as 1
T2=$HO/.trunc; rm -rf "$T2"; mkdir "$T2"
for v in "-s 5" "-s +5" "-s -3" "-s -100" "-s <4" "-s >40" "-s /5" "-s %5" "-s 2K" "-s 1KB" \
         "-r $T2/ref" "-r $T2/ref -s +2" "-o -s 1"; do
  printf 'hello world\n' > "$T2/f"; printf 0123456789 > "$T2/ref"
  korerun truncate $v "$T2/f" || fail "kore truncate $v"
  k=$(wc -c < "$T2/f")
  if command -v truncate >/dev/null 2>&1; then
    printf 'hello world\n' > "$T2/f"; truncate $v "$T2/f"
    [ "$k" -eq "$(wc -c < "$T2/f")" ] || fail "kore truncate $v vs GNU ($k)"
  fi
done
printf 'hello world\n' > "$T2/f"; korerun truncate -s %5 "$T2/f"; [ "$(wc -c < "$T2/f")" -eq 15 ] || fail "kore truncate -s %5"
korerun truncate -c -s 7 "$T2/none"; [ ! -e "$T2/none" ] || fail "kore truncate -c made a file"
korerun truncate -s 9 "$T2/new"; [ "$(wc -c < "$T2/new")" -eq 9 ] || fail "kore truncate made the file"
for v in "" "-s 5" "-s abc $T2/f" "-s /0 $T2/f" "-r $T2/ref -s 3 $T2/f"; do
  korerun truncate $v 2>/dev/null; r=$?; [ $r -eq 1 ] || fail "kore truncate $v is 1 (got $r)"
done
# pathchk: each mode against GNU's -- the verdict, the sentence and the status
PC=$HO/.pathchk; rm -rf "$PC"; mkdir "$PC"; : > "$PC/f"
long=$(printf '%0300d' 0)
pc() { LC_ALL=C pathchk "$@" > "$g" 2>&1; rg=$?; korerun pathchk "$@" > "$o" 2>&1; ro=$?
       same "pathchk $*"; [ "$rg" -eq "$ro" ] || fail "kore pathchk $* exit ($ro vs $rg)"; }
if command -v pathchk >/dev/null 2>&1; then
  pc "$PC/f/x"; pc "$PC/nope/x"; pc "nope/x"; pc "$long"; pc "nope/$long"; pc ""
  pc -p 'a b/c'; pc -p xxxxxxxxxxxxxxxxxxxx; pc -p ''; pc -p "a'b"; pc -p "$(printf 'x\303\251')"
  pc -p "$(printf '%0300d' 0 | sed 's/0000000000/abcdefghi\//g')"
  pc -P -- -x ''; pc -P a//b a/-b; pc -P -; pc --portability /a/b; pc -pP ok/name; pc; pc -q
fi
# mountpoint: util-linux's verdicts off the same mount table
mp() { mountpoint "$@" > "$g" 2>&1; rg=$?; korerun mountpoint "$@" > "$o" 2>&1; ro=$?
       same "mountpoint $*"; [ "$rg" -eq "$ro" ] || fail "kore mountpoint $* exit ($ro vs $rg)"; }
if command -v mountpoint >/dev/null 2>&1 && [ -r /proc/self/mountinfo ]; then
  mp /; mp /proc; mp -d /proc; mp -d /; mp "$PC"; mp -d "$PC"; mp "$PC/f"; mp "$PC/nope"
  mp -q /; mp -q "$PC"; mp --nofollow /; mp -x /dev/null; mp -x "$PC/f"; mp; mp / /proc
  for d in /dev/nvme0n1 /dev/sda /dev/vda; do [ -b "$d" ] && { mp -x "$d"; break; }; done
fi
# shred: the file overwritten where it lies, at GNU's size, and its -v sentences
SH=$HO/.shred; rm -rf "$SH"; mkdir -p "$SH/g" "$SH/o"
printf 'hello\n' > "$SH/a"; cp "$SH/a" "$SH/b"
korerun shred -n 1 "$SH/a" || fail "kore shred"
cmp -s "$SH/a" "$SH/b" && fail "kore shred left the bytes"
if command -v shred >/dev/null 2>&1; then
  shred -n 1 "$SH/b"; [ "$(wc -c < "$SH/a")" -eq "$(wc -c < "$SH/b")" ] || fail "kore shred's size vs GNU's"
  for v in "-v" "-vz" "-vzu" "-vu -n 2" "-vzu -n 0" "-vx -n 1"; do
    printf 'hello\n' > "$SH/g/abc"; printf 'hello\n' > "$SH/o/abc"
    # shellcheck disable=SC2086
    (cd "$SH/g" && LC_ALL=C shred $v abc) 2> "$g"; (cd "$SH/o" && "$K" kore shred $v abc) 2> "$o"
    same "shred $v"
    { [ -e "$SH/g/abc" ] && [ -e "$SH/o/abc" ]; } || { [ ! -e "$SH/g/abc" ] && [ ! -e "$SH/o/abc" ]; } \
      || fail "kore shred $v: the file's fate differs"
  done
  LC_ALL=C shred "$SH/nope" 2> "$g"; rg=$?; korerun shred "$SH/nope" 2> "$o"; ro=$?
  same "shred of no file"; [ "$rg" -eq "$ro" ] || fail "kore shred of no file exit ($ro vs $rg)"
fi
printf 'hello\n' > "$SH/z"; korerun shred -x -z "$SH/z"
[ "$(od -An -tx1 "$SH/z" | tr -d ' \n')" = 000000000000 ] || fail "kore shred -xz is six zeros"
# GNU's arrangement: 30 passes put random first, last, and evenly between
[ "$(korerun shred -v -n 30 "$SH/z" 2>&1 | grep -n random | cut -d: -f1 | tr '\n' ' ')" = "1 11 21 30 " ] \
  || fail "kore shred -n 30's random passes"
head -c 100 /dev/zero > "$SH/s"; korerun shred -x -s 10 -n 1 "$SH/s"
[ "$(tail -c 90 "$SH/s" | od -An -v -tx1 | tr -d ' \n' | tr -d 0)" = "" ] && [ "$(wc -c < "$SH/s")" -eq 100 ] \
  || fail "kore shred -s 10 reached past its ten bytes"
# dircolors: GNU's own database, printed and spelled for both shells under several
# terminals, and a file of the language with its quoting and its complaints
if command -v dircolors >/dev/null 2>&1; then
  DC=$HO/.dircolors; mkdir -p "$DC"
  printf "TERM xterm*\nCOLOR tty\nDIR 01;34\nLINK 01;36 # x\n.tar 01;31\n*.gz 01;31\n*README 00;33\n*# 1\nEXEC 01;32\nOTHER_WRITABLE 34;42\nnormal 0\n.a'b 1\n*x=y 1:2\n" > "$DC/good"
  printf 'TERM xterm\nBOGUS 3\nDIR\n' > "$DC/bad"
  for tm in xterm dumb linux screen-256color; do
    for v in "-b" "-c" "--print-ls-colors" "-b $DC/good" "-c $DC/good" "--print-ls-colors $DC/good" "-b $DC/bad"; do
      # shellcheck disable=SC2086
      TERM=$tm COLORTERM= LC_ALL=C dircolors $v > "$g" 2>&1; rg=$?; TERM=$tm COLORTERM= korerun dircolors $v > "$o" 2>&1; ro=$?
      same "dircolors $v (TERM=$tm)"; [ $rg -eq $ro ] || fail "kore dircolors $v exit ($ro vs $rg)"
    done
  done
  dircolors -p > "$g"; korerun dircolors -p > "$o"; same "dircolors -p"
  COLORTERM=truecolor TERM=dumb dircolors -b > "$g"; COLORTERM=truecolor TERM=dumb korerun dircolors -b > "$o"; same "dircolors under COLORTERM"
fi
# the flag walk: a stranger letter or a flag after an operand refuses before anything is
# done -- read as operands, `rm -i x` removed x and `cp -a s d` counted -a a source
F=$ho/.fsflags; rm -rf "$F"; mkdir "$F"; printf 'keep\n' > "$F/x"
for c in "rm -x $F/x" "rm $F/x -f" "cp -Z $F/x $F/y" "mv -Z $F/x $F/y" "ln -Z $F/x $F/y" "mkdir -Z $F/y" "rmdir -Z $F" "touch -Z $F/y"; do
  # shellcheck disable=SC2086
  korerun $c > /dev/null 2>&1; r=$?; [ $r -eq 2 ] && [ -f "$F/x" ] && [ ! -e "$F/y" ] || fail "kore $c must refuse (rc $r)"
done
# chmod: symbolic modes as GNU's, on a file and a directory; a word that is no mode
# changes nothing -- read as octal, u+x left a 644 file 540
for st in 644 755 4750 1777 0; do
  for md in u+x go-w a=rX u=rwx,g=rx,o= +x =r o+t g+s ug=rw o=u g=u-w u+rw,go-rwx 750 +X =; do
    for k in f d; do
      rm -rf "$F/a" "$F/b"; if [ $k = f ]; then : > "$F/a"; : > "$F/b"; else mkdir "$F/a" "$F/b"; fi
      chmod "$st" "$F/a" "$F/b"; chmod -- "$md" "$F/a"; korerun chmod -- "$md" "$F/b"
      [ "$(stat -c %a "$F/a")" = "$(stat -c %a "$F/b")" ] || fail "kore chmod $md on a $st $k: $(stat -c %a "$F/b"), GNU $(stat -c %a "$F/a")"
    done
  done
done
chmod 644 "$F/x"; korerun chmod u+q "$F/x" 2> /dev/null; r=$?
[ $r -eq 1 ] && [ "$(stat -c %a "$F/x")" = 644 ] || fail "kore chmod of no mode (rc $r, $(stat -c %a "$F/x"))"
mkdir -p "$F/t/s" "$F/out"; chmod 755 "$F/out"; ln -s ../../out "$F/t/s/l"
korerun chmod -R go-rwx "$F/t" && [ "$(stat -c %a "$F/t/s")" = 700 ] && [ "$(stat -c %a "$F/out")" = 755 ] || fail "kore chmod -R through a link"
# rm -r never walks through a link: a link to a directory goes, what it points at stays
printf 'p\n' > "$F/out/precious"
korerun rm -r "$F/t" && [ ! -e "$F/t" ] && [ -f "$F/out/precious" ] || fail "kore rm -r through a link"
ln -s out "$F/lo"; korerun rm -r "$F/lo" && [ ! -e "$F/lo" ] && [ -f "$F/out/precious" ] || fail "kore rm -r of a link to a directory"
: > "$F/i1"; : > "$F/i2"; printf 'n\ny\n' | korerun rm -i "$F/i1" "$F/i2" 2> /dev/null
[ -e "$F/i1" ] && [ ! -e "$F/i2" ] || fail "kore rm -i"
korerun rm -r "$F/." > /dev/null 2>&1; [ -d "$F/out" ] || fail "kore rm -r ."
mkdir "$F/e"; korerun rm -d "$F/e" && [ ! -e "$F/e" ] || fail "kore rm -d"
# cp -a keeps the mode, the time and a link as a link; -n leaves what is there
mkdir "$F/s"; printf 'hi\n' > "$F/s/f"; chmod 640 "$F/s/f"; ln -s f "$F/s/l"; touch -d @1000000000 "$F/s/f"
korerun cp -a "$F/s" "$F/d" && [ "$(stat -c '%a %Y' "$F/d/f")" = "640 1000000000" ] && [ "$(readlink "$F/d/l")" = f ] || fail "kore cp -a"
printf 'new\n' > "$F/n1"; printf 'old\n' > "$F/n2"; korerun cp -n "$F/n1" "$F/n2"; [ "$(cat "$F/n2")" = old ] || fail "kore cp -n"
korerun cp -t "$F/d" "$F/n1" && [ -f "$F/d/n1" ] || fail "kore cp -t"
# ln into a directory, and -sfn over a link to one
mkdir "$F/ld"; korerun ln -s ../n1 "$F/ld" && [ "$(readlink "$F/ld/n1")" = ../n1 ] || fail "kore ln TARGET DIR"
ln -s s "$F/ls"; korerun ln -sfn n2 "$F/ls" && [ "$(readlink "$F/ls")" = n2 ] || fail "kore ln -sfn"
korerun mkdir -m 700 "$F/m7" && [ "$(stat -c %a "$F/m7")" = 700 ] || fail "kore mkdir -m"
korerun mkdir -p "$F/p/q/r" && korerun rmdir -p "$F/p/q/r" 2> /dev/null; [ ! -e "$F/p" ] || fail "kore rmdir -p"
korerun touch -c "$F/nothere"; [ ! -e "$F/nothere" ] || fail "kore touch -c"
korerun touch -r "$F/s/f" "$F/tr" && [ "$(stat -c %Y "$F/tr")" = 1000000000 ] || fail "kore touch -r"
korerun touch -d @1234567890 "$F/tr" && [ "$(stat -c %Y "$F/tr")" = 1234567890 ] || fail "kore touch -d @"
rm -rf "$F"
echo "kore: fs tools (mkdir/cp/mv/ln/touch/chmod/ls/pwd/rm/rmdir/install/cmp/readlink/realpath/link/test/chgrp/truncate/pathchk/mountpoint/shred/dircolors) ok"
