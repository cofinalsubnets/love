#!/bin/sh
# test/gate/sqfs.sh -- src/apps/sqfs.l against mksquashfs, byte for byte: the same tree
# stored uncompressed, no fragments, no exports, root's, one stamp, must be the same image.
# the trees: one of every node and the block edges (an empty file, one of exactly a block, one
# a byte past, a mode, a symlink, a deep path), a directory past 256 entries (the extended
# inode), one past a metadata block (its index points), and the tree's own src/.
# skips without mksquashfs; takes the love binary as $1.
. test/gate/skip.sh
set -u

love=${1:-out/love}
[ -x "$love" ] || { echo "sqfs: no $love -- run 'make host'"; exit 1; }
command -v mksquashfs >/dev/null 2>&1 || gate_skip "sqfs: no mksquashfs, skipped"
w=$(mktemp -d) || exit 1
trap 'rm -rf "$w"' EXIT
fail() { echo "FAIL sqfs: $*" >&2; exit 1; }

t=$w/one; mkdir -p "$t/sub/deep/er" "$t/empty"
printf 'hello\n' > "$t/a.txt"
: > "$t/zero"; chmod 600 "$t/zero"
head -c 131072 /dev/zero | tr '\0' x > "$t/sub/block"
head -c 131073 /dev/zero | tr '\0' y > "$t/sub/block1"
awk 'BEGIN { for (i = 0; i < 40000; i++) printf "%d\n", i * 7919 % 10007 }' > "$t/sub/deep/er/nums"
ln -s a.txt "$t/link"; ln -s sub/deep/er/nums "$t/far"
chmod 750 "$t/sub"
mkdir -p "$w/wide/d"; i=0; while [ $i -lt 300 ]; do : > "$w/wide/d/$i"; i=$((i + 1)); done
mkdir -p "$w/long/d"; i=0; while [ $i -lt 1000 ]; do : > "$w/long/d/name-$i"; i=$((i + 1)); done
cp -r src "$w/src"

for d in one wide long src; do
  mksquashfs "$w/$d" "$w/$d.ref" -noI -noD -noF -noX -no-fragments -no-exports -no-xattrs \
    -all-root -mkfs-time 0 -inode-time 0 -no-duplicates -processors 1 -quiet -no-progress \
    > "$w/mk.log" 2>&1 || { cat "$w/mk.log"; fail "mksquashfs refused $d"; }
  "$love" -l src/apps/sqfs.l -e "(borrow 'sqfs) (uwrite \"$w/$d.ours\" (sqfs-make (sqfs-tree \"$w/$d\") 0))" \
    > /dev/null || fail "ours did not write $d"
  cmp -s "$w/$d.ref" "$w/$d.ours" || fail "$d differs from mksquashfs's: $(cmp "$w/$d.ref" "$w/$d.ours" 2>&1)"
done
echo "sqfs: ok (4 trees byte-identical to mksquashfs)"
