#!/bin/sh
# test/gate/rtall.sh -- the runtime is whole: every name moonlibc's headers declare links on
# every isa mooncc targets, bare ones too. the links run outside the tree, where mooncc finds
# no source home: an isa this build carries (runtime-ar 0) takes the carried archive, which
# rtcarried must answer, and an isa config.mk left out compiles its runtime from the carried
# source, and links all the same
# usage: rtall.sh OUTDIR LOVE
. test/gate/skip.sh
. test/gate/cclib.sh
set -u

ho=$1
m=$(cd "$(dirname "$2")" && pwd)/$(basename "$2")
d=$(mkdir -p "$ho/rtall" && cd "$ho/rtall" && pwd)
name=test_rtall

names=$(hdrnames)
nref=$(printf '%s\n' $names | grep -c .)
hdrdecls $names > "$d/decls.c"

w=$d/w
rm -rf "$w"
mkdir -p "$w"
# what this build carries, and what moon serves a link of each with no home
carried=$(cd "$w" && printf '%s\n' "(borrow 'tree)" "(map (s \\ puts (s + \" \")) (runtime-ar 0))" | LOVE_NO_IMAGE= "$m")
[ -n "$carried" ] || fail "runtime-ar 0 names no isa: this love carries no runtime"
served() { (cd "$w" && printf '%s\n' "(borrow 'moon)" "(puts (string? (rtcarried () '$1 'linux) ? \"yes\" \"no\"))" | LOVE_NO_IMAGE= "$m"); }

# a bare link lays at an address and takes no crt0
hosted="x64 a64 rv64 i386 arm rv32 wasm"
bare="thumb1 thumb2 thumb2sp xtensa"
n=0 nc=0
for t in $hosted $bare; do
  case " $bare " in *" $t "*) org="-Ttext 0x10000" ;; *) org= ;; esac
  # shellcheck disable=SC2086
  (cd "$w" && LOVE_NO_IMAGE= "$m" mooncc -t "$t" $org -o "$d/decls.$t" "$d/decls.c") > "$d/$t.build" 2>&1 || {
    grep -i "undef" "$d/$t.build" >&2 || cat "$d/$t.build" >&2
    fail "$t: $nref names declared, at least one does not link"; }
  case " $carried " in
    *" $t "*) [ "$(served "$t")" = yes ] || fail "$t: carried, yet rtcarried serves no archive"
              nc=$((nc + 1)) ;;
  esac
  n=$((n + 1))
done
rm -rf "$w"

echo "test_rtall: all $nref names moonlibc's headers declare link on $n isas ($hosted, bare $bare), $nc from the carried archives alone ($carried)"
