# mk/lib.mk -- the out/lib/*.h egg + service headers (lcat + sed_lit)
#
# Fragment of the root Makefile (split out 2026-07-15). Included by ./Makefile,
# which is invoked from the project root; paths resolve from there. Shared vars
# live in common.mk. Every recipe here is unchanged from the single-file Makefile.

# Static lisp headers: each ai/*.l is serialized to a C string literal in
# out/lib/*.h by tools/lcat.l (run on the bootstrap interpreter ai0). Frontends
# #include these and assemble the bootstrap with G_EGG_PRE/POST (ai.h).
# Drop a .l into ai/ and it is picked up automatically -- no rule to edit.
lib_h = $(patsubst ai/%.l,out/lib/%.h,$(wildcard ai/*.l))
# the crew/holo/ assembler baked into BOTH runtimes as a core language service: the
# neutral core + BOTH backends. They are pure ai (produce machine-code bytes as
# DATA, never execute them), so every backend is arch-neutral and rides along on
# every host -- only the glaze, which EXECUTES the bytes, is arch-bound (and it is
# cat-loaded + x86-gated separately, never baked). asm_h = lcat headers (host ai);
# asm0_h = sed-wrapped raw source (ai0, the bootstrap -- can't lcat its own sources).
holo_h = out/lib/holo.h  out/lib/x64.h  out/lib/arm64.h  out/lib/export.h
asm0_h = out/lib/holo0.h out/lib/x640.h out/lib/arm640.h out/lib/export0.h
# the glaze (native JIT, ai/glaze/{emit,auto}.l): baked to raw-text headers (sed_lit,
# like asm0 -- no lcat reader round-trip). Evaled ONLY before a --bake (x86-gated
# in main.c), so a normal boot never pays the ~810 ms; the baked snapshot then carries
# an always-on JIT at zero startup (Phase 4, doc/snapshot.md). Their self-test asserts
# native-compile transient closures -- the bake's gen_major drops them before serializing.
glaze_h = out/lib/emit.h out/lib/auto.h out/lib/gexport.h out/lib/hook.h
# ai0's bootstrap headers: sed-wrapped raw source (a text->C-literal needing no
# interpreter -- the l reader strips the ; comments at read time), since ai0
# can't lcat the very sources it is assembled from (chicken/egg). cli.l doubles as
# ai0's CLI arg handler; prel/ev/egg/repl + the whole concatenated test corpus
# are baked in so ai0 self-tests both compilers in one run (see main.c). The final
# l uses the canonicalized lcat headers from the rule below instead.
sed_lit = sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/^/"/' -e 's/$$/\\n"/'
gl0_h = out/lib/cli0.h out/lib/egg0.h out/lib/prel0.h out/lib/ev0.h out/lib/bao0.h out/lib/uu0.h out/lib/tests0.h $(asm0_h)
.PHONY: lib
lib: $(lib_h) $(gl0_h)
# lcat a .l source into its C-string header, ATOMICALLY: generate to a temp, require it
# non-empty, then mv into place. A bare `> $@` truncates first, so a broken ai0 (or any
# lcat failure) would leave a 0-byte header that make then treats as up-to-date -- which
# SILENTLY drops a baked service (e.g. an empty holo.h => `assemble` unbound => the glaze's
# map lane emits nothing => a corrupt native => crash/hang). Fail loudly instead.
lcat_h = @mkdir -p out/lib; echo AI	$@; \
  $(ai0) -l ai/prel.l tools/lcat.l $< > $@.tmp && test -s $@.tmp && mv -f $@.tmp $@ \
    || { rm -f $@.tmp; echo "FAIL: $@ empty (ai0 lcat failed -- broken bootstrap?)"; exit 1; }
$(lib_h): out/lib/%.h: ai/%.l tools/lcat.l   # + $(ai0), stated below
	$(lcat_h)
# the crew/holo/ assembler (crew/holo/holo.l + crew/holo/x64.l) rides the SAME lcat pipeline into the
# post-egg layer -- a core language service (the glaze is its client). Explicit rules
# (their sources live in crew/holo/, not ai/, so the pattern rule above misses them).
out/lib/holo.h: crew/holo/holo.l tools/lcat.l
	$(lcat_h)
out/lib/x64.h: crew/holo/x64.l tools/lcat.l
	$(lcat_h)
out/lib/arm64.h: crew/holo/arm64.l tools/lcat.l
	$(lcat_h)
out/lib/export.h: crew/holo/export.l tools/lcat.l
	$(lcat_h)
# ai0's sed-wrapped raw source of the same three (no interpreter -- the l reader
# strips ; comments at read time), baked into the bootstrap so the corpus can test
# the assembler under BOTH compilers (c0 + the self-hosted ev), like prel/ev/bao.
out/lib/holo0.h: crew/holo/holo.l
	@mkdir -p out/lib
	@echo AI	$@
	@$(sed_lit) $< > $@
out/lib/x640.h: crew/holo/x64.l
	@mkdir -p out/lib
	@echo AI	$@
	@$(sed_lit) $< > $@
out/lib/arm640.h: crew/holo/arm64.l
	@mkdir -p out/lib
	@echo AI	$@
	@$(sed_lit) $< > $@
out/lib/export0.h: crew/holo/export.l
	@mkdir -p out/lib
	@echo AI	$@
	@$(sed_lit) $< > $@
out/lib/%0.h: ai/%.l
	@mkdir -p out/lib
	@echo AI	$@
	@$(sed_lit) $< > $@
# the glaze headers (ai/glaze/ -- outside the ai/*.l wildcard, so explicit). Raw sed_lit:
# the glaze source is sigil-heavy, so skip the lcat reader round-trip and bake it verbatim.
out/lib/emit.h: ai/glaze/emit.l
	@mkdir -p out/lib
	@echo AI	$@
	@$(sed_lit) $< > $@
out/lib/auto.h: ai/glaze/auto.l
	@mkdir -p out/lib
	@echo AI	$@
	@$(sed_lit) $< > $@
out/lib/gexport.h: ai/glaze/export.l
	@mkdir -p out/lib
	@echo AI	$@
	@$(sed_lit) $< > $@
out/lib/hook.h: ai/glaze/hook.l
	@mkdir -p out/lib
	@echo AI	$@
	@$(sed_lit) $< > $@
out/lib/tests0.h: $t
	@mkdir -p out/lib
	@echo AI	$@
	@cat $t | $(sed_lit) > $@

# ai_version.h: the build's version-control id, surfaced in the runtime as the `ai-version`
# global (ai.c ai_ini_0). VCS-AGNOSTIC: a _darcs/ repo stamps darcs-<12-hex patch hash>
# (-dirty when darcs whatsnew is non-empty), else git describe, else "unknown" -- so the
# darcs snapshot import carries this rule verbatim and stamps itself. Regenerated every
# make but only rewritten when the id changes, so l.o relinks on a new revision, not on
# every build. Frontends without it on the include path fall back to "unknown" (ai.c
# uses __has_include).
.PHONY: force_version
force_version: ;
out/lib/ai_version.h: force_version
	@mkdir -p out/lib
	@if [ -d $(R)/_darcs ]; then \
	  v="darcs-$$(darcs log --repodir $(R) --last 1 2>/dev/null | awk '/^patch/{print substr($$2,1,12)}')"; \
	  darcs whatsnew --repodir $(R) >/dev/null 2>&1 && v="$$v-dirty"; \
	else \
	  v="$$(git -C $(R) describe --always --dirty 2>/dev/null || echo unknown)"; \
	fi; printf '#define AI_VERSION "%s"\n' "$$v" > $@.tmp
	@if cmp -s $@.tmp $@ 2>/dev/null; then rm -f $@.tmp; else mv $@.tmp $@; echo SH $@; fi

# The lcat'd lib headers (egg.h et al) are PRODUCED BY running ai0, so re-lay
# them whenever ai0 changes. (The old "edit a .h => make clean or ai0 hangs" gum is
# cleaned: ai0's own objects already depend on $(ai_h), so ai0 can't go stale.)
$(lib_h): $(ai0)
