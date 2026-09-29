#!/bin/sh
# test/kore/archive.sh -- gzip, gunzip, zcat, xz, unxz, bzip2, bunzip2, tar, cpio under kore's door
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
# bzip2: the round trip, the empty stream (14 bytes), a torn one and a stranger refused
# with bzip2's statuses, tar's j, and both directions against bzip2 itself where it is
# there -- the 600 KiB binary crosses a 100k block at -1
korerun bzip2 -c < "$ho/.arc1" > "$ho/.arc1.bz2" || fail "kore bzip2"
korerun bunzip2 -c < "$ho/.arc1.bz2" > "$o"; cmp -s "$ho/.arc1" "$o" || fail "kore bzip2 | bunzip2 round trip"
korerun bzip2 -c "$ho/.arc0" > "$ho/.arc0.bz2"
[ "$(wc -c < "$ho/.arc0.bz2")" -eq 14 ] || fail "kore bzip2: an empty input is a 14-byte stream"
korerun bzcat "$ho/.arc0.bz2" > "$o"; [ ! -s "$o" ] || fail "kore bzcat of the empty stream"
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
( cd "$ho" && "$K" kore tar cjf .arc.tbz .arcd ) || fail "kore tar cjf"
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
# tar's spelling beyond the bundled key: dashed letters, -C, members, f - both ways, J,
# the codec sniffed on a read that names none, --strip-components and -O
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
# the coders read flags in gnu order (post.l's uoptp): a flag may follow a file, the later
# of two levels or directions wins, and a bad flag names itself
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
hv "bzip2 -V" '^bzip2 (love' korerun bzip2 -V
( cd "$ho" && printf '.arc1\n' | "$K" kore cpio -o > "$F/c.cpio" ) || fail "kore cpio -o for the flags"
korerun cpio -t --file="$F/c.cpio" > "$o" 2>/dev/null; grep -q '\.arc1' "$o" || fail "kore cpio --file=F"
korerun cpio --format=odc -t < "$F/c.cpio" 2> "$o" && fail "kore cpio --format=odc was taken"
grep -q 'format odc is not here' "$o" || fail "kore cpio --format=odc: the refusal"
# a hostile archive stays under the root: a ".." member is refused, a leading / comes
# off, a symlink laid a member ago is neither written through nor chmod'ed through nor
# walked through, and a set-id bit is not laid. both wires, the same members.
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
korerun tar xf "$E/evil.tar" -C "$E/tx" 2> "$o"; r=$?
[ $r -eq 2 ] || fail "kore tar: a hostile archive (rc $r)"
grep -q "Member name contains '..'" "$o" || fail "kore tar: a '..' member not named"
evil tar "$E/tx"
( cd "$E/cx" && "$K" kore cpio -i -u --quiet < "$E/evil.cpio" ) 2> "$o"; r=$?
[ $r -eq 1 ] || fail "kore cpio: a hostile archive (rc $r)"
grep -q "contains '..'" "$o" || fail "kore cpio: a '..' member not named"
evil cpio "$E/cx"
# an output past 1 GiB is refused with a word, not grown into the heap: 1100 MiB of zeros,
# a few MiB packed, through each decoder where the system coder is here to pack it
B=$HO/.arcbig; rm -rf "$B"; mkdir -p "$B"
big() { dd if=/dev/zero bs=1048576 count=1100 2>/dev/null | "$@"; }
if command -v gzip >/dev/null 2>&1; then
  big gzip -1 > "$B/z.gz"
  korerun gunzip -c "$B/z.gz" > /dev/null 2> "$o"; r=$?
  [ $r -eq 1 ] && grep -q 'past 1 GiB' "$o" || fail "kore gunzip of 1100 MiB (rc $r)"
  korerun tar tzf "$B/z.gz" > /dev/null 2>&1 && fail "kore tar z of 1100 MiB was taken"
fi
if command -v xz >/dev/null 2>&1; then
  big xz --format=lzma -0 > "$B/z.lzma"
  korerun unlzma -c "$B/z.lzma" > /dev/null 2> "$o"; r=$?
  [ $r -eq 1 ] && grep -q 'Memory usage limit' "$o" || fail "kore unlzma of a sizeless 1100 MiB (rc $r)"
  big xz -0 -T1 > "$B/z.xz"
  korerun unxz -c "$B/z.xz" > /dev/null 2> "$o"; r=$?
  [ $r -eq 1 ] && grep -q 'Memory usage limit' "$o" || fail "kore unxz of 1100 MiB (rc $r)"
fi
if command -v bzip2 >/dev/null 2>&1; then
  big bzip2 -1 > "$B/z.bz2"
  korerun bunzip2 -c "$B/z.bz2" > /dev/null 2> "$o"; r=$?
  [ $r -eq 2 ] && grep -q 'past 1 GiB' "$o" || fail "kore bunzip2 of 1100 MiB (rc $r)"
fi
rm -rf "$B"
echo "kore: gzip/gunzip/zcat/xz/unxz/bzip2/bunzip2/tar/cpio under kore's door ok"
