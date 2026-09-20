#!/bin/sh
# test/kore/sum.sh -- cksum, md5sum, sha256sum over the block boundaries, -c both ways round
. "$(dirname "$0")/common.sh"

# cksum, md5sum and sha256sum against GNU. these three are the tools whose entire
# output is one number, so a single wrong byte in inle/hash.c is a wrong line here and
# nowhere else. THE LENGTHS ARE THE POINT of the battery: a digest pads its last block
# with the message length in the final 8 bytes, so 55/56 and 119/120 are where a pad
# off by one shows, and 0 is where cksum's own length fold does (an empty file is
# 4294967295 0, not 0 0).
ck=$ho/.kore-ck
rm -rf "$ck"; mkdir -p "$ck"
as() { i=0; s=; while [ "$i" -lt "$1" ]; do s=$s"a"; i=$((i + 1)); done; printf '%s' "$s"; }
for n in 0 1 55 56 57 63 64 65 119 120 128 1000; do as "$n" > "$ck/n$n"; done
printf '\0\1\2\377\376abc\n' > "$ck/bin"        # NULs and high bytes: bytes, not text
printf 'hello\nworld\n' > "$ck/a"
for t in cksum md5sum sha256sum; do
  for n in 0 1 55 56 57 63 64 65 119 120 128 1000; do both "$t n$n" $t "$ck/n$n"; done
  both "$t binary" $t "$ck/bin"
  both "$t many"   $t "$ck/a" "$ck/bin" "$ck/n0"
  both "$t missing" $t "$ck/nope"                # the unreadable operand, stdout and all
  pipe "$t stdin" 'hello
world
' $t
done
# -c: the list one run writes is the list the other reads, both ways round -- which is
# the only claim that matters for a checksum file, and it fails if either side's line
# shape is off by a space. the mismatch lane carries its own exit code.
( cd "$ck" && LOVE_NO_IMAGE= "$K" kore sha256sum a bin n64 > sums.ours )
( cd "$ck" && sha256sum a bin n64 > sums.gnu )
cmp -s "$ck/sums.ours" "$ck/sums.gnu" || fail "sha256sum's list is not GNU's"
for l in sums.ours sums.gnu; do
  ( cd "$ck" && sha256sum -c "$l" ) > "$g" 2>/dev/null; rg=$?
  ( cd "$ck" && LOVE_NO_IMAGE= "$K" kore sha256sum -c "$l" ) > "$o" 2>/dev/null; ro=$?
  same "sha256sum -c $l"
  [ "$rg" -eq "$ro" ] || fail "sha256sum -c $l exit ($rg vs $ro)"
done
( cd "$ck" && md5sum a bin > m.ours ) && ( cd "$ck" && md5sum -c m.ours ) > "$g" 2>/dev/null
( cd "$ck" && LOVE_NO_IMAGE= "$K" kore md5sum -c m.ours ) > "$o" 2>/dev/null
same "md5sum -c"
# the other shapes a list wears: the ` *` marker GNU writes under -b, and upper-case hex
( cd "$ck" && sha256sum -b a bin > b.list )
awk '{ print toupper($1) "  " $2 }' "$ck/sums.gnu" > "$ck/up.list"
for l in b.list up.list; do
  ( cd "$ck" && sha256sum -c "$l" ) > "$g" 2>/dev/null; rg=$?
  ( cd "$ck" && LOVE_NO_IMAGE= "$K" kore sha256sum -c "$l" ) > "$o" 2>/dev/null; ro=$?
  same "sha256sum -c $l"
  [ "$rg" -eq "$ro" ] || fail "sha256sum -c $l exit ($rg vs $ro)"
done
# ..and the shapes that are NOT a list. a file of prose has no checksum line in it, and
# saying so is the whole answer -- a looser reader takes every line with a space in it
# for a checksum and reports a page of failures instead.
printf 'not a checksum line\nnor this one\n' > "$ck/prose"
( cd "$ck" && sha256sum -c prose ) > "$g" 2>/dev/null; rg=$?
( cd "$ck" && LOVE_NO_IMAGE= "$K" kore sha256sum -c prose ) > "$o" 2>/dev/null; ro=$?
same "sha256sum -c over prose"
[ "$rg" -eq 1 ] && [ "$ro" -eq 1 ] || fail "sha256sum -c prose exit ($rg vs $ro)"
# a corrupted line must FAIL, say so on stdout, and leave with 1
printf '%s  a\n' 0000000000000000000000000000000000000000000000000000000000000000 > "$ck/bad"
( cd "$ck" && sha256sum -c bad ) > "$g" 2>/dev/null; rg=$?
( cd "$ck" && LOVE_NO_IMAGE= "$K" kore sha256sum -c bad ) > "$o" 2>/dev/null; ro=$?
same "sha256sum -c mismatch"
[ "$rg" -eq 1 ] && [ "$ro" -eq 1 ] || fail "sha256sum -c mismatch exit ($rg vs $ro)"
# A DIRECTORY OPENS AND SLURPS EMPTY, so an unguarded digest of one is the digest of
# nothing -- a plausible number, which is worse than none. GNU refuses it and so do we.
mkdir -p "$ck/dir"
for t in cksum md5sum sha256sum; do
  $t "$ck/dir" > "$g" 2>/dev/null; rg=$?
  korerun $t "$ck/dir" > "$o" 2>/dev/null; ro=$?
  same "$t on a directory"
  [ "$rg" -eq 1 ] && [ "$ro" -eq 1 ] || fail "$t on a directory exit ($rg vs $ro)"
done
echo "kore: checksums (cksum/md5sum/sha256sum GNU-identical over the block boundaries, -c both ways round) ok"
