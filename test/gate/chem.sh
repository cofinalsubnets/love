#!/bin/sh
# test/gate/chem.sh -- chem (src/apps/kore/chem.l) against groff's, byte for byte.
#
# each test/chem/*.chem runs through groff's chem and through `love chem`: stdout and the
# exit status must agree, and our pic must take what our chem wrote as groff's pic takes
# what groff's wrote: the exit status the same, and how many draw the same byte for byte
# counted (kore's pic still puts the odd dot of a dotted line a hair off groff's).
# test/chem/open holds the cases not yet climbed: counted and named,
# never failing the gate. fz-* are random diagrams, kept once they came out the same. every
# run is capped (2 GB, 20 s), one at a time. with -v, the first lines of each difference.
#
# skips where groff's chem is missing; takes the love binary as $1.
love=${1:-out/love}
[ -x "$love" ] || { echo "chem: no $love -- run 'make host'"; exit 1; }
ref=/usr/bin/chem
[ -x "$ref" ] || { echo "chem: no $ref (groff), skipped"; exit 0; }
verbose=$2
r=$(pwd)
L=$r/$love
w=$(mktemp -d)
trap 'rm -rf "$w"' EXIT
pic=/usr/bin/pic
[ -x "$pic" ] || pic=

# run DIR: one line per case, "ok NAME" or "differs NAME"
run() {
  rm -rf "$w/c"; mkdir "$w/c"
  cp "$1"/*.chem "$w/c/" 2>/dev/null
  for f in "$w/c"/*.chem; do
    [ -f "$f" ] || continue
    n=$(basename "$f" .chem)
    (cd "$w/c" && ulimit -v 2000000 && timeout 20 "$ref" "$n.chem" > "$w/a" 2> /dev/null; echo "exit=$?" >> "$w/a")
    (cd "$w/c" && ulimit -v 2000000 && timeout 20 "$L" chem "$n.chem" > "$w/b" 2> /dev/null; echo "exit=$?" >> "$w/b")
    same=1
    cmp -s "$w/a" "$w/b" || same=
    # the pictures, where groff's pic is here to say what they draw: the same exit status
    # owed, the same drawing counted
    if [ -n "$same" ] && [ -n "$pic" ]; then
      (cd "$w/c" && "$ref" "$n.chem" 2> /dev/null | timeout 20 "$pic" > "$w/pa" 2> /dev/null; echo "exit=$?" >> "$w/pa")
      (cd "$w/c" && ulimit -v 2000000 && "$L" chem "$n.chem" 2> /dev/null | timeout 20 "$L" pic > "$w/pb" 2> /dev/null; echo "exit=$?" >> "$w/pb")
      [ "$(tail -1 "$w/pa")" = "$(tail -1 "$w/pb")" ] || same=
      cmp -s "$w/pa" "$w/pb" && echo "drawn $n"
    fi
    if [ -n "$same" ]; then echo "ok $n"
    else
      echo "differs $n"
      [ -n "$verbose" ] && { diff "$w/a" "$w/b" | head -8; diff "$w/pa" "$w/pb" 2> /dev/null | head -4; } >&2
    fi
  done
}

[ -n "$pic" ] || echo "chem: no groff pic, the pictures left undrawn"
run test/chem > "$w/gate"
k=$(grep -c '^ok\|^differs' "$w/gate"); d=$(grep -c '^differs' "$w/gate"); dr=$(grep -c '^drawn' "$w/gate")
grep '^differs' "$w/gate" | sed 's/^differs/  differs:/'
run test/chem/open > "$w/open"
ok=$(grep -c '^ok' "$w/open"); all=$(grep -c '^ok\|^differs' "$w/open")
echo "chem: $((k - d)) of $k identical, $dr drawn the same by both pics; open $ok of $all"
[ $d -eq 0 ] || { echo "FAIL chem: $d of $k differ from $ref"; exit 1; }
echo "chem: ok"
