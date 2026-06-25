#!/bin/sh
# run.sh <lang> <benches> [timeout] [skip] [samples] -- run one language across
# the named benches.
#
# Emits one raw "<name> <lang> <reps> <ms> <chk>" result line per bench on stdout
# (the Makefile redirects them into out/bench/<lang>.txt) and a progress tick per
# bench on stderr. Each bench is run `samples` times (default 5); the line whose
# per-iteration time (ms/reps) is the MEDIAN of the samples is the one reported.
# Median -- not min -- is the honest central tendency for a GC'd language: a GC
# pause is intrinsic cost, so min would catch the runs that happened to dodge a
# collection and SYSTEMATICALLY under-report it, biasing toward high-variance
# collectors (the artifact that made a generational build look like a `hash`
# regression). Median is robust to BOTH the GC-lucky lows AND OS-noise highs.
# Each sample runs under `timeout` (default 30s); a bench that times out or
# errors on every sample produces no line, so a language that can't finish a
# workload drops that cell rather than failing the build. `skip` is a
# space-separated list of <lang>:<bench> pairs known to time out; those are
# dropped up front, so the build never pays the timeout wall for them. If the
# interpreter/compiler isn't on PATH the whole language is skipped. BENCH_LANG is
# exported so the shared harnesses (lib/bench.* + lib/Bench.*) print the right
# column label.
lang=$1
benches=$2
to=${3:-30}
skip=" ${4:-} "   # padded so `case` can match whole " lang:bench " words
samples=${5:-5}   # timed windows per bench; the median ms/it window is reported

# per-language file extension, interpreter binary, and run command. the command
# is eval'd with $b bound to the bench name, so the source is benches/$b.$ext.
case $lang in
  # ai: for `mandelbrot`, `fib`, `tak`, `primes`, `strscan`, `strcat`, `deforest`, `polysum`, `closure`, `tree`, `bintrees`, load
  # the native glaze (ai/glaze/emit.l + auto.l) AHEAD of the bench on an x86-64 host -- the recognizers then read
  # the bench's UNCHANGED source and compile it to native (mandelbrot's float-recurrence grid -> a whole-grid SSE
  # kernel: its IDIOMATIC complex ~(re im) recurrence is LOWERED to a real/imag float pair (twolow) onto that
  # kernel; fib/tak/primes' integer call graph -> a native mutually-recursive group, with primes'
  # named-let loops lambda-lifted into it; deforest's map/filter/fold list pipeline DEFORESTED into one
  # native loop; polysum's pure-polynomial pipeline CLOSED to its O(1) closed form by the loop-closer;
  # strcat's O(n^2) string-accumulator loop rebuilt to a native O(n) cask-fill while its rolling hash glazes
  # via the string lane; closure's curried HOFs (twice/adder) INLINED to a first-order recurrence by dehof;
  # tree's + bintrees' binary-tree BUILD (mk) -> native cons (the Stage-D value-lane, GC-safe under the moving
  # collector) and node-count TRAVERSE (ck) -> a native chain fold (the chain lane: (two? t)/(cap t)/(cup t)
  # lowered inline) -- bintrees adds the sustained-alloc / long-lived-survival loop (a GC-throughput stress);
  # hash's read-only
  # sum-lookup SCAN PARTIAL-LIFTED out of hash-run (plift) to a top-level fn taking the map as a param, its
  # (peep h k) compiled to a native open-addressed map probe via the map lane, the allocating ins/bump staying
  # interpreted), the ai analogue of LuaJIT auto-JITting Lua. The glaze self-tests print to stderr
  # (discarded here); other benches stay interpreted (the glaze matches only these).
  ai)            ext=l;    bin=../out/host/ai;  cmd='cat $({ [ "$b" = mandelbrot ] || [ "$b" = fib ] || [ "$b" = tak ] || [ "$b" = primes ] || [ "$b" = strscan ] || [ "$b" = strcat ] || [ "$b" = deforest ] || [ "$b" = polysum ] || [ "$b" = closure ] || [ "$b" = tree ] || [ "$b" = bintrees ] || [ "$b" = hash ]; } && [ "$(uname -m)" = x86_64 ] && printf "%s %s " ../ai/glaze/emit.l ../ai/glaze/auto.l; [ "$b" = cdcl ] && printf "%s " ../sat/sat.l) bench.l benches/$b.l | ../out/host/ai' ;;
  chez)         ext=ss;   bin=chez;       cmd='chez --script benches/$b.ss' ;;
  sbcl)         ext=lisp; bin=sbcl;       cmd='sbcl --script benches/$b.lisp' ;;
  elixir)       ext=exs;  bin=elixir;     cmd='elixir benches/$b.exs' ;;
  julia)        ext=jl;   bin=julia;      cmd='julia --startup-file=no benches/$b.jl' ;;
  pypy)         ext=py;   bin=pypy3;      cmd='pypy3 benches/$b.py' ;;
  node)         ext=js;   bin=node;       cmd='node benches/$b.js' ;;
  luajit)       ext=lua;  bin=luajit;     cmd='luajit benches/$b.lua' ;;
  # compiled languages: build to a scratch dir (the compile is NOT timed -- each
  # bench self-times its inner loop), run, clean up. A compile failure produces no
  # output, so run.sh drops the cell exactly as it does for a missing source file.
  go)           ext=go;   bin=go;         cmd='d=$(mktemp -d); cp benches/$b.go "$d/main.go"; cp lib/bench.go "$d/bench.go"; go run "$d/main.go" "$d/bench.go"; rm -rf "$d"' ;;
  rust)         ext=rs;   bin=rustc;      cmd='d=$(mktemp -d); rustc -O -o "$d/b" benches/$b.rs >/dev/null 2>&1 && "$d/b"; rm -rf "$d"' ;;
  java)         ext=java; bin=javac;      cmd='d=$(mktemp -d); javac -d "$d" benches/$b.java lib/Bench.java >/dev/null 2>&1 && java -cp "$d" Main; rm -rf "$d"' ;;
  *) echo "run.sh: unknown language '$lang'" >&2; exit 1 ;;
esac

if ! command -v "$bin" >/dev/null 2>&1; then
  echo "  $lang: $bin not found, skipped" >&2
  exit 0
fi

export BENCH_LANG=$lang b   # $b is read by $cmd inside `sh -c` below
for b in $benches; do
  [ -f "benches/$b.$ext" ] || continue
  case $skip in *" $lang:$b "*)                     # known-timeout pair: don't attempt
    printf '  %-13s %-10s (dropped: known timeout)\n' "$lang" "$b" >&2; continue ;;
  esac
  printf '  %-13s %-10s' "$lang" "$b" >&2          # start the line (no newline)
  acc=''                                            # collect one result line per sample
  i=0
  while [ "$i" -lt "$samples" ]; do
    i=$((i + 1))
    o=$(timeout "$to" sh -c "$cmd" 2>/dev/null)
    [ -n "$o" ] && acc="$acc$o
"
  done
  if [ -n "$acc" ]; then
    # report the sample whose per-iteration time (ms/reps) is the median. keying on
    # ms/reps -- not raw ms -- normalizes the auto-scaled rep count, which can differ
    # between samples near the MIN_MS boundary; the emitted line is one real run, so
    # its reps+ms stay internally consistent for report.awk (which divides ms/reps).
    med=$(printf '%s' "$acc" | awk '
      NF == 5 && $3 + 0 > 0 { line[++n] = $0; key[n] = $4 / $3 }
      END {
        if (!n) exit
        for (i = 1; i <= n; i++) ord[i] = i        # insertion-sort indices by ms/reps (n is tiny)
        for (i = 2; i <= n; i++) {
          v = ord[i]; j = i - 1
          while (j >= 1 && key[ord[j]] > key[v]) { ord[j + 1] = ord[j]; j-- }
          ord[j + 1] = v }
        print line[ord[int((n + 1) / 2)]] }')
    if [ -n "$med" ]; then
      printf '%s\n' "$med"                          # the median result line -> stdout (the .txt)
      printf ' %s ms (median/%s)\n' "$(printf '%s\n' "$med" | awk '{print $4}')" "$samples" >&2
    else
      printf ' (skipped: no valid sample)\n' >&2
    fi
  else
    printf ' (skipped: >%ss or error)\n' "$to" >&2
  fi
done
