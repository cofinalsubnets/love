# Benchmark harness. Times equivalent numeric/list workloads written in gwen,
# python, ruby, chez scheme, sbcl, node and lua and prints a comparison table.
# Each language self-times the inner loop (auto-scaling reps past a 200ms floor)
# so interpreter startup is excluded; see bench.g / lib/bench.* for the shared
# protocol.
#
#   make            run every bench in all available languages -> table
#   make BENCHES=fib run a subset
#   make gwen       gwen only   (also: python ruby chez sbcl node lua)
#   make raw        print the raw "<name> <lang> <reps> <ms> <chk>" lines
#   make clean      remove bench/out/
#
# gwen is always run; the other interpreters are auto-skipped if not on PATH,
# and a bench is skipped for a language that has no implementation file (e.g.
# bell has no lua version -- lua lacks bignums).
R := ..
include $(R)/common.mk

GL  := $(R)/out/host/$n
HARN := bench.g
BDIR := out
RAW  := $(BDIR)/results.txt

# default suite, in display order; override with `make BENCHES="fib primes"`.
BENCHES := fib tak sum mapfilter reverse primes bell strcat strscan

# column order in the report; columns with no data are omitted automatically.
LANGS := gwen python ruby chez sbcl node lua

HAVE_PY   := $(shell command -v python3 2>/dev/null)
HAVE_RB   := $(shell command -v ruby 2>/dev/null)
HAVE_CHEZ := $(shell command -v chez 2>/dev/null)
HAVE_SBCL := $(shell command -v sbcl 2>/dev/null)
HAVE_NODE := $(shell command -v node 2>/dev/null)
HAVE_LUA  := $(shell command -v lua 2>/dev/null)

.PHONY: all run gwen python ruby chez sbcl node lua raw clean $(GL)

all: run

# Build/refresh the host binary via the root Makefile.
$(GL):
	@$(MAKE) -s -C $(R) host

run: raw
	@awk -v langs="$(LANGS)" -f report.awk $(RAW)

# Collect the raw result lines for the selected benches + languages. Each
# non-gwen interpreter is guarded by `-f` so a missing implementation is skipped.
raw: $(GL) | $(BDIR)
	@: > $(RAW)
	@for b in $(BENCHES); do \
	  cat $(HARN) benches/$$b.$x | $(GL) >> $(RAW) ; \
	  $(if $(HAVE_PY),  [ -f benches/$$b.py ]   && python3 benches/$$b.py       >> $(RAW) ;) \
	  $(if $(HAVE_RB),  [ -f benches/$$b.rb ]   && ruby benches/$$b.rb          >> $(RAW) ;) \
	  $(if $(HAVE_CHEZ),[ -f benches/$$b.ss ]   && chez --script benches/$$b.ss >> $(RAW) ;) \
	  $(if $(HAVE_SBCL),[ -f benches/$$b.lisp ] && sbcl --script benches/$$b.lisp >> $(RAW) ;) \
	  $(if $(HAVE_NODE),[ -f benches/$$b.js ]   && node benches/$$b.js          >> $(RAW) ;) \
	  $(if $(HAVE_LUA), [ -f benches/$$b.lua ]  && lua benches/$$b.lua          >> $(RAW) ;) \
	  : ; \
	done
	@$(if $(HAVE_PY),,  echo "note: python3 not found, skipped" >&2)
	@$(if $(HAVE_RB),,  echo "note: ruby not found, skipped" >&2)
	@$(if $(HAVE_CHEZ),,echo "note: chez not found, skipped" >&2)
	@$(if $(HAVE_SBCL),,echo "note: sbcl not found, skipped" >&2)
	@$(if $(HAVE_NODE),,echo "note: node not found, skipped" >&2)
	@$(if $(HAVE_LUA),, echo "note: lua not found, skipped" >&2)

# Single-language runs (handy when iterating on one implementation).
gwen: $(GL) | $(BDIR)
	@for b in $(BENCHES); do cat $(HARN) benches/$$b.$x | $(GL) ; done

python: | $(BDIR)
	@for b in $(BENCHES); do [ -f benches/$$b.py ]   && python3 benches/$$b.py || : ; done

ruby: | $(BDIR)
	@for b in $(BENCHES); do [ -f benches/$$b.rb ]   && ruby benches/$$b.rb || : ; done

chez: | $(BDIR)
	@for b in $(BENCHES); do [ -f benches/$$b.ss ]   && chez --script benches/$$b.ss || : ; done

sbcl: | $(BDIR)
	@for b in $(BENCHES); do [ -f benches/$$b.lisp ] && sbcl --script benches/$$b.lisp || : ; done

node: | $(BDIR)
	@for b in $(BENCHES); do [ -f benches/$$b.js ]   && node benches/$$b.js || : ; done

lua: | $(BDIR)
	@for b in $(BENCHES); do [ -f benches/$$b.lua ]  && lua benches/$$b.lua || : ; done

$(BDIR):
	@mkdir -p $(BDIR)

clean:
	@rm -rf $(BDIR)
