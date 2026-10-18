#!/bin/sh
# test/kore/archive.sh -- gzip, gunzip, zcat, xz, unxz, bzip2, bunzip2, zstd, unzstd, tar, cpio under kore's door
. "$(dirname "$0")/common.sh"

# the cmd modules leak their mains off a bodyless letrec (the trailing `_ (pins ..)`), which
# is how the registry's cite reaches them; without it the verb is kore's usage, exit 2
printf 'alpha\nbeta\ngamma\n' > "$ho/.arc1"
korerun gzip -c < "$ho/.arc1" > "$ho/.arc1.gz" || fail "kore gzip"
korerun gunzip < "$ho/.arc1.gz" > "$o" || fail "kore gunzip"
cmp -s "$ho/.arc1" "$o" || fail "kore gzip | gunzip round trip"
korerun zcat "$ho/.arc1.gz" > "$o" 2>/dev/null || fail "kore zcat"
cmp -s "$ho/.arc1" "$o" || fail "kore zcat"
# -v is gzip's own (the shared door takes only --help/--version long): the ratio on err, and compresses
cp "$ho/.arc1" "$ho/.arcv"
korerun gzip -v "$ho/.arcv" 2> "$ho/.arcv.say" || fail "kore gzip -v"
grep -q 'replaced with' "$ho/.arcv.say" || fail "gzip -v was answered as --version"
korerun gunzip "$ho/.arcv.gz" || fail "kore gunzip of gzip -v"
cmp -s "$ho/.arc1" "$ho/.arcv" || fail "gzip -v did not compress"
# gunzip: following members read on, trailing junk a warning with the output whole, a bad
# crc an error that drops the partial output and keeps the .gz, -t writes nothing
printf 'delta\n' > "$ho/.arc2"; korerun gzip -c < "$ho/.arc2" > "$ho/.arc2.gz"
cat "$ho/.arc1.gz" "$ho/.arc2.gz" | korerun gunzip > "$o" || fail "kore gunzip of two members"
cat "$ho/.arc1" "$ho/.arc2" | cmp -s - "$o" || fail "kore gunzip of two members: not both"
{ cat "$ho/.arc1.gz"; printf 'junk'; } | korerun gunzip > "$o" 2> "$g"; r=$?
[ $r -eq 2 ] && grep -q 'trailing garbage ignored' "$g" || fail "kore gunzip of trailing junk (rc $r)"
cmp -s "$ho/.arc1" "$o" || fail "kore gunzip of trailing junk: the member did not come out"
n=$(wc -c < "$ho/.arc1.gz"); head -c $((n - 8)) "$ho/.arc1.gz" > "$ho/.arcx.gz"
printf '\001\002\003\004' >> "$ho/.arcx.gz"; tail -c 4 "$ho/.arc1.gz" >> "$ho/.arcx.gz"
rm -f "$ho/.arcx"; korerun gunzip "$ho/.arcx.gz" 2> "$g"; r=$?
[ $r -eq 1 ] && grep -q 'crc error' "$g" || fail "kore gunzip of a wrong crc (rc $r)"
[ ! -e "$ho/.arcx" ] && [ -e "$ho/.arcx.gz" ] || fail "kore gunzip of a wrong crc left its output"
korerun gunzip -t "$ho/.arc1.gz" > "$o" || fail "kore gunzip -t"
[ ! -s "$o" ] && [ -e "$ho/.arc1.gz" ] || fail "kore gunzip -t wrote or removed"
korerun gunzip -t "$ho/.arcx.gz" 2> /dev/null && fail "kore gunzip -t passed a wrong crc"
# -9: never longer than the default, and gzip's gunzip reads it
dd if="$K" of="$ho/.arc9" bs=1024 count=300 2>/dev/null
korerun gzip -c "$ho/.arc9" > "$ho/.arc96.gz"; korerun gzip -9 -c "$ho/.arc9" > "$ho/.arc99.gz"
[ "$(wc -c < "$ho/.arc99.gz")" -le "$(wc -c < "$ho/.arc96.gz")" ] || fail "kore gzip -9 is longer than the default"
korerun gunzip -c "$ho/.arc99.gz" | cmp -s - "$ho/.arc9" || fail "kore gzip -9 | gunzip round trip"
if command -v gzip >/dev/null 2>&1; then
  gzip -dc "$ho/.arc99.gz" | cmp -s - "$ho/.arc9" || fail "GNU gunzip of kore's gzip -9"
fi
hv "gzip --version" '^gzip / love ' korerun gzip --version
hv "gzip --help"    '^gzip -- the' korerun gzip --help
hv "cpio --help"    '^usage: cpio {' korerun cpio --help
hv "tar --help"     '^usage: tar '   korerun tar --help
if command -v gzip >/dev/null 2>&1; then
  gzip -c "$ho/.arc1" > "$ho/.arc1.ggz"
  korerun gunzip < "$ho/.arc1.ggz" > "$o" || fail "kore gunzip of GNU's gzip"
  cmp -s "$ho/.arc1" "$o" || fail "kore gunzip of GNU's gzip"
  gunzip -c "$ho/.arc1.gz" > "$o" 2>/dev/null || fail "GNU gunzip of kore's gzip"
  cmp -s "$ho/.arc1" "$o" || fail "GNU gunzip of kore's gzip"
fi
# tar and cpio: the verb resolves (each format has its own gate); a missing row prints usage
rm -rf "$ho/.arcd"; mkdir -p "$ho/.arcd/sub"
printf 'x\n' > "$ho/.arcd/one.txt"; printf 'y\n' > "$ho/.arcd/sub/two.txt"
# the cd'd subshells want $K, the absolute love
( cd "$ho" && "$K" tar czf .arc.tgz .arcd ) || fail "kore tar czf"
korerun tar tzf "$ho/.arc.tgz" > "$o" 2>&1 || fail "kore tar tzf"
korerun tar tvzf "$ho/.arc.tgz" | grep -q ' 2 .*\.arcd/one\.txt$' || fail "kore tar tvzf: the size off the header"
n=$(wc -c < "$ho/.arc.tgz"); head -c $((n / 2)) "$ho/.arc.tgz" > "$ho/.arch.tgz"
korerun tar tzf "$ho/.arch.tgz" > /dev/null 2> "$g"; r=$?
[ $r -eq 2 ] && grep -q 'not a gzip stream' "$g" || fail "kore tar tzf of a torn .tgz (rc $r)"
grep -q 'one\.txt' "$o" || fail "kore tar: the verb fell through to the usage screen"
( cd "$ho" && "$K" find .arcd | "$K" cpio -o --quiet > .arc.cpio ) || fail "kore cpio -o"
korerun cpio -t < "$ho/.arc.cpio" > "$o" 2>/dev/null || fail "kore cpio -t"
grep -q 'one\.txt' "$o" || fail "kore cpio: the verb fell through to the usage screen"
# xz: round trip, the empty stream (32 bytes, no block), each check, a torn stream refused
# as xz does, and both directions against xz-utils where present, .lzma too
korerun xz -c < "$ho/.arc1" > "$ho/.arc1.xz" || fail "kore xz"
korerun unxz -c < "$ho/.arc1.xz" > "$o"; cmp -s "$ho/.arc1" "$o" || fail "kore xz | unxz round trip"
: > "$ho/.arc0"; korerun xz -c "$ho/.arc0" > "$ho/.arc0.xz"
[ "$(wc -c < "$ho/.arc0.xz")" -eq 32 ] || fail "kore xz: an empty input is a 32-byte stream"
korerun xzcat "$ho/.arc0.xz" > "$o"; [ ! -s "$o" ] || fail "kore xzcat of the empty stream"
for c in none crc32 crc64 sha256; do
  korerun xz -C $c -c "$ho/.arc1" > "$ho/.arcc.xz" || fail "kore xz -C $c"
  korerun xz -dc "$ho/.arcc.xz" > "$o"; cmp -s "$ho/.arc1" "$o" || fail "kore xz -C $c round trip"
done
dd if="$ho/.arc1.xz" of="$ho/.arct.xz" bs=1 count=40 2>/dev/null
korerun xz -t "$ho/.arct.xz" 2> "$ho/.arct.say"; r=$?
[ $r -eq 1 ] || fail "kore xz -t of a torn stream (rc $r)"
grep -q 'Unexpected end of input' "$ho/.arct.say" || fail "kore xz: a torn stream says so"
cp "$ho/.arc1" "$ho/.arcx"; korerun xz "$ho/.arcx"; korerun xz "$ho/.arcx.xz" 2>/dev/null; r=$?
[ $r -eq 2 ] || fail "kore xz: a .xz name is a warning, not a second layer (rc $r)"
korerun unxz "$ho/.arcx.xz"; cmp -s "$ho/.arc1" "$ho/.arcx" || fail "kore unxz in place"
# ..and a binary crossing lzma2's chunk bounds
dd if="$K" of="$ho/.arcb" bs=1024 count=600 2>/dev/null
korerun xz -c "$ho/.arcb" | korerun xz -dc > "$o"; cmp -s "$ho/.arcb" "$o" || fail "kore xz round trip, 600 KiB"
if command -v xz >/dev/null 2>&1; then
  for p in -0 -6 -9e; do
    xz $p -c "$ho/.arc1" > "$ho/.arcg.xz"
    korerun xz -dc "$ho/.arcg.xz" > "$o"; cmp -s "$ho/.arc1" "$o" || fail "kore unxz of xz $p"
  done
  xz -dc "$ho/.arc1.xz" > "$o" 2>/dev/null; cmp -s "$ho/.arc1" "$o" || fail "xz -d of kore's xz"
  # blocks with sizes in the header (xz -T2 --block-size), and noise lzma2 stores whole
  xz -T2 --block-size=100000 -c "$ho/.arcb" > "$ho/.arcm.xz"
  korerun xz -dc "$ho/.arcm.xz" > "$o"; cmp -s "$ho/.arcb" "$o" || fail "kore unxz of xz's blocks"
  head -c 300000 /dev/urandom > "$ho/.arcr"; xz -c "$ho/.arcr" > "$ho/.arcr.xz"
  korerun xz -dc "$ho/.arcr.xz" > "$o"; cmp -s "$ho/.arcr" "$o" || fail "kore unxz of stored chunks"
  xz -t "$ho/.arc0.xz" || fail "xz -t of kore's empty stream"
  korerun xz -c "$ho/.arcb" | xz -dc > "$o"; cmp -s "$ho/.arcb" "$o" || fail "xz -d of kore's xz, 600 KiB"
  xz -c "$ho/.arcb" | korerun xz -dc > "$o"; cmp -s "$ho/.arcb" "$o" || fail "kore unxz of xz's, 600 KiB"
  # ..and past -0's 256 KiB dictionary: a sliding window keeps the position bits
  cat src/love/*.c src/apps/*.l src/apps/*/*.l | head -c 3000000 > "$ho/.arcw"
  xz -0 -T1 -c "$ho/.arcw" | korerun xz -dc > "$o"; cmp -s "$ho/.arcw" "$o" || fail "kore unxz of xz -0 past its dictionary"
  cat "$ho/.arcg.xz" "$ho/.arc1.xz" > "$ho/.arcs.xz"
  cat "$ho/.arc1" "$ho/.arc1" > "$g"
  korerun xz -dc "$ho/.arcs.xz" > "$o"; cmp -s "$g" "$o" || fail "kore unxz of two streams"
  xz --format=lzma -c "$ho/.arc1" > "$ho/.arc1.lzma"
  korerun unlzma -c "$ho/.arc1.lzma" > "$o"; cmp -s "$ho/.arc1" "$o" || fail "kore unlzma of xz's .lzma"
  cat "$ho/.arc1" | xz --format=lzma | korerun lzcat > "$o"; cmp -s "$ho/.arc1" "$o" || fail "kore lzcat of a sizeless .lzma"
  n=$(wc -c < "$ho/.arc1.lzma"); head -c $((n - 6)) "$ho/.arc1.lzma" | korerun lzcat > /dev/null 2> "$g"; r=$?
  [ $r -eq 1 ] || fail "kore lzcat of a torn .lzma (rc $r)"
fi
hv "xz --help" '^xz -- the' korerun xz --help
# bzip2: round trip, the empty stream (14 bytes), torn and foreign streams with bzip2's
# statuses, tar's j, both directions against bzip2 where present; 600 KiB crosses a block at -1
korerun bzip2 -c < "$ho/.arc1" > "$ho/.arc1.bz2" || fail "kore bzip2"
korerun bunzip2 -c < "$ho/.arc1.bz2" > "$o"; cmp -s "$ho/.arc1" "$o" || fail "kore bzip2 | bunzip2 round trip"
korerun bzip2 -c "$ho/.arc0" > "$ho/.arc0.bz2"
[ "$(wc -c < "$ho/.arc0.bz2")" -eq 14 ] || fail "kore bzip2: an empty input is a 14-byte stream"
korerun bzcat "$ho/.arc0.bz2" > "$o"; [ ! -s "$o" ] || fail "kore bzcat of the empty stream"
korerun bzip2 -c "$ho/.arcb" > "$ho/.arcb.bz2"
n=$(wc -c < "$ho/.arcb.bz2"); head -c $((n - 30)) "$ho/.arcb.bz2" | korerun bzcat > /dev/null 2> "$g"; r=$?
[ $r -eq 2 ] && grep -q 'ends unexpectedly' "$g" || fail "kore bzcat of a torn stream (rc $r)"
dd if="$ho/.arc1.bz2" of="$ho/.arct.bz2" bs=1 count=20 2>/dev/null
korerun bzip2 -t "$ho/.arct.bz2" 2> "$ho/.arct.say"; r=$?
[ $r -eq 2 ] || fail "kore bzip2 -t of a torn stream (rc $r)"
grep -q 'ends unexpectedly' "$ho/.arct.say" || fail "kore bzip2: a torn stream says so"
korerun bunzip2 -t "$ho/.arc1.xz" 2> "$ho/.arct.say"; r=$?
[ $r -eq 2 ] || fail "kore bunzip2 of an xz stream (rc $r)"
grep -q 'is not a bzip2 file' "$ho/.arct.say" || fail "kore bunzip2: a stranger says so"
cp "$ho/.arc1" "$ho/.arcz"; korerun bzip2 "$ho/.arcz"; korerun bzip2 "$ho/.arcz.bz2" 2>/dev/null; r=$?
[ $r -eq 1 ] || fail "kore bzip2: a .bz2 name is refused, not a second layer (rc $r)"
korerun bunzip2 "$ho/.arcz.bz2"; cmp -s "$ho/.arc1" "$ho/.arcz" || fail "kore bunzip2 in place"
korerun bzip2 -1 -c "$ho/.arcb" | korerun bzip2 -dc > "$o"; cmp -s "$ho/.arcb" "$o" || fail "kore bzip2 round trip, 600 KiB"
( cd "$ho" && "$K" tar cjf .arc.tbz .arcd ) || fail "kore tar cjf"
korerun tar tjf "$ho/.arc.tbz" > "$o" 2>&1 || fail "kore tar tjf"
grep -q 'sub/two\.txt' "$o" || fail "kore tar j: the listing"
if command -v bzip2 >/dev/null 2>&1; then
  for p in -1 -9; do
    bzip2 $p -c "$ho/.arcb" > "$ho/.arcg.bz2"
    korerun bzip2 -dc "$ho/.arcg.bz2" > "$o"; cmp -s "$ho/.arcb" "$o" || fail "kore bunzip2 of bzip2 $p"
  done
  korerun bzip2 -1 -c "$ho/.arcb" | bzip2 -dc > "$o"; cmp -s "$ho/.arcb" "$o" || fail "bzip2 -d of kore's bzip2, 600 KiB"
  bzip2 -t "$ho/.arc0.bz2" || fail "bzip2 -t of kore's empty stream"
  cat "$ho/.arcg.bz2" "$ho/.arc1.bz2" > "$ho/.arcs.bz2"
  cat "$ho/.arcb" "$ho/.arc1" > "$g"
  korerun bzcat "$ho/.arcs.bz2" > "$o"; cmp -s "$g" "$o" || fail "kore bzcat of two streams"
  bzip2 -dc "$ho/.arc.tbz" | tar tf - > "$o" 2>&1; grep -q 'sub/two\.txt' "$o" || fail "tar -j of kore's tar cjf"
fi
hv "bzip2 --help" '^bzip2 -- the' korerun bzip2 --help
# zstd: the round trip, the empty frame (13 bytes), the input kept unless --rm, a torn frame
# and a stranger refused with zstd's status 1, -o, and both directions against zstd itself
# where it is there -- the 600 KiB binary crosses a 128 KiB block
korerun zstd -c < "$ho/.arc1" > "$ho/.arc1.zst" || fail "kore zstd"
korerun unzstd -c < "$ho/.arc1.zst" > "$o"; cmp -s "$ho/.arc1" "$o" || fail "kore zstd | unzstd round trip"
korerun zstd -c "$ho/.arc0" > "$ho/.arc0.zst"
[ "$(wc -c < "$ho/.arc0.zst")" -eq 13 ] || fail "kore zstd: an empty input is a 13-byte frame"
korerun zstdcat "$ho/.arc0.zst" > "$o"; [ ! -s "$o" ] || fail "kore zstdcat of the empty frame"
for l in -1 -3 -19; do
  korerun zstd $l -c "$ho/.arcb" | korerun zstd -dc > "$o"; cmp -s "$ho/.arcb" "$o" || fail "kore zstd $l round trip, 600 KiB"
done
korerun zstd -c "$ho/.arcb" > "$ho/.arcb.zst"
n=$(wc -c < "$ho/.arcb.zst"); head -c $((n - 30)) "$ho/.arcb.zst" | korerun zstdcat > /dev/null 2> "$g"; r=$?
[ $r -eq 1 ] && grep -q 'premature end' "$g" || fail "kore zstdcat of a torn frame (rc $r)"
korerun zstd -t "$ho/.arc1.xz" 2> "$ho/.arct.say"; r=$?
[ $r -eq 1 ] && grep -q 'unsupported format' "$ho/.arct.say" || fail "kore zstd -t of an xz stream (rc $r)"
cp "$ho/.arc1" "$ho/.arcq"; rm -f "$ho/.arcq.zst"; korerun zstd -q "$ho/.arcq" || fail "kore zstd FILE"
[ -e "$ho/.arcq" ] && [ -e "$ho/.arcq.zst" ] || fail "kore zstd: the input is kept"
korerun zstd -q "$ho/.arcq" 2> "$g"; r=$?
[ $r -eq 1 ] && grep -q 'already exists' "$g" || fail "kore zstd: an output there is not overwritten (rc $r)"
rm "$ho/.arcq"; korerun unzstd --rm "$ho/.arcq.zst" || fail "kore unzstd --rm"
cmp -s "$ho/.arc1" "$ho/.arcq" && [ ! -e "$ho/.arcq.zst" ] || fail "kore unzstd --rm in place"
rm -f "$ho/.arco.zst"; korerun zstd -q -o "$ho/.arco.zst" "$ho/.arc1" && korerun zstd -dc "$ho/.arco.zst" | cmp -s - "$ho/.arc1" || fail "kore zstd -o"
korerun unzstd "$ho/.arc1" 2> "$g"; r=$?
[ $r -eq 1 ] && grep -q 'unknown suffix' "$g" || fail "kore unzstd of a name it cannot strip (rc $r)"
( cd "$ho" && "$K" tar --zstd -cf .arc.tzst .arcd ) || fail "kore tar --zstd -cf"
korerun tar tf "$ho/.arc.tzst" > "$o" 2>&1 || fail "kore tar tf of a .tzst, sniffed"
grep -q 'sub/two\.txt' "$o" || fail "kore tar --zstd: the listing"
( cd "$ho" && "$K" tar caf .arca.tar.zst .arcd ) || fail "kore tar caf .tar.zst"
korerun zstd -t "$ho/.arca.tar.zst" || fail "kore tar -a: .tar.zst is not zstd"
if command -v zstd >/dev/null 2>&1; then
  zstd -q -dc "$ho/.arc.tzst" | tar tf - > "$o" 2>&1; grep -q 'sub/two\.txt' "$o" || fail "zstd -d | tar of kore's tar --zstd"
  ( cd "$ho" && tar cf - .arcd ) | zstd -q -c > "$ho/.arcg.tzst"
  korerun tar tf "$ho/.arcg.tzst" > "$o" 2>&1; grep -q 'sub/two\.txt' "$o" || fail "kore tar of tar | zstd"
  for p in -1 -19 "-T2 --no-check"; do
    zstd -q $p -c "$ho/.arcb" > "$ho/.arcg.zst"
    korerun zstd -dc "$ho/.arcg.zst" > "$o"; cmp -s "$ho/.arcb" "$o" || fail "kore unzstd of zstd $p"
  done
  zstd -q -c < "$ho/.arcb" > "$ho/.arcp.zst"
  korerun zstd -dc "$ho/.arcp.zst" > "$o"; cmp -s "$ho/.arcb" "$o" || fail "kore unzstd of a frame with no size"
  for l in -1 -9; do
    korerun zstd $l -c "$ho/.arcb" | zstd -q -dc > "$o"; cmp -s "$ho/.arcb" "$o" || fail "zstd -d of kore's zstd $l, 600 KiB"
  done
  zstd -q -t "$ho/.arc0.zst" || fail "zstd -t of kore's empty frame"
  cat "$ho/.arcg.zst" "$ho/.arc1.zst" > "$ho/.arcs.zst"
  cat "$ho/.arcb" "$ho/.arc1" > "$g"
  korerun zstdcat "$ho/.arcs.zst" > "$o"; cmp -s "$g" "$o" || fail "kore zstdcat of two frames"
fi
hv "zstd --help" '^zstd -- zstandard' korerun zstd --help
# tar beyond the bundled key: dashed letters, -C, members, f - both ways, J, a sniffed codec,
# --strip-components, -O
T=$HO/.arctar; rm -rf "$T"; mkdir -p "$T/o"
korerun tar -cJf "$T/a.txz" -C "$ho" .arcd || fail "kore tar -cJf -C"
korerun tar tf "$T/a.txz" > "$o"; grep -q '^\.arcd/sub/two\.txt$' "$o" || fail "kore tar: a sniffed xz listing"
korerun tar cf - -C "$ho" .arcd/sub | korerun tar tf - > "$o"
[ "$(cat "$o")" = "$(printf '.arcd/sub\n.arcd/sub/two.txt')" ] || fail "kore tar cf - | tar tf -"
korerun tar xf "$T/a.txz" -C "$T/o" --strip-components=1 .arcd/sub || fail "kore tar x a member, stripped"
cmp -s "$ho/.arcd/sub/two.txt" "$T/o/sub/two.txt" || fail "kore tar --strip-components"
[ ! -e "$T/o/one.txt" ] || fail "kore tar x took a member it was not asked for"
[ "$(korerun tar -xOf "$T/a.txz" .arcd/one.txt)" = x ] || fail "kore tar -O"
korerun tar tf "$T/a.txz" no/such 2> /dev/null; r=$?; [ $r -eq 2 ] || fail "kore tar: a missing member (rc $r)"
if command -v tar >/dev/null 2>&1 && command -v xz >/dev/null 2>&1; then
  tar tJf "$T/a.txz" > "$o" 2>&1; grep -q 'sub/two\.txt' "$o" || fail "tar -J of kore's tar cJf"
  tar cJf "$T/g.txz" -C "$ho" .arcd && korerun tar tf "$T/g.txz" > "$o"
  grep -q '^\.arcd/one\.txt$' "$o" || fail "kore tar: GNU's xz tarball, sniffed"
fi
# the coders read flags in gnu order: a flag after a file, the later of two wins, a bad one named
F=$HO/.arcflag; rm -rf "$F"; mkdir -p "$F"; cp "$ho/.arc1" "$F/a"; cp "$ho/.arc1" "$F/b"
korerun gzip "$F/a" -k || fail "kore gzip FILE -k"
[ -f "$F/a" ] && [ -f "$F/a.gz" ] || fail "kore gzip: -k after the file was not read"
korerun bzip2 "$F/b" -k -c > "$F/b.bz2" || fail "kore bzip2 FILE -k -c"
[ -f "$F/b" ] || fail "kore bzip2: -c after the file was not read"
korerun xz -c -z -d < "$F/a.gz" > /dev/null 2>&1 && fail "kore xz: -d after -z did not win"
korerun xz -c -d -z < "$F/a" | korerun xz -dc > "$o" || fail "kore xz: -z after -d did not win"
cmp -s "$F/a" "$o" || fail "kore xz -d -z round trip"
korerun gzip -x "$F/a" 2> "$o" && fail "kore gzip -x was taken"
grep -q 'unknown option -x' "$o" || fail "kore gzip -x: not named"
korerun bzip2 -cx "$F/a" 2> "$o" && fail "kore bzip2 -cx was taken"
grep -q 'Bad flag `-cx' "$o" || fail "kore bzip2 -cx: the word not named"
korerun gzip --suffix 2> "$o" && fail "kore gzip --suffix with no value was taken"
grep -q -- '--suffix wants' "$o" || fail "kore gzip --suffix: not named"
hv "bzip2 -V" '^bzip2 / love ' korerun bzip2 -V
( cd "$ho" && printf '.arc1\n' | "$K" cpio -o > "$F/c.cpio" ) || fail "kore cpio -o for the flags"
korerun cpio -t --file="$F/c.cpio" > "$o" 2>/dev/null; grep -q '\.arc1' "$o" || fail "kore cpio --file=F"
korerun cpio --format=odc -t < "$F/c.cpio" 2> "$o" && fail "kore cpio --format=odc was taken"
grep -q 'format odc is not here' "$o" || fail "kore cpio --format=odc: the refusal"
# a hostile archive stays under the root: ".." refused, a leading / dropped, a symlink member
# never written, chmod'ed or walked through, no set-id bit. both wires
E=$HO/.arcevil; rm -rf "$E"; mkdir -p "$E/tx" "$E/cx" "$E/out" "$E/tdir"
printf 'orig\n' > "$E/target"; chmod 600 "$E/target"; chmod 700 "$E/tdir"
cat > "$E/mk.l" <<EOF
(borrow 'posix)
(borrow 'tar)
(borrow 'cpio)
(: (en nom kind body to mode) (: t (tar-entry nom kind body) (pins t 'to to 'mode mode))
   es [(en "../up.txt" 'file "up\n" "" 420)
       (en "a/../../up2.txt" 'file "up\n" "" 420)
       (en "/abs.txt" 'file "abs\n" "" 420)
       (en "l" 'link "" "../target" 511)
       (en "l" 'file "pwn\n" "" 511)
       (en "d" 'link "" "../out" 511)
       (en "d/x" 'file "pwn\n" "" 420)
       (en "c" 'link "" "../tdir" 511)
       (en "c" 'dir "" "" 511)
       (en "s" 'file "suid\n" "" 2541)
       (en "ok/f.txt" 'file "fine\n" "" 420)]
   (wr p s) (: q (open p "w") _ (say q s) (close q))
   _ (wr "$E/evil.tar" (tar-pack es))
   _ (wr "$E/evil.cpio" (cpio-pack es))
   0)
EOF
LOVE_NO_IMAGE= "$m" "$E/mk.l" || fail "kore tar: the hostile archives were not made"
evil() { w=$1; x=$2
  [ ! -e "$E/up.txt" ] && [ ! -e "$E/up2.txt" ] || fail "kore $w: a '..' member climbed out"
  [ -f "$x/abs.txt" ] || fail "kore $w: a leading / was not taken off"
  [ "$(cat "$E/target")" = orig ] || fail "kore $w: wrote through a symlink"
  [ -f "$x/l" ] && [ ! -L "$x/l" ] || fail "kore $w: the member did not replace its link"
  [ "$(stat -c %a "$E/target")" = 600 ] || fail "kore $w: chmod'ed through a symlink"
  [ "$(stat -c %a "$E/tdir")" = 700 ] || fail "kore $w: chmod'ed a directory through a symlink"
  [ ! -e "$E/out/x" ] || fail "kore $w: walked through a symlinked directory"
  [ "$(stat -c %a "$x/s")" = 755 ] || fail "kore $w: laid a set-id bit"
  [ "$(cat "$x/ok/f.txt")" = fine ] || fail "kore $w: an ordinary member was lost"; }
# git archive leads with a pax global header ('g', the commit): read past, as GNU tar does
if command -v git >/dev/null 2>&1; then
  P=$HO/.arcp; rm -rf "$P"; mkdir -p "$P/r" "$P/x"
  ( cd "$P/r" && git init -q && printf 'g\n' > f && git add f \
    && git -c user.name=t -c user.email=t@t -c commit.gpgsign=false commit -qm m && git archive --format=tar -o ../g.tar HEAD ) \
    || fail "git archive"
  korerun tar tf "$P/g.tar" > "$o" || fail "kore tar tf of git archive's tar"
  [ "$(cat "$o")" = f ] || fail "kore tar tf lists git archive's pax header: $(cat "$o")"
  korerun tar xf "$P/g.tar" -C "$P/x" || fail "kore tar xf of git archive's tar"
  [ ! -e "$P/x/pax_global_header" ] && [ "$(cat "$P/x/f")" = g ] || fail "kore tar xf laid git archive's pax header"
  rm -rf "$P"
fi
korerun tar xf "$E/evil.tar" -C "$E/tx" 2> "$o"; r=$?
[ $r -eq 2 ] || fail "kore tar: a hostile archive (rc $r)"
grep -q "Member name contains '..'" "$o" || fail "kore tar: a '..' member not named"
evil tar "$E/tx"
( cd "$E/cx" && "$K" cpio -i -u --quiet < "$E/evil.cpio" ) 2> "$o"; r=$?
[ $r -eq 1 ] || fail "kore cpio: a hostile archive (rc $r)"
grep -q "contains '..'" "$o" || fail "kore cpio: a '..' member not named"
evil cpio "$E/cx"
# an output past 1 GiB is refused, not grown into the heap: 1100 MiB of zeros through each
# decoder the system can pack for; gunzip streams to its port under a 64 MiB heap
B=$HO/.arcbig; rm -rf "$B"; mkdir -p "$B"
big() { dd if=/dev/zero bs=1048576 count=1100 2>/dev/null | "$@"; }
if command -v gzip >/dev/null 2>&1; then
  big gzip -1 > "$B/z.gz"
  LOVE_BUDGET_MB=64 LOVE_NO_IMAGE= "$m" gunzip -c "$B/z.gz" 2> "$o" | wc -c > "$g"
  [ "$(tr -d ' ' < "$g")" = 1153433600 ] || { cat "$o"; fail "kore gunzip of 1100 MiB did not stream: $(cat "$g") bytes"; }
  # ..and tar: zeros end the archive at the first block, the rest still read to its crc
  LOVE_BUDGET_MB=64 LOVE_NO_IMAGE= "$m" tar tzf "$B/z.gz" > "$g" 2> "$o"; r=$?
  [ $r -eq 0 ] && [ ! -s "$g" ] || { cat "$o"; fail "kore tar tzf of 1100 MiB of zeros did not stream (rc $r)"; }
  # a member bigger than the heap is poured to its file: 300 MiB under 64 MiB
  mkdir -p "$B/t" "$B/x"; dd if=/dev/zero bs=1048576 count=300 2>/dev/null > "$B/t/big"; printf 'tail\n' > "$B/t/small"
  # ..and is packed a run at a time, as gzip members, bzip2 and xz streams read on in one
  ( cd "$B" && LOVE_BUDGET_MB=64 LOVE_NO_IMAGE= "$K" tar czf big.tgz t ) 2> "$o" || { cat "$o"; fail "kore tar czf of a 300 MiB member did not stream"; }
  cbig() {
    ( cd "$B" && LOVE_BUDGET_MB=64 LOVE_NO_IMAGE= "$K" tar c$1f big.$2 t ) 2> "$o" \
      || { cat "$o"; fail "kore tar c$1f of a 300 MiB member did not stream"; }
    LOVE_BUDGET_MB=64 LOVE_NO_IMAGE= "$m" tar tvf "$B/big.$2" > "$g" 2> "$o" || { cat "$o"; fail "kore tar tvf big.$2"; }
    grep -q ' 314572800 .* t/big$' "$g" && grep -q 't/small$' "$g" || fail "kore tar c$1f of a 300 MiB member: $(cat "$g")"
  }
  cbig j tbz; cbig J txz
  if command -v tar >/dev/null 2>&1; then
    tar tzf "$B/big.tgz" > "$g" 2>&1 && grep -q '^t/small$' "$g" || fail "the system tar of kore's czf: $(cat "$g")"
  fi
  rm -rf "$B/t"
  LOVE_BUDGET_MB=64 LOVE_NO_IMAGE= "$m" tar xzf "$B/big.tgz" -C "$B/x" 2> "$o" || { cat "$o"; fail "kore tar xzf of a 300 MiB member did not stream"; }
  [ "$(wc -c < "$B/x/t/big" | tr -d ' ')" = 314572800 ] && [ "$(cat "$B/x/t/small")" = tail ] \
    || fail "kore tar xzf of a 300 MiB member: the files are not whole"
  # ..and cpio -i, off an archive the system cpio packs
  if command -v cpio >/dev/null 2>&1; then
    ( cd "$B/x" && find t | cpio -o -H newc --quiet > "$B/big.cpio" ) || fail "cpio -o of a 300 MiB member"
    mkdir -p "$B/c"
    ( cd "$B/c" && LOVE_BUDGET_MB=64 LOVE_NO_IMAGE= "$K" cpio -i -d --quiet < "$B/big.cpio" ) 2> "$o" \
      || { cat "$o"; fail "kore cpio -i of a 300 MiB member did not stream"; }
    cmp -s "$B/x/t/big" "$B/c/t/big" && cmp -s "$B/x/t/small" "$B/c/t/small" \
      || fail "kore cpio -i of a 300 MiB member: the files are not whole"
    head -c 1000 "$B/big.cpio" | korerun cpio -t > /dev/null 2> "$o"; r=$?
    [ $r -eq 1 ] && grep -q 'premature end' "$o" || fail "kore cpio -t of a torn archive (rc $r)"
  fi
fi
if command -v xz >/dev/null 2>&1; then
  # .lzma, sizeless, the same: whole, under a 64 MiB heap
  big xz --format=lzma -0 > "$B/z.lzma"
  LOVE_BUDGET_MB=64 LOVE_NO_IMAGE= "$m" unlzma -c "$B/z.lzma" 2> "$o" | wc -c > "$g"
  [ "$(tr -d ' ' < "$g")" = 1153433600 ] || { cat "$o"; fail "kore unlzma of a sizeless 1100 MiB did not stream: $(cat "$g") bytes"; }
  # .xz streams a chunk at a time under a 64 MiB heap, through unxz and tar J
  big xz -0 -T1 > "$B/z.xz"
  LOVE_BUDGET_MB=64 LOVE_NO_IMAGE= "$m" unxz -c "$B/z.xz" 2> "$o" | wc -c > "$g"
  [ "$(tr -d ' ' < "$g")" = 1153433600 ] || { cat "$o"; fail "kore unxz of 1100 MiB did not stream: $(cat "$g") bytes"; }
  LOVE_BUDGET_MB=64 LOVE_NO_IMAGE= "$m" tar tJf "$B/z.xz" > "$g" 2> "$o"; r=$?
  [ $r -eq 0 ] && [ ! -s "$g" ] || { cat "$o"; fail "kore tar tJf of 1100 MiB of zeros did not stream (rc $r)"; }
fi
if command -v bzip2 >/dev/null 2>&1; then
  # .bz2 a block at a time, through bunzip2 and tar j
  big bzip2 -1 > "$B/z.bz2"
  LOVE_BUDGET_MB=64 LOVE_NO_IMAGE= "$m" bunzip2 -c "$B/z.bz2" 2> "$o" | wc -c > "$g"
  [ "$(tr -d ' ' < "$g")" = 1153433600 ] || { cat "$o"; fail "kore bunzip2 of 1100 MiB did not stream: $(cat "$g") bytes"; }
  LOVE_BUDGET_MB=64 LOVE_NO_IMAGE= "$m" tar tjf "$B/z.bz2" > "$g" 2> "$o"; r=$?
  [ $r -eq 0 ] && [ ! -s "$g" ] || { cat "$o"; fail "kore tar tjf of 1100 MiB of zeros did not stream (rc $r)"; }
fi
rm -rf "$B"
echo "kore: gzip/gunzip/zcat/xz/unxz/bzip2/bunzip2/zstd/unzstd/tar/cpio under kore's door ok"
