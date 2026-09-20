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
echo "kore: fs tools (mkdir/cp/mv/ln/touch/chmod/ls/pwd/rm/rmdir/install/cmp/readlink/realpath/link) ok"
