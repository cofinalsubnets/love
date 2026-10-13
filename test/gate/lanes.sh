#!/bin/sh
# test/gate/lanes.sh -- run a gate's lanes at once: one make, its jobserver the gate's budget,
# so a gate takes about its slowest lane instead of the sum. a log and an exit per lane.
#
# usage: lanes.sh [-j N] [-d DIR] [--slow] LANE|test_extra|test_quick ...
#
#   1. the lanes' own prerequisites (host, love0, a lane another lane names) build once, first
#   2. what lanes otherwise build from inside their recipes (kernels, the wasm seat) builds once
#   3. one `make -k -jN` over the rest: a chain below runs its lanes in turn, every other lane
#      on its own; each a sub-make on the shared jobserver, assuming step 1's targets old
#   4. the lanes that rebuild love0 under another cc, alone
#   5. --slow: test_slow last and alone, on the same tree, only after every lane is green
#
# heavy slots are the caller's: `love bee --lock --heavy --out out -- sh test/gate/lanes.sh ..`.
# N defaults to 4. logs land in DIR (out/lanes): LANE.log, LANE.rc, summary.
set -u

# lanes that share scratch or sub-build the same tree: each chain runs in this order
chains="test_extract,test_big,test_encver
test_inle,test_kernel_vmx,test_disk,test_uefi,test_kboot,test_kmitty,test_kverb,test_kernel_a64,test_uefi_a64,test_kernel_rv64,test_kernel_wasm,test_seedwasm,test_nestwasm
test_doomx,test_doomwasm
test_elf32,test_mps2_build,test_virt_build,test_mps2,test_mps2_t1,test_mps2_wake,test_virt,test_nucleo446,test_nucleo446_smoke,test_teensy41,test_playdate,test_rp2040,test_boards,test_objcopy,test_links
test_freebsd,test_netbsd,test_freebsd_a64,test_netbsd_a64"
# lanes that rebuild out/0 and love0 with a foreign cc: nothing may run beside them
alone="test_hdiff test_ccwarn"

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

j= d=out/lanes slow= args=
while [ $# -gt 0 ]; do
  case $1 in
    -j) j=$2; shift 2 ;;
    -d) d=$2; shift 2 ;;
    --slow) slow=1; shift ;;
    -*) echo "lanes.sh: unknown flag $1" >&2; exit 2 ;;
    *) args="$args $1"; shift ;;
  esac
done
[ -n "$args" ] || { echo "usage: lanes.sh [-j N] [-d DIR] [--slow] LANE..." >&2; exit 2; }
[ -n "$j" ] || j=4
rm -rf "$d" && mkdir -p "$d" || exit 1
t0=$(date +%s)

# a target's prerequisites, from make's own database (pattern lanes included once named)
# MAKE=: because a question still runs every $(MAKE) line, and test_inle's are whole lanes
db() { $MAKE -pq MAKE=: "$@" 2>/dev/null > "$d/db"; }
deps() { awk -v t="$1" '(index($0, t ": ") == 1 || $0 == t ":") && !/=/ { sub(/^[^:]*:/, ""); gsub(/\|/, ""); print; exit }' "$d/db"; }
has() { case " $2 " in *" $1 "*) return 0 ;; esac; return 1; }

# a gate's name is its lanes
db $args
lanes=
for a in $args; do
  case $a in
    test_extra|test_quick) for l in $(deps "$a"); do has "$l" "$lanes" || lanes="$lanes $l"; done ;;
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

# step 2: the builds lanes would otherwise race from their recipes
case $(uname -m) in aarch64|arm64) ha=a64 ;; riscv64) ha=rv64 ;; *) ha=x64 ;; esac
any() { for x in "$@"; do has "$x" "$run" && return 0; done; return 1; }
builds=
add() { builds="$builds
$*"; }
any test_vec test_links test_inle test_disk test_kverb test_kboot test_kmitty test_kernel_vmx && add a=x64 kernel
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

# step 3: one make over the chains and the lone lanes
mk=$d/lanes.mk
par= late=
for l in $run; do has "$l" "$alone" && late="$late $l" || par="$par $l"; done
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
$MAKE -k -j"$j" -f "$mk" all > "$d/make.log" 2>&1

# step 4: alone, in turn
for l in $late; do
  MAKE=$MAKE sh test/gate/lanes.sh --chain "$d" -j"$j" -- "$l"
done

# the summary, in the order the lanes were named
red=0
sum() {
  if [ -f "$d/$1.rc" ]; then
    read -r r s < "$d/$1.rc"
  else
    r=missing s=0
  fi
  [ "$r" = 0 ] || red=1
  echo "$1 exit=$r secs=$s"
}
for l in $lanes; do sum "$l"; done > "$d/summary"
grep -v 'exit=0 ' "$d/summary" > /dev/null && red=1
cat "$d/summary"
echo "wall=$(( $(date +%s) - t0 ))"
if [ $red -ne 0 ]; then
  echo "RED: $(grep -v 'exit=0 ' "$d/summary" | cut -d' ' -f1 | tr '\n' ' ')-- logs in $d"
  exit 1
fi

# step 5: the merge gate, last and alone on the tree that passed
if [ -n "$slow" ]; then
  MAKE=$MAKE sh test/gate/lanes.sh --chain "$d" -- test_slow
  sum test_slow >> "$d/summary"
  tail -1 "$d/summary"
  echo "wall=$(( $(date +%s) - t0 ))"
  [ $red -eq 0 ] || exit 1
fi
echo "GREEN: $(echo $lanes | wc -w) lanes$([ -n "$slow" ] && echo ', test_slow last')"
