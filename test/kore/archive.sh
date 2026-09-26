#!/bin/sh
# test/kore/archive.sh -- gzip, gunzip, zcat, xz, unxz, tar, cpio under kore's door
. "$(dirname "$0")/common.sh"

# gz.l, tar.l and the two cpio files are kore members now, not crew ones: the distro's
# /bin IS the kore cat, so a userland that cannot open a tarball wants them here. all
# three cmd modules leak their mains off a BODYLESS letrec (the trailing `_ (pins ..)`),
# which is the whole of how the registry's cite reaches them -- drop the `_` and the
# verb falls through to kore's usage screen, silently and with a 2.
printf 'alpha\nbeta\ngamma\n' > "$ho/.arc1"
korerun gzip -c < "$ho/.arc1" > "$ho/.arc1.gz" || fail "kore gzip"
korerun gunzip < "$ho/.arc1.gz" > "$o" || fail "kore gunzip"
cmp -s "$ho/.arc1" "$o" || fail "kore gzip | gunzip round trip"
korerun zcat "$ho/.arc1.gz" > "$o" 2>/dev/null || fail "kore zcat"
cmp -s "$ho/.arc1" "$o" || fail "kore zcat"
# -v is gzip's own: the shared door answers --help and --version in their long spelling
# alone, so -v reports the ratio on err and the file it replaced, and compresses
cp "$ho/.arc1" "$ho/.arcv"
korerun gzip -v "$ho/.arcv" 2> "$ho/.arcv.say" || fail "kore gzip -v"
grep -q 'replaced with' "$ho/.arcv.say" || fail "gzip -v was answered as --version"
korerun gunzip "$ho/.arcv.gz" || fail "kore gunzip of gzip -v"
cmp -s "$ho/.arc1" "$ho/.arcv" || fail "gzip -v did not compress"
hv "gzip --version" '^gzip (love' korerun gzip --version
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
# tar and cpio: that the verb RESOLVES is the thing this file can go wrong about --
# each has its own gate for the format. a missing row prints kore's usage, so the
# check is that the answer is the listing and not the screen.
rm -rf "$ho/.arcd"; mkdir -p "$ho/.arcd/sub"
printf 'x\n' > "$ho/.arcd/one.txt"; printf 'y\n' > "$ho/.arcd/sub/two.txt"
# the cd'd subshells want $K, the ABSOLUTE love: korerun's $m is relative to $PWD
( cd "$ho" && "$K" kore tar czf .arc.tgz .arcd ) || fail "kore tar czf"
korerun tar tzf "$ho/.arc.tgz" > "$o" 2>&1 || fail "kore tar tzf"
grep -q 'one\.txt' "$o" || fail "kore tar: the verb fell through to the usage screen"
( cd "$ho" && "$K" kore find .arcd | "$K" kore cpio -o --quiet > .arc.cpio ) || fail "kore cpio -o"
korerun cpio -t < "$ho/.arc.cpio" > "$o" 2>/dev/null || fail "kore cpio -t"
grep -q 'one\.txt' "$o" || fail "kore cpio: the verb fell through to the usage screen"
# xz: the round trip, the empty stream (32 bytes, no block), each check, a torn stream
# refused as xz refuses it, and both directions against xz-utils where it is there --
# its streams read here whatever the preset, ours read there, and .lzma both ways in
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
# ..and a binary big enough to cross LZMA2's chunk bounds
dd if="$K" of="$ho/.arcb" bs=1024 count=600 2>/dev/null
korerun xz -c "$ho/.arcb" | korerun xz -dc > "$o"; cmp -s "$ho/.arcb" "$o" || fail "kore xz round trip, 600 KiB"
if command -v xz >/dev/null 2>&1; then
  for p in -0 -6 -9e; do
    xz $p -c "$ho/.arc1" > "$ho/.arcg.xz"
    korerun xz -dc "$ho/.arcg.xz" > "$o"; cmp -s "$ho/.arc1" "$o" || fail "kore unxz of xz $p"
  done
  xz -dc "$ho/.arc1.xz" > "$o" 2>/dev/null; cmp -s "$ho/.arc1" "$o" || fail "xz -d of kore's xz"
  xz -t "$ho/.arc0.xz" || fail "xz -t of kore's empty stream"
  korerun xz -c "$ho/.arcb" | xz -dc > "$o"; cmp -s "$ho/.arcb" "$o" || fail "xz -d of kore's xz, 600 KiB"
  xz -c "$ho/.arcb" | korerun xz -dc > "$o"; cmp -s "$ho/.arcb" "$o" || fail "kore unxz of xz's, 600 KiB"
  cat "$ho/.arcg.xz" "$ho/.arc1.xz" > "$ho/.arcs.xz"
  cat "$ho/.arc1" "$ho/.arc1" > "$g"
  korerun xz -dc "$ho/.arcs.xz" > "$o"; cmp -s "$g" "$o" || fail "kore unxz of two streams"
  xz --format=lzma -c "$ho/.arc1" > "$ho/.arc1.lzma"
  korerun unlzma -c "$ho/.arc1.lzma" > "$o"; cmp -s "$ho/.arc1" "$o" || fail "kore unlzma of xz's .lzma"
  cat "$ho/.arc1" | xz --format=lzma | korerun lzcat > "$o"; cmp -s "$ho/.arc1" "$o" || fail "kore lzcat of a sizeless .lzma"
fi
hv "xz --help" '^xz -- the' korerun xz --help
echo "kore: gzip/gunzip/zcat/xz/unxz/tar/cpio under kore's door ok"
