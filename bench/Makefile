# Benchmark harness. Times equivalent numeric / list workloads written in many
# languages and prints a side-by-side comparison. Each language self-times the
# inner loop (auto-scaling reps past a 200ms floor) so interpreter startup is
# excluded; see bench.ai / lib/bench.* for the shared protocol.
#
# Results are cached per language under out/bench/<lang>.txt. The user-facing
# targets DEPEND on those files and just pretty-print them -- a bench is only
# (re)run when its result file is missing or older than the bench sources (or,
# for ai, the ai binary). So `make bench` reformats instantly once the files
# exist; touch a source or `make clean` to force a re-run.
#
#   make / make bench   show the default column set (ai pypy ruby node
#                          luajit julia go rust), running only what is stale
#   make all            show every language present on this machine
#   make <lang>         show one language (ai is shown alongside for contrast),
#                          e.g. make chez / make pypy / make rust
#   make BENCHES=fib …  restrict the workload set (then clean to refresh files)
#   make TIMEOUT=60 …   per-bench wall-clock cutoff in seconds (default 30)
#   make raw            cat the raw "<name> <lang> <reps> <ms> <chk>" lines
#   make clean          remove out/bench/
#
# A language whose interpreter/compiler is not on PATH is skipped automatically, as
# is any bench a language has no implementation file for (e.g. luajit/rust lack bell
# -- no bignums); the cell drops out of the table. Pairs that exceed TIMEOUT are
# listed in SKIP (below) and dropped up front so the build never pays the timeout
# wall for them. The per-language run logic lives in run.sh.
R := ..
include $(R)/common.mk

GL   := $(R)/out/host/ai
HARN := bench.l
BDIR := $(R)/out/bench
TIMEOUT ?= 30

# workloads, in display order; override with `make BENCHES="fib primes"`.
BENCHES := fib tak sum mapfilter deforest primes bell strcat strscan hash sort tree float closure sat

# <lang>:<bench> pairs that exceed TIMEOUT -- dropped up front so the build never
# pays the timeout wall for them (re-test by removing one and `make clean`).
SKIP :=

# every language, in report-column order (grouped by family). ai first.
ALL_LANGS := ai \
             chez sbcl clojure \
             elixir pypy ruby node luajit julia \
             go java haskell rust

# the columns `make bench` shows by default.
DEFAULT_LANGS := ai pypy ruby node luajit julia go rust

# per-language: source extension, harness file (a result depends on it), the
# interpreter binary (for the PATH presence check), and any extra prereq.
EXT_ai := l
EXT_chez := ss
EXT_sbcl := lisp
EXT_clojure := clj
EXT_elixir := exs
EXT_pypy := py
EXT_ruby := rb
EXT_node := js
EXT_luajit := lua
EXT_julia := jl
EXT_go := go
EXT_java := java
EXT_haskell := hs
EXT_rust := rs

HARN_ai := $(HARN)
HARN_chez := lib/bench.ss
HARN_sbcl := lib/bench.lisp
HARN_clojure := lib/bench.clj
HARN_elixir := lib/bench.exs
HARN_pypy := lib/bench.py
HARN_ruby := lib/bench.rb
HARN_node := lib/bench.js
HARN_luajit := lib/bench.lua
HARN_julia := lib/bench.jl
HARN_go := lib/bench.go
HARN_java := lib/Bench.java
HARN_haskell := lib/Bench.hs
HARN_rust := lib/bench.rs

BIN_chez := chez
BIN_sbcl := sbcl
BIN_clojure := clojure
BIN_elixir := elixir
BIN_pypy := pypy3
BIN_ruby := ruby
BIN_node := node
BIN_luajit := luajit
BIN_julia := julia
BIN_go := go
BIN_java := javac
BIN_haskell := ghc
BIN_rust := rustc

EXTRA_ai := $(GL)

# ai is always available (we build it); others only if their binary is on PATH.
present = $(if $(filter ai,$(1)),$(1),$(if $(shell command -v $(BIN_$(1)) 2>/dev/null),$(1)))
PRESENT := $(foreach L,$(ALL_LANGS),$(call present,$(L)))
SHOW    := $(filter $(PRESENT),$(DEFAULT_LANGS))

txt = $(addprefix $(BDIR)/,$(addsuffix .txt,$(1)))

.PHONY: all bench run raw html clean $(ALL_LANGS)
.DEFAULT_GOAL := bench

# Build/refresh the host binary via the root Makefile.
$(GL):
	@$(MAKE) -s -C $(R) host

$(BDIR):
	@mkdir -p $(BDIR)

# Per-language result file + single-language report target. The result file is
# regenerated (benches re-run) only when its sources change; the phony <lang>
# target just formats it, alongside ai for contrast (ai shows only itself).
define LANG_rule
$$(BDIR)/$(1).txt: $(HARN_$(1)) $$(wildcard benches/*.$(EXT_$(1))) run.sh $(EXTRA_$(1)) | $$(BDIR)
	@./run.sh $(1) "$$(BENCHES)" $$(TIMEOUT) "$$(SKIP)" > $$@

$(1): $$(call txt,$(1)) $(if $(filter ai,$(1)),,$$(call txt,ai))
	@awk -v langs='$(if $(filter ai,$(1)),ai,ai $(1))' -f report.awk $$^
endef
$(foreach L,$(ALL_LANGS),$(eval $(call LANG_rule,$(L))))

# Default view: the chosen column set (minus any whose interpreter is absent).
bench: $(call txt,$(SHOW))
	@awk -v langs='$(SHOW)' -f report.awk $^

# Full view: every language present on this machine.
all run: $(call txt,$(PRESENT))
	@awk -v langs='$(PRESENT)' -f report.awk $^

raw: $(call txt,$(PRESENT))
	@cat $^

# Self-contained results page: bench/bench.html, the full roster as columns
# (a present-but-empty language shows a dotted column), with a transpose button
# and a viewport-chosen initial orientation. Regenerate after a fresh `make all`.
html: $(call txt,$(PRESENT)) mkhtml.sh | $(BDIR)
	@cat $(call txt,$(PRESENT)) | ./mkhtml.sh "$(ALL_LANGS)" > bench.html
	@echo "wrote bench/bench.html"

clean:
	@rm -rf $(BDIR)
