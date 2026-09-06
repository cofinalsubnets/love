#!/bin/sh
# fat32.sh -- `love fat` and `love mkfs.vfat`, the command line over src/apps/fat/fat.l.
#
# ⚠ NOT test/gate/fat.sh, which is a different subject entirely: that one gates the
# FAT CONTAINER of doc/misc/plan/seed-universal.md (one file, many architectures) and
# has nothing to do with the filesystem. `make test_fat` is that gate; this is
# `make test_fat32`.
#
# test/host/fat.l proves the FILESYSTEM against its own laws over a cask; this gate
# proves the FACE -- that an image on disk survives the round trip through a real
# second implementation. mtools is that implementation: it reads the image we format
# and writes one we read, so neither side is grading its own homework. Without mtools
# on PATH the interop half is skipped by name and the rest still runs.
#
# ⚠ FAT32 REFUSES ANYTHING UNDER ~33 MB by the format's own law -- under 65525
# clusters the type IS FAT16. every image here is 40 MB for that reason, not for room.
#
# usage: fat32.sh OUTDIR LOVE
set -u
ho=$1
m=$2
fail() { echo "FAIL $*" >&2; exit 1; }
case $ho in /*) HO=$ho;; *) HO=$PWD/$ho;; esac
W=$HO/.fat32; rm -rf "$W"; mkdir -p "$W"
I=$W/img.fat

# ---------------------------------------------------------------- format
"$m" fat mkfs "$I" 40M || fail "fat mkfs 40M"
[ "$(wc -c < "$I")" = 41943040 ] || fail "fat mkfs: the image is not the size asked for"
# ⚠ the refusal is a FEATURE and is tested as one: a 4 MB image is FAT16 territory,
# and writing a boot sector that claims otherwise would be worse than saying no.
"$m" fat mkfs "$W/small.fat" 4M 2>/dev/null && fail "fat mkfs: 4M must be refused"
# a size that is not whole sectors is refused too
"$m" fat mkfs "$W/odd.fat" 41943041 2>/dev/null && fail "fat mkfs: a partial sector must be refused"

# ---------------------------------------------------------------- the verbs
printf 'hello from love\n'   > "$W/a.txt"
head -c 9000 /dev/zero       > "$W/big.bin"
printf ''                    > "$W/empty.txt"

"$m" fat ls "$I" / > "$W/o" || fail "fat ls on a fresh image"
[ -s "$W/o" ] && fail "fat ls: a fresh root is not empty"

"$m" fat put "$I" /a.txt "$W/a.txt"        || fail "fat put"
"$m" fat put "$I" /big.bin "$W/big.bin"    || fail "fat put (a multi-cluster file)"
"$m" fat put "$I" /empty.txt "$W/empty.txt" || fail "fat put (empty)"
"$m" fat mkdir "$I" /docs                  || fail "fat mkdir"
"$m" fat put "$I" /docs/inner.txt "$W/a.txt" || fail "fat put into a subdirectory"
# a long name, which is the LFN path and not the 8.3 one
"$m" fat put "$I" "/a rather long name.text" "$W/a.txt" || fail "fat put (long name)"

printf 'a rather long name.text\na.txt\nbig.bin\ndocs\nempty.txt\n' > "$W/want"
"$m" fat ls "$I" / > "$W/o" || fail "fat ls /"
cmp -s "$W/want" "$W/o" || { diff "$W/want" "$W/o"; fail "fat ls /"; }

printf 'inner.txt\n' > "$W/want"
"$m" fat ls "$I" /docs > "$W/o" || fail "fat ls /docs"
cmp -s "$W/want" "$W/o" || fail "fat ls /docs"

# the bytes come back exactly, small, empty and multi-cluster alike
"$m" fat cat "$I" /a.txt > "$W/o"     || fail "fat cat"
cmp -s "$W/a.txt" "$W/o"              || fail "fat cat: the bytes changed"
"$m" fat get "$I" /big.bin "$W/o"     || fail "fat get"
cmp -s "$W/big.bin" "$W/o"            || fail "fat get: the bytes changed"
"$m" fat cat "$I" /empty.txt > "$W/o" || fail "fat cat (empty)"
[ -s "$W/o" ] && fail "fat cat: an empty file came back with bytes"

"$m" fat stat "$I" /a.txt | grep -q '^16 bytes' || fail "fat stat: the size"

# stdin is the source when none is named
"$m" fat put "$I" /piped.txt - < "$W/a.txt" || fail "fat put from stdin"
"$m" fat cat "$I" /piped.txt > "$W/o"       || fail "fat cat (piped)"
cmp -s "$W/a.txt" "$W/o"                    || fail "fat put from stdin: the bytes changed"

# rm, and the two refusals that are not the same refusal
"$m" fat rm "$I" /piped.txt || fail "fat rm"
"$m" fat ls "$I" / | grep -qx piped.txt && fail "fat rm: it is still listed"
"$m" fat rm "$I" /docs 2>/dev/null && fail "fat rm: a directory with a file in it must be refused"
"$m" fat rm "$I" /nope 2>/dev/null && fail "fat rm: a missing file must be refused"
"$m" fat cat "$I" /nope 2>/dev/null && fail "fat cat: a missing file must be refused"
"$m" fat ls "$W/a.txt" 2>/dev/null && fail "fat ls: a non-filesystem must be refused"
"$m" fat ls "$W/nothing-here" 2>/dev/null && fail "fat ls: a missing image must be refused"

echo "fat: the verbs (mkfs/ls/stat/cat/get/put/mkdir/rm, LFN, empty, multi-cluster) ok"

# ---------------------------------------------------------------- mkfs.vfat
"$m" mkfs.vfat -C "$W/bb.fat" 40960 || fail "mkfs.vfat -C"
[ "$(wc -c < "$W/bb.fat")" = 41943040 ] || fail "mkfs.vfat -C: BLOCKS are 1024 bytes"
"$m" fat ls "$W/bb.fat" / > /dev/null || fail "mkfs.vfat -C: the image will not mount"
"$m" mkdosfs -C "$W/dd.fat" 40960 || fail "mkdosfs (the other spelling)"
echo "fat: mkfs.vfat / mkdosfs (busybox's two spellings, -C, 1K blocks) ok"

# ---------------------------------------------------------------- mtools interop
# the half that matters: a second implementation, written by other people, reading
# what we wrote and writing what we read. ⚠ mtools wants a drive letter, so every
# call here carries its own config through MTOOLSRC rather than the user's ~/.mtoolsrc.
if command -v mdir > /dev/null 2>&1 && command -v mcopy > /dev/null 2>&1; then
  printf 'drive z: file="%s"\nmtools_skip_check=1\n' "$I" > "$W/mtoolsrc"
  MTOOLSRC=$W/mtoolsrc; export MTOOLSRC

  # mtools reads ours. ⚠ `mdir -/` alone prints the classic 8.3 COLUMN layout, where
  # a.txt reads "a        txt" and no grep for a filename matches; -b is the bare
  # one-path-a-line form and the only one worth comparing against.
  mdir -b -/ z:/ > "$W/mdir" 2>&1 || fail "mtools cannot read the image we formatted"
  grep -qx 'Z:/a.txt'   "$W/mdir" || fail "mtools does not see a.txt"
  grep -qx 'Z:/big.bin' "$W/mdir" || fail "mtools does not see big.bin"
  grep -qx 'Z:/docs/inner.txt' "$W/mdir" || fail "mtools does not see the subdirectory"
  grep -qx 'Z:/a rather long name.text' "$W/mdir" || fail "mtools does not see the long name"
  mcopy -n z:/big.bin "$W/o" || fail "mcopy out"
  cmp -s "$W/big.bin" "$W/o" || fail "mtools read different bytes than we wrote"

  # ours reads mtools'
  mmd z:/fromm            || fail "mmd"
  mcopy -n "$W/a.txt" z:/fromm/via-mtools.txt || fail "mcopy in"
  "$m" fat ls "$I" /fromm | grep -qx via-mtools.txt \
    || fail "we do not see what mtools wrote"
  "$m" fat cat "$I" /fromm/via-mtools.txt > "$W/o" || fail "fat cat of an mtools file"
  cmp -s "$W/a.txt" "$W/o" || fail "we read different bytes than mtools wrote"

  # and a fresh image made by mtools' own mkfs, if it is here
  if command -v mformat > /dev/null 2>&1; then
    head -c 41943040 /dev/zero > "$W/mt.fat"
    printf 'drive y: file="%s"\nmtools_skip_check=1\n' "$W/mt.fat" >> "$W/mtoolsrc"
    if mformat -F y: 2>/dev/null; then
      mcopy -n -i "$W/mt.fat" "$W/a.txt" ::/hello.txt || fail "mcopy into an mformat image"
      "$m" fat ls "$W/mt.fat" / | grep -qx hello.txt \
        || fail "we cannot read a filesystem mformat made"
      echo "fat: mformat interop (their format, our reader) ok"
    fi
  fi
  echo "fat: mtools interop (their reader on our format, our reader on their writes) ok"
else
  echo "fat: mtools not on PATH -- the interop half skipped"
fi

rm -rf "$W"
