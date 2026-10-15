#!/bin/sh
# test/gate/vec.sh -- the exception vectors a clean boot never reaches.
# boots, raises real faults with (fault n) and reads each report; then reads the laid
# object back: x64's error-code split stub by stub, a64's table alignment and spacing,
# rv64's save/restore symmetry. a faulted kernel halts, so each boot stops at its report.
# usage: vec.sh ARCH ELF OBJ
. test/gate/skip.sh
. test/gate/cclib.sh
set -u
arch=$1; elf=$2; obj=$3
work=${TMPDIR:-/tmp}/vec.$$
mkdir -p "$work"
trap 'rm -rf "$work"' EXIT
# a piped `while read` is a subshell: a failure marks the filesystem
fail() { echo "FAIL test_vec($arch): $*" >&2; : > "$work/failed"; }

case $arch in
  x64)  qemu=qemu-system-x86_64;  mach="-M q35" ;;
  a64) qemu=qemu-system-aarch64; mach="-M virt,gic-version=2 -cpu cortex-a72" ;;
  rv64) qemu=qemu-system-riscv64; mach="-M virt" ;;
  *) echo "FAIL test_vec: unknown arch $arch" >&2; exit 1 ;;
esac

# kvm for x64 on x64 only: an arm host may lack gic v2 backing
if [ "$arch" = x64 ] && [ -e /dev/kvm ] && [ "$(uname -m)" = x86_64 ]; then
  mach="$mach -enable-kvm -cpu host"
fi

if ! have "$qemu"; then
  gate_partly "  (vec $arch: fault boots skipped, no $qemu)"
else
  # only complete lines count: the fields land after the marker
  said() {
    n=$(tr -d '\0' < "$work/out" | wc -l | tr -d ' ')
    [ "${n:-0}" -gt 0 ] && tr -d '\0' < "$work/out" | head -n "$n" | grep -qa '\*\*\* CPU exception'
  }
  # boot, type at the prompt (an early uart byte is dropped by firmware), stop at the
  # report. the ceiling is for rv64 under tcg, ~60s to a prompt
  fault_report() {
    : > "$work/out"
    rm -f "$work/in"; mkfifo "$work/in"
    # 768M: a major wants a contiguous 2x pool. `love` asks for the plain console
    # shellcheck disable=SC2086
    $qemu $mach -m 768M -serial stdio -display none -no-reboot \
          -kernel "$elf" -append love < "$work/in" > "$work/out" 2>/dev/null &
    qp=$!
    exec 3> "$work/in"
    typed=0 i=0
    while [ $i -lt 3000 ]; do
      said && break
      if [ $typed = 0 ] && grep -qa -e '^> ' -e 'm> ' "$work/out"; then
        printf '(fault %s)\n' "$1" >&3; typed=1
      fi
      kill -0 $qp 2>/dev/null || break
      sleep 0.1; i=$((i + 1))
    done
    exec 3>&-
    kill $qp 2>/dev/null
    wait $qp 2>/dev/null
    n=$(tr -d '\0' < "$work/out" | wc -l | tr -d ' ')
    tr -d '\0' < "$work/out" | head -n "${n:-0}" | grep -a '\*\*\* CPU exception' | head -1
  }

  # vector:strings its report holds. x64: no error code (0 3 6), a zero one (13), all fields (14)
  case $arch in
    x64) cases='0:exception 0 (#DE)
3:exception 3 (#BP)
6:exception 6 (#UD)
13:exception 13 (#GP)
14:exception 14 (#PF)|err=2|cr2=600000000000' ;;
    # a64: one sync vector; esr 2000000 is the udf
    a64) cases='6:esr=2000000
14:data abort|far=600000000000' ;;
    # rv64: one entry; cause 2 illegal, 3 breakpoint, f store page fault
    rv64) cases='6:illegal instruction|cause=2
3:breakpoint|cause=3
14:store page fault|cause=f|tval=ffffffc100000000' ;;
  esac

  echo "$cases" | while IFS=: read -r vec want; do
    [ -n "$vec" ] || continue
    got=$(fault_report "$vec")
    [ -n "$got" ] || { fail "(fault $vec) produced no exception report"; continue; }
    echo "$want" | tr '|' '\n' | while read -r w; do
      case $got in
        *"$w"*) ;;
        *) fail "(fault $vec): report is missing \"$w\""; echo "    got: $got" >&2 ;;
      esac
    done
  done
fi

# the stubs no boot reaches
if ! have llvm-objdump; then
  gate_partly "  (vec $arch: object checks skipped, no llvm-objdump)"
elif [ ! -f "$obj" ]; then
  fail "$obj was never laid"
else
  case $arch in
    x64)
      # the vectors the cpu pushes an error code for (sdm vol.3 6.3.1)
      errset=" 8 10 11 12 13 14 17 21 29 30 "
      d=$(llvm-objdump -d --no-show-raw-insn "$obj")
      v=0
      while [ $v -lt 32 ]; do
        body=$(echo "$d" | awk -v s="<exc_stub_$v>:" '
                 $0 ~ s {on = 1; next} /^[0-9a-f]+ </ {on = 0} on && NF')
        [ -n "$body" ] || { fail "exc_stub_$v is not in $obj"; v=$((v + 1)); continue; }
        n=$(echo "$body" | grep -c 'push')
        case $errset in
          *" $v "*) wantn=1; kind="takes the CPU's error code" ;;
          *)        wantn=2; kind="must push a dummy error code" ;;
        esac
        [ "$n" = "$wantn" ] || fail "exc_stub_$v $kind, so it should push $wantn word(s); it pushes $n"
        # drop the align's nop filler after the last stub
        echo "$body" | grep -v 'nop' | tail -1 | grep -q 'jmp.*exc_common' ||
          fail "exc_stub_$v does not end in a jump to exc_common"
        v=$((v + 1))
      done
      ;;
    a64)
      # VBAR_EL1 ignores the low 11 bits; the align is the header's last column,
      # and the name's field number moves with the index's width
      al=$(llvm-readelf -S "$obj" |
           awk '{ for (i = 1; i <= NF; i++) if ($i == ".text.vectors") { print $NF; exit } }')
      [ "$al" = 2048 ] ||
        fail ".text.vectors must ask the linker for 2048-byte alignment; it asks for ${al:-nothing}"
      # sixteen entries 0x80 apart, exactly one (slot 5) different
      br=$(llvm-objdump -d --no-show-raw-insn "$obj" |
           awk '/^ +[0-9a-f]+:/ { off = strtonum("0x" substr($1, 1, length($1) - 1))
                                  if (off < 2048 && off % 128 == 0) print off, $2, $3 }')
      n=$(echo "$br" | grep -c .)
      [ "$n" = 16 ] || fail "the vector table should hold 16 entries at 0x80 spacing; found $n"
      echo "$br" | awk '$2 != "b" { print "slot at " $1 " is not a branch" }' | while read -r m; do fail "$m"; done
      odd=$(echo "$br" | awk '{c[$3]++; t[$3] = t[$3] " " NR} END { for (k in c) if (c[k] == 1) print t[k] }')
      [ "$(echo "$odd" | tr -d ' ')" = 6 ] ||
        fail "exactly one of the sixteen vectors (slot 5, current EL SP_ELx IRQ) must differ; the odd one out is entry$odd"
      ;;
    rv64)
      # every register saved comes back, fcsr rides a0, and sret is the last word
      d=$(llvm-objdump -d --no-show-raw-insn --mattr=+c,+d "$obj")
      sd=$(echo "$d" | awk '$2 == "sd" { print $3 }' | sort)
      ld=$(echo "$d" | awk '$2 == "ld" { print $3 }' | sort)
      n=$(echo "$sd" | sort -u | grep -c .)
      [ "$n" = 16 ] || fail "the trap entry should save 16 registers; it saves $n"
      [ "$sd" = "$ld" ] || fail "the trap entry restores a different set than it saves"
      n=$(echo "$d" | awk '$2 == "fsd"' | grep -c .)
      [ "$n" = 20 ] || fail "the trap entry should save the 20 float registers C spends; it saves $n"
      [ "$(echo "$d" | awk '$2 == "fsd" { print $3 }' | sort)" = "$(echo "$d" | awk '$2 == "fld" { print $3 }' | sort)" ] ||
        fail "the trap entry restores a different float set than it saves"
      echo "$d" | awk '$2 == "frcsr" { r = 1 } r && $2 == "sd" && $3 == "a0," { ok = 1 } END { exit !ok }' ||
        fail "the trap entry does not store fcsr"
      echo "$d" | awk '$2 == "ld" && $3 == "a0," && !l { l = 1; next } l && $2 == "fscsr" { ok = 1 } END { exit !ok }' ||
        fail "the trap entry does not restore fcsr"
      echo "$sd" | grep -q '^t5,' || fail "the trap entry does not save t5, the flag scratch"
      echo "$sd" | grep -q '^t6,' || fail "the trap entry does not save t6, the address scratch"
      n=$(echo "$d" | grep -c 'sret')
      [ "$n" = 1 ] || fail "the trap entry should hold exactly one sret; found $n"
      echo "$d" | awk 'NF && /^ +[0-9a-f]+:/ { last = $2 } END { print last }' | grep -q sret ||
        fail "the sret is not the last instruction of the trap entry"
      ;;
  esac
fi

[ -f "$work/failed" ] && exit 1
echo "test_vec($arch): the fault path reports what it caught, and every stub is on the right side of the error-code split"
exit 0
