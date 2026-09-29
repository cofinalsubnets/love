#!/bin/sh
# test/kore/seams.sh -- the 4096-byte gulp seams, over every tool that reads by chugs
. "$(dirname "$0")/common.sh"

# THE GULP SEAMS, one property over every tool that reads. cat/head/tail/nl/rev pull
# 4096-byte chugs (src/apps/kore/u.l's urd-line and urd-gulp), so a line that spans a gulp,
# an input with no newline in it at all, and a file that ends exactly on the boundary
# are each a place the reader can lose or double a byte -- and none of them shows on
# the few-line fixtures the per-tool files use.
awk 'BEGIN{for(i=0;i<300;i++)printf "%09d-", i; print ""}' > "$ho/.gs1"   # one 3000-char line
awk 'BEGIN{for(i=0;i<40;i++){for(j=0;j<300;j++)printf "%09d-",j; print ""}}' > "$ho/.gs2"
dd if=/dev/zero bs=4096 count=1 2>/dev/null | tr '\0' 'x' > "$ho/.gs3"    # 4096, no newline
printf 'abc' > "$ho/.gs4"                                                 # no newline at all
: > "$ho/.gs5"                                                            # empty
# wc counts a WORD as a maximal ink run, so one straddling a gulp is the seam that
# double-counts; and uniq's runs straddle too. Neither shows on the fixtures above,
# which hold no spaces and no repeats.
awk 'BEGIN{for(i=0;i<2000;i++)printf "word%d ", i%7; print ""}' > "$ho/.gs6"
awk 'BEGIN{for(i=0;i<9000;i++)print "dup" i%3}' > "$ho/.gs7"
# ONE ROW PER READER, not per tool. two mutations settle the roster: a fault in the
# continuation fill (a line straddling a gulp) is caught by every tool on urd-line and
# by none on urd-gulp, and a fault in urd-gulp by exactly the other set. so the tools
# that ride `ulines` and carry nothing of their own -- nl, fold, expand, unexpand --
# all answer for rev, and their own work is held to GNU in field.sh and column.sh.
# what stays is one row per DISTINCT loop: rev for ulines, cat for uchunks, head's two
# clips (first-n and the -N queue) and its two byte clips (-c N, -c -N), tail's ring, its
# byte hold and its +N open, uniq's run, sed's lookahead, grep's own walk, wc's three
# counters (ucount-go/-l/-b, picked by flag), and the three digests, which share a read
# loop but not a hash state.
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
# sed JOINS its operands, so $ is the last line of the LAST file and an unterminated
# file in the MIDDLE keeps its newline -- both are lookahead, and both are invisible
# on one operand. grep does not join: its numbers restart per file.
for t in 'sed $d' 'sed $s/^/L/' "sed -n 2p" "sed 3q" "grep -n 000000002" "grep -c 0"; do
  # shellcheck disable=SC2086
  $t "$ho/.gs2" "$ho/.gs4" "$ho/.gs2" > "$g" 2>/dev/null
  korerun $t "$ho/.gs2" "$ho/.gs4" "$ho/.gs2" > "$o" 2>/dev/null
  cmp -s "$g" "$o" || fail "kore $t over three operands (the join, and its lookahead)"
done
# tee holds every destination open while it reads, so its seam is the fan-out
tee "$ho/.te1" "$ho/.te2" < "$ho/.gs6" > "$g"
korerun tee "$ho/.to1" "$ho/.to2" < "$ho/.gs6" > "$o"
cmp -s "$g" "$o" && cmp -s "$ho/.te1" "$ho/.to1" && cmp -s "$ho/.te2" "$ho/.to2" \
  || fail "kore tee: two destinations across the gulps"
wc "$ho/.gs6" "$ho/.gs7" | sed "s|$ho/||g" > "$g"
korerun wc "$ho/.gs6" "$ho/.gs7" | sed "s|$ho/||g" > "$o"
cmp -s "$g" "$o" || fail "kore wc: the total row over two operands"
echo "kore: the gulp seams (a line past 4096, no final newline, empty, boundary-exact) ok"
