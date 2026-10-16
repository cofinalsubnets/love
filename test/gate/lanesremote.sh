#!/bin/sh
# test/gate/lanesremote.sh -- lanes.sh --remote over a stand-in tree: a Makefile of three lanes,
# two of them placed off the box, and an out/love that answers the lane map and plays two
# hosts -- `up` runs what it is handed in a directory of its own, `gone` answers its room and
# its prerequisites and then drops every lane the way a lost ssh does (255). every lane must
# answer, none skipped: a placed lane on up or back here, the local one here, and each .rc and
# log agreeing on where.
#
# usage: sh test/gate/lanesremote.sh
set -u
t=$(pwd)/out/.lanesremote
rm -rf "$t" && mkdir -p "$t/out" "$t/test/gate" || exit 1
cp test/gate/lanes.sh test/gate/skip.sh "$t/test/gate/" || exit 1
fail() { echo "FAIL lanesremote: $*"; exit 1; }

# where a lane ran is the directory make ran it in: the tree's own, or far/up
cat > "$t/Makefile" <<'EOF'
host: ; @true
test_a: host ; @sleep 4; echo "a ran in $$(basename $$(pwd))"
test_b: host ; @sleep 1; echo "b ran in $$(basename $$(pwd))"
test_c: host ; @sleep 1; echo "c ran in $$(basename $$(pwd))"
EOF

cat > "$t/out/love" <<EOF
#!/bin/sh
case "\$*" in
  "bee --lanes-map")
    printf 'chain test_x,test_y\nalone test_z\nplace test_b source\nplace test_c source\ncost test_b 50\ncost test_c 90\n'
    exit 0 ;;
  "bee --on lanes --list") printf 'up 1 x64\ngone 1 x64\n'; exit 0 ;;
esac
h= src=
while [ \$# -gt 0 ] && [ "\$1" != -- ]; do
  case \$1 in
    name=*) h=\${1#name=} ;;
    --sync) src=\$2; shift ;;
  esac
  shift
done
[ \$# -gt 0 ] && shift
d=$t/far/\$h
mkdir -p "\$d"
[ -n "\$src" ] && cp "\$src/Makefile" "\$d/"
[ \$# -gt 0 ] || exit 0
case "\$h \$*" in
  "gone "*--no-print-directory*) exit 255 ;;
esac
cd "\$d" && exec "\$@"
EOF
chmod +x "$t/out/love"

( cd "$t" && LANES_HOST_MEM_GB=0 sh test/gate/lanes.sh --remote -j 1 -d out/lanes test_a test_b test_c ) > "$t/run.log" 2>&1 \
  || { cat "$t/run.log"; fail "the run was red"; }
on=
for l in a b c; do
  read -r r s w < "$t/out/lanes/test_$l.rc" || fail "test_$l left no rc"
  [ "$r" = 0 ] || fail "test_$l answered $r"
  want=.lanesremote
  [ "$w" = up ] && want=up
  [ -z "$w" ] || [ "$w" = up ] || fail "test_$l ran on $w"
  grep -qx "$l ran in $want" "$t/out/lanes/test_$l.log" || fail "test_$l's log does not say it ran in $want"
  on="$on${w:+ $l}"
done
grep -q 'on=up' "$t/out/lanes/summary" || fail "no lane went to the host that answered"
grep -q '^test_a exit=0 secs=[0-9]*$' "$t/out/lanes/summary" || fail "the local lane names a host"
grep -q "gone dropped" "$t/out/lanes/remote.log" || fail "the host that drops was never handed a lane"
echo "lanesremote: a placed lane runs on the host that answers (test_${on# }), the one a host dropped here, the local one here"
rm -rf "$t"
