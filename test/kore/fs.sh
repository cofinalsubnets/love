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
         "1 a -ot none" "0 ! a -ef b"; do
  (cd "$T" && eval "$K kore test ${c#? }"); k=$?
  [ "$k" = "${c%% *}" ] || fail "kore test ${c#? } (got $k, want ${c%% *})"
done
(cd "$T" && "$K" kore [ a -ef h ]) || fail "kore [ a -ef h ]"
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
echo "kore: fs tools (mkdir/cp/mv/ln/touch/chmod/ls/pwd/rm/rmdir/install/cmp/readlink/realpath/link/test/chgrp/truncate) ok"
