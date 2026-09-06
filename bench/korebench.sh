#!/bin/sh
# korebench.sh -- kore's applets against busybox, uutils and GNU, on generated
# corpora. NOT A GATE and deliberately not wired into one: a development
# instrument, run by hand while working in src/apps/kore/, printing four readings
# of the same jobs rather than a verdict. The doc it fills is doc/misc/kore-gauge.md.
#
# THE SUBJECT is src/apps/kore/ -- love on the u-floor, interpreted, against three
# C/Rust userlands. Being slower than all three is expected and is not the finding.
# WHAT THIS LOOKS FOR IS THE SHAPE OF THE SLOWNESS, and that is why there are five
# tables instead of one number:
#
#   answers -- every lane runs the same command line, outputs diffed against GNU.
#              A divergence is a BUG and this is the only table where a tool can be
#              said to be wrong. It is also the cheapest differential src/apps/kore/
#              has: three independent implementations of the same POSIX text, which
#              will disagree with us in different places if we are wrong and in none
#              if we are right. ⚠ LC_ALL=C throughout -- sort and tr have a locale,
#              and without it GNU collates differently from the other three and
#              every row reads as a divergence.
#   start   -- the fixed price of one invocation. love loads an image and wakes a
#              heap before reading a byte; busybox execs and is in main(). This is
#              what a `find -exec` loop pays and it has nothing to do with any
#              applet, so it is measured once and never folded into a row below.
#   work    -- the corpus rows, big enough that start is a rounding error.
#   shapes  -- THE POINT OF THIS SCRIPT. The same tools on inputs chosen to be
#              adversarial rather than typical: one line with no newline in it, a
#              million one-byte lines, a file of one repeated byte, random bytes,
#              and an ERE built to make a backtracking matcher explode. A tool can
#              be a flat 8x on the `work` table and 400x on one of these, and
#              nothing in ordinary use would ever say so.
#   scaling -- the other half of the same question, and the more reliable one: the
#              same job at n, 2n and 4n, reported as t(4n)/t(n) with the start cost
#              SUBTRACTED OUT first. 4.0 is linear, ~4.3 is n log n, 16.0 is
#              quadratic, and 1.0 means the tool stopped early instead of reading
#              the whole input. A single timing cannot tell a slow constant from a
#              bad exponent; this table is what tells them apart, and an exponent
#              is the defect that keeps growing after the machine gets faster.
#
# ⚠ NEVER READ A WORK ROW ALONE. The nif-backed rows (md5sum, sha256sum, cksum) are
# the floor: their inner loop is the same C in every lane, so whatever ratio they
# show is love's own per-invocation and per-byte overhead and NOT the applet's
# algorithm. A row at the md5sum ratio is as fast as this tree can currently make
# it; a row well above it is the applet's own, and the scaling table says whether
# that is a constant or an exponent.
#
# ⚠ EVERY TIMED RUN IS UNDER A TIMEOUT (default 60 s). A pathology need not
# terminate -- catastrophic backtracking is the one here that will not -- so a cell
# reading `to` is a result and not a harness failure.
#
# A lane not on PATH drops out of every table; uutils is coreutils only, so the
# grep/sed/awk/bc/tar/sh rows show `-` for it and that is not a failure.
#
# usage: ./korebench.sh [mb] [samples]
#   mb       corpus size in megabytes for the work table (default 8)
#   samples  timed runs per cell, median reported (default 3)
# env:
#   LOVE=path   the binary under test (default ../out/love)
#   TIMEOUT=n   per-run wall-clock cutoff, seconds (default 60). ⚠ not tight: the
#               rows here are chosen to be slow, and a cutoff that catches one of
#               them turns a NUMBER worth recording into an unreadable `to`.
#   SCALE=n     the LARGEST scaling size in MB; the table reads n/4, n/2, n
#               (default 4). A scaling row answering `too fast` wants this raised.
#   RAW=path    also write "<row> <lane> <ms>" lines for bench/mkhtml.sh
set -u

R=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
MB=${1:-8}
SAMPLES=${2:-3}
TO=${TIMEOUT:-60}
RAW=${RAW:-}
SCALE=${SCALE:-4}
W=$R/out/bench/kore
m=${LOVE:-$R/out/love}

export LC_ALL=C

[ -x "$m" ] || { echo "korebench: no $m -- run \`make host\` first" >&2; exit 1; }

# the lanes, in report order; kore first so it is the numerator everywhere
have=
[ -x "$m" ]                        && have="$have kore"
command -v busybox > /dev/null 2>&1 && have="$have busybox"
command -v uu-cat  > /dev/null 2>&1 && have="$have uutils"
command -v cat     > /dev/null 2>&1 && have="$have gnu"

# the rosters are asked for ONCE -- `love verbs` is an image load, and asking it per
# cell would cost more than some of the rows being timed.
kore_verbs=$("$m" verbs 2>/dev/null)
bb_verbs=$(busybox --list 2>/dev/null)
carries() {                      # does LANE carry TOOL?
  case $1 in
    kore)    echo "$kore_verbs" | grep -qx "$2" ;;
    busybox) echo "$bb_verbs"   | grep -qx "$2" ;;
    uutils)  command -v "uu-$2" > /dev/null 2>&1 ;;
    gnu)     command -v "$2" > /dev/null 2>&1 ;;
  esac
}
# the one place a lane's spelling lives. only the PREFIX varies, never the
# arguments, so this answers the prefix words and a caller writes
# `med $(pfx "$l" "$t") "$@"` -- the prefix unquoted (it splits into 1-2 words that
# never contain one) and the arguments still quoted. Handing the whole line back
# for splitting instead would tear `awk '{n += $1} END { print n }'` into eight.
# `sh` is the row every lane spells differently: ours is lush, busybox's is ash,
# GNU's is bash.
pfx() {
  case "$1:$2" in
    kore:sh)    echo "$m sh" ;;
    busybox:sh) echo "busybox ash" ;;
    gnu:sh)     echo "bash" ;;
    kore:*)     echo "$m $2" ;;
    busybox:*)  echo "busybox $2" ;;
    uutils:*)   echo "uu-$2" ;;
    gnu:*)      echo "$2" ;;
  esac
}

rm -rf "$W"; mkdir -p "$W"

# ---------------------------------------------------------------- the corpora
# generated, never a real file off the disk: a row has to be reproducible on
# another machine and its contents have to be known. a linear congruential walk,
# so awk's own rand() (which differs between awks) is not in the measurement.
#
#   mixed      "<n> <word> <word> <hex>" -- the ordinary shape. one file cannot
#              exercise a line scanner, a field cutter and a number parser at once,
#              so this one carries all three columns.
#   oneline    the same bytes with NO newline anywhere. a line-oriented tool that
#              conses a charm at a time, or appends to a string in a loop, goes
#              quadratic here and nowhere else.
#   manylines  one byte per line. all per-line overhead and no per-byte work.
#   same       one repeated byte. deflate's hash chain and any sort with an
#              all-equal key are both worst-cased by it.
#   binary     random bytes, high bit set throughout. text tools agree with each
#              other under any bug that only mangles the high bit, so a divergence
#              here is one nothing in the ordinary corpus can show.
gen() {   # gen SHAPE MB PATH
  awk -v shape="$1" -v mb="$2" 'BEGIN {
    s = 12345; want = mb * 1048576; n = 0
    split("alpha bravo charlie delta echo foxtrot golf hotel india juliet " \
          "kilo lima mike november oscar papa quebec romeo sierra tango", P, " ")
    while (n < want) {
      s = (s * 1103515245 + 12345) % 2147483648; a = int(s / 65536) % 20 + 1
      s = (s * 1103515245 + 12345) % 2147483648; b = int(s / 65536) % 20 + 1
      s = (s * 1103515245 + 12345) % 2147483648
      if (shape == "mixed") {
        l = sprintf("%d %s %s %06x", s % 100000, P[a], P[b], s % 16777216)
        print l; n += length(l) + 1 }
      else if (shape == "oneline") {
        l = sprintf("%d %s %s %06x ", s % 100000, P[a], P[b], s % 16777216)
        printf "%s", l; n += length(l) }
      else if (shape == "manylines") { print substr(P[a], 1, 1); n += 2 }
      else if (shape == "same") { print "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"; n += 40 }
      else if (shape == "binary") {
        l = ""
        for (i = 0; i < 40; i++) {
          s = (s * 1103515245 + 12345) % 2147483648
          l = l sprintf("%c", 128 + int(s / 65536) % 127) }
        print l; n += 41 } } }' > "$3"
}

corpus=$W/corpus
gen mixed "$MB" "$corpus"
bytes=$(wc -c < "$corpus"); lines=$(wc -l < "$corpus")

# the shape corpora are 1 MB whatever the work corpus is: they exist to expose an
# exponent, and an exponent shows on 1 MB or it is not there.
for sh in oneline manylines same binary; do gen "$sh" 1 "$W/c.$sh"; done
# the backtracker: 'a' x 40 with no 'b'. an ERE engine that tries every split of a
# repeated alternation walks 2^40 of them; one that builds an automaton answers at
# once. the input is TINY on purpose -- if a cell here is slow it is not the bytes.
awk 'BEGIN { s = ""; for (i = 0; i < 40; i++) s = s "a"; print s }' > "$W/c.backtrack"

# the scaling corpora: n, 2n, 4n of the ordinary shape. SCALE names the LARGEST,
# so the default reads 1/2/4 MB -- fast, and enough slope for the rows that cost
# real time per byte. A row that answers `too fast at 1MB` wants `SCALE=16`: at
# these sizes its whole runtime is the start cost and there is no slope to read.
gen mixed $((SCALE / 4)) "$W/s1"
gen mixed $((SCALE / 2)) "$W/s2"
gen mixed "$SCALE"       "$W/s4"

# a tree for the fs rows: many small files, where start dominates
tree=$W/tree; mkdir -p "$tree"
i=0
while [ $i -lt 300 ]; do printf 'file %d\n' $i > "$tree/f$(printf %03d $i)"; i=$((i + 1)); done

# the shell script the `sh` row runs: expansion and a loop, no forks, so what is
# timed is the shell's own evaluator and not 2000 execs.
{ printf 'n=0\nws="'
  i=0; while [ $i -lt 400 ]; do printf 'w%d ' $i; i=$((i + 1)); done
  printf '"\nfor r in 1 2 3 4 5 6 7 8 9 10; do for w in $ws; do n=$w; done; done\necho $n\n'
} > "$W/loop.sh"

echo "korebench: lanes:$have   samples=$SAMPLES  timeout=${TO}s"
echo "corpus: $bytes bytes, $lines lines"
echo

# ---------------------------------------------------------------- answers
# the oracle is GNU: it is what src/apps/kore/'s gate smokes against, so a kore row
# disagreeing here is the same fault test_kore would name. busybox and uutils are
# second opinions -- where all three of them agree with each other and not with GNU,
# the fault is likelier GNU's dialect than anyone's bug.
echo "== answers (oracle: GNU; LC_ALL=C) =="
answer() {   # answer LABEL FILE TOOL ARGS.. -- FILE arrives on stdin
  lbl=$1; f=$2; t=$3; shift 3
  ok=
  for l in $have; do
    carries "$l" "$t" || continue
    # shellcheck disable=SC2046
    $(pfx "$l" "$t") "$@" < "$f" > "$W/a.$lbl.$l" 2>"$W/a.$lbl.$l.err" \
      || { echo "  $lbl $l: died (exit $?)"; sed -n 1,2p "$W/a.$lbl.$l.err" | sed 's/^/      /'; continue; }
    ok="$ok $l"
  done
  case " $ok " in *" gnu "*) ;; *) echo "  $lbl: no GNU lane to compare against"; return ;; esac
  same= ; diverged=
  for l in $ok; do
    [ "$l" = gnu ] && continue
    if cmp -s "$W/a.$lbl.gnu" "$W/a.$lbl.$l"; then same="$same $l"; else diverged="$diverged $l"; fi
  done
  if [ -z "$diverged" ]; then echo "  $lbl: gnu ==$same"
  else
    echo "  $lbl: gnu ==$same,  DIVERGES:$diverged"
    for l in $diverged; do
      echo "    -- $l vs gnu, first 3 lines of difference:"
      diff "$W/a.$lbl.gnu" "$W/a.$lbl.$l" 2>/dev/null | sed -n 1,3p | sed 's/^/       /'
    done
  fi
}
answer wc      "$corpus" wc -l
answer wcc     "$corpus" wc -c
answer head    "$corpus" head -n 1000
answer tail    "$corpus" tail -n 1000
answer sort    "$corpus" sort
answer sortn   "$corpus" sort -n
answer uniq    "$corpus" uniq -c
answer cut     "$corpus" cut -d' ' -f2
answer tr      "$corpus" tr a-z A-Z
answer grep    "$corpus" grep sierra
answer grepE   "$corpus" grep -E '^[0-9]+ (alpha|romeo) '
answer sed     "$corpus" sed 's/alpha/ALPHA/g'
answer awk     "$corpus" awk '{n += $1} END { print n }'
answer md5     "$corpus" md5sum
answer sha256  "$corpus" sha256sum
answer cksum   "$corpus" cksum
answer b64     "$corpus" base64 -w 76
answer rev     "$corpus" rev
answer nl      "$corpus" nl
# the same questions against the shapes: an answer bug that only a long line, a
# one-byte line or a high-bit byte can reach is exactly the kind ordinary use hides.
answer wc-1ln  "$W/c.oneline"   wc -lc
answer wc-many "$W/c.manylines" wc -lc
answer sort-eq "$W/c.same"      sort -u
answer md5-bin "$W/c.binary"    md5sum
answer b64-bin "$W/c.binary"    base64 -w 76
answer tr-bin  "$W/c.binary"    tr a-z A-Z
echo

# ---------------------------------------------------------------- timing floor
# ⚠ EXIT 1 IS A TIMED RESULT, not a failure. grep answers 1 for "no match" and cmp
# for "differ" -- and the two rows here that matter most (the long-line grep, and
# the backtracker, which no lane matches) both end that way. Reading 1 as dnf blanks
# exactly the cells the shapes table was built to show. 124 is the timeout, and
# anything above 1 is a real death.
run_to() {   # run "$@" under the timeout, stdout dropped; echoes ms or to/dnf
  s=$(date +%s%N)
  if command -v timeout > /dev/null 2>&1; then
    timeout "$TO" "$@" > /dev/null 2>&1; rc=$?
  else
    "$@" > /dev/null 2>&1; rc=$?
  fi
  e=$(date +%s%N)
  [ "$rc" = 124 ] && { echo to; return; }
  [ "$rc" -gt 1 ] && { echo dnf; return; }
  echo $(( (e - s) / 1000000 ))
}
# ⚠ the median has to survive a SHORT list. A `to` or `dnf` ends the sampling, so
# the awk sees one line where it expected SAMPLES -- and an `NR == (n+1)/2` picked
# off the sample count then matches nothing and the cell comes out EMPTY, which
# reads on the page as a tool that was never run rather than as one that failed.
# The count is taken from what actually arrived.
mid() {
  awk '/^(to|dnf)$/ { bad = $1 }
       !/^(to|dnf)$/ { v[++n] = $1 + 0 }
       END { if (bad) { print bad; exit }
             if (!n) { print "dnf"; exit }
             for (i = 1; i < n; i++) for (j = i + 1; j <= n; j++)
               if (v[j] < v[i]) { t = v[i]; v[i] = v[j]; v[j] = t }
             print v[int((n + 1) / 2)] }'
}
med() {   # median of SAMPLES; a to/dnf in any sample wins the cell
  i=0
  while [ $i -lt "$SAMPLES" ]; do
    v=$(run_to "$@")
    echo "$v"
    case $v in to|dnf) break ;; esac
    i=$((i + 1))
  done | mid
}
medin() {   # med with $IN on stdin. a separate function: the redirect cannot ride
  i=0     # "$@", and an `sh -c` wrapper would time a second fork into every cell.
  while [ $i -lt "$SAMPLES" ]; do
    s=$(date +%s%N)
    if command -v timeout > /dev/null 2>&1; then
      timeout "$TO" "$@" < "$IN" > /dev/null 2>&1; rc=$?
    else
      "$@" < "$IN" > /dev/null 2>&1; rc=$?
    fi
    e=$(date +%s%N)
    if [ "$rc" = 124 ]; then echo to; break
    elif [ "$rc" -gt 1 ]; then echo dnf; break
    fi
    echo $(( (e - s) / 1000000 ))
    i=$((i + 1))
  done | mid
}
cell() {   # print one cell: VALUE relative to BASE (blank ratio for the kore lane)
  v=$1; b=$2; k=$3
  case "$k$v$b" in
    kore*) printf '%14s' "$v"; return ;;
  esac
  case "$v" in to|dnf|0) printf '%14s' "$v"; return ;; esac
  case "$b" in to|dnf|0) printf '%14s' "$v"; return ;; esac
  printf '%14s' "$v($(awk -v a="$b" -v b="$v" 'BEGIN{printf "%.1fx", a/b}'))"
}
# the nine rows bench/mkhtml.sh renders. chosen as a cross-section rather than a
# best-of: two stream editors, a language, a calculator, two archivers, two sorters
# and a shell -- so the page shows kore's range and not one flattering shape.
HTMLROWS="cat sed awk bc gzip tar sort uniq sh"
emit() {   # emit ROW LANE MS -- the machine-readable half, for the page
  [ -n "$RAW" ] || return 0
  case " $HTMLROWS " in *" $1 "*) printf '%s %s %s\n' "$1" "$2" "$3" >> "$RAW" ;; esac
}
[ -n "$RAW" ] && : > "$RAW"

# ---------------------------------------------------------------- start
# ⚠ THE ONE ROW THAT IS NOT ABOUT AN APPLET. `true` does nothing, so what is timed
# is exec plus whatever the binary does before it looks at its arguments -- for
# love, the image load and the heap. Every row below carries this same constant,
# which is why the work corpus is megabytes: on a small input this number IS the
# measurement, and it is subtracted out of the scaling table by hand.
echo "== start, ms per invocation =="
printf '%-16s' "row"; for l in $have; do printf '%14s' "$l"; done; echo
printf '%-16s' "true"
base=; startof_kore=
for l in $have; do
  case $l in
    kore)    v=$(med "$m" true) ;;
    busybox) v=$(med busybox true) ;;
    uutils)  v=$(med uu-true) ;;
    gnu)     v=$(med /usr/bin/true) ;;
  esac
  [ -n "$base" ] || base=$v
  [ "$l" = kore ] && startof_kore=$v
  cell "$v" "$base" "$l"
done
echo; echo

# ---------------------------------------------------------------- work
echo "== work, ms over the corpus (median of $SAMPLES; ratio is kore/lane) =="
printf '%-16s' "row"; for l in $have; do printf '%14s' "$l"; done; echo
IN=$corpus
work() {   # work LABEL TOOL ARGS.. -- $IN on stdin
  lbl=$1; t=$2; shift 2
  printf '%-16s' "$lbl"
  base=
  for l in $have; do
    if ! carries "$l" "$t"; then printf '%14s' "-"; continue; fi
    # shellcheck disable=SC2046
    v=$(medin $(pfx "$l" "$t") "$@")
    [ -n "$base" ] || base=$v
    emit "$lbl" "$l" "$v"
    cell "$v" "$base" "$l"
  done
  echo
}
# the nif-backed three go first: their inner loop is the same C in every lane, so
# their ratio is the floor every row under them is read against.
work md5sum    md5sum
work sha256sum sha256sum
work cksum     cksum
work cat       cat
work base64    base64 -w 76
work wc-l      wc -l
work head      head -n 1000
work tail      tail -n 1000
work cut       cut -d' ' -f2
work tr        tr a-z A-Z
work rev       rev
work grep      grep sierra
work grep-E    grep -E '^[0-9]+ (alpha|romeo) '
work sed       sed 's/alpha/ALPHA/g'
work awk       awk '{n += $1} END { print n }'
work sort      sort
work uniq      uniq -c
echo

# ---------------------------------------------------------------- tools
# the rows that are not stdin filters: an archiver writes a file, a calculator
# reads a program, a shell reads a script. kept apart from the work table because
# their argument shapes are each their own, not because they measure anything else.
echo "== tools, ms (median of $SAMPLES; ratio is kore/lane) =="
printf '%-16s' "row"; for l in $have; do printf '%14s' "$l"; done; echo

printf '%-16s' "gzip"
base=; IN=$corpus
for l in $have; do
  if ! carries "$l" gzip; then printf '%14s' "-"; continue; fi
  case $l in
    kore)    v=$(medin "$m" gzip -c) ;;
    busybox) v=$(medin busybox gzip -c) ;;
    gnu)     v=$(medin gzip -c) ;;
    *)       v=- ;;
  esac
  [ -n "$base" ] || base=$v
  emit gzip "$l" "$v"; cell "$v" "$base" "$l"
done
echo

# tar: every lane writes an archive of the same 300-file tree to a file, since
# kore's tar writes a path and not a stream. `cf`, not `czf` -- the gzip row above
# already prices the coder, and czf here would price it twice.
printf '%-16s' "tar"
base=
for l in $have; do
  if ! carries "$l" tar; then printf '%14s' "-"; continue; fi
  case $l in
    kore)    v=$(med "$m" tar cf "$W/t.kore.tar" "$tree") ;;
    busybox) v=$(med busybox tar cf "$W/t.bb.tar" "$tree") ;;
    gnu)     v=$(med tar cf "$W/t.gnu.tar" "$tree") ;;
    *)       v=- ;;
  esac
  [ -n "$base" ] || base=$v
  emit tar "$l" "$v"; cell "$v" "$base" "$l"
done
echo

# bc: 500 digits of pi through the -l library, which is the arctangent series and
# is all bignum division. love's own bigints are under ours; GNU bc has its own.
printf '%-16s' "bc"
printf 'scale=500\n4*a(1)\n' > "$W/pi.bc"
base=; IN=$W/pi.bc
for l in $have; do
  if ! carries "$l" bc; then printf '%14s' "-"; continue; fi
  case $l in
    kore)    v=$(medin "$m" bc -l) ;;
    busybox) v=$(medin busybox bc -l) ;;
    gnu)     v=$(medin bc -l) ;;
    *)       v=- ;;
  esac
  [ -n "$base" ] || base=$v
  emit bc "$l" "$v"; cell "$v" "$base" "$l"
done
echo

# sh: 4000 loop turns of expansion, no forks -- the evaluator, not exec.
printf '%-16s' "sh"
base=
for l in $have; do
  case $l in
    kore)    v=$(med "$m" sh "$W/loop.sh") ;;
    busybox) v=$(med busybox ash "$W/loop.sh") ;;
    gnu)     command -v bash > /dev/null 2>&1 && v=$(med bash "$W/loop.sh") || v=- ;;
    *)       printf '%14s' "-"; continue ;;
  esac
  [ -n "$base" ] || base=$v
  emit sh "$l" "$v"; cell "$v" "$base" "$l"
done
echo; echo

# ---------------------------------------------------------------- shapes
# ⚠ THE TABLE THIS SCRIPT EXISTS FOR. Each corpus is 1 MB (the backtracker is 41
# bytes), so a cell far above its own row in the work table is not bytes -- it is
# the shape. A `to` is a result: the tool did not finish inside the timeout.
echo "== shapes, ms on 1 MB of adversarial input (ratio is kore/lane) =="
printf '%-22s' "row"; for l in $have; do printf '%14s' "$l"; done; echo
shape() {   # shape LABEL FILE TOOL ARGS..
  lbl=$1; IN=$2; t=$3; shift 3
  printf '%-22s' "$lbl"
  base=
  for l in $have; do
    if ! carries "$l" "$t"; then printf '%14s' "-"; continue; fi
    # shellcheck disable=SC2046
    v=$(medin $(pfx "$l" "$t") "$@")
    [ -n "$base" ] || base=$v
    cell "$v" "$base" "$l"
  done
  echo
}
# one 1 MB line, no newline: the line reader's worst case
shape "1line wc -l"    "$W/c.oneline"   wc -l
shape "1line grep"     "$W/c.oneline"   grep zzzz
shape "1line sed"      "$W/c.oneline"   sed 's/alpha/A/g'
shape "1line cut"      "$W/c.oneline"   cut -d' ' -f2
shape "1line rev"      "$W/c.oneline"   rev
shape "1line tr"       "$W/c.oneline"   tr a-z A-Z
# a million one-byte lines: all per-line overhead, no per-byte work
shape "many wc -l"     "$W/c.manylines" wc -l
shape "many sort"      "$W/c.manylines" sort
shape "many uniq"      "$W/c.manylines" uniq -c
shape "many head -n1"  "$W/c.manylines" head -n 1
# one repeated byte: an all-equal sort key, and deflate's hash chain
shape "same sort"      "$W/c.same"      sort
shape "same uniq"      "$W/c.same"      uniq -c
# high-bit bytes throughout
shape "bin base64"     "$W/c.binary"    base64 -w 76
shape "bin tr"         "$W/c.binary"    tr a-z A-Z
shape "bin wc -c"      "$W/c.binary"    wc -c
# catastrophic backtracking: 41 bytes. an engine that builds an automaton answers
# at once; one that tries every split of the repeated alternation does not finish.
shape "backtrack -E"   "$W/c.backtrack" grep -E '^(a|aa)+b$'
echo

# gzip on the repeated byte is its own row: deflate's match finder walks a hash
# chain, and a file of one byte is the longest chain the format can produce.
printf '%-22s' "same gzip"
base=; IN=$W/c.same
for l in $have; do
  if ! carries "$l" gzip; then printf '%14s' "-"; continue; fi
  case $l in
    kore)    v=$(medin "$m" gzip -c) ;;
    busybox) v=$(medin busybox gzip -c) ;;
    gnu)     v=$(medin gzip -c) ;;
    *)       v=- ;;
  esac
  [ -n "$base" ] || base=$v
  cell "$v" "$base" "$l"
done
echo; echo

# ---------------------------------------------------------------- scaling
# the same job at 1, 2 and 4 MB, KORE ONLY -- this table is not a comparison, it is
# a reading of one implementation's exponent, and the other lanes are all linear on
# every row here by construction.
#
# ⚠ THE START COST IS SUBTRACTED before the ratio is taken. love pays ~30 ms to
# wake before it reads a byte; leaving that in makes every row look sublinear at
# these sizes, which is precisely the reading that would hide a quadratic one.
#
#   ~4.0  linear          ~4.3  n log n         ~16  quadratic
#   ~1.0  did not read the whole input (early exit -- correct for head, and a
#         finding for anything else)
echo "== scaling, kore only: t(4n)/t(n) at $((SCALE / 4))/$((SCALE / 2))/$SCALE MB, start subtracted =="
echo "   4.0 linear · 4.3 n log n · 16 quadratic · 1.0 stopped early"
printf '%-16s%10s%10s%10s%10s   %s\n' "row" \
  "$((SCALE / 4))MB" "$((SCALE / 2))MB" "${SCALE}MB" "growth" "reading"
scale() {   # scale LABEL TOOL ARGS..
  lbl=$1; t=$2; shift 2
  carries kore "$t" || return 0
  # shellcheck disable=SC2046
  IN=$W/s1; a=$(medin $(pfx kore "$t") "$@")
  # shellcheck disable=SC2046
  IN=$W/s2; b=$(medin $(pfx kore "$t") "$@")
  # shellcheck disable=SC2046
  IN=$W/s4; c=$(medin $(pfx kore "$t") "$@")
  printf '%-16s%10s%10s%10s' "$lbl" "$a" "$b" "$c"
  case "$a$b$c" in *to*|*dnf*) printf '%10s   %s\n' "-" "did not finish"; return ;; esac
  # ⚠ the floor is not fussiness. With start subtracted, a row costing 7 ms of real
  # work at the small size divides two numbers that are each mostly timer noise, and
  # the quotient lands anywhere -- `wc -l` read as 8.3x QUADRATIC on the first fill
  # this way, and it is linear. A slope needs both ends clear of the noise before it
  # means anything; below that the honest answer is that this run cannot say.
  awk -v a="$a" -v c="$c" -v s="$startof_kore" -v sc="$SCALE" 'BEGIN {
    a -= s; c -= s
    if (a < 25 || c < 100) {
      printf "%10s   too fast at %d MB -- rerun with SCALE=%d\n", "-", sc / 4, sc * 4
      exit }
    g = c / a
    printf "%10.1f   ", g
    if      (g < 1.6)  print "STOPPED EARLY -- reads only what it needs"
    else if (g < 5.5)  print "linear"
    else if (g < 8.0)  print "superlinear -- worth a look"
    else               print "QUADRATIC -- a defect that grows" }'
}
scale cat       cat
scale wc-l      wc -l
scale head-n1   head -n 1
scale tail-n1   tail -n 1
scale md5sum    md5sum
scale base64    base64 -w 76
scale cut       cut -d' ' -f2
scale tr        tr a-z A-Z
scale rev       rev
scale grep      grep sierra
scale sed       sed 's/alpha/ALPHA/g'
scale awk       awk '{n += $1} END { print n }'
scale sort      sort
scale uniq      uniq -c
echo

echo "korebench: a ratio is kore/that lane -- 1.0x is parity, 30.0x is thirty times the clock."
echo "           read every work row against md5sum's: that row's inner loop is the SAME C in"
echo "           every lane, so its ratio is love's overhead and not the applet's algorithm."
[ -n "$RAW" ] && echo "korebench: wrote $RAW ($HTMLROWS)"
exit 0
