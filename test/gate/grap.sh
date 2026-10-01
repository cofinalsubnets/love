#!/bin/sh
# test/gate/grap.sh -- grap (src/apps/kore/grap.l) against plan 9's, byte for byte.
#
# each test/grap/*.g runs through plan9port's grap and through `love grap`: stdout and the
# exit status must agree, and our pic must take what our grap wrote as groff's pic takes
# what plan 9's wrote: the exit status the same, and how many draw the same byte for byte
# counted.
# test/grap/open holds the cases not yet climbed: counted and named,
# never failing the gate. fz-* are random graphs, kept once they came out the same; each
# holds one graph, since plan 9's grap carries a freed mark from one graph to the next.
# every run is capped (2 GB, 20 s), one at a time. with -v, the first lines of each
# difference.
#
# skips where plan 9's grap is missing; takes the love binary as $1.
love=${1:-out/love}
[ -x "$love" ] || { echo "grap: no $love -- run 'make host'"; exit 1; }
ref=/usr/lib/plan9/bin/grap
[ -x "$ref" ] || { echo "grap: no $ref (plan9port), skipped"; exit 0; }
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
  cp "$1"/* "$w/c/" 2>/dev/null
  for f in "$w/c"/*.g; do
    [ -f "$f" ] || continue
    n=$(basename "$f" .g)
    (cd "$w/c" && ulimit -v 2000000 && timeout 20 "$ref" "$n.g" > "$w/a" 2> /dev/null; echo "exit=$?" >> "$w/a")
    (cd "$w/c" && ulimit -v 2000000 && timeout 20 "$L" grap "$n.g" > "$w/b" 2> /dev/null; echo "exit=$?" >> "$w/b")
    same=1
    cmp -s "$w/a" "$w/b" || same=
    # the pictures, where groff's pic is here to say what they draw: the same exit status
    # owed, the same drawing counted
    if [ -n "$same" ] && [ -n "$pic" ]; then
      (cd "$w/c" && "$ref" "$n.g" 2> /dev/null | timeout 20 "$pic" > "$w/pa" 2> /dev/null; echo "exit=$?" >> "$w/pa")
      (cd "$w/c" && ulimit -v 2000000 && "$L" grap "$n.g" 2> /dev/null | timeout 20 "$L" pic > "$w/pb" 2> /dev/null; echo "exit=$?" >> "$w/pb")
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

[ -n "$pic" ] || echo "grap: no groff pic, the pictures left undrawn"
run test/grap > "$w/gate"
k=$(grep -c '^ok\|^differs' "$w/gate"); d=$(grep -c '^differs' "$w/gate"); dr=$(grep -c '^drawn' "$w/gate")
grep '^differs' "$w/gate" | sed 's/^differs/  differs:/'
run test/grap/open > "$w/open"
ok=$(grep -c '^ok' "$w/open"); all=$(grep -c '^ok\|^differs' "$w/open")
echo "grap: $((k - d)) of $k identical, $dr drawn the same by both pics; open $ok of $all"
[ $d -eq 0 ] || { echo "FAIL grap: $d of $k differ from $ref"; exit 1; }
echo "grap: ok"
