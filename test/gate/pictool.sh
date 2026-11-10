#!/bin/sh
# test/gate/pictool.sh -- pic (src/apps/pic/gpic.l), grap and chem against their references, byte for byte.
#
# each test/TOOL case runs through the reference and through `love`: stdout and the exit status
# must agree. grap's and chem's output then goes through our pic and groff's: the exit status the
# same, and how many draw the same byte for byte counted. pic runs in each of its five modes, and a
# reference that aborts (groff's -c now and then) leaves its case without an oracle; its chem-*
# cases copy groff's chem.pic, and are left out where that is missing. test/TOOL/open holds the
# cases not yet climbed: counted and named, never failing the gate. fz-* are random cases, drawn by
# test/gate/fzgen.l under a pinned seed; grap's each hold one graph, since plan 9's carries a freed
# mark from one graph to the next. every run is capped (2 GB, 20 s), one at a time. with -v, the
# first lines of each difference.
#
# skips where the reference is missing. usage: pictool.sh gpic|grap|chem LOVE [-v]
. test/gate/skip.sh
tool=$1
love=${2:-out/love}
verbose=$3
modes=one
pic=/usr/bin/pic
[ -x "$pic" ] || pic=
case $tool in
  gpic) ref=/usr/bin/pic; verb=pic; ext=pic; dfn=135; pic=; modes="troff -n -t -c -tz" ;;
  grap) ref=/usr/lib/plan9/bin/grap; verb=grap; ext=g; dfn=222 ;;
  chem) ref=/usr/bin/chem; verb=chem; ext=chem; dfn=150 ;;
  *) echo "pictool.sh: unknown tool $tool" >&2; exit 1 ;;
esac
[ -x "$love" ] || { echo "$tool: no $love -- run 'make host'"; exit 1; }
[ -x "$ref" ] || gate_skip "$tool: no $ref, skipped"
r=$(pwd)
L=$r/$love
# the fz-* cases: FZ_N drawn from test/gate/fzgen.l under FZ_SEED; a case that differs is printed
seed=${FZ_SEED:-20261018} fzn=${FZ_N:-$dfn}
w=$(mktemp -d)
trap 'rm -rf "$w"' EXIT
chem=
if [ $tool = gpic ]; then
  for f in /usr/share/groff/*/tmac/chem.pic; do [ -f "$f" ] && { chem=$f; break; }; done
  [ -n "$chem" ] || echo "gpic: no chem.pic beside groff, the chem cases left out"
elif [ -z "$pic" ]; then
  echo "$tool: no groff pic, the pictures left undrawn"
fi

# run DIR FLAG: one line per case: ok, differs, drawn or skip, and its name
run() {
  rm -rf "$w/c"; mkdir "$w/c"
  cp "$1"/* "$w/c/" 2>/dev/null
  # the random cases are drawn here, from the seed
  [ "$1" = test/$tool ] && "$L" "$r/test/gate/fzgen.l" $tool "$seed" "$fzn" "$w/c"
  if [ $tool = gpic ]; then
    if [ -n "$chem" ]; then cp "$chem" "$w/c/chem.pic"; else rm -f "$w/c"/chem-*.pic; fi
  fi
  for f in "$w/c"/*.$ext; do
    [ -f "$f" ] || continue
    n=$(basename "$f" .$ext)
    [ $tool = gpic ] && [ "$n" = chem ] && continue
    (cd "$w/c" && ulimit -v 2000000 && timeout 20 "$ref" $2 "$n.$ext" > "$w/a" 2> /dev/null; echo "exit=$?" >> "$w/a")
    if [ $tool = gpic ] && grep -q '^exit=\(124\|134\|137\|139\)$' "$w/a"; then echo "skip $n"; continue; fi
    (cd "$w/c" && ulimit -v 2000000 && timeout 20 "$L" $verb $2 "$n.$ext" > "$w/b" 2> /dev/null; echo "exit=$?" >> "$w/b")
    same=1
    cmp -s "$w/a" "$w/b" || same=
    # the pictures: the same exit status owed, the same drawing counted
    if [ -n "$same" ] && [ -n "$pic" ]; then
      (cd "$w/c" && "$ref" "$n.$ext" 2> /dev/null | timeout 20 "$pic" > "$w/pa" 2> /dev/null; echo "exit=$?" >> "$w/pa")
      (cd "$w/c" && ulimit -v 2000000 && "$L" $verb "$n.$ext" 2> /dev/null | timeout 20 "$L" pic > "$w/pb" 2> /dev/null; echo "exit=$?" >> "$w/pb")
      [ "$(tail -1 "$w/pa")" = "$(tail -1 "$w/pb")" ] || same=
      cmp -s "$w/pa" "$w/pb" && echo "drawn $n"
    fi
    if [ -n "$same" ]; then echo "ok $n"
    else
      echo "differs $n"
      case $n in fz-*) sed 's/^/    | /' "$f" >&2 ;; esac
      [ -n "$verbose" ] && { diff "$w/a" "$w/b" | head -8; [ -z "$pic" ] || diff "$w/pa" "$w/pb" 2> /dev/null | head -4; } >&2
    fi
  done
}

bad=0; total=0
for m in $modes; do
  fl=; lab=
  if [ $tool = gpic ]; then lab="pic $m: "; [ $m = troff ] || fl=$m; fi
  run test/$tool "$fl" > "$w/gate"
  k=$(grep -c '^ok\|^differs' "$w/gate"); d=$(grep -c '^differs' "$w/gate"); s=$(grep -c '^skip' "$w/gate"); dr=$(grep -c '^drawn' "$w/gate")
  total=$((total + k)); bad=$((bad + d))
  grep '^differs' "$w/gate" | sed "s/^differs/  differs ($lab):/"
  run test/$tool/open "$fl" > "$w/open"
  ok=$(grep -c '^ok' "$w/open"); all=$(grep -c '^ok\|^differs' "$w/open")
  x=; [ "$s" -gt 0 ] && x=", $s without an oracle"
  [ -z "$pic" ] || x="$x, $dr drawn the same by both pics"
  echo "$tool: $lab$((k - d)) of $k identical$x; open $ok of $all"
done
# the differences the fz cases are steered around, still to fix (test/gate/fzgen.l's fz-known)
"$L" "$r/test/gate/fzgen.l" $tool known > "$w/known"
sed 's/^/  known: /' "$w/known"
echo "$tool: $(grep -c . "$w/known") known differences steered around"
[ $bad -eq 0 ] || { echo "FAIL $tool: $bad of $total differ from $ref (fz cases: FZ_SEED=$seed FZ_N=$fzn)"; exit 1; }
echo "$tool: ok"
