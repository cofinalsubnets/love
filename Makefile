R ?= .
include $(R)/mk/common.mk

CCACHE ?= $(shell command -v ccache 2>/dev/null)

ifneq ($(words $(CC)),1)
CCACHE :=
endif

# bootstrap interpreter
love0 = out/host/love0

.PHONY: all install uninstall clean distclean host kernel wasm love0 lint ccdb ulp \
  site site-serve valg disasm flame cat cata catav perf repl gdb bench cloc

# an unpacked release builds the product; a checkout keeps the fast gate
ifeq ($(in_git),)
.DEFAULT_GOAL := dist
else
.DEFAULT_GOAL := test
endif

# avoid creating empty artifacts with fresh mtime
.DELETE_ON_ERROR:

lib_h = $(patsubst src/core/boot/%.l,out/lib/%.h,$(wildcard src/core/boot/*.l))
holo_h = out/lib/holo.h  out/lib/x64.h  out/lib/a64.h  out/lib/rv64.h
asm0_h = out/lib/holo0.h out/lib/x640.h out/lib/a640.h
glaze_h = out/lib/emit.h out/lib/auto.h out/lib/hook.h out/lib/walk.h
sed_lit = sed \
  -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/^/"/' -e 's/$$/\\n"/'
boot_h = out/lib/cli0.h out/lib/egg0.h out/lib/post0.h out/lib/p10.h out/lib/prel0.h out/lib/ev0.h out/lib/bao0.h out/lib/uu0.h out/lib/rng0.h out/lib/q0.h out/lib/glob0.h out/lib/kanren0.h out/lib/overlay0.h out/lib/peg0.h out/lib/verbs0.h $(asm0_h)
.PHONY: lib
lib: $(lib_h) $(boot_h)
lcat_love = $(love0) -l src/core/boot/prel.l
# A FORCED WITNESS KEEPS ITS MTIME, and that is the whole point: make cannot depend on a
# variable's VALUE, so a roster change has to be noticed some other way. Depending on the
# Makefile instead was measured at 90 s and 42 targets for a bare `touch Makefile` -- the
# .mooncc-cat.l -> mooncc0.image -> every moon object chain. Do not simplify this away.
note = if cmp -s $$tf $@ 2>/dev/null; then rm -f $$tf; else mv $$tf $@; echo 'SH	'$@; fi
# every header below is written straight to $@. .DELETE_ON_ERROR (above) takes the
# half-written one away when a generator dies, which is the whole of the guarantee.
$(lib_h): out/lib/%.h: src/core/boot/%.l tools/lcat.l   # + $(love0), stated below
	@echo 'LOVE	'$@
	@mkdir -p out/lib
	@$(lcat_love) tools/lcat.l $< > $@
$(holo_h): out/lib/%.h: src/core/holo/%.l tools/lcat.l
	@echo 'LOVE	'$@
	@mkdir -p out/lib
	@$(lcat_love) tools/lcat.l $< > $@
out/lib/rune.h: src/apps/rune/rune.l tools/lcat.l
	@echo 'LOVE	'$@
	@mkdir -p out/lib
	@$(lcat_love) tools/lcat.l $< > $@
$(glaze_h): out/lib/%.h: src/core/boot/glaze/%.l
	@echo 'LOVE	'$@
	@mkdir -p out/lib
	@$(lcat_love) tools/lcat.l $< > $@
$(asm0_h): out/lib/%0.h: src/core/holo/%.l
	@echo 'SED	'$@
	@mkdir -p out/lib
	@LOVE_NO_IMAGE= $(sed_lit) $< > $@
out/lib/%0.h: src/core/boot/%.l
	@echo 'SED	'$@
	@mkdir -p out/lib
	@LOVE_NO_IMAGE= $(sed_lit) $< > $@
glaze_items = "(use 'holo)(module 'glaze " @out/lib/emit.h @out/lib/auto.h ")" \
  "(: ev (from 'glaze 'ev) member? (from 'glaze 'member?))" \
  @out/lib/hook.h @out/lib/walk.h @out/lib/holo.h @out/lib/x64.h @out/lib/a64.h
cats_egg_items   = @out/lib/egg.h
cats_p1_items    = @out/lib/p1.h
cats_prel_items  = @out/lib/prel.h " " @out/lib/ev.h
cats_post_items  = @out/lib/post.h
cats_modsa_items = @out/lib/rng.h @out/lib/q.h @out/lib/glob.h \
  @out/lib/kanren.h @out/lib/overlay.h @out/lib/uu.h
cats_modsb_items = @out/lib/bao.h @out/lib/verbs.h @out/lib/scan.h @out/lib/re.h @out/lib/peg.h
cats_z = out/lib/cat_egg_z.h out/lib/cat_p1_z.h out/lib/cat_prel_z.h out/lib/cat_post_z.h \
  out/lib/cat_modsa_z.h out/lib/cat_modsb_z.h \
  out/lib/cat_mods_x64_z.h out/lib/cat_mods_a64_z.h out/lib/cat_mods_rv64_z.h
# mkgz names its own symbol and sizes on err, so these carry no echo of their own.
out/lib/glaze_z.h: $(glaze_h) $(holo_h) tools/mkgz.l $(love0)
	@$(lcat_love) tools/mkgz.l src_glaze_z $(glaze_items) > $@
out/lib/cat_egg_z.h: out/lib/egg.h tools/mkgz.l $(love0)
	@$(lcat_love) tools/mkgz.l ai_cat_egg_z $(cats_egg_items) > $@
out/lib/cat_p1_z.h: out/lib/p1.h tools/mkgz.l $(love0)
	@$(lcat_love) tools/mkgz.l ai_cat_p1_z $(cats_p1_items) > $@
out/lib/cat_prel_z.h: out/lib/prel.h out/lib/ev.h tools/mkgz.l $(love0)
	@$(lcat_love) tools/mkgz.l ai_cat_prel_z $(cats_prel_items) > $@
out/lib/cat_post_z.h: out/lib/post.h tools/mkgz.l $(love0)
	@$(lcat_love) tools/mkgz.l ai_cat_post_z $(cats_post_items) > $@
out/lib/cat_modsa_z.h: out/lib/rng.h out/lib/q.h out/lib/glob.h out/lib/kanren.h out/lib/overlay.h out/lib/uu.h tools/mkgz.l $(love0)
	@$(lcat_love) tools/mkgz.l ai_cat_mods_a_z $(cats_modsa_items) > $@
out/lib/cat_modsb_z.h: out/lib/bao.h out/lib/verbs.h out/lib/scan.h out/lib/re.h out/lib/peg.h tools/mkgz.l $(love0)
	@$(lcat_love) tools/mkgz.l ai_cat_mods_b_z $(cats_modsb_items) > $@
out/lib/cat_mods_%_z.h: out/lib/holo.h out/lib/%.h tools/mkgz.l $(love0)
	@$(lcat_love) tools/mkgz.l ai_cat_mods_h_z @out/lib/holo.h @out/lib/$*.h > $@
.PHONY: force_corpus_list
force_corpus_list: ;
# love0 reads this at runtime to find the corpus. $t is a glob, so it is written
# every run; only the phony test_love0 wants it, so the moving mtime costs nothing.
out/lib/corpus.list: force_corpus_list
	@mkdir -p out/lib
	@echo '$t' > $@

out/lib/love_version.h: $(R)/VERSION
	@mkdir -p out/lib
	@printf '#define AiVersion "%s"\n' "$$(cat $(R)/VERSION)" > $@
	@echo 'SH	'$@

out/lib/readme.bin: $(love0) $(R)/src/core/boot/cli.l $(R)/VERSION
	@mkdir -p out/lib
	@printf 'love %s\n' "$$(cat $(R)/VERSION)" > $@
	@$(love0) -h </dev/null >> $@
	@echo 'LOVE	'$@

$(lib_h) $(holo_h) $(glaze_h) out/lib/rune.h: $(love0)
ho = out/host$(hsuf)
h_o = $(love_c:$(R)/%.c=$(ho)/%.o)
host_o = $(host_c:$(R)/%.c=$(ho)/%.o)
hcc = LOVE_NO_IMAGE= $(CC) $(ai_cflags) $(GCDBG) -Dai_tco=$(tco) -fpic -I$(ho) -I. -Isrc/core -Isrc/host -Isrc/inle -Iout/lib
image_ldflags = -Wl,--section-start=.love.image=0x2000000
.PHONY: force_hostcc
force_hostcc: ;
$(ho)/.hostcc: force_hostcc
	@mkdir -p $(ho)
	@tf=$@.$$$$.tmp; printf '%s\n' '$(CC) $(image_ldflags)' > $$tf; \
	 $(note)
host: $(ho)/love $(ho)/love.baked $(ho)/love.1 $(ho)/cook.1
love0: $(love0)

$(ho)/love.baked $(ho)/love.cand.baked: %.baked: % $(ho)/.dist-cat.l
	@echo 'LOVE	'$< "(bake)"
	@$< bake -l $(ho)/.dist-cat.l
	@touch $@

.PHONY: candidate
candidate: $(ho)/love.cand.baked

$(ho)/liblove.a: $(h_o)
	@echo 'AR	'$@
	@mkdir -p $(dir $@)
	@rm -f $@; ar rcs $@ $^

# pinned to out/host/0, never $(ho)/0: love0 is one binary whatever HCC and tco say
love0_o = $(patsubst $(R)/%.c,out/host/0/%.o,$(filter-out $(R)/src/host/cats.c,$(host_c)) $(love_c))
out/host/0/src/host/main.o: $(boot_h)
out/host/0/src/host/cb.o: src/core/quay/quay.c src/core/quay/nif.c src/core/quay/quay.h
boot_cc = $(CCACHE) $(CC) $(ai_cflags) -fPIE -DLoveBoot -Dai_tco=0 -Dai_data_section=0 -DAiVersion='"$(love_base)+bootstrap"' -I. -Isrc/core -Isrc/host -Isrc/inle -Iout/lib
.PHONY: force_love0cc
force_love0cc: ;
out/host/0/.love0cc: force_love0cc
	@mkdir -p $(dir $@)
	@tf=$@.$$$$.tmp; printf '%s\n' '$(boot_cc)' > $$tf; \
	 $(note)
out/host/0/%.o: $(R)/%.c $(love_h) out/host/0/.love0cc
	@echo 'CC	'$@
	@mkdir -p $(dir $@)
	@LOVE_NO_IMAGE= $(boot_cc) -c $< -o $@
$(love0): $(love0_o)
	@echo 'LD	'$@
	@mkdir -p $(dir $@)
	@LOVE_NO_IMAGE= $(CC) $(ai_cflags) -pie -o $@ $(love0_o)

# src/core/love.c -> out/host/*.o
$(ho)/%.o: $(R)/%.c $(love_h) $(ho)/.hostcc
	@echo 'CC	'$@
	@mkdir -p $(dir $@)
	@$(hcc) -c $< -o $@

# l.o carries the version string; recompile it when the id changes. love0's twin is
# deliberately not here -- see the -DAiVersion note on boot_cc.
$(ho)/src/core/love.o: out/lib/love_version.h
# the lcat'd headers the frontends bake inline -- src/host/cats.c takes the egg and the module
# set, src/host/main.c the CLI and the glaze. one roster for both: the mooncc twin and the HCC
# link below read the same name, and three spellings is how they drift.
baked_h = out/lib/egg.h out/lib/post.h out/lib/p1.h out/lib/prel.h out/lib/ev.h out/lib/cli.h out/lib/bao.h out/lib/rng.h out/lib/q.h out/lib/glob.h out/lib/kanren.h out/lib/overlay.h out/lib/scan.h out/lib/re.h out/lib/peg.h out/lib/uu.h out/lib/verbs.h out/lib/distlist.h $(holo_h) $(glaze_h)
$(ho)/src/host/main.o $(ho)/src/host/cats.o: $(baked_h)
$(ho)/src/host/cats.o: $(cats_z)
# the carried-blob reader both the first boot and the kernel's ram fs decode with
$(ho)/src/host/main.o $(ho)/src/host/ustar.o: $(R)/src/host/ustar.h
# src/host/cb.c rides the src/core/quay sources by unity include -- recompile when they move.
$(ho)/src/host/cb.o: src/core/quay/quay.c src/core/quay/nif.c src/core/quay/quay.h

moon0 = $(love0) wake out/host/mooncc0.image mooncc $(GCDBG)
moon0_dep = out/host/mooncc0.image
# THE MOONCC OBJECT LANE: love's own C compiled by mooncc into one directory, worn twice --
# at the host's arch, and at the cross arch $(xa) names. $(call moonlane,NAME,DIRVAR,CCVAR,
# ARCHVAR), every argument but the first a variable NAME so the body stays deferred; the
# kart shape below is the same idiom. Answers $(1)_love_o, _host_o, _math_o and $(1)_o.
define moonlane
$(1)_love_o = $$(core_tu:%.c=$$($(2))/%.o)
$(1)_host_o = $$(host_c:$$(R)/src/host/%.c=$$($(2))/host_%.o)
$(1)_math_o = $$(patsubst src/apps/moon/lib/math/%.c,$$($(2))/m_%.o,$$(wildcard src/apps/moon/lib/math/*.c))
$(1)_o = $$($(1)_love_o) $$($(1)_host_o) $$($(1)_math_o) $$($(2))/sys.o
$$($(1)_love_o): $$($(2))/%.o: $$(R)/src/core/%.c $$(love_h) $$(moon0_dep)
	@echo 'MOON	'$$@
	@mkdir -p $$(dir $$@)
	@$$($(3)) -D ai_tco=$$(tco) -D AiHaveVersionH -I$$(ho) -I. -Isrc/core -Isrc/host -Isrc/inle -Iout/lib -c $$< $$@
$$($(2))/love.o: out/lib/love_version.h        # only this TU carries the version id
$$($(2))/host_%.o: $$(R)/src/host/%.c $$(love_h) $$(moon0_dep)
	@echo 'MOON	'$$@
	@mkdir -p $$(dir $$@)
	@$$($(3)) -D ai_tco=$$(tco) -I$$(ho) -I. -Isrc/core -Isrc/host -Isrc/inle -Iout/lib -c $$< $$@
$$($(2))/host_main.o $$($(2))/host_cats.o: $$(baked_h)
$$($(2))/host_main.o: out/lib/glaze_z.h
$$($(2))/host_cats.o: $$(cats_z)
$$($(2))/host_cb.o: src/core/quay/quay.c src/core/quay/nif.c src/core/quay/quay.h
$$($(2))/m_%.o: src/apps/moon/lib/math/%.c $$(moon0_dep)
	@echo 'MOON	'$$@
	@mkdir -p $$(dir $$@)
	@$$($(3)) -Isrc/apps/moon/lib/math -Isrc/apps/moon/include -c $$< $$@
# the machine tail rides the host's own cat, one cut for every consumer; only the entry
# names the arch.
$$($(2))/sys.o: out/host/.mksys-cat.l $$(love0)
	@echo 'HOLO	'$$@
	@mkdir -p $$(dir $$@)
	@LOVE_NO_IMAGE= $$(love0) -l out/host/.mksys-cat.l -q -e "((from 'moon 'mksys-$$($(4))) \"$$@\")" && test -s $$@
endef

moon_d = $(ho)/moon
$(eval $(call moonlane,moon,moon_d,moon0,hosta))
mksys_l = src/apps/kore/text.l src/apps/kore/u.l src/apps/kore/asbook.l \
          src/core/holo/x64.l src/core/holo/a64.l src/core/holo/rv64.l \
          src/core/holo/elf.l src/core/holo/obj.l src/apps/moon/lib/mksys.l
.PHONY: force_dist_list
force_dist_list: ;
out/host/.mksys-cat.list: force_dist_list
	@mkdir -p $(dir $@)
	@tf=$@.$$$$.tmp; echo '$(mksys_l)' > $$tf; \
	 $(note)
out/host/.mksys-cat.l: $(mksys_l) out/host/.mksys-cat.list
	@echo 'CAT	'$@
	@mkdir -p $(dir $@)
	@cat $(mksys_l) > $@
ifneq ($(HCC),)
$(ho)/love $(ho)/love.cand: $(host_o) $(ho)/liblove.a $(ho)/.hostcc $(R)/src/core/love_data.ld $(baked_h)
	@echo 'LD	'$@
	@mkdir -p $(dir $@)
	@$(hcc) -o $@ $(host_o) $(ho)/liblove.a $(image_ldflags) $(data_ld)
else
nolibc_src = $(wildcard src/apps/moon/lib/nolibc/*.c src/apps/moon/lib/nolibc/*.h \
                        src/apps/moon/lib/nolibc/*/*.c src/apps/moon/lib/nolibc/*/*.h)
$(ho)/love $(ho)/love.cand: $(moon_o) out/host/src.o out/host/rt.o out/lib/readme.bin $(nolibc_src)
	@echo 'MOON	'$@
	@mkdir -p $(dir $@)
	@$(moon0) -pie $(moon_o) $(kart_o) out/host/src.o out/host/rt.o -freadme=out/lib/readme.bin -o $@
endif

$(ho)/love.1 $(ho)/cook.1 $(ho)/lush.1: $(ho)/%.1: doc/%.md tools/mkman.l src/apps/lapiz/lapiz.l out/lib/love_version.h $(ho)/love
	@echo 'LOVE	'$@
	@mkdir -p $(dir $@)
	@$(ho)/love tools/mkman.l doc/$*.md out/lib/love_version.h > $@

lushfiles = src/apps/lush/job.l src/apps/lush/lex.l src/apps/lush/gram.l src/apps/lush/glob.l src/apps/lush/word.l src/apps/lush/eval.l src/apps/lush/line.l src/apps/lush/main.l
korefiles =src/apps/kore/text.l src/apps/kore/u.l src/apps/kore/core.l src/apps/kore/fs.l src/apps/kore/sum.l src/apps/kore/re.l src/apps/kore/sed.l src/apps/kore/awk.l src/apps/kore/expr.l src/apps/kore/bc.l src/apps/kore/proc.l src/apps/kore/less.l src/apps/libra/lint.l src/apps/vi/config.l src/apps/vi/hue.l src/apps/vi/core.l src/apps/vi/vi.l src/apps/kore/diff.l src/apps/kore/patch.l src/apps/dns/dns.l src/apps/ain/ain.l $(lushfiles) src/apps/kore/find.l src/apps/cook/cook.l src/apps/kore/asbook.l src/core/holo/elf.l src/core/holo/obj.l src/core/holo/link.l src/core/holo/copy.l src/apps/kore/kore.l
moonfiles = src/apps/kore/text.l src/apps/kore/u.l src/apps/kore/asbook.l src/core/holo/x64.l src/core/holo/a64.l src/core/holo/thumb2.l src/core/holo/rv64.l src/core/holo/thumb1.l src/core/holo/text.l src/core/holo/elf.l src/core/holo/obj.l src/core/holo/link.l src/apps/moon/floor.l src/apps/moon/lex.l src/apps/moon/cpp.l src/apps/moon/parse.l src/apps/moon/val.l src/apps/moon/gen.l src/apps/moon/lib/mksys.l src/apps/moon/moon.l
$(ho)/.mooncc-cat.list: force_dist_list
	@mkdir -p $(dir $@)
	@tf=$@.$$$$.tmp; echo '$(moonfiles)' > $$tf; \
	 $(note)
$(ho)/.mooncc-cat.l: $(moonfiles) $(ho)/.mooncc-cat.list
	@echo 'CAT	'$@
	@mkdir -p $(dir $@)
	@cat $(moonfiles) > $@
sbfiles = src/apps/kore/text.l src/apps/kore/diff.l src/apps/dns/dns.l src/apps/sb/merge.l src/apps/sb/http.l src/apps/sb/sb.l
$(ho)/sb: $(sbfiles)
$(ho)/lush: $(lushfiles)
$(ho)/sb $(ho)/lush:
	@echo 'CAT	'$@
	@mkdir -p $(dir $@)
	@{ echo '#!/usr/bin/env -S love'; cat $^; } > $@
	@chmod 755 $@
out/host/mooncc0.image: out/host/.mooncc-cat.l $(love0)
	@echo 'LOVE	'$@
	@$(love0) -l out/host/.mooncc-cat.l -e '(? ((bake "$@") = 1) (quit 0) (quit 1))'

distfiles = src/apps/kore/text.l src/apps/kore/u.l src/apps/kore/core.l src/apps/kore/fs.l src/apps/kore/sum.l src/apps/kore/re.l \
            src/apps/kore/sed.l src/apps/kore/awk.l src/apps/kore/expr.l src/apps/kore/bc.l src/apps/kore/proc.l src/apps/kore/less.l src/apps/libra/lint.l src/apps/vi/config.l src/apps/vi/hue.l \
            src/apps/vi/core.l src/apps/vi/vi.l \
            src/apps/kore/diff.l src/apps/kore/patch.l src/apps/dns/dns.l src/apps/ain/ain.l $(lushfiles) src/apps/kore/find.l \
            src/apps/cook/cook.l src/apps/kore/asbook.l \
            src/core/holo/x64.l src/core/holo/a64.l src/core/holo/thumb2.l src/core/holo/rv64.l \
            src/core/holo/thumb1.l src/core/holo/text.l src/core/holo/elf.l src/core/holo/obj.l \
            src/core/holo/link.l src/core/holo/copy.l src/apps/moon/floor.l src/apps/moon/lex.l src/apps/moon/cpp.l src/apps/moon/parse.l \
            src/apps/moon/val.l src/apps/moon/gen.l src/apps/moon/lib/mksys.l src/apps/moon/moon.l src/apps/kore/kore.l src/apps/sb/merge.l \
            src/apps/sb/http.l src/apps/sb/sb.l src/apps/kiosko/kiosko.l \
            src/apps/gz/gz.l src/apps/tar/tar.l src/apps/tar/tarcmd.l src/apps/gz/gzcmd.l src/apps/cpio/cpio.l \
            src/apps/cpio/cpiocmd.l src/apps/source/source.l src/apps/lapiz/lapiz.l \
            src/apps/libra/salt.l src/apps/libra/libra.l src/apps/vi/hueweb.l src/apps/kiosko/serve.l
$(ho)/.dist.list: force_dist_list
	@mkdir -p $(dir $@)
	@tf=$@.$$$$.tmp; echo '$(distfiles)' > $$tf; \
	 $(note)
$(ho)/.dist-cat.l: $(distfiles) $(ho)/.dist.list
	@echo 'CAT	'$@
	@mkdir -p $(dir $@)
	@cat $(distfiles) > $@
out/lib/distlist.h: Makefile
	@mkdir -p out/lib
	@tf=$@.$$$$.tmp; printf '"%s"\n' '$(distfiles)' > $$tf; \
	 $(note)
.PHONY: dist dist-source dist-seed

dist_ver  := $(love_base)
dist_stamp ?= 0
dist_source = out/dist/love-$(dist_ver).tar.gz
dist-source: $(dist_source)
ifneq ($(HCC),)
dist-seed:
	$(error dist: the HCC flavor is a differential, not the artifact -- drop HCC=)
else
dist-seed: $(ho)/love.baked
endif
dist: dist-source dist-seed   # a release is both

dist_drop = bench src/port
.PHONY: force_src
force_src: ;
$(dist_source): force_src $(love0)
	@mkdir -p $(dir $@)
	@LOVE_NO_IMAGE= LOVE_BUDGET_MB=256 $(love0) tools/selfpack.l $@ love-$(dist_ver) $(dist_stamp) $(dist_drop)

out/host/src.o: $(dist_source) tools/mksrc.l out/host/.mksys-cat.l $(love0)
	@$(love0) -l out/host/.mksys-cat.l tools/mksrc.l $(dist_source) $@ $(hosta)

rt_slice = $(wildcard src/apps/moon/include/*.h src/apps/moon/include/*/*.h \
                      src/apps/moon/lib/*.l \
                      src/apps/moon/lib/nolibc/*.c src/apps/moon/lib/nolibc/*.h \
                      src/apps/moon/lib/nolibc/*/*.c src/apps/moon/lib/nolibc/*/*.h \
                      src/apps/moon/lib/math/*.c)
out/host/rt.o: $(rt_slice) tools/mkrt.l out/host/mooncc0.image $(love0)
	@$(love0) wake out/host/mooncc0.image tools/mkrt.l $@ $(hosta)

xqemu_x64  = qemu-x86_64
xqemu_a64 = qemu-aarch64
xqemu_rv64 = qemu-riscv64
xa ?= $(if $(filter a64,$a),x64,a64)
xqemu  = $(xqemu_$(xa))
ifeq ($(filter $(xa),x64 a64 rv64),)
$(error x-lane: no such arch `$(xa)' -- the roster carries x64 a64 rv64)
endif
xd = out/x-$(xa)
moonx = $(moon0) -t $(xa)
$(eval $(call moonlane,x,xd,moonx,xa))
$(ho)/src/host/main.o: out/lib/glaze_z.h

$(xd)/src.o: $(dist_source) tools/mksrc.l out/host/.mksys-cat.l $(love0)
	@$(love0) -l out/host/.mksys-cat.l tools/mksrc.l $(dist_source) $@ $(xa)
$(xd)/rt.o: $(rt_slice) tools/mkrt.l out/host/mooncc0.image $(love0)
	@$(love0) wake out/host/mooncc0.image tools/mkrt.l $@ $(xa)
$(xd)/love: $(x_o) $(xd)/src.o $(xd)/rt.o out/lib/readme.bin
	@echo 'MOON	'$@
	@$(moonx) -pie $(x_o) $(xkart_o) $(xd)/src.o $(xd)/rt.o -freadme=out/lib/readme.bin -o $@
fat = out/dist/love-fat
.PHONY: dist-fat
dist-fat: $(ho)/love.baked $(xd)/love tools/fatpack.l
	@mkdir -p out/dist
	@$(love0) tools/fatpack.l $(fat) $a $(ho)/love $(xa) $(xd)/love
	@chmod +x $(fat)

huefiles = src/apps/vi/config.l src/apps/vi/hue.l tools/hue2vim.l
$(ho)/syntax.vim: $(huefiles) $(m)
	@echo 'HUE	'$@
	@mkdir -p $(dir $@); t=$@.$$$$.tmp; \
	  cat $(huefiles) | env -u LOVE_NO_IMAGE $(m) > $$t && test -s $$t && mv -f $$t $@ \
	    || { rm -f $$t; echo "FAIL: $@ empty (hue2vim.l failed)"; exit 1; }
.PHONY: syntax
syntax: $(ho)/syntax.vim
include $(R)/mk/distro.mk

ko = out/free

# the kernel's verbs; its gates are test/test.mk's.
.PHONY: kmain_o run run-$a run-sh run-headless init-container uefi

# love's own mooncc, and the artifact that answers it. the compiler IS the shipped
# binary, so nothing foreign builds the kernel and there is no second cc to name.
# LOVE_NO_IMAGE= leads: an egg-booted love has no verbs.
mooncc = LOVE_NO_IMAGE= $(ho)/love mooncc
mooncc_dep = $(ho)/love.baked

# this machine's metal files, and the three TUs only a kernel has a frontend for.
k_arch_c = $(wildcard $(R)/src/inle/$a/*.c)
k_free_c = $R/src/inle/kmain.c $R/src/inle/blk.c $R/src/inle/sys.c
# the whole kernel compile, in link order: the runtime and its math floor, the console
# engine with its two fonts, nolibc, the metal, the free trio -- and $(host_c) itself,
# because the kernel runs the same frontend the host does. taking that roster rather than
# copying it is what lets a new src/<app>.c reach the kernel with no rule edit.
k_c = $(love_c) \
  $R/src/core/quay/cga_8x8.c $R/src/core/quay/moderndos_8x16.c $R/src/core/quay/paint.c \
  $(c_c) $(k_arch_c) $(k_free_c) $(host_c)
k_h = $(love_h) $(R)/src/inle/k.h $(R)/src/host/ustar.h $(wildcard $(R)/src/inle/$a/*.h)

k_odir = $(ko)/$a
k_elf = $(ko)/love-$a.elf
k_pie = $(k_odir)/love.pie

# the lays and the machine tail live under $(k_odir)/$a/ so vec.o and sys.o do not
# collide with the src/ objects of the same name.
k_lay_o = $(k_odir)/$a/vec.o
k_boot_o = $(k_odir)/$a/boot.o
k_tail_o = $(k_odir)/$a/sys.o
# $(k_free_o) alone is named apart: `make kmain_o` is the ports' door to it.
k_free_o = $(k_free_c:$(R)/%.c=$(k_odir)/%.o)
k_o = $(k_c:$(R)/%.c=$(k_odir)/%.o) $(k_lay_o) $(k_tail_o) \
  $(k_odir)/rt.o $(k_odir)/src.o $(k_doom_o)

kcppflags := \
  -I$(k_odir) \
  -I. -Isrc/core -Isrc/host -Isrc/inle -Iout/lib -I$(R)/src/core/quay -I$(R) \
  -I$(R)/src/apps/moon/include \
  $(kcppflags)
kcc = $(mooncc) $(kcppflags) -t $a

kernel: $(k_elf)

$(k_odir)/src/host/cb.o: src/core/quay/quay.c src/core/quay/nif.c src/core/quay/quay.h
$(k_odir)/rt.o: $(rt_slice) tools/mkrt.l $m
	@echo 'LOVE	'$@
	@mkdir -p "$(dir $@)"
	@$m tools/mkrt.l $@ $a
$(k_odir)/src.o: $(dist_source) tools/mksrc.l out/host/.mksys-cat.l $m
	@echo 'HOLO	'$@
	@mkdir -p "$(dir $@)"
	@LOVE_NO_IMAGE= $m -l out/host/.mksys-cat.l tools/mksrc.l $(dist_source) $@ $a
$(k_pie): $(k_o) $m
	@echo 'MOON	'$@
	@mkdir -p "$(dir $@)"
	@$(mooncc) -pie -t $a $(k_o) -o $@
kproject_l = $R/src/apps/kore/text.l $R/src/apps/kore/u.l $R/src/apps/kore/asbook.l \
  $R/src/core/holo/elf.l $R/src/core/holo/obj.l $R/src/core/holo/link.l $R/tools/kproject.l
$(k_odir)/kproject.list: force_dist_list
	@mkdir -p "$(dir $@)"
	@tf=$@.$$$$.tmp; echo '$(kproject_l)' > $$tf; \
	 $(note)
$(k_odir)/kproject.l: $(kproject_l) $(k_odir)/kproject.list
	@echo 'CAT	'$@
	@mkdir -p "$(dir $@)"
	@{ echo "(use 'holo)"; cat $R/src/apps/kore/text.l $R/src/apps/kore/u.l; \
	   echo "(use 'kore)"; cat $(filter-out $R/src/apps/kore/text.l $R/src/apps/kore/u.l,$(kproject_l)); } > $@

# at the host's own arch there is no second kernel build: $(kart_o) is linked into the
# shipped love already, so the elf is projected out of that binary, and it WAKES the
# image the binary carries. $(k_pie) is the other lane -- a machine this one cannot
# run, built from source, which carries no image and WARMS the egg instead. one gate
# apiece: test_disk rides the projection, test_kernel_a64 the pie.
k_pie_in = $(k_pie)
k_pie_dep =
ifeq ($a,$(hosta))
k_pie_in = $(ho)/love
# `love bake` rewrites $(ho)/love in place, so the projection is ordered behind the stamp
k_pie_dep = $(mooncc_dep)
endif
$(k_elf): $(k_odir)/kproject.l $(k_pie_in) $(k_pie_dep) $(k_boot_o) $m
	@echo 'KPROJ	'$@
	@mkdir -p "$(dir $@)"
	@$m $(k_odir)/kproject.l $(k_pie_in) $(k_boot_o) $@ $a && test -s $@

out/lib/korelist.h: Makefile
	@mkdir -p out/lib
	@tf=$@.$$$$.tmp; printf '"%s"\n' '$(korefiles)' > $$tf; \
	 $(note)

# every $(k_c) source, wherever in the tree it lives, lands under $(k_odir) by its path.
$(k_odir)/%.o: $(R)/%.c $(k_h) $(mooncc_dep) $(baked_h) $(cats_z) out/lib/korelist.h
	@echo 'MOON	'$@
	@mkdir -p "$(dir $@)"
	@$(kcc) -c $< -o $@

# kmain_o -- the kernel frontend, COMPILED AND NOTHING MORE, at whatever arch the caller's
# `a=` says; the odir is spelled here so a caller never re-derives it.
kmain_o: $(k_free_o)

# THE CARRIED SEAT: the metal objects the one binary links, so `love kernel` projects a
# bootable elf out of the running artifact instead of building a second one. one shape,
# worn once per machine -- $(call kart,ROSTER,DIRVAR,CCVAR,ARCHVAR), every argument but
# the first a variable NAME so the body stays deferred. an arch with no src/inle/<arch>/
# carries no seat and its roster is empty.
kart_inc = -I$(ho) -I. -Isrc/core -Isrc/host -Isrc/inle -Iout/lib -I$R \
  -I$R/src/core/quay -I$R/src/apps/moon/include
# kmain.c's own bake is the kore ROSTER now; the egg and the module set are src/host/cats.c's,
# and that object rides the host lane above.
kart_bake = out/lib/korelist.h
define kart
$(1)_h = $$(love_h) $$R/src/inle/k.h $$R/src/host/ustar.h $$(wildcard $$R/src/inle/$$($(4))/*.h)
$(1)_arch_o = $$(patsubst $$R/src/inle/$$($(4))/%.c,$$($(2))/ka_%.o,$$(wildcard $$R/src/inle/$$($(4))/*.c))
# the console's painter and its fonts: kernel-only draws the host link never had
$(1)_quay_o = $$(patsubst %,$$($(2))/k_q_%.o,paint cga_8x8 moderndos_8x16)
$(1)_o = $$(if $$($(1)_arch_o),$$($(2))/k_kmain.o $$($(2))/k_blk.o $$($(2))/k_sys.o \
  $$($(1)_arch_o) $$($(1)_quay_o) $$($(2))/kvec.o,)
$(1)_lay_l = $$R/src/apps/kore/text.l $$R/src/apps/kore/u.l $$R/src/apps/kore/asbook.l \
  $$R/src/core/holo/$$($(4)).l $$R/src/core/holo/elf.l $$R/src/core/holo/obj.l
$$($(2))/k_%.o: $$R/src/inle/%.c $$($(1)_h) $$(kart_bake) $$(moon0_dep)
	@echo 'MOON	'$$@
	@mkdir -p "$$(dir $$@)"
	@$$($(3)) $$(kart_inc) -c $$< $$@
# ..and the per-ISA half on its own stem, so src/inle/kmain.c and src/inle/<a>/arch.c
# cannot collide on one pattern.
$$($(2))/ka_%.o: $$R/src/inle/$$($(4))/%.c $$($(1)_h) $$(kart_bake) $$(moon0_dep)
	@echo 'MOON	'$$@
	@mkdir -p "$$(dir $$@)"
	@$$($(3)) $$(kart_inc) -c $$< $$@
$$($(2))/k_q_%.o: $$R/src/core/quay/%.c $$(moon0_dep)
	@echo 'MOON	'$$@
	@mkdir -p "$$(dir $$@)"
	@$$($(3)) $$(kart_inc) -c $$< $$@
$$($(2))/mkvec.l: $$R/src/inle/mkvec.l $$($(1)_lay_l)
	@echo 'CAT	'$$@
	@mkdir -p "$$(dir $$@)"
	@{ echo "(use 'holo)"; cat $$R/src/apps/kore/text.l $$R/src/apps/kore/u.l; \
	   echo "(use 'kore)"; cat $$(filter-out $$R/src/apps/kore/text.l $$R/src/apps/kore/u.l,$$($(1)_lay_l)) $$<; } > $$@
# the vector lay, under whatever love a fresh tree has (mksys's own idiom)
$$($(2))/kvec.o: $$($(2))/mkvec.l $$(love0)
	@echo 'HOLO	'$$@
	@mkdir -p "$$(dir $$@)"
	@LOVE_NO_IMAGE= $$(love0) -l $$< -q -e '(lay-vec "$$@" "$$($(4))")' && test -s $$@
endef
$(eval $(call kart,kart,moon_d,moon0,hosta))
$(eval $(call kart,xkart,xd,moonx,xa))

ifdef DOOM
doom_d = $R/dl/doomgeneric/doomgeneric
doom_drop = $(wildcard $(doom_d)/doomgeneric_*.c $(doom_d)/i_allegro*.c $(doom_d)/i_sdl*.c)
doom_c = $(filter-out $(doom_drop),$(wildcard $(doom_d)/*.c))
k_doom_o = $(patsubst $(doom_d)/%.c,$(k_odir)/doom/%.o,$(doom_c)) $(k_odir)/doom/wad.o
k_free_c += $R/src/inle/doom.c
kcppflags += -I$(doom_d)
$(k_odir)/doom/%.o: $(doom_d)/%.c $(mooncc_dep)
	@echo 'DOOM	'$@
	@mkdir -p "$(dir $@)"
	@$(kcc) -c $< -o $@
$(k_odir)/doom/wad.o: $R/dl/doom1.wad tools/mkblob.l out/host/.mksys-cat.l $m
	@echo 'MKBLOB	'$@
	@mkdir -p "$(dir $@)"
	@LOVE_NO_IMAGE= $m -l out/host/.mksys-cat.l tools/mkblob.l $< $@ doom_wad $a
# and the same set on the KART lane, which is where the host's own kernel is
# built (plan C2: the artifact carries it) -- so `make kernel DOOM=1` at $(hosta)
# rides these and the cross odir rides the rows above.
kart_inc += -I$(doom_d)
kart_doom_o = $(patsubst $(doom_d)/%.c,$(moon_d)/kd_%.o,$(doom_c)) \
  $(moon_d)/kd_wad.o $(moon_d)/k_doom.o
kart_o += $(kart_doom_o)
$(moon_d)/kd_%.o: $(doom_d)/%.c $(moon0_dep)
	@echo 'DOOM	'$@
	@mkdir -p "$(dir $@)"
	@$(moon0) $(kart_inc) -c $< $@
$(moon_d)/kd_wad.o: $R/dl/doom1.wad tools/mkblob.l out/host/.mksys-cat.l $(love0)
	@echo 'MKBLOB	'$@
	@mkdir -p "$(dir $@)"
	@LOVE_NO_IMAGE= $(love0) -l out/host/.mksys-cat.l tools/mkblob.l $< $@ doom_wad $(hosta)
endif

$(ho)/love $(ho)/love.cand: $(kart_o)

$(k_odir)/src/core/love.o: out/lib/love_version.h
$(k_odir)/src/core/love.o: kcppflags += -DAiHaveVersionH

klay_l = $R/src/apps/kore/text.l $R/src/apps/kore/u.l $R/src/apps/kore/asbook.l \
  $R/src/core/holo/$a.l $R/src/core/holo/elf.l $R/src/core/holo/obj.l
$(k_odir)/mkvec.l $(k_odir)/mkboot.l: $(k_odir)/%.l: $R/src/inle/%.l $(klay_l)
	@echo 'CAT	'$@
	@mkdir -p "$(dir $@)"
	@{ echo "(use 'holo)"; cat $R/src/apps/kore/text.l $R/src/apps/kore/u.l; \
	   echo "(use 'kore)"; cat $(filter-out $R/src/apps/kore/text.l $R/src/apps/kore/u.l,$(klay_l)) $<; } > $@

$(xd)/love: $(xkart_o)

# `test -s`: an empty object is the failure this build cannot see -- it links, and the
# kernel boots into nothing.
$(k_lay_o) $(k_boot_o): $(k_odir)/$a/%.o: $(k_odir)/mk%.l $m
	@echo 'HOLO	'$@
	@mkdir -p "$(dir $@)"
	@$m -l $< -q -e '(lay-$* "$@" "$a")' && test -s $@

# the machine tail rides the host's own cat (flavour-neutral, one cut for every
# consumer); only the entry names the arch.
$(k_tail_o): out/host/.mksys-cat.l $m
	@echo 'HOLO	'$@
	@mkdir -p "$(dir $@)"
	@$m -l out/host/.mksys-cat.l -q -e "((from 'moon 'mksys-$a) \"$@\")" && test -s $@

k_kvm = $(if $(and $(wildcard /dev/kvm),$(filter x64,$a),$(filter x64,$(hosta))),-enable-kvm -cpu host,)
k_qemu_x64 = -M q35 -serial stdio
k_qemu_a64 = -M virt,gic-version=2 -cpu cortex-a72 -serial stdio -semihosting \
  -device ramfb -device qemu-xhci -device usb-kbd -device usb-mouse
k_qemu_rv64 = -M virt -serial stdio -display none
k_qemu = qemu-system-$(uname_$a) -m 256M $(k_qemu_$a) $(k_kvm)
k_fw = -drive if=pflash,unit=0,format=raw,file=dl/edk2-ovmf/ovmf-code-$(uname_$a).fd,readonly=on

ifeq ($a,x64)
run: run-$a
run-$a: $(ko)/esp-$a/EFI/BOOT/$(k_efiname) $(ko)/esp-$a/love.elf dl/edk2-ovmf/ovmf-code-$(uname_$a).fd
	exec $(k_qemu) $(k_fw) -drive format=raw,file=fat:rw:$(ko)/esp-$a
else
run: run-$a
run-$a: $(k_elf)
	exec $(k_qemu) -kernel $<
endif
# the serial doors: no firmware, nothing downloaded, and a command line.
run-sh: $(k_elf)
	exec $(k_qemu) -kernel $< -append "sh"
run-headless: $(k_elf)
	exec $(k_qemu) -kernel $< -display none -no-reboot

init-container: host
	@command -v unshare >/dev/null || { echo "init-container: needs unshare (util-linux)"; exit 1; }
	@echo "-- love as PID 1 in a pid+user+mount namespace --"
	unshare --pid --fork --mount-proc --user --map-root-user -- $m -l src/apps/init/init.l -e "(pid1 0)"

uefi_l = $R/src/apps/kore/text.l $R/src/apps/kore/u.l $R/src/apps/kore/asbook.l \
  $R/src/core/holo/elf.l $R/src/core/holo/obj.l $R/src/core/holo/link.l $R/src/core/holo/pe.l \
  $R/src/inle/uefi/mkefi.l
# the removable-media path firmware looks for, per arch -- it is the FILENAME that
# picks the loader, so the two ESPs differ in nothing else.
k_efiname_x64 = BOOTX64.EFI
k_efiname_a64 = BOOTAA64.EFI
k_efiname = $(k_efiname_$a)
k_uefid = $(ko)/uefi-$a
k_espd = $(ko)/esp-$a
$(k_uefid)/loader.o: $R/src/inle/uefi/loader.c $(ho)/love.baked
	@echo 'MOON	'$@
	@mkdir -p $(dir $@)
	@$(mooncc) -t $a -c $< $@
$(k_uefid)/$(k_efiname): $(k_uefid)/loader.o $(uefi_l) $m
	@echo 'HOLO	'$@
	@mkdir -p $(dir $@)
	@{ echo "(use 'holo)"; cat $(uefi_l); echo '(mkboot "$@" "$a" (list "$<"))'; } | $m
# the ESP: the loader at that path, and the kernel beside it (the loader opens
# "love.elf" on its own volume).
$(k_espd)/EFI/BOOT/$(k_efiname): $(k_uefid)/$(k_efiname)
$(k_espd)/love.elf: $(ko)/love-$a.elf
$(k_espd)/EFI/BOOT/$(k_efiname) $(k_espd)/love.elf:
	@echo 'CP	'$@
	@mkdir -p $(dir $@)
	@cp $< $@
# the boot line an ESP carries: a firmware door has no -append, so the loader reads
# this file beside love.elf. only the gates ask for one -- `make uefi` ships an ESP
# that comes up in the console shell, which is what a person wants off a usb stick.
$(k_espd)/love.cmd:
	@echo 'CMD	'$@
	@mkdir -p $(dir $@)
	@echo 'test/kernel/all.l' > $@
uefi: $(ko)/esp-$a/EFI/BOOT/$(k_efiname) $(ko)/esp-$a/love.elf
	@echo "uefi: $(ko)/esp-$a is an ESP -- copy it to a FAT32 partition, or"
	@echo "      qemu-system-$(uname_$a) -drive format=raw,file=fat:rw:$(ko)/esp-$a ..."

# --- downloads -------------------------------------------------------
dl/edk2-ovmf/ovmf-code-%.fd:
	@echo 'MK	'ovmf
	@mkdir -p dl
	@curl -L https://github.com/osdev0/edk2-ovmf-nightly/releases/latest/download/edk2-ovmf.tar.gz | gunzip | tar -C dl -xf -
	@case "$a" in \
		a64) dd if=/dev/zero of=$@ bs=1 count=0 seek=67108864 2>/dev/null;; \
	esac
include $(R)/test/test.mk
include $(R)/mk/install.mk

all: host kernel wasm dist

lint: $(ho)/love
	@$(ho)/love $R/src/apps/libra/libra.l $$(git ls-files '*.l') && echo "lint: parens balance"

ccdb: $(ho)/love
	@$(ho)/love $R/tools/ccdb.l

crewtools = $(foreach d,$(wildcard src/apps/*),$(wildcard $d/$(notdir $d).l))
sitetools = $(foreach f,$(crewtools),\
  $(if $(wildcard doc/$(notdir $(basename $f)).md doc/misc/$(notdir $(basename $f)).md),,$f))
out/toolmd.stamp: $(sitetools) src/apps/libra/libra.l $(ho)/love
	@rm -rf out/toolmd && mkdir -p out/toolmd
	@for f in $(sitetools); do n=$${f##*/}; n=$${n%.l}; \
	   { $(ho)/love $R/src/apps/libra/libra.l doc $$f && echo && echo "[the source]($$n.src.html)"; } \
	     > out/toolmd/$$n.md || exit 1; done
	@echo "  toolmd: $(words $(sitetools)) crew headers -> out/toolmd/"
	@touch $@
# the source pages and their stylesheet, written into the site papel just built
huesrc = $(crewtools) src/apps/vi/hue.l src/apps/vi/config.l tools/hue2web.l $(ho)/love
site: host out/toolmd.stamp
	@$(ho)/love -l src/apps/papel/papel.l -t love -o out/site README.md doc out/toolmd
	@$(MAKE) --no-print-directory out/site/hue.css
out/site/hue.css: $(huesrc)
	@env -u LOVE_NO_IMAGE $(ho)/love $R/tools/hue2web.l css > $@
	@for f in $(crewtools); do n=$${f##*/}; n=$${n%.l}; \
	   env -u LOVE_NO_IMAGE $(ho)/love $R/tools/hue2web.l src $$f > out/site/$$n.src.html \
	     || exit 1; done
	@echo "  hue2web: $(words $(crewtools)) sources painted -> out/site/*.src.html"
SITEPORT ?= 8080
site-serve: host out/toolmd.stamp
	@$(ho)/love -l src/apps/papel/papel.l -t love -o out/site -s $(SITEPORT) README.md doc out/toolmd

wasm:
	@$(MAKE) -C src/port/wasm

clean:
	rm -rf out
	@rm -f test/proof/rocq/*.vo test/proof/rocq/*.vok test/proof/rocq/*.vos test/proof/rocq/*.glob test/proof/rocq/.*.aux
	@[ -d src/port/wasm ] && $(MAKE) -C src/port/wasm clean || :
distclean: clean
	rm -rf dl
valg: host
	@cat $t > $(ho)/.valg-corpus.l
	valgrind --error-exitcode=1 --suppressions=$R/tools/valgrind.supp $m $(ho)/.valg-corpus.l </dev/null
.PHONY: ulp
ulp:
	@mkdir -p out/host
	@$(CC) -O2 -o out/host/ulp $R/tools/ulp.c $R/src/apps/moon/lib/math/am.c -lm
	@out/host/ulp
out/host/perf.data: host
	cat $t | perf record -o $@ $m
perf: out/host/perf.data
	exec perf report -i $<
flame: out/host/flamegraph.svg
out/host/flamegraph.svg: out/host/perf.data
	flamegraph -o $@ --perfdata $<
repl: host
	@exec $m
cloc:
	cloc --by-file src tools test
cat: clean all test
cata: clean all test_slow
# full clean rebuild, every frontend, all tests, then the corpus under valgrind
catav: clean all test_slow valg

disasm: host
	exec rizin -A $m
gdb: host
	exec gdb $m

bench: host
	$(MAKE) -C bench bench

