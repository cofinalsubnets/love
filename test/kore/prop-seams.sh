#!/bin/sh
# test/kore/prop-seams.sh -- the 4096-byte read seams, over every tool that reads by chunks
. "$(dirname "$0")/common.sh"

# a line across a gulp, input with no newline, a file ending on the boundary: each a place
# to lose or double a byte
awk 'BEGIN{for(i=0;i<300;i++)printf "%09d-", i; print ""}' > "$ho/.gs1"   # one 3000-char line
awk 'BEGIN{for(i=0;i<40;i++){for(j=0;j<300;j++)printf "%09d-",j; print ""}}' > "$ho/.gs2"
dd if=/dev/zero bs=4096 count=1 2>/dev/null | tr '\0' 'x' > "$ho/.gs3"    # 4096, no newline
printf 'abc' > "$ho/.gs4"                                                 # no newline at all
: > "$ho/.gs5"                                                            # empty
# wc's words and uniq's runs straddle a gulp too
awk 'BEGIN{for(i=0;i<2000;i++)printf "word%d ", i%7; print ""}' > "$ho/.gs6"
awk 'BEGIN{for(i=0;i<9000;i++)print "dup" i%3}' > "$ho/.gs7"
# one row per distinct read loop, not per tool: rev for ulines (nl fold expand unexpand ride
# it), cat for uchunks, head's line and byte clips, tail's ring, byte hold and +N, uniq's run,
# sed's lookahead, grep's walk, wc's three counters, the three digests
for f in .gs1 .gs2 .gs3 .gs4 .gs5 .gs6 .gs7; do
  for t in "cat" "rev" "head -n 3" "tail -n 3" "head -n 1" "head -n -2" "tail -n +2" \
           "grep 000000001" "grep -c 0" "grep -n 000000002" "sed s/00/QQ/" "sed -n 2p" \
           'sed $d' "sed 2q" "wc" "wc -c" "wc -l" "wc -w" "uniq" "uniq -c" \
           "tac" "cksum" "md5sum" "sha256sum" "head -c 4097" "head -c -4097" \
           "tail -c 4097" "tail -c +4097"; do
    # shellcheck disable=SC2086
    $t "$ho/$f" > "$g" 2>/dev/null; korerun $t "$ho/$f" > "$o" 2>/dev/null
    cmp -s "$g" "$o" || fail "kore $t over $f (a gulp seam)"
  done
done
korerun cat "$ho/.gs1" "$ho/.gs4" "$ho/.gs2" > "$o"; cat "$ho/.gs1" "$ho/.gs4" "$ho/.gs2" > "$g"
cmp -s "$g" "$o" || fail "kore cat: operands joined across the seams"
# sed joins its operands: $ is the last file's last line, a middle file keeps its newline.
# grep does not: its numbers restart per file
for t in 'sed $d' 'sed $s/^/L/' "sed -n 2p" "sed 3q" "grep -n 000000002" "grep -c 0"; do
  # shellcheck disable=SC2086
  $t "$ho/.gs2" "$ho/.gs4" "$ho/.gs2" > "$g" 2>/dev/null
  korerun $t "$ho/.gs2" "$ho/.gs4" "$ho/.gs2" > "$o" 2>/dev/null
  cmp -s "$g" "$o" || fail "kore $t over three operands (the join, and its lookahead)"
done
# tee holds every destination open while reading: its seam is the fan-out
tee "$ho/.te1" "$ho/.te2" < "$ho/.gs6" > "$g"
korerun tee "$ho/.to1" "$ho/.to2" < "$ho/.gs6" > "$o"
cmp -s "$g" "$o" && cmp -s "$ho/.te1" "$ho/.to1" && cmp -s "$ho/.te2" "$ho/.to2" \
  || fail "kore tee: two destinations across the gulps"
wc "$ho/.gs6" "$ho/.gs7" | sed "s|$ho/||g" > "$g"
korerun wc "$ho/.gs6" "$ho/.gs7" | sed "s|$ho/||g" > "$o"
cmp -s "$g" "$o" || fail "kore wc: the total row over two operands"
echo "kore: the gulp seams (a line past 4096, no final newline, empty, boundary-exact) ok"
