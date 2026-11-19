#!/bin/sh
# test/gate/lanesremote.sh -- lanes.sh --remote over a stand-in tree: a Makefile of four lanes,
# three of them placed off the box, one of those alone, and an out/love that answers the lane
# map and plays two hosts -- `up` runs what it is handed in a directory of its own, `gone`
# answers its room and its prerequisites and then drops every lane the way a lost ssh does
# (255). every lane must answer, none skipped: a placed lane on up or back here, the local one
# here, each .rc and log agreeing on where, and only the alone lane holding a whole host. up
# rebuilds love under test_b, which so runs here, refuses test_a's twin test_e for want of a
# tool, which runs here too, and a lane there has this box's TERM. a pinned input this box's dl/
# holds reaches a host's.
#
# usage: sh test/gate/lanesremote.sh
set -u
t=$(pwd)/out/.lanesremote
rm -rf "$t" && mkdir -p "$t/out" "$t/test/gate" "$t/src/tools" "$t/dl/chibicc" || exit 1
cp test/gate/lanes.sh test/gate/skip.sh test/gate/dl.sh "$t/test/gate/" && cp src/tools/dlfind.sh "$t/src/tools/" || exit 1
echo cadb44e82354002000f6d2bbf41d3155f47a9b3e9abd50a309fdcd9b5ef791e0 > "$t/dl/chibicc/.pin"
fail() { echo "FAIL lanesremote: $*"; exit 1; }

# where a lane ran is the directory make ran it in: the tree's own, or far/up
cat > "$t/Makefile" <<'EOF'
host: ; @true
test_a: host ; @sleep 4; echo "a ran in $$(basename $$(pwd))"
test_b: host ; @[ $$(basename $$(pwd)) != up ] || printf 'BAKE\tout/love\n'; echo "b ran in $$(basename $$(pwd))"
test_c: host ; @sleep 1; echo "c ran in $$(basename $$(pwd))"; echo "TERM=$$TERM"
test_d: host ; @echo "d ran in $$(basename $$(pwd))"
test_e: host ; @[ $$(basename $$(pwd)) != up ] || { echo 'e: REFUSED: a strict box runs every lane'; exit 1; }; echo "e ran in $$(basename $$(pwd))"
EOF

cat > "$t/out/love" <<EOF
#!/bin/sh
case "\$*" in
  "bee --lanes-map")
    printf 'chain test_x,test_y\nalone test_z test_d\nplace test_b source\nplace test_c source\nplace test_d source\nplace test_e source\ncost test_b 50\ncost test_c 90\ncost test_d 99\ncost test_e 95\n'
    exit 0 ;;
  "bee --on lanes --list") printf 'up 1 x64\ngone 1 x64\n'; exit 0 ;;
esac
echo "\$*" >> $t/calls
h= src= at=
while [ \$# -gt 0 ] && [ "\$1" != -- ]; do
  case \$1 in
    name=*) h=\${1#name=} ;;
    --push) src=\$2; at=\$2; shift ;;
    --at) at=\$2; shift ;;
  esac
  shift
done
[ \$# -gt 0 ] && shift
d=$t/far/\$h
mkdir -p "\$d"
[ -z "\$at" ] || [ "\$at" = "\$(git -C $t rev-parse HEAD)" ] || exit 97
[ -n "\$src" ] && cp "$t/Makefile" "\$d/"
[ \$# -gt 0 ] || exit 0
case "\$h \$*" in
  "gone "*--no-print-directory*) exit 255 ;;
esac
cd "\$d" && exec "\$@"
EOF
chmod +x "$t/out/love"
# a host runs the gated commit: the stand-in tree is one
git -C "$t" init -q && git -C "$t" add Makefile test && git -C "$t" -c user.name=t -c user.email=t@t commit -qm t || exit 1

( cd "$t" && DL=$t/dl TERM=lanes-term LANES_HOST_MEM_GB=0 sh test/gate/lanes.sh --remote -j 1 -d out/lanes test_a test_b test_c test_d test_e ) > "$t/run.log" 2>&1 \
  || { cat "$t/run.log"; fail "the run was red"; }
on=
for l in a b c d e; do
  read -r r s w < "$t/out/lanes/test_$l.rc" || fail "test_$l left no rc"
  [ "$r" = 0 ] || fail "test_$l answered $r"
  want=.lanesremote
  [ "$w" = up ] && want=up
  [ -z "$w" ] || [ "$w" = up ] || fail "test_$l ran on $w"
  grep -qx "$l ran in $want" "$t/out/lanes/test_$l.log" || fail "test_$l's log does not say it ran in $want"
  on="$on${w:+ $l}"
done
grep -q 'on=up' "$t/out/lanes/summary" || fail "no lane went to the host that answered"
grep -q '^test_b .* on=up' "$t/out/lanes/summary" && fail "test_b rebuilt love on up and was kept"
grep -q '^test_e .* on=up' "$t/out/lanes/summary" && fail "test_e was refused on up and kept"
grep -qx 'TERM=lanes-term' "$t/out/lanes/test_c.log" || fail "test_c did not have this box's TERM"
grep -q '^test_a exit=0 secs=[0-9]*$' "$t/out/lanes/summary" || fail "the local lane names a host"
grep -q "gone dropped" "$t/out/lanes/remote.log" || fail "the host that drops was never handed a lane"
for l in $(sed -n 's/^lanes: gone dropped \([^ ]*\) .*/\1/p' "$t/out/lanes/remote.log"); do
  grep -q "^$l exit=0 .* back=gone$" "$t/out/lanes/summary" || fail "$l, which gone gave back, is not marked back=gone"
done
cmp -s "$t/dl/chibicc/.pin" "$t/far/up/dl/chibicc/.pin" || fail "up's dl/ did not take this box's chibicc"
grep -- '--whole' "$t/calls" | grep -q 'test_d$' || fail "the alone lane went to a host without --whole"
grep -- '--whole' "$t/calls" | grep -qv 'test_d$' && fail "a lane beside others went to a host with --whole"
echo "lanesremote: a placed lane runs on the host that answers (test_${on# }), the one a host dropped here, the local one here"
rm -rf "$t"
