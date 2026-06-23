#!/bin/sh
# run.sh <lang> <benches> [timeout] [skip] -- run one language across the named
# benches.
#
# Emits the raw "<name> <lang> <reps> <ms> <chk>" result lines on stdout (the
# Makefile redirects them into out/bench/<lang>.txt) and a progress tick per
# bench on stderr. Each bench is run under `timeout` (default 30s); a bench that
# times out or errors is skipped with a note and simply produces no line, so a
# language that can't finish a workload drops that cell rather than failing the
# build. `skip` is a space-separated list of <lang>:<bench> pairs known to time
# out; those are dropped up front, so the build never pays the timeout wall for
# them. If the interpreter/compiler isn't on PATH the whole language is skipped.
# BENCH_LANG is exported so the shared harnesses (lib/bench.* + lib/Bench.*) print
# the right column label.
lang=$1
benches=$2
to=${3:-30}
skip=" ${4:-} "   # padded so `case` can match whole " lang:bench " words

# per-language file extension, interpreter binary, and run command. the command
# is eval'd with $b bound to the bench name, so the source is benches/$b.$ext.
case $lang in
  # ai: for `float`, `fib`, `tak`, `primes`, `strscan`, `deforest`, load the native glaze (ai/glaze/emit.l
  # + auto.l) AHEAD of the bench on an x86-64 host -- the recognizers then read the bench's UNCHANGED
  # source and compile it to native (float.l's float-recurrence grid -> a whole-grid SSE kernel;
  # fib/tak/primes' integer call graph -> a native mutually-recursive group, with primes' named-let loops
  # lambda-lifted into it; deforest's map/filter/fold list pipeline DEFORESTED into one native loop), the
  # ai analogue of LuaJIT auto-JITting Lua. The glaze self-tests print to stderr (discarded here); other
  # benches stay interpreted (the glaze matches only these).
  ai)            ext=l;    bin=../out/host/ai;  cmd='cat $({ [ "$b" = float ] || [ "$b" = fib ] || [ "$b" = tak ] || [ "$b" = primes ] || [ "$b" = strscan ] || [ "$b" = deforest ]; } && [ "$(uname -m)" = x86_64 ] && printf "%s %s " ../ai/glaze/emit.l ../ai/glaze/auto.l; [ "$b" = sat ] && printf "%s " ../sat/sat.l) bench.l benches/$b.l | ../out/host/ai' ;;
  chez)         ext=ss;   bin=chez;       cmd='chez --script benches/$b.ss' ;;
  sbcl)         ext=lisp; bin=sbcl;       cmd='sbcl --script benches/$b.lisp' ;;
  clojure)      ext=clj;  bin=clojure;    cmd='clojure -M benches/$b.clj' ;;
  elixir)       ext=exs;  bin=elixir;     cmd='elixir benches/$b.exs' ;;
  julia)        ext=jl;   bin=julia;      cmd='julia --startup-file=no benches/$b.jl' ;;
  pypy)         ext=py;   bin=pypy3;      cmd='pypy3 benches/$b.py' ;;
  ruby)         ext=rb;   bin=ruby;       cmd='ruby benches/$b.rb' ;;
  node)         ext=js;   bin=node;       cmd='node benches/$b.js' ;;
  luajit)       ext=lua;  bin=luajit;     cmd='luajit benches/$b.lua' ;;
  # compiled languages: build to a scratch dir (the compile is NOT timed -- each
  # bench self-times its inner loop), run, clean up. A compile failure produces no
  # output, so run.sh drops the cell exactly as it does for a missing source file.
  go)           ext=go;   bin=go;         cmd='d=$(mktemp -d); cp benches/$b.go "$d/main.go"; cp lib/bench.go "$d/bench.go"; go run "$d/main.go" "$d/bench.go"; rm -rf "$d"' ;;
  rust)         ext=rs;   bin=rustc;      cmd='d=$(mktemp -d); rustc -O -o "$d/b" benches/$b.rs >/dev/null 2>&1 && "$d/b"; rm -rf "$d"' ;;
  haskell)      ext=hs;   bin=ghc;        cmd='d=$(mktemp -d); ghc -O2 -fno-full-laziness -dynamic -ilib -outputdir "$d" -o "$d/b" benches/$b.hs >/dev/null 2>&1 && "$d/b"; rm -rf "$d"' ;;
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
  out=$(timeout "$to" sh -c "$cmd" 2>/dev/null)
  if [ -n "$out" ]; then
    printf '%s\n' "$out"                            # result line(s) -> stdout (the .txt)
    # field 4 of the result line is the measured ms; show it at the end of the tick.
    printf ' %s ms\n' "$(printf '%s\n' "$out" | awk 'NF>=4{m=$4} END{print m}')" >&2
  else
    printf ' (skipped: >%ss or error)\n' "$to" >&2
  fi
done
