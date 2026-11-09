#!/bin/sh
# test/gate/lanes.sh -- run a gate's lanes at once: one make, its jobserver the gate's budget,
# so a gate takes about its slowest lane instead of the sum. a log and an exit per lane.
#
# usage: lanes.sh [-j N] [-d DIR] [--slow] [--remote] LANE|test_extra|test_core ...
#
#   1. the lanes' own prerequisites (host, love0, a lane another lane names) build once, first
#   2. what lanes otherwise build from inside their recipes (kernels, the wasm seat) builds once
#   3. one `make -k -jN` over the rest: a chain below runs its lanes in turn, every other lane
#      on its own; each a sub-make on the shared jobserver, assuming step 1's targets old
#   4. the lanes that rebuild love0 under another cc, alone; the lane map's early lanes start
#      with step 3 instead and run beside it and step 4, one at a time
#   5. --slow: test_slow last and alone, on the same tree, only after every lane is green,
#      taking the lanes this run just passed as passed
#
# --remote: the lanes the lane map places off this box go to the lanes hosts of its isa (love
# bee --on lanes): the gated commit is pushed to each host's kept tree and this box's build of
# their prerequisites laid over it, then its slots take those lanes longest first. this box takes
# them too once its own are done, and a host that drops gives its lane back to run here, never
# skipped. a lane's .rc names where it ran
#
# heavy slots are the caller's: `love bee --lock --heavy --out out -- sh test/gate/lanes.sh ..`.
# N defaults to 4. logs land in DIR (out/lanes): LANE.log, LANE.rc, summary; the last run's in DIR.prev.
set -u

# GNU make's: the lanes ask -p -q -k -o, which cook does not take
MAKE=${MAKE:-make}

# a lane starts only while the box has LANES_MEM_GB (8) available: a shared box runs out of
# memory before it runs out of cores. off linux there is no meminfo, and no wait
roomy() {
  [ -r /proc/meminfo ] || return 0
  k=$(awk '/^MemAvailable:/ { print $2 }' /proc/meminfo)
  [ -z "$k" ] || [ "$k" -ge $(( ${LANES_MEM_GB:-8} * 1048576 )) ]
}

# --- a chain, from inside the generated make: DIR then OFLAGS words up to --, then lanes
if [ "${1:-}" = --chain ]; then
  d=$2; shift 2
  o=
  while [ "$1" != -- ]; do o="$o $1"; shift; done
  shift
  st=0
  for l in "$@"; do
    roomy || echo "lanes: $l waits for ${LANES_MEM_GB:-8} GB available" >&2
    until roomy; do sleep 15; done
    s=$(date +%s)
    $MAKE --no-print-directory $o "$l" > "$d/$l.log" 2>&1
    r=$?
    echo "$r $(( $(date +%s) - s ))" > "$d/$l.rc"
    [ $r -eq 0 ] || st=1
  done
  exit $st
fi

j= d=out/lanes slow= remote=${LANES_REMOTE:-} args=
while [ $# -gt 0 ]; do
  case $1 in
    -j) j=$2; shift 2 ;;
    -d) d=$2; shift 2 ;;
    --slow) slow=1; shift ;;
    --remote) remote=1; shift ;;
    -*) echo "lanes.sh: unknown flag $1" >&2; exit 2 ;;
    *) args="$args $1"; shift ;;
  esac
done
[ -n "$args" ] || { echo "usage: lanes.sh [-j N] [-d DIR] [--slow] LANE..." >&2; exit 2; }
[ -n "$j" ] || j=4
# a rerun keeps the run it reruns for: a trip's logs outlive the gate that clears it
rm -rf "$d.prev" && { [ ! -d "$d" ] || mv "$d" "$d.prev"; } && mkdir -p "$d" || exit 1
t0=$(date +%s)

# a target's prerequisites, from make's own database (pattern lanes included once named)
# MAKE=: because a question still runs every $(MAKE) line, and test_inle's are whole lanes
db() { $MAKE -pq MAKE=: "$@" 2>/dev/null > "$d/db"; }
deps() { awk -v t="$1" '(index($0, t ": ") == 1 || $0 == t ":") && !/=/ { sub(/^[^:]*:/, ""); gsub(/\|/, ""); print; exit }' "$d/db"; }
has() { case " $2 " in *" $1 "*) return 0 ;; esac; return 1; }

# a gate's name is its lanes; a group's members run as lanes, and the group answers for them
db $args
lanes= groups=
for a in $args; do
  case $a in
    test_extra|test_core)
      has "$a" "$groups" || groups="$groups $a"
      deps "$a" > "$d/$a.group"
      for l in $(cat "$d/$a.group"); do has "$l" "$lanes" || lanes="$lanes $l"; done ;;
    test_slow) slow=1 ;;
    *) has "$a" "$lanes" || lanes="$lanes $a" ;;
  esac
done
db $lanes

# step 1: every prerequisite of a lane, and a lane another lane needs, made once
pre= dep=
for l in $lanes; do
  for p in $(deps "$l"); do
    has "$p" "$pre" || pre="$pre $p"
    has "$p" "$lanes" && ! has "$p" "$dep" && dep="$dep $p"
  done
done
run=
for l in $lanes; do has "$l" "$dep" || run="$run $l"; done
oflags=
for p in $pre; do oflags="$oflags -o $p"; done
echo "lanes: $(echo $lanes | wc -w) at -j$j, logs in $d"
if [ -n "$pre" ]; then
  echo "prerequisites:$pre"
  $MAKE -k -j"$j" $pre > "$d/pre.log" 2>&1 || { echo "FAIL the prerequisites -- $d/pre.log"; tail -20 "$d/pre.log"; exit 1; }
fi
for l in $dep; do echo "0 0" > "$d/$l.rc"; echo "(made as a prerequisite, $d/pre.log)" > "$d/$l.log"; done

# the lanes that share scratch or sub-build one tree (a chain runs in its order), and the ones that
# rebuild love0 under another cc or run their own fleet (nothing beside them): the lane map's,
# src/apps/lanemap.l, asked of the tree's own love
[ -x out/love ] || $MAKE -s host >> "$d/pre.log" 2>&1
map=$(out/love bee --lanes-map) || { echo "FAIL out/love bee --lanes-map"; exit 1; }
chains=$(echo "$map" | sed -n 's/^chain //p')
alone=$(echo "$map" | sed -n 's/^alone //p')
early=$(echo "$map" | sed -n 's/^early //p')
[ -n "$chains" ] && [ -n "$alone" ] || { echo "FAIL the lane map has no chains or no alone set"; exit 1; }

# the remote half: a queue of the placed lanes, dearest first, that the hosts' slots and then
# this box take from; a take is a rename, so no lane is taken twice
places=$(echo "$map" | sed -n 's/^place //p')
costs=$(echo "$map" | sed -n 's/^cost //p')
mkdir -p "$d/q" "$d/qt"
# a place may name isas after its class (`place test_libc source x64`): pop ISA EXACT KIND
# takes only a lane that isa may run, an exact one only where EXACT is 1 (a host whose own
# build is this box's, byte for byte); ISA empty is this box, which may run any. KIND alone
# takes only the lane map's alone lanes, empty only the rest
isas() { echo "$places" | awk -v l="$1" '$1 == l { for (i = 3; i <= NF; i++) print $i }'; }
class() { echo "$places" | awk -v l="$1" '$1 == l { print $2 }'; }
pop() {
  for f in $(ls "$d/q"); do
    l=${f#*-}
    k=
    has "$l" "$alone" && k=alone
    [ "$k" = "${3:-}" ] || continue
    if [ -n "${1:-}" ]; then
      a=$(isas "$l")
      [ -z "$a" ] || echo "$a" | grep -qx "$1" || continue
      [ "$(class "$l")" != exact ] || [ "${2:-}" = 1 ] || continue
    fi
    mv "$d/q/$f" "$d/qt/$f" 2>/dev/null && { echo "$l"; return 0; }
  done
  return 1
}
# a host runs the gated commit itself, so a tree that is not its commit runs every lane here
rlanes= sha=
if [ -n "$remote" ]; then
  sha=$(git rev-parse HEAD 2>/dev/null) && git diff --quiet HEAD 2>/dev/null \
    || { echo "lanes: the tree is not its commit; every lane runs here"; remote=; }
fi
if [ -n "$remote" ]; then
  for l in $run; do
    echo "$chains" | tr , '\n' | grep -qx "$l" && continue
    case $(class "$l") in source|exact) ;; *) continue ;; esac
    c=$(echo "$costs" | awk -v l="$l" '$1 == l { print $2 }')
    touch "$d/q/$(printf '%06d' $(( 999999 - ${c:-900} )))-$l"
    rlanes="$rlanes $l"
  done
fi
rd=.love/run/lanes/$(basename "$PWD")
rpre=
for l in $rlanes; do for p in $(deps "$l"); do has "$p" "$rpre" || rpre="$rpre $p"; done; done
# a host builds nothing: it takes this box's build of the prerequisites, a target under out/
# or what a target outside it names there, with love, love.raw and out/lib, all newer than its
# checkout, and make takes them as made
ship=
for p in $rpre; do
  case $p in out/*) echo "$p" ;; *) for f in $(deps "$p"); do case $f in out/*) echo "$f" ;; esac; done ;; esac
done > "$d/ship"
for f in $(cat "$d/ship") out/love out/love.raw out/lib; do [ -e "$f" ] && ! has "$f" "$ship" && ship="$ship $f"; done
roflags=
for p in $rpre $ship; do roflags="$roflags -o $p"; done
# a strict box's lanes are strict there too, and its TERM and LANG: bee hands a host only
# PATH, HOME and LANG=C
rst=
[ -z "$rlanes" ] || { . test/gate/skip.sh; gate_strict && rst=LOVE_GATE_STRICT=1; }
for v in TERM LANG LC_ALL; do eval "x=\${$v:-}"; [ -z "$x" ] || rst="$rst $v=$x"; done
# a slot on host h: lanes of a KIND until the queue has none, each only on the gated commit,
# an alone one holding the whole host. a host that cannot be reached (75, or ssh's 255) or has
# moved off it (97) puts its lane back for this box and takes no more; so does one whose make
# rebuilt love after all (a recipe's own $(MAKE) does not take -o), since its love is not ours.
# a lane a strict host refused for want of a tool goes back too, and the host takes others
worker() {
  while [ ! -f "$d/off-$1" ] && l=$(pop "$2" "$3" "${4:-}"); do
    s=$(date +%s)
    out/love bee --on lanes --where "name=$1" ${4:+--whole} --in "$rd" --at "$sha" -- env $rst make --no-print-directory $roflags "$l" > "$d/$l.log" 2>&1
    r=$?
    grep -qE '^(BAKE|LOVE|RAW)[[:space:]]+out/love(\.raw)?$' "$d/$l.log" && { touch "$d/off-$1"; r=love; }
    [ $r = love ] || [ $r -eq 0 ] || ! grep -q 'REFUSED: a strict box' "$d/$l.log" || {
      echo "lanes: $1 refused $l; it runs here" >> "$d/remote.log"; echo "$l $1" >> "$d/back"; continue; }
    if [ $r = love ] || [ $r -eq 75 ] || [ $r -eq 97 ] || [ $r -eq 255 ]; then
      echo "lanes: $1 dropped $l ($r); it runs here" >> "$d/remote.log"
      echo "$l $1" >> "$d/back"
      return 1
    fi
    echo "$r $(( $(date +%s) - s )) $1" > "$d/$l.rc"
  done
  [ ! -f "$d/off-$1" ]
}
# a host: this box's isa, room enough (LANES_HOST_MEM_GB, 3, available there), the gated
# commit pushed and this box's build laid over it, byte for byte, then its alone lanes one at
# a time, then a worker a slot
rhost() {
  case $(uname -m) in aarch64|arm64) me=a64 ;; riscv64) me=rv64 ;; *) me=x64 ;; esac
  [ "$3" = "$me" ] || { echo "lanes: $1 is $3, not $me; it takes no lanes" >> "$d/remote.log"; return; }
  k=$(out/love bee --on lanes --where "name=$1" -- awk '/^MemAvailable:/ { print $2 }' /proc/meminfo 2>/dev/null)
  [ -n "$k" ] && [ "$k" -ge $(( ${LANES_HOST_MEM_GB:-3} * 1048576 )) ] \
    || { echo "lanes: $1 has ${k:-no} kB available, under ${LANES_HOST_MEM_GB:-3} GB; it takes no lanes" >> "$d/remote.log"; return; }
  { out/love bee --on lanes --where "name=$1" --in "$rd" --push "$sha" < /dev/null \
      && tar cf - $ship | out/love bee --on lanes --where "name=$1" --in "$rd" --at "$sha" -- tar xmf -; } > "$d/host-$1.log" 2>&1 \
    || { echo "lanes: $1 could not take the gated commit and this box's build -- $d/host-$1.log" >> "$d/remote.log"; return; }
  [ "$(out/love bee --on lanes --where "name=$1" --in "$rd" --at "$sha" -- sha256sum out/love out/love.raw 2>/dev/null)" = "$(sha256sum out/love out/love.raw 2>/dev/null)" ] \
    || { echo "lanes: $1's love is not this box's; it takes no lanes" >> "$d/remote.log"; return; }
  worker "$1" "$3" 1 alone || return
  i=0
  while [ $i -lt "$2" ]; do worker "$1" "$3" 1 & i=$((i + 1)); done
  wait
}
if [ -n "$rlanes" ]; then
  hl=$(out/love bee --on lanes --list 2>/dev/null)
  echo "remote:$rlanes on $(echo "$hl" | awk '{ printf "%s%s(%s)", (NR > 1 ? " " : ""), $1, $2 }')"
  echo "$hl" | { while read -r h n a; do [ -n "$h" ] && rhost "$h" "$n" "$a" & done; wait; } &
  rpid=$!
fi

# step 2: the builds lanes would otherwise race from their recipes
case $(uname -m) in aarch64|arm64) ha=a64 ;; riscv64) ha=rv64 ;; *) ha=x64 ;; esac
any() { for x in "$@"; do has "$x" "$run" && return 0; done; return 1; }
builds=
add() { builds="$builds
$*"; }
any test_vec test_links test_inle test_disk test_kverb test_kboot test_kpier test_kernel_vmx test_kernel_uproc && add a=x64 kernel
any test_vec test_links test_inle test_kernel_a64 test_uefi_a64 && add a=a64 kernel
any test_vec test_links test_inle test_kernel_rv64 test_rvboot && add a=rv64 kernel
any test_rvboot && add a=rv64 out/rv64/rv64/boot.o out/rv64/inle/rv64/dtb.o
any test_uefi test_inle && add out/esp-x64/EFI/BOOT/BOOTX64.EFI out/esp-x64/love.elf out/esp-x64/love.cmd
any test_uefi_a64 test_inle && add a=a64 out/esp-a64/EFI/BOOT/BOOTAA64.EFI out/esp-a64/love.elf out/esp-a64/love.cmd
any test_links test_inle test_kernel_wasm test_seedwasm test_nestwasm && add wasm
any test_fixpoint && add a=$ha out/$ha/mkvec.l
echo "$builds" | while read -r b; do
  [ -n "$b" ] || continue
  echo "build: $b"
  $MAKE -s -j"$j" $b >> "$d/pre.log" 2>&1 || { echo "FAIL build $b -- $d/pre.log"; exit 1; }
done || exit 1

# step 3: one make over the chains and the lone lanes, the early ones beside it from its start
mk=$d/lanes.mk
par= late= first=
for l in $run; do
  has "$l" "$rlanes" && continue
  if has "$l" "$early"; then first="$first $l"
  elif has "$l" "$alone"; then late="$late $l"
  else par="$par $l"; fi
done
# the stress bake runs test_gcstress's shards in the same scratch: owing both runs it alone
if has test_gcstress_bake "$first" && has test_gcstress "$late"; then
  late=$(for l in $late; do [ "$l" = test_gcstress ] || printf ' %s' "$l"; done)
  echo "0 0" > "$d/test_gcstress.rc"; echo "(covered by test_gcstress_bake, which runs its shards)" > "$d/test_gcstress.log"
fi
{
  echo "all:"
  n=0
  inch=
  echo "$chains" | while IFS=, read -r c; do
    m=
    for l in $(echo "$c" | tr , ' '); do has "$l" "$par" && m="$m $l"; done
    [ -n "$m" ] || continue
    n=$((n + 1))
    printf 'all: chain%d\nchain%d:\n\t+@MAKE='"'"'$(MAKE)'"'"' sh test/gate/lanes.sh --chain %s %s --%s\n' $n $n "$d" "$oflags" "$m"
  done
  for l in $par; do
    echo "$chains" | tr , '\n' | grep -qx "$l" && continue
    printf 'all: lane-%s\nlane-%s:\n\t+@MAKE='"'"'$(MAKE)'"'"' sh test/gate/lanes.sh --chain %s %s -- %s\n' "$l" "$l" "$d" "$oflags" "$l"
  done
} > "$mk"
# a lane that moves the tree mid-gate relinks love under its neighbours: the summary says so
sums() { cksum out/love out/love.raw out/mooncc0.image 2>/dev/null; }
before=$(sums)
# ..and the log says what moved: a file out/src.tree packs (the tree as it is), summed here and
# at the trip, a directory (the tar packs an empty one too), or one of love.raw's own inputs
# newer than it before the lane
walk() { w=$(out/love src/tools/selfpack.l -l 2>/dev/null) && [ -n "$w" ] && cksum $w 2>/dev/null
  find . \( -path ./out -o -path ./.git -o -path ./.claude \) -prune -o -type d -print | sed 's,.*,0 0 &/,' | sort; }
walk > "$d/walk"
newer() { for f in $(deps out/love.raw); do [ ! "$f" -nt out/love.raw ] || echo "$f"; done > "$d/newer"; }
moved() { [ "$(sums)" = "$before" ] || [ -f "$d/love-moved.rc" ] || {
  echo "1 0" > "$d/love-moved.rc"; echo "out/love, love.raw or mooncc0.image was rebuilt $1" > "$d/love-moved.log"
  walk | diff "$d/walk" - | sed -n 's/^[<>] [0-9]* [0-9]* //p' | sort -u > "$d/walk.moved"
  [ -s "$d/walk.moved" ] && { echo "what out/src.tree packs, moved since the lanes began:"; cat "$d/walk.moved"; } >> "$d/love-moved.log"
  [ -s "$d/newer" ] && { echo "love.raw's inputs newer than it before:"; cat "$d/newer"; } >> "$d/love-moved.log"; }; }
newer
epid=
[ -z "$first" ] || { ( for l in $first; do MAKE=$MAKE sh test/gate/lanes.sh --chain "$d" -j"$j" $oflags -- "$l"; done ) & epid=$!; }
# the box's least MemAvailable while they run, in kB, for the gate's log
[ -z "$epid" ] || [ ! -r /proc/meminfo ] || ( lo=; while kill -0 $epid 2>/dev/null; do
  k=$(awk '/^MemAvailable:/ { print $2 }' /proc/meminfo); [ -n "$lo" ] && [ "$lo" -le "$k" ] || { lo=$k; echo "$lo" > "$d/early.mem"; }
  sleep 10; done ) &
$MAKE -k -j"$j" -f "$mk" all > "$d/make.log" 2>&1
moved "during the parallel phase"

# the placed lanes no host has taken yet, here, j at a time
if [ -n "$rlanes" ]; then
  steal() { while l=$(pop "" "" ""); do MAKE=$MAKE sh test/gate/lanes.sh --chain "$d" $oflags -- "$l"; done; }
  i=0
  while [ $i -lt "$j" ]; do steal & i=$((i + 1)); done
  wait
fi

# step 4: alone, in turn, step 1's targets old as in step 3: a lane's own make of host packs the
# tree again and moves out/love. then the placed alone lanes no host has taken, the hosts'
# last, and every lane a host gave back or left
alone1() { newer; MAKE=$MAKE sh test/gate/lanes.sh --chain "$d" -j"$j" $oflags -- "$1"; moved "by $1"; }
for l in $late; do alone1 "$l"; done
if [ -n "$rlanes" ]; then
  while l=$(pop "" "" alone); do alone1 "$l"; done
  wait $rpid 2>/dev/null
  [ -f "$d/back" ] && for l in $(awk '{ print $1 }' "$d/back"); do alone1 "$l"; done
  while l=$(pop "" "" "") || l=$(pop "" "" alone); do alone1 "$l"; done
  [ -f "$d/remote.log" ] && cat "$d/remote.log"
fi

[ -z "$epid" ] || { wait $epid; moved "beside the early lanes"
  [ -s "$d/early.mem" ] && echo "early:$first, the box's least MemAvailable beside them $(cat "$d/early.mem") kB"; }

# a group is green when every member is, else red naming the red ones; its secs its slowest
for g in $groups; do
  gr= gs=0
  for l in $(cat "$d/$g.group"); do
    if [ -f "$d/$l.rc" ]; then read -r r s < "$d/$l.rc"; else r=missing s=0; fi
    [ "$r" = 0 ] || gr="$gr${gr:+,}$l"
    [ "$s" -gt "$gs" ] && gs=$s
  done
  echo "${gr:+1:}${gr:-0} $gs" > "$d/$g.rc"
done

# the summary, in the order the lanes were named
red=0
sum() {
  if [ -f "$d/$1.rc" ]; then
    read -r r s w < "$d/$1.rc"
  else
    r=missing s=0 w=
  fi
  b=$([ -f "$d/back" ] && awk -v l="$1" '$1 == l { print $2; exit }' "$d/back")
  [ "$r" = 0 ] || red=1
  echo "$1 exit=$r secs=$s${w:+ on=$w}${b:+ back=$b}"
}
{ for l in $lanes $groups; do sum "$l"; done; [ -f "$d/love-moved.rc" ] && sum love-moved; } > "$d/summary"
grep -v 'exit=0 ' "$d/summary" > /dev/null && red=1
cat "$d/summary"
echo "wall=$(( $(date +%s) - t0 ))"
if [ $red -ne 0 ]; then
  echo "RED: $(grep -v 'exit=0 ' "$d/summary" | cut -d' ' -f1 | tr '\n' ' ')-- logs in $d"
  exit 1
fi

# step 5: the merge gate, last and alone on the tree that passed. a red or a moved love stopped
# above, so a lane it names that ran here ran on this tree; test_inle runs test_kernel_wasm
if [ -n "$slow" ]; then
  o=
  for l in $lanes; do o="$o -o $l"; done
  has test_inle "$lanes" && o="$o -o test_kernel_wasm"
  MAKE=$MAKE sh test/gate/lanes.sh --chain "$d" $o -- test_slow
  sum test_slow >> "$d/summary"
  tail -1 "$d/summary"
  echo "wall=$(( $(date +%s) - t0 ))"
  [ $red -eq 0 ] || exit 1
fi
echo "GREEN: $(echo $lanes | wc -w) lanes$([ -n "$slow" ] && echo ', test_slow last')"
