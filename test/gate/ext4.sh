#!/bin/sh
# test/gate/ext4.sh -- src/apps/ext4.l against mke2fs, byte for byte, at sizes that walk its
# rules: one group; a backup; the other inode ratio; a last group too small, dropped; two flex
# groups. mke2fs runs on an empty config with every choice spelled. s_kbytes_written is its own
# count of what it wrote, so each of our superblocks takes the reference's before the cmp.
# skips without mke2fs; takes the love binary as $1.
. test/gate/skip.sh
set -u

love=${1:-out/love}
[ -x "$love" ] || { echo "ext4: no $love -- run 'make host'"; exit 1; }
command -v mke2fs >/dev/null 2>&1 || gate_skip "ext4: no mke2fs, skipped"
w=$(mktemp -d -p /var/tmp) || exit 1
trap 'rm -rf "$w"' EXIT
fail() { echo "FAIL ext4: $*" >&2; exit 1; }

printf '[defaults]\n' > "$w/m.conf"
uu=6b3c3a2e-0000-4000-8000-000000000001 hs=6b3c3a2e-0000-4000-8000-000000000002
cat > "$w/mk.l" <<'EOF'
(borrow 'bytes)
(borrow 'posix)
(borrow 'ext4)
; ours, each superblock copy given the reference's s_kbytes_written: n ref out
(: (after l) (atom? l ? () (<l @ (_ + "mk.l") >l (after >l)))
   as (after cmdline)
   n (read (as 0))
   img (ext4-make n (hex2b "6b3c3a2e000040008000000000000001") (hex2b "6b3c3a2e000040008000000000000002") 1)
   (crc c s) (4294967295 - crc32c-on (4294967295 - c) s)
   (refkb off)
    (openfd (as 1) 0 @ fd (lseek fd (off + 376) 0, (fdopen fd @ p (see p @ c (unsee p c, (chug p @ s (close p, rdle s 0 8)))))))
   (fix b o)
    (: k (img b)
       s (snip k o (o + 1020))
       t (snip s 0 376 + wrle (refkb (b * 4096 + o)) 8 + snip s 384 1020)
       (pin img b (snip k 0 o + t + wrle (crc 4294967295 t) 4 + snip k (o + 1024) 4096)))
   (sb? b) (string? (img b) && rdle (img b) (b = 0 ? 1080 56) 2 = 61267 && b % 32768 = 0)
   _ (each (filter sb? (sort (keys img))) (b \ fix b (b = 0 ? 1024 0)))
   (ext4-write (as 2) img n))
EOF
for n in 16384 76800 153600 262244 786432; do
  rm -f "$w/ref.img" "$w/ours.img"
  truncate -s $((n * 4096)) "$w/ref.img" || fail "cannot make $n blocks"
  i=$([ $((n * 4096)) -lt 536870912 ] && echo 4096 || echo 16384)
  MKE2FS_CONFIG="$w/m.conf" E2FSPROGS_FAKE_TIME=1 mke2fs -q -F -b 4096 -I 256 -m 5 -G 16 -i $i \
    -O has_journal,ext_attr,resize_inode,dir_index,orphan_file,filetype,extent,64bit,flex_bg,metadata_csum_seed,sparse_super,large_file,huge_file,dir_nlink,extra_isize,metadata_csum \
    -U $uu -E hash_seed=$hs,root_owner=0:0,nodiscard,lazy_itable_init=0,lazy_journal_init=1 \
    "$w/ref.img" $n > "$w/mk.log" 2>&1 || { cat "$w/mk.log"; fail "mke2fs refused $n blocks"; }
  "$love" -l src/apps/ext4.l "$w/mk.l" $n "$w/ref.img" "$w/ours.img" > "$w/ours.log" 2>&1 \
    || { tail -5 "$w/ours.log"; fail "ours did not write $n blocks"; }
  cmp -s "$w/ref.img" "$w/ours.img" || fail "$n blocks differ from mke2fs's: $(cmp "$w/ref.img" "$w/ours.img" 2>&1)"
done
echo "ext4: ok (5 sizes byte-identical to mke2fs)"
