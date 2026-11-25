# test/gate/shiplove.sh -- the love a board's host runs: this one where the host is of its machine,
# else the cross-built one, made here when a lane wants it. sourced.
#   ship_love LOVE CAP    prints its path; fails where the host does not say or none is made
ship_love() {
  ship_m=$("$1" bee --on "$2" -- uname -m 2>/dev/null | tr -d '\r') || return 1
  [ "$ship_m" = "$(uname -m)" ] && { echo "$1"; return 0; }
  case $ship_m in
    x86_64) ship_a=x64 ;; aarch64) ship_a=a64 ;; riscv64) ship_a=rv64 ;;
    *) echo "no love for a host that is ${ship_m:-silent}" >&2; return 1 ;;
  esac
  ${MAKE:-make} -s xa=$ship_a out/x-$ship_a/love >&2 || return 1
  echo out/x-$ship_a/love
}
