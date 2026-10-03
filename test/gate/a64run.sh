# test/gate/a64run.sh -- where an a64 lane's binaries run: on an a64 host when one answers
# (a64exec.l, bee's `--on a64-exec` in waiting), else under qemu-aarch64 here. sourced after
# skip.sh; the binaries are built HERE either way, and the answers are compared here.
#
#   a64_how LOVE        a64_via = host | qemu | "" (neither: the lane skips, as it always has);
#                       a64_where=K=V first asks for a host with that fact (page=16384)
#   a64_jobs DIR        a fresh batch in DIR: what the binaries need goes in DIR, nothing else
#   a64_tree TGZ        the tree goes too: TGZ (the carried source, out/dist's) unpacks to
#                       DIR/tree first, for a corpus that reads the tree beside it
#   a64_job NAME CMD    CMD runs in DIR, $RUN before each binary (empty on a host), stdin
#                       closed; its output lands in DIR/res/NAME.out and its status in NAME.rc
#   a64_run DIR         runs the batch, one ssh on a host; the res/ files come back to DIR,
#                       and res/page with the host's page size
#   a64_one LOVE BIN [ARG..]   one binary, its output and status as a local run's
a64_where=${a64_where-}
a64x() { LOVE_NO_IMAGE= "$a64_love" test/gate/a64exec.l --on a64-exec ${a64_where:+--where "$a64_where"} "$@"; }
a64_how() {
  a64_love=$1
  a64_qemu=$(command -v qemu-aarch64 2>/dev/null || true)
  [ -z "$a64_where" ] || a64x --probe 2>/dev/null || a64_where=
  if a64x --probe; then a64_via=host
  elif [ -n "$a64_qemu" ]; then a64_via=qemu
  else a64_via=; fi
}
a64_jobs() {
  rm -rf "$1"; mkdir -p "$1/res"
  a64_batch=$1/batch.sh
  : > "$a64_batch"
}
a64_tree() {
  cp "$1" "$(dirname "$a64_batch")/tree.tgz"
  echo 'mkdir tree && tar xzf tree.tgz -C tree --strip-components=1 && rm tree.tgz && mkdir tree/out' >> "$a64_batch"
}
a64_job() {
  n=$1; shift
  printf '( %s ; exit $? ) < /dev/null > res/%s.out 2>&1; echo $? > res/%s.rc\n' "$*" "$n" "$n" >> "$a64_batch"
}
a64_run() {
  if [ "$a64_via" = host ]; then
    a64x --ship "$1" -- sh -c 'RUN= sh batch.sh 2>/dev/null; getconf PAGESIZE > res/page; tar cf - res' > "$1/res.tar"
    s=$?
    [ $s -eq 0 ] || { echo "a64run: the host answered $s" >&2; return $s; }
    tar xf "$1/res.tar" -C "$1" && rm -f "$1/res.tar"
  else
    ( cd "$1" && RUN=$a64_qemu sh batch.sh 2>/dev/null )
  fi
}
a64_one() {
  if [ "$a64_via" = host ]; then
    b=$2; shift 2
    a64_d=$(dirname "$b")/.a64one
    rm -rf "$a64_d"; mkdir -p "$a64_d"; cp "$b" "$a64_d/"
    a64x --ship "$a64_d" -- "./$(basename "$b")" "$@"
  else
    shift; "$a64_qemu" "$@"
  fi
}
