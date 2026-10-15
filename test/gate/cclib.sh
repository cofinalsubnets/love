# test/gate/cclib.sh -- the C gates' shared helpers, dotted after skip.sh.
# fail reads $name; moonrun runs love $m's mooncc, moonc the one in $ho
fail() { echo "FAIL $name: $*" >&2; exit 1; }
moonrun() { LOVE_NO_IMAGE= "$m" mooncc "$@"; }
moonc() { LOVE_NO_IMAGE= "$ho/love" mooncc "$@"; }
have() { command -v "$1" > /dev/null 2>&1; }
# refusal ST LOG SRC: mooncc's refusal of SRC exited ST, not a signal, and LOG names SRC
refusal() {
  [ "$1" -lt 128 ] || fail "$3: mooncc died on a signal ($1) where a refusal was expected"
  grep -q "$3" "$2" || { cat "$2" >&2; fail "$3: the refusal does not name the file"; }
}
# refused LOG SRC ARGS..: mooncc ARGS must refuse SRC
refused() {
  _l=$1 _s=$2; shift 2
  moonrun "$@" > "$_l" 2>&1 && fail "$_s: mooncc $* BUILT a program listed as refused -- take it off the list"
  refusal $? "$_l" "$_s"
}
