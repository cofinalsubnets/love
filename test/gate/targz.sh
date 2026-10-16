#!/bin/sh
# test/gate/targz.sh -- src/apps/tar.l and gz.l against GNU tar and gzip, both directions,
# over a tree of header shapes: a symlink, mode 0600, an empty file, an exact 512, a deep path.
# usage: targz.sh LOVE; skips without tar or gzip
. test/gate/skip.sh
set -e

love=${1:-b/love}
[ -x "$love" ] || { echo "targz: no $love -- run 'make host'"; exit 1; }
command -v tar  >/dev/null 2>&1 || gate_skip "targz: no system tar, skipped"
command -v gzip >/dev/null 2>&1 || gate_skip "targz: no system gzip, skipped"

w=$(mktemp -d)
trap 'rm -rf "$w"' EXIT
r=$(pwd)

mkdir -p "$w/tree/sub/deep"
printf 'alpha\n'                        > "$w/tree/a.txt"
: >                                       "$w/tree/empty"
printf 'beta beta beta beta beta beta\n' > "$w/tree/sub/b.txt"
head -c 512  /dev/urandom               > "$w/tree/sub/exact512.bin"
head -c 4096 /dev/urandom               > "$w/tree/sub/deep/blob.bin"
# past tar-hash's 64 KB read buffer: one body, several chunks
head -c 200000 /dev/urandom             > "$w/tree/sub/deep/big.bin"
cat src/apps/gz.l src/apps/tar.l                  > "$w/tree/text.l"
ln -s a.txt "$w/tree/link"
chmod 0600 "$w/tree/sub/b.txt"

fail() { echo "FAIL targz: $*"; exit 1; }

# ---- 1. we write, they read ------------------------------------------------
cat > "$w/pack.l" <<EOF
(borrow 'posix)
(borrow 'tar)
(borrow 'gz)
(: g (tar-gather "$w/tree" "")
   _ (? (! g) (: _ (say err "gather failed\n") (quit 1)) 0)
   a (tar-pack (<(>g)))
   _ (? (! a) (: _ (say err "pack failed\n") (quit 1)) 0)
   z (gz-zip a "" 0)
   q (open "$w/ours.tar.gz" "w") _ (say q z) _ (close q)
   p (open "$w/ours.tar" "w") _ (say p a) _ (close p)
   0)
EOF
"$love" "$w/pack.l" || fail "love could not write the archive"
[ -s "$w/ours.tar.gz" ] || fail "love wrote an empty .tar.gz"

gzip -t "$w/ours.tar.gz" || fail "system gzip rejects our .gz container"
tar tzf "$w/ours.tar.gz" > /dev/null || fail "system tar cannot list our .tar.gz"
mkdir -p "$w/theirs"
( cd "$w/theirs" && tar xzf "$w/ours.tar.gz" ) || fail "system tar cannot extract our .tar.gz"
diff -r "$w/tree" "$w/theirs" || fail "system tar's extraction of our archive differs"
[ -L "$w/theirs/link" ] || fail "the symlink came out as a regular file"
[ "$(readlink "$w/theirs/link")" = a.txt ] || fail "the symlink target is wrong"
m=$(stat -c %a "$w/theirs/sub/b.txt")
[ "$m" = 600 ] || fail "mode not preserved through our writer (got $m, want 600)"
echo "  OK we write, GNU tar + gzip read -- tree identical, symlink and mode intact"

# ---- 2. they write, we read ------------------------------------------------
( cd "$w/tree" && tar czf "$w/theirs.tar.gz" . )
mkdir -p "$w/ours"
cat > "$w/unpack.l" <<EOF
(borrow 'posix)
(borrow 'tar)
(borrow 'gz)
(: q (open "$w/theirs.tar.gz" "r") z (: s (slurp q) _ (close q) (s + ""))
   u (gz-unzip z)
   _ (? (! u) (: _ (say err "gunzip failed\n") (quit 1)) 0)
   r (tar-unpack (<(>u)))
   _ (? (! r) (: _ (say err "untar failed\n") (quit 1)) 0)
   w (tar-scatter "$w/ours" (<(>r)))
   _ (? (! w) (: _ (say err "scatter failed\n") (quit 1)) 0)
   0)
EOF
"$love" "$w/unpack.l" || fail "love could not read the system's .tar.gz"
diff -r "$w/tree" "$w/ours" || fail "our extraction of the system archive differs"
# diff -r compares bytes, not modes: the modes are their own list
( cd "$w/tree" && find . -type f | sort | xargs stat -c '%a %n' ) > "$w/modes.want"
( cd "$w/ours" && find . -type f | sort | xargs stat -c '%a %n' ) > "$w/modes.got"
diff "$w/modes.want" "$w/modes.got" || fail "our extraction did not preserve file modes"
echo "  OK GNU tar + gzip write, we read -- tree identical, modes preserved"

# ---- 3. the gzip container alone, both ways, over shapes that break coders --
for f in tree/text.l tree/sub/deep/blob.bin tree/empty; do
  src="$w/$f"
  cat > "$w/one.l" <<EOF
(borrow 'posix)
(borrow 'gz)
(: q (open "$src" "r") s (: t (slurp q) _ (close q) (t + ""))
   z (gz-zip s "" 0)
   o (open "$w/one.gz" "w") _ (say o z) _ (close o)
   0)
EOF
  "$love" "$w/one.l" || fail "love could not gzip $f"
  gzip -dc "$w/one.gz" | cmp - "$src" || fail "system gunzip disagrees on $f"
  # ..and the reverse at -9, where gzip's dynamic codes differ from ours
  gzip -9 -c "$src" > "$w/theirs.gz"
  cat > "$w/one2.l" <<EOF
(borrow 'posix)
(borrow 'gz)
(: q (open "$w/theirs.gz" "r") z (: t (slurp q) _ (close q) (t + ""))
   u (gz-unzip z)
   _ (? (! u) (: _ (say err "unzip failed\n") (quit 1)) 0)
   o (open "$w/back" "w") _ (say o (<(>u))) _ (close o)
   0)
EOF
  "$love" "$w/one2.l" || fail "love could not gunzip gzip -9's output for $f"
  cmp "$w/back" "$src" || fail "we disagree with gzip -9 on $f"
done
echo "  OK gzip container both ways (text, incompressible, empty; -9 dynamic codes read)"

# ---- 4. the command faces: gzip, gunzip, zcat (src/apps/gz.l) --------------
# the suffix rules, the in-place replace, mode and mtime carried, the flags, the statuses
c="$w/cmd"; mkdir -p "$c"
head -c 20000 /etc/services > "$c/f.txt" 2>/dev/null || cat src/apps/gz.l > "$c/f.txt"
cp "$c/f.txt" "$c/g.txt"
chmod 0640 "$c/f.txt"
touch -d '2021-02-03 04:05:06' "$c/f.txt"

# ours out, GNU in -- and the input is GONE, the mode and the mtime carried over
( cd "$c" && "$r/$love" gzip f.txt ) || fail "gzip exit"
[ ! -e "$c/f.txt" ] || fail "gzip left the input behind"
gzip -t "$c/f.txt.gz" || fail "system gzip rejects ours"
gunzip -c "$c/f.txt.gz" | cmp - "$c/g.txt" || fail "system gunzip disagrees with our gzip"
[ "$(stat -c %a "$c/f.txt.gz")" = 640 ] || fail "gzip did not carry the mode over"
[ "$(stat -c %Y "$c/f.txt.gz")" = "$(date -d '2021-02-03 04:05:06' +%s)" ] \
  || fail "gzip did not carry the mtime over"

# GNU out, ours in -- -k keeps the .gz for the checks below
cp "$c/g.txt" "$c/gsave.txt"
gzip -9 "$c/g.txt"
( cd "$c" && "$r/$love" gunzip -k g.txt.gz ) || fail "gunzip exit"
cmp "$c/g.txt" "$c/gsave.txt" || fail "gunzip differs from the original"
[ -e "$c/g.txt.gz" ] || fail "gunzip -k removed the input"

# the filter, both directions, and zcat
cat "$c/g.txt" | "$love" gzip | gunzip -c | cmp - "$c/g.txt" || fail "gzip filter"
gzip -c "$c/g.txt" | "$love" zcat | cmp - "$c/g.txt" || fail "zcat"
"$love" gzip -c "$c/g.txt" | "$love" gunzip -c | cmp - "$c/g.txt" || fail "our own round trip"

# -l, byte-identical to GNU's over a file GNU wrote
gzip -l "$c/g.txt.gz" > "$w/l.want" 2>/dev/null
"$love" gzip -l "$c/g.txt.gz" > "$w/l.got" 2>/dev/null
cmp -s "$w/l.want" "$w/l.got" || { diff "$w/l.want" "$w/l.got"; fail "gzip -l vs GNU"; }

# -t: quiet on a good member, 1 on a torn one. under set -e a status is caught with `|| e=$?`
run() { e=0; "$@" > /dev/null 2>&1 || e=$?; }
"$love" gzip -t "$c/g.txt.gz" || fail "gzip -t on a good member"
head -c 200 "$c/g.txt.gz" > "$c/torn.gz"
run "$love" gzip -t "$c/torn.gz";     [ $e -eq 1 ] || fail "gzip -t on a torn member ($e)"

# the statuses: a miss is 1, a name that is not a member is 1, a suffix that says
# nothing is 2, and an output already there is 2 until -f says otherwise
run "$love" gzip "$c/nosuch";         [ $e -eq 1 ] || fail "gzip miss exit ($e)"
run "$love" gunzip -c "$c/g.txt";     [ $e -eq 1 ] || fail "gunzip not-gzip exit ($e)"
run "$love" gunzip "$c/g.txt";        [ $e -eq 2 ] || fail "gunzip unknown suffix exit ($e)"
cp "$c/g.txt" "$c/h.txt"; : > "$c/h.txt.gz"
run "$love" gzip "$c/h.txt";          [ $e -eq 2 ] || fail "gzip existing output exit ($e)"
[ -e "$c/h.txt" ] || fail "gzip removed the input it refused to replace"
"$love" gzip -f "$c/h.txt" || fail "gzip -f exit"
gunzip -c "$c/h.txt.gz" | cmp - "$c/g.txt" || fail "gzip -f wrote the wrong bytes"

# -S, -N, -r, and the levels a script spends
cp "$c/g.txt" "$c/s.txt"
"$love" gzip -S .zz "$c/s.txt" && [ -e "$c/s.txt.zz" ] || fail "gzip -S"
"$love" gunzip -S .zz "$c/s.txt.zz" && cmp "$c/s.txt" "$c/g.txt" || fail "gunzip -S"
cp "$c/g.txt" "$c/named.txt"
"$love" gzip -9 "$c/named.txt" || fail "gzip -9 (a level is taken, not refused)"
mv "$c/named.txt.gz" "$c/other.gz"
( cd "$c" && "$r/$love" gunzip -N other.gz ) || fail "gunzip -N"
[ -e "$c/named.txt" ] || fail "gunzip -N did not take the stored name back"
# ..and from elsewhere: the stored name lands beside the archive, not in the cwd
mkdir -p "$c/nd" "$c/elsewhere"
cp "$c/g.txt" "$c/nd/stored.txt"
"$love" gzip -N "$c/nd/stored.txt" || fail "gzip -N"
mv "$c/nd/stored.txt.gz" "$c/nd/moved.gz"
( cd "$c/elsewhere" && "$r/$love" gunzip -N "$c/nd/moved.gz" ) || fail "gunzip -N elsewhere"
[ -e "$c/nd/stored.txt" ] || fail "gunzip -N did not restore beside the archive"
[ -e "$c/elsewhere/stored.txt" ] && fail "gunzip -N dropped the file in the cwd"
mkdir -p "$c/tree/in"; cp "$c/g.txt" "$c/tree/in/r1.txt"; cp "$c/g.txt" "$c/tree/r2.txt"
"$love" gzip -r "$c/tree" || fail "gzip -r"
[ -e "$c/tree/in/r1.txt.gz" ] && [ -e "$c/tree/r2.txt.gz" ] || fail "gzip -r missed a file"
"$love" gunzip -r "$c/tree" || fail "gunzip -r"
cmp "$c/tree/in/r1.txt" "$c/g.txt" || fail "gunzip -r differs"
echo "  OK the command faces -- gzip/gunzip/zcat, the suffixes, the statuses, -l vs GNU"

# ---- 5. tar-hash's streamed digest equals sha256 of the packed archive -------
cat > "$w/hash.l" <<EOF
(borrow 'tar)
(borrow 'hashes)
(: g (tar-gather? (\ _ 1) "$w/tree" "")
   t (tar-thin? (\ _ 1) "$w/tree" "")
   _ (? (g && t) 0 (: _ (say err "walk failed\n") (quit 1)))
   a (tar-pack (tar-level (<(>g)) 0))
   _ (? a 0 (: _ (say err "pack failed\n") (quit 1)))
   h1 (sha256 a)
   h2 (tar-hash (tar-level (<(>t)) 0))
   _ (? (string? h2) 0 (: _ (say err "tar-hash answered ()\n") (quit 1)))
   _ (? (= h1 h2) 0 (: _ (say err ("packed " + h1 + " streamed " + h2 + "\n")) (quit 1)))
   0)
EOF
"$love" "$w/hash.l" || fail "tar-hash disagrees with sha256 of tar-pack"
echo "  OK the streamed archive digest equals the packed one"

# ---- 6. a lay under umask 077 keeps every mode, dirs too, and re-packs to the same sha
mkdir -p "$w/um"
cat > "$w/unpack6.l" <<EOF
(borrow 'posix)
(borrow 'tar)
(borrow 'gz)
(: q (open "$w/ours.tar.gz" "r") z (: s (slurp q) _ (close q) (s + ""))
   u (gz-unzip z)
   _ (? (! u) (: _ (say err "gunzip failed\n") (quit 1)) 0)
   r (tar-unpack (<(>u)))
   _ (? (! r) (: _ (say err "untar failed\n") (quit 1)) 0)
   v (tar-scatter "$w/um" (<(>r)))
   _ (? (! v) (: _ (say err "scatter failed\n") (quit 1)) 0)
   0)
EOF
( umask 077; "$love" "$w/unpack6.l" ) || fail "love could not lay the archive under umask 077"
( cd "$w/tree" && find . -mindepth 1 \( -type f -o -type d \) | sort | xargs stat -c '%a %n' ) > "$w/m6.want"
( cd "$w/um"   && find . -mindepth 1 \( -type f -o -type d \) | sort | xargs stat -c '%a %n' ) > "$w/m6.got"
diff "$w/m6.want" "$w/m6.got" || fail "a lay under umask 077 lost the archived modes"
cat > "$w/repack6.l" <<EOF
(borrow 'tar)
(borrow 'hashes)
(: g1 (tar-gather "$w/tree" "")
   g2 (tar-gather "$w/um" "")
   _ (? (g1 && g2) 0 (: _ (say err "walk failed\n") (quit 1)))
   a1 (tar-pack (tar-level (<(>g1)) 0))
   a2 (tar-pack (tar-level (<(>g2)) 0))
   _ (? (a1 && a2) 0 (: _ (say err "pack failed\n") (quit 1)))
   h1 (sha256 a1)
   h2 (sha256 a2)
   _ (? (= h1 h2) 0 (: _ (say err ("tree " + h1 + " relaid " + h2 + "\n")) (quit 1)))
   0)
EOF
"$love" "$w/repack6.l" || fail "the re-pack of a 077 lay is not the pack of the tree"
echo "  OK a lay under umask 077 keeps every archived mode, dirs included, and re-packs to one sha"

echo "targz: src/apps/tar.l + src/apps/gz.l agree with GNU tar and GNU gzip both ways -- ok"
