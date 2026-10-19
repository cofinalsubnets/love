#!/bin/sh
# test/kore/sum.sh -- cksum, sum and the digest tools over the block boundaries, -c both ways round
. "$(dirname "$0")/common.sh"

# the lengths are the point: a digest pads its last block with the length, so 55/56 and
# 119/120 (111/112, 239/240 for sha-384/512; 128, 256 for blake2b's held block) show a pad
# off by one, and 0 shows cksum's length fold (empty is 4294967295 0)
ck=$ho/.kore-ck
rm -rf "$ck"; mkdir -p "$ck"
as() { i=0; s=; while [ "$i" -lt "$1" ]; do s=$s"a"; i=$((i + 1)); done; printf '%s' "$s"; }
lens="0 1 55 56 57 63 64 65 111 112 119 120 127 128 129 239 240 256 257 1000"
for n in $lens; do as "$n" > "$ck/n$n"; done
printf '\0\1\2\377\376abc\n' > "$ck/bin"        # NULs and high bytes: bytes, not text
printf 'hello\nworld\n' > "$ck/a"
tools="cksum sum md5sum sha1sum sha224sum sha256sum sha384sum sha512sum b2sum"
for t in $tools; do
  for n in $lens; do both "$t n$n" $t "$ck/n$n"; done
  both "$t binary" $t "$ck/bin"
  both "$t many"   $t "$ck/a" "$ck/bin" "$ck/n0"
  both "$t missing" $t "$ck/nope"                # the unreadable operand, stdout and all
  pipe "$t stdin" 'hello
world
' $t
done
# -c: each side's list read by the other, a space off in a line shape fails; the mismatch
# lane has its own exit code
( cd "$ck" && LOVE_NO_IMAGE= "$K" sha256sum a bin n64 > sums.ours )
( cd "$ck" && sha256sum a bin n64 > sums.gnu )
cmp -s "$ck/sums.ours" "$ck/sums.gnu" || fail "sha256sum's list is not GNU's"
for l in sums.ours sums.gnu; do bothrc -C "$ck" "sha256sum -c $l" sha256sum -c "$l"; done
( cd "$ck" && md5sum a bin > m.ours ) && ( cd "$ck" && md5sum -c m.ours ) > "$g" 2>/dev/null
( cd "$ck" && LOVE_NO_IMAGE= "$K" md5sum -c m.ours ) > "$o" 2>/dev/null
same "md5sum -c"
# a list's other shapes: -b's ` *` marker, and upper-case hex
( cd "$ck" && sha256sum -b a bin > b.list )
awk '{ print toupper($1) "  " $2 }' "$ck/sums.gnu" > "$ck/up.list"
for l in b.list up.list; do bothrc -C "$ck" "sha256sum -c $l" sha256sum -c "$l"; done
# prose has no checksum line, and saying so is the whole answer
printf 'not a checksum line\nnor this one\n' > "$ck/prose"
bothrc -C "$ck" "sha256sum -c over prose" sha256sum -c prose
[ $rg -eq 1 ] || fail "sha256sum -c prose exit $rg"
# a corrupted line fails, says so on stdout, and exits 1
printf '%s  a\n' 0000000000000000000000000000000000000000000000000000000000000000 > "$ck/bad"
bothrc -C "$ck" "sha256sum -c mismatch" sha256sum -c bad
[ $rg -eq 1 ] || fail "sha256sum -c mismatch exit $rg"
# a directory reads empty, so its unguarded digest is a plausible lie; it is refused
mkdir -p "$ck/dir"
for t in $tools; do
  bothrc "$t on a directory" $t "$ck/dir"
  [ $rg -eq 1 ] || fail "$t on a directory exit $rg"
done
# every digest tool's list read back by the other side
for t in md5sum sha1sum sha224sum sha384sum sha512sum b2sum; do
  ( cd "$ck" && $t a bin n128 > $t.gnu ) && ( cd "$ck" && LOVE_NO_IMAGE= "$K" $t a bin n128 > $t.ours )
  cmp -s "$ck/$t.gnu" "$ck/$t.ours" || fail "$t's list is not GNU's"
  ( cd "$ck" && LOVE_NO_IMAGE= "$K" $t -c $t.gnu ) > "$o" 2>/dev/null; ro=$?
  ( cd "$ck" && $t -c $t.ours ) > "$g" 2>/dev/null; rg=$?
  same "$t -c"
  [ "$rg" -eq 0 ] && [ "$ro" -eq 0 ] || fail "$t -c exit ($rg vs $ro)"
done
# sum's two algorithms; a named operand, "-" too, is said
for f in "-r" "-s" "-rs" "-sr"; do both "sum $f" sum $f "$ck/a" "$ck/bin"; done
pipe "sum -s stdin" 'hello
' sum -s
pipe "sum - " 'hello
' sum -
# b2sum's shorter digests, and -c reading any length a line carries
for l in 8 256 504; do both "b2sum -l $l" b2sum -l $l "$ck/a" "$ck/n129"; done
( cd "$ck" && b2sum -l 256 a bin > b2.256 )
( cd "$ck" && LOVE_NO_IMAGE= "$K" b2sum -c b2.256 ) > "$o" 2>/dev/null; ro=$?
( cd "$ck" && b2sum -c b2.256 ) > "$g" 2>/dev/null
same "b2sum -c of a 256-bit list"
[ "$ro" -eq 0 ] || fail "b2sum -c 256 exit $ro"
for l in 12 520 x; do
  LC_ALL=C b2sum -l $l "$ck/a" > "$g" 2>&1; rg=$?
  korerun b2sum -l $l "$ck/a" > "$o" 2>&1; ro=$?
  same "b2sum -l $l refused"
  [ "$rg" -eq "$ro" ] || fail "b2sum -l $l exit ($rg vs $ro)"
done
# sha3sum and crc32 against busybox's (sha3sum -a any of 128..512, 224 by default), lists read back
if command -v busybox >/dev/null 2>&1; then
  for a in 224 256 384 512; do
    for n in $lens; do
      busybox sha3sum -a $a "$ck/n$n" > "$g"; korerun sha3sum -a $a "$ck/n$n" > "$o"; same "sha3sum -a $a n$n"
    done
  done
  busybox sha3sum "$ck/a" "$ck/bin" > "$g"; korerun sha3sum "$ck/a" "$ck/bin" > "$o"; same "sha3sum's default"
  korerun sha3sum -a 512 "$ck/a" "$ck/bin" > "$ck/s3.list"
  busybox sha3sum -a 512 -c "$ck/s3.list" > "$g" 2>&1; korerun sha3sum -a 512 -c "$ck/s3.list" > "$o" 2>&1; same "sha3sum -c"
  busybox crc32 "$ck/a" "$ck/bin" "$ck/n1000" > "$g"; korerun crc32 "$ck/a" "$ck/bin" "$ck/n1000" > "$o"; same "crc32"
  busybox crc32 < "$ck/n1000" > "$g"; korerun crc32 < "$ck/n1000" > "$o"; same "crc32 stdin"
fi
[ "$(printf abc | korerun sha3sum -a 256 -b)" = 3a985da74fe225b2045c172d6bd390bd855f086e3e9d525b46bfe24511431532 ] \
  || fail "kore sha3sum -a 256 of abc (fips 202)"
korerun sha3sum -a 100 "$ck/a" 2>/dev/null; r=$?; [ $r -eq 1 ] || fail "kore sha3sum -a 100 is 1 (got $r)"
# -c's --quiet --status --ignore-missing --strict -w, the warning counts, a list with no good
# line; -b's star; b2sum the same; output and status
D2=$PWD/$ho/.sumf; rm -rf "$D2"; mkdir "$D2"; echo a > "$D2/fa"; echo b > "$D2/fb"
(cd "$D2" && md5sum fa fb > good && echo "d41d8cd98f00b204e9800998ecf8427e  nope" > good2 && cat good >> good2 && echo b2 > fb && printf 'junk line\n' >> good && b2sum fa > b2l)
for c in "md5sum -c good" "md5sum -c --quiet good" "md5sum -c --status good" "md5sum -c --ignore-missing good2" "md5sum -c good2" \
         "md5sum -c --strict good" "md5sum -c -w good" "md5sum -b fa" "sha256sum --check --quiet good" "b2sum -c --quiet b2l" "b2sum -b fa"; do
  # shellcheck disable=SC2086
  (cd "$D2" && { $c; echo "rc=$?"; }) > "$g" 2>&1; (cd "$D2" && { LOVE_NO_IMAGE= "$PWD/../../$m" $c; echo "rc=$?"; }) > "$o" 2>&1; same "$c"
done
rm -rf "$D2"
echo "kore: checksums (cksum/sum/crc32/md5sum/sha*sum/b2sum/sha3sum over the block boundaries, -c both ways round) ok"
