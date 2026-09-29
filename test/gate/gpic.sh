#!/bin/sh
# test/gate/gpic.sh -- classic pic (src/apps/kore/gpic.l) against groff's own, byte for byte.
#
# each test/gpic/*.pic runs through /usr/bin/pic and through `love pic` in five modes --
# troff, -n, -t, -c and -tz -- and stdout and the exit status must agree. test/gpic/open
# holds the cases not yet climbed: counted and named, never failing the gate. the chem-*
# cases are groff chem's output and copy groff's chem.pic, which the run finds beside groff;
# where it is missing they are left out. fz-* and fy-* are random pictures, kept once they
# came out the same. every run is capped (2 GB, 20 s), one at a time: a runaway picture is
# a failure, not a machine brought down, and a reference that aborts (groff's -c now and
# then) leaves its case without an oracle. with -v, the first lines of each difference.
#
# skips where groff's pic is missing; takes the love binary as $1.
love=${1:-out/love}
[ -x "$love" ] || { echo "gpic: no $love -- run 'make host'"; exit 1; }
ref=/usr/bin/pic
[ -x "$ref" ] || { echo "gpic: no $ref (groff), skipped"; exit 0; }
verbose=$2
r=$(pwd)
L=$r/$love
w=$(mktemp -d)
trap 'rm -rf "$w"' EXIT
chem=
for f in /usr/share/groff/*/tmac/chem.pic; do [ -f "$f" ] && { chem=$f; break; }; done

# run DIR MODE: one line per case, "ok NAME" or "differs NAME"
run() {
  rm -rf "$w/c"; mkdir "$w/c"
  cp "$1"/*.pic "$w/c/" 2>/dev/null
  if [ -n "$chem" ]; then cp "$chem" "$w/c/chem.pic"; else rm -f "$w/c"/chem-*.pic; fi
  for f in "$w/c"/*.pic; do
    [ -f "$f" ] || continue
    n=$(basename "$f" .pic)
    [ "$n" = chem ] && continue
    (cd "$w/c" && ulimit -v 2000000 && timeout 20 "$ref" $2 "$n.pic" > "$w/a" 2> /dev/null; echo "exit=$?" >> "$w/a")
    # groff's pic -c aborts now and then on a picture it drew the last time: no oracle
    if grep -q '^exit=\(124\|134\|137\|139\)$' "$w/a"; then echo "skip $n"; continue; fi
    (cd "$w/c" && ulimit -v 2000000 && timeout 20 "$L" pic $2 "$n.pic" > "$w/b" 2> /dev/null; echo "exit=$?" >> "$w/b")
    if cmp -s "$w/a" "$w/b"; then echo "ok $n"
    else
      echo "differs $n"
      [ -n "$verbose" ] && diff "$w/a" "$w/b" | head -8 >&2
    fi
  done
}

bad=0; total=0
[ -n "$chem" ] || echo "gpic: no chem.pic beside groff, the chem cases left out"
for m in "" -n -t -c -tz; do
  run test/gpic "$m" > "$w/gate"
  k=$(grep -c '^ok\|^differs' "$w/gate"); d=$(grep -c '^differs' "$w/gate"); s=$(grep -c '^skip' "$w/gate")
  total=$((total + k)); bad=$((bad + d))
  grep '^differs' "$w/gate" | sed "s/^differs/  differs (pic $m):/"
  run test/gpic/open "$m" > "$w/open"
  ok=$(grep -c '^ok' "$w/open"); all=$(grep -c . "$w/open")
  x=; [ "$s" -gt 0 ] && x=", $s without an oracle"
  echo "gpic: pic ${m:-(troff)}: $((k - d)) of $k gating identical$x; open $ok of $all"
done
[ $bad -eq 0 ] || { echo "FAIL gpic: $bad of $total differ from $ref"; exit 1; }
echo "gpic: ok"
