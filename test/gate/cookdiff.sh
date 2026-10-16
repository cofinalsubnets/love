#!/bin/sh
# test/gate/cookdiff.sh -- cook against GNU make: each case is a tiny Makefile run by
# both, outputs equal byte for byte. an unknown builtin expands to nothing in silence
# usage: cookdiff.sh LOVE     (LOVE = a binary whose `kore make` verb is cook)
. test/gate/skip.sh
set -u
K=${1:?usage: cookdiff.sh LOVE}
K=$(cd "$(dirname "$K")" && pwd)/$(basename "$K")

command -v make >/dev/null 2>&1 || gate_skip "cookdiff: no ambient make -- skipped"
case "$(make --version 2>/dev/null | head -1)" in
  *"GNU Make"*) ;;
  *) gate_skip "cookdiff: ambient make is not GNU make -- skipped" ;;
esac

# the oracle runs top-level and serial: an inherited jobserver reorders `all: a | b`
unset MAKEFLAGS MFLAGS GNUMAKEFLAGS MAKELEVEL

# cook's own progress lines, filtered; nothing else may join them
cooknoise='is already up to date|^cook: cooked '

work=$(mktemp -d) || exit 1
trap 'rm -rf "$work"' EXIT
fail=0; ran=0; known=0

# case_ NAME KIND <<'E' .. E   KIND: same (must agree) | known (a recorded difference)
# each case runs once per make: shell_once counts its side effects
case_() {
  nm=$1; kind=$2
  d=$work/$nm; mkdir -p "$d"; cat > "$d/Makefile"
  g=$(cd "$d" && make -s 2>&1)
  c=$(cd "$d" && LOVE_NO_IMAGE= "$K" kore make 2>&1 | grep -vE "$cooknoise")
  ran=$((ran + 1))
  [ "$g" = "$c" ] && return 0
  if [ "$kind" = known ]; then
    known=$((known + 1)); echo "cookdiff: KNOWN  $nm"; return 0
  fi
  echo "cookdiff: FAIL   $nm"
  echo "  gnu : $(printf '%s' "$g" | tr '\n' '|')"
  echo "  cook: $(printf '%s' "$c" | tr '\n' '|')"
  fail=$((fail + 1))
}

# ---- functions -------------------------------------------------------------
case_ subst same      <<'E'
all:;@echo "$(subst ee,EE,feet street)"
E
case_ patsubst same   <<'E'
all:;@echo "$(patsubst %.c,%.o,a.c b.c c.h)"
E
case_ strip same      <<'E'
all:;@echo "[$(strip   a   b   )]"
E
case_ findstring same <<'E'
all:;@echo "[$(findstring a,b a c)][$(findstring z,b a c)]"
E
case_ filter same     <<'E'
all:;@echo "$(filter %.c %.h,a.c b.o c.h) / $(filter-out %.o,a.c b.o)"
E
case_ sort same       <<'E'
all:;@echo "$(sort c b a b)"
E
case_ words same      <<'E'
all:;@echo "[$(word 2,a b c)][$(words a b c)][$(wordlist 2,3,a b c d)]"
E
case_ firstlast same  <<'E'
all:;@echo "[$(firstword a b)][$(lastword a b)]"
E
case_ paths same      <<'E'
all:;@echo "[$(dir a/b c)][$(notdir a/b c)][$(basename a.c)][$(suffix a.c)]"
E
case_ addfix same     <<'E'
all:;@echo "[$(addprefix p-,a b)][$(addsuffix -s,a b)]"
E
case_ join same       <<'E'
all:;@echo "[$(join a b,1 2)][$(join a b c,1)]"
E
case_ if same         <<'E'
all:;@echo "[$(if ,yes,no)][$(if x,yes,no)]"
E
case_ orand same      <<'E'
all:;@echo "[$(or ,,x)][$(and x,y)][$(and x,,y)]"
E
case_ foreach same    <<'E'
all:;@echo "[$(foreach v,a b c,<$(v)>)]"
E
case_ foreach_scope same <<'E'
v = outer
all:;@echo "[$(foreach v,a b,$(v))][$(v)]"
E
case_ call same       <<'E'
rev = $(2) $(1)
all:;@echo "[$(call rev,a,b)]"
E
case_ flavor same     <<'E'
A = 1
B := 2
all:;@echo "[$(flavor A)][$(flavor B)][$(flavor NOPE)]"
E
case_ origin same     <<'E'
A = 1
all:;@echo "[$(origin A)][$(origin NOPE)]"
E
case_ shell same      <<'E'
all:;@echo "[$(shell echo hi)]"
E
case_ info same       <<'E'
all:;@echo "[$(info side)done]"
E
case_ nested_var same <<'E'
A = B
B = deep
all:;@echo "[$($(A))]"
E

# ---- assignment and expansion ----------------------------------------------
case_ flavors same    <<'E'
A = 1
A += 2
B := x
B += y
C ?= d
all:;@echo "[$(A)][$(B)][$(C)]"
E
case_ recursive same  <<'E'
X = $(Y)
Y = late
all:;@echo "[$(X)]"
E
case_ simple same     <<'E'
Y = early
X := $(Y)
Y = late
all:;@echo "[$(X)]"
E
case_ substref same   <<'E'
S = a.c b.c
all:;@echo "[$(S:.c=.o)][$(S:%.c=%.x)]"
E

# ---- rules and recipes -----------------------------------------------------
case_ autovars same   <<'E'
all: dep1 dep2
	@echo "[$@][$<][$^]"
dep1 dep2:;@:
E
case_ patrule same    <<'E'
%.o: %.c ; @echo "[$@ from $< stem=$*]"
all: a.o
a.c: ;@touch a.c
E
# a pattern whose prerequisite cannot be made does not apply; an existing target is a leaf
case_ patrule_reject same <<'E'
$(shell printf 'int x;\n' > src.c)
%.c: %.l ; @echo "LEXED $<"
all: src.c
	@echo "made $<"
E
# ..and the other side of it: a prerequisite that CAN be made still applies
case_ patrule_chain same <<'E'
%.c: %.l ; @echo "[lex $< -> $@]"
gen.l: ;@touch gen.l
all: gen.c
E
case_ inline_semi same <<'E'
all:;@echo one ; echo two
E
case_ orderonly same  <<'E'
all: a | b
	@echo "[built]"
a:;@echo "[a]"
b:;@echo "[b]"
E
case_ dollardollar same <<'E'
all:;@echo "[$$(echo nested)]" ; echo "[$${HOME:+set}]"
E
case_ conditionals same <<'E'
V = x
ifeq ($(V),x)
R = eq
else
R = ne
endif
ifneq (a,b)
Q = differ
endif
ifdef V
D = def
endif
ifndef NOPE
N = ndef
endif
all:;@echo "[$(R)][$(Q)][$(D)][$(N)]"
E
case_ defaultgoal same <<'E'
first:;@echo "[first is default]"
second:;@echo "[second]"
E
case_ export same     <<'E'
export FOO = bar
all:;@echo "[$$FOO]"
E
case_ phony same      <<'E'
.PHONY: all
all:;@echo "[phony ok]"
E

# a recipe line expanded twice runs its $(shell ..) twice: count the runs
case_ shell_once same <<'E'
all:
	@echo "[$(shell echo R >> ./n.txt; wc -l < ./n.txt)]" ; rm -f ./n.txt
E

# ---- the two-run law -------------------------------------------------------
# build, age the artifact, build again, both runs compared as one. age, never touch the
# source forward: a future mtime makes GNU make warn of clock skew
# case2_ NAME KIND ARTIFACT [GOAL] -- GOAL reaches both makes; empty means the default
case2_() {
  nm=$1; kind=$2; art=$3; goal=${4-}; body=$(cat)
  ran=$((ran + 1))
  dg=$work/$nm.gnu;  mkdir -p "$dg"; printf '%s' "$body" > "$dg/Makefile"; printf 'one\n' > "$dg/src"
  dc=$work/$nm.cook; mkdir -p "$dc"; printf '%s' "$body" > "$dc/Makefile"; printf 'one\n' > "$dc/src"
  g1=$(cd "$dg" && make -s $goal 2>&1)
  c1=$(cd "$dc" && LOVE_NO_IMAGE= "$K" kore make $goal 2>&1 | grep -vE "$cooknoise")
  touch -t 200001010000 "$dg/$art" "$dc/$art" 2>/dev/null
  g2=$(cd "$dg" && make -s $goal 2>&1)
  c2=$(cd "$dc" && LOVE_NO_IMAGE= "$K" kore make $goal 2>&1 | grep -vE "$cooknoise")
  g="$g1 | $g2"; c="$c1 | $c2"
  [ "$g" = "$c" ] && return 0
  if [ "$kind" = known ]; then
    known=$((known + 1)); echo "cookdiff: KNOWN  $nm"; return 0
  fi
  echo "cookdiff: FAIL   $nm"
  echo "  gnu : $(printf '%s' "$g" | tr '\n' '|')"
  echo "  cook: $(printf '%s' "$c" | tr '\n' '|')"
  fail=$((fail + 1))
}
# a built target rebuilds when its prerequisite is newer
case2_ stale same out <<'E'
all: out
out: src
	@cp src out; echo "[built]"
E
# ..and when the named goal is a file the first run left: it is a goal, not a build file
case2_ goal_names_a_file same prog prog <<'E'
prog: src
	@cp src prog; echo "[built]"
E
# a goal whose file exists and whose rule has no prerequisites is up to date
case2_ goal_no_prereqs same stamp stamp <<'E'
stamp:
	@echo "[made]"; : > stamp
E

# ---- recorded differences, reported and not failed -------------------------
# a known row is a divergence with a reason; it moves to `same` once fixed
# continuation: a variable folds \<newline> and the indent to one space, a recipe does not
case_ continuation same <<'E'
A = one \
    two
all:;@echo "[$(A)]"
E
# make keeps the space before a trailing `#`, cook trims it
case_ comment known <<'E'
A = 1 # trailing
all:;@echo "[$(A)]"
E
# under -s make is silent on a failed `-cmd`; cook names it
case_ ignored_fail known <<'E'
all:
	@echo "[at]"
	-false
	@echo "[after]"
E

echo "cookdiff: $ran cases, $fail failed, $known recorded differences"
[ $fail -eq 0 ] || exit 1
exit 0
