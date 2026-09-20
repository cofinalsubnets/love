#!/bin/sh
# test/kore/patch.sh -- patch: 13 applications compared by the TREE they leave
. "$(dirname "$0")/common.sh"

# THE ORACLE IS THE TREE, not the message. GNU patch's chatter has moved between
# releases; what has not is what it leaves on disk, so every check here runs GNU
# and ours over two identical copies and requires the copies to still match.
pw=$HO/.kore-pw
pset() { rm -rf "$pw"; mkdir -p "$pw/g/sub" "$pw/o/sub"
         printf 'one\ntwo\nthree\nfour\nfive\nsix\nseven\neight\n' > "$pw/base"
         cp "$pw/base" "$pw/g/sub/f.txt"; cp "$pw/base" "$pw/o/sub/f.txt"; }
pmk() { cp "$pw/base" "$pw/new"; sed -i "$1" "$pw/new"
        ( cd "$pw" && diff -u base new \
            | sed -e '1s|^--- base.*|--- a/sub/f.txt|' -e '2s|^+++ new.*|+++ b/sub/f.txt|' ) > "$pw/p.diff"; }
prun() { n=$1; shift
         ( cd "$pw/g" && patch "$@" < "$pw/p.diff" ) >/dev/null 2>&1; a=$?
         ( cd "$pw/o" && LOVE_NO_IMAGE= "$K" kore patch "$@" < "$pw/p.diff" ) >/dev/null 2>&1; b=$?
         diff -r "$pw/g" "$pw/o" > /dev/null 2>&1 && [ $a -eq $b ] \
           || { diff -r "$pw/g" "$pw/o" | head -5; fail "kore patch $n (gnu $a ours $b)"; }; }
pset; pmk 's/three/THREE/; s/seven/SEVEN/'; prun "two hunks" -p1
pset; pmk 's/three/THREE/; s/seven/SEVEN/'
( cd "$pw/g" && patch -p1 < "$pw/p.diff" ) >/dev/null 2>&1
( cd "$pw/o" && LOVE_NO_IMAGE= "$K" kore patch -p1 < "$pw/p.diff" ) >/dev/null 2>&1
prun "-R puts it back" -p1 -R
# an offset: a line inserted ahead of the hunk moves it, and both must find it there
pset; pmk 's/three/THREE/; s/seven/SEVEN/'
for s in g o; do ( cd "$pw/$s/sub" && printf 'zero\n' > t && cat f.txt >> t && mv t f.txt ); done
prun "offset (and the .orig a mismatch leaves)" -p1
pset; pmk 's/three/THREE/'; prun "--dry-run touches nothing" -p1 --dry-run
# no -p at all: the basename, which is why `patch < p` works from inside the directory
pset; pmk 's/four/FOUR/'
( cd "$pw/g/sub" && patch < "$pw/p.diff" ) >/dev/null 2>&1; a=$?
( cd "$pw/o/sub" && LOVE_NO_IMAGE= "$K" kore patch < "$pw/p.diff" ) >/dev/null 2>&1; b=$?
diff -r "$pw/g" "$pw/o" > /dev/null 2>&1 && [ $a -eq $b ] || fail "kore patch (no -p)"
# a create (--- /dev/null), whose -0,0 seat is the one the search has to reach
pset; printf 'x\ny\nz\n' > "$pw/new"
( cd "$pw" && diff -u /dev/null new | sed -e '2s|^+++ new.*|+++ b/sub/new.txt|' ) > "$pw/p.diff"
prun "creates a file" -p1
# the missing final newline, BOTH directions -- the `\ No newline` line carries no
# count of its own, so the one closing a hunk arrives after the counts are spent
pset; printf 'a\nb\nc' > "$pw/base"
cp "$pw/base" "$pw/g/sub/f.txt"; cp "$pw/base" "$pw/o/sub/f.txt"
pmk 's/c/C/'; prun "a source with no final newline" -p1
pset; printf 'a\nb\nc\n' > "$pw/base"
cp "$pw/base" "$pw/g/sub/f.txt"; cp "$pw/base" "$pw/o/sub/f.txt"
printf 'a\nb\nC' > "$pw/new"
( cd "$pw" && diff -u base new \
    | sed -e '1s|^--- base.*|--- a/sub/f.txt|' -e '2s|^+++ new.*|+++ b/sub/f.txt|' ) > "$pw/p.diff"
prun "the patch takes the newline away" -p1
# many hunks over a longer file, so the running delta gets exercised
pset; seq 1 200 > "$pw/base"
cp "$pw/base" "$pw/g/sub/f.txt"; cp "$pw/base" "$pw/o/sub/f.txt"
pmk 's/^7$/SEVEN/; s/^70$/SEVENTY/; s/^133$/ONETHIRTYTHREE/; 40d; 100i\INSERTED'
prun "many hunks" -p1
# -i names the patch, -p2 strips deeper, and two files ride one patch
pset; pmk 's/two/TWO/'
sed -i -e '1s|.*|--- x/y/sub/f.txt|' -e '2s|.*|+++ x/y/sub/f.txt|' "$pw/p.diff"
( cd "$pw/g" && patch -p2 -i "$pw/p.diff" ) >/dev/null 2>&1; a=$?
( cd "$pw/o" && LOVE_NO_IMAGE= "$K" kore patch -p2 -i "$pw/p.diff" ) >/dev/null 2>&1; b=$?
diff -r "$pw/g" "$pw/o" > /dev/null 2>&1 && [ $a -eq $b ] || fail "kore patch -p2 -i"
pset
printf 'aa\nbb\n' > "$pw/g/sub/g.txt"; cp "$pw/g/sub/g.txt" "$pw/o/sub/g.txt"
{ printf -- '--- a/sub/f.txt\n+++ b/sub/f.txt\n@@ -1,3 +1,3 @@\n one\n-two\n+TWO\n three\n'
  printf -- '--- a/sub/g.txt\n+++ b/sub/g.txt\n@@ -1,2 +1,2 @@\n aa\n-bb\n+BB\n'; } > "$pw/p.diff"
prun "two files in one patch" -p1
# a hunk with nowhere to go: exit 1, the file half-applied the same way, and a .rej
pset; pmk 's/three/THREE/; s/seven/SEVEN/'
for s in g o; do printf 'nope\nnope\nnope\nnope\nnope\nnope\nnope\nnope\n' > "$pw/$s/sub/f.txt"; done
( cd "$pw/g" && patch -p1 < "$pw/p.diff" ) >/dev/null 2>&1; a=$?
( cd "$pw/o" && LOVE_NO_IMAGE= "$K" kore patch -p1 < "$pw/p.diff" ) >/dev/null 2>&1; b=$?
[ $a -eq 1 ] && [ $b -eq 1 ] && cmp -s "$pw/g/sub/f.txt" "$pw/o/sub/f.txt" \
  && [ -f "$pw/o/sub/f.txt.rej" ] && [ -f "$pw/o/sub/f.txt.orig" ] \
  || fail "kore patch reject (gnu $a ours $b)"
cmp -s "$pw/g/sub/f.txt.rej" "$pw/o/sub/f.txt.rej" || fail "kore patch .rej vs GNU"
# the .orig is the file AS IT WAS, which here is the unrelated one -- so the reject
# is re-applied to the tree the patch was cut against, and that is the real claim: a
# .rej we wrote is a patch our own reader takes back.
cp "$pw/base" "$pw/o/sub/f.txt"
( cd "$pw/o/sub" && LOVE_NO_IMAGE= "$K" kore patch f.txt < f.txt.rej ) >/dev/null 2>&1 \
  || fail "kore patch: the .rej does not re-apply"
cmp -s "$pw/o/sub/f.txt" "$pw/new" || fail "kore patch: the re-applied .rej lands elsewhere"
echo "kore: patch (13 applications leaving the same tree GNU patch does -- offsets, creates, rejects, the newline) ok"
