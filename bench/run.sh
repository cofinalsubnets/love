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
# out (e.g. owl:bell); those are dropped up front, so the build never pays the
# timeout wall for them. If the interpreter isn't on PATH the whole language is
# skipped. BENCH_LANG is exported so the shared harnesses (bench.ss/.lisp/.lua/
# .js/.py) print the right column label.
lang=$1
benches=$2
to=${3:-30}
skip=" ${4:-} "   # padded so `case` can match whole " lang:bench " words

# per-language file extension, interpreter binary, and run command. the command
# is eval'd with $b bound to the bench name, so the source is benches/$b.$ext.
case $lang in
  # ai: for `float`, `fib`, `tak`, `primes`, load the native glaze (ai/glaze/emit.l + auto.l) AHEAD of the
  # bench on an x86-64 host -- the recognizers then read the bench's UNCHANGED source and compile it to
  # native (float.l's float-recurrence grid -> a whole-grid SSE kernel; fib/tak/primes' integer call
  # graph -> a native mutually-recursive group, with primes' named-let loops lambda-lifted into it), the
  # ai analogue of LuaJIT auto-JITting Lua. The glaze self-tests print to stderr (discarded here); other
  # benches stay interpreted (the glaze matches only these).
  ai)            ext=l;    bin=../out/host/ai;  cmd='cat $({ [ "$b" = float ] || [ "$b" = fib ] || [ "$b" = tak ] || [ "$b" = primes ] || [ "$b" = strscan ]; } && [ "$(uname -m)" = x86_64 ] && printf "%s %s " ../ai/glaze/emit.l ../ai/glaze/auto.l) bench.l benches/$b.l | ../out/host/ai' ;;
  chez)         ext=ss;   bin=chez;       cmd='chez --script benches/$b.ss' ;;
  petite)       ext=ss;   bin=petite;     cmd='petite --script benches/$b.ss' ;;
  guile)        ext=scm;  bin=guile;      cmd='guile --no-auto-compile -s benches/$b.scm' ;;
  racket)       ext=rkt;  bin=racket;     cmd='racket benches/$b.rkt' ;;
  mit-scheme)   ext=mit;  bin=mit-scheme; cmd='mit-scheme --quiet --load benches/$b.mit --eval "(%exit 0)"' ;;
  sbcl)         ext=lisp; bin=sbcl;       cmd='sbcl --script benches/$b.lisp' ;;
  clisp)        ext=lisp; bin=clisp;      cmd='clisp -q benches/$b.lisp' ;;
  ecl)          ext=lisp; bin=ecl;        cmd='ecl -eval "(setq *load-verbose* nil)" --shell benches/$b.lisp' ;;
  clojure)      ext=clj;  bin=clojure;    cmd='clojure -M benches/$b.clj' ;;
  elixir)       ext=exs;  bin=elixir;     cmd='elixir benches/$b.exs' ;;
  chicken)      ext=ck;   bin=chicken-csi; cmd='chicken-csi -s benches/$b.ck' ;;
  bigloo)       ext=bgl;  bin=bigloo;     cmd='bigloo -i benches/$b.bgl' ;;
  owl)          ext=owl;  bin=ol;         cmd='cat lib/bench.owl benches/$b.owl | ol /dev/stdin' ;;
  hy)           ext=hy;   bin=hy;         cmd='hy benches/$b.hy' ;;
  fennel)       ext=fnl;  bin=fennel;     cmd='fennel benches/$b.fnl' ;;
  python)       ext=py;   bin=python3;    cmd='python3 benches/$b.py' ;;
  pypy)         ext=py;   bin=pypy3;      cmd='pypy3 benches/$b.py' ;;
  ruby)         ext=rb;   bin=ruby;       cmd='ruby benches/$b.rb' ;;
  node)         ext=js;   bin=node;       cmd='node benches/$b.js' ;;
  deno)         ext=js;   bin=deno;       cmd='deno run -A --quiet --unstable-detect-cjs benches/$b.js' ;;
  lua)          ext=lua;  bin=lua;        cmd='lua benches/$b.lua' ;;
  luajit)       ext=lua;  bin=luajit;     cmd='luajit benches/$b.lua' ;;
  luajit-nojit) ext=lua;  bin=luajit;     cmd='luajit -joff benches/$b.lua' ;;
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
