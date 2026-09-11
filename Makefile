R ?= .
include $(R)/common.mk

CCACHE ?= $(shell command -v ccache 2>/dev/null)

ifneq ($(words $(CC)),1)
CCACHE :=
endif

# bootstrap interpreter
love0 = b/love0

.PHONY: all install uninstall clean distclean host kernel wasm love0 lint ulp fonts web \
  site site-serve valg disasm flame cat cata catav perf repl gdb bench cloc

# an unpacked release builds the product; a checkout keeps the fast gate
ifeq ($(in_git),)
.DEFAULT_GOAL := dist
else
.DEFAULT_GOAL := test
endif

# avoid creating empty artifacts with fresh mtime
.DELETE_ON_ERROR:

# love0's boot text: one header, one src0_<name>[] literal per file, laid by sed alone --
# love0 is what runs lcat, so nothing love-made can sit under it. every boot file rides;
# i/main.c names the ones love0 evaluates.
sed_lit = sed \
  -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/^/"/' -e 's/$$/\\n"/'
boot0_l = $(wildcard l/boot/*.l) l/holo/holo.l l/holo/x64.l l/holo/a64.l
b/lib/boot0.h: $(boot0_l)
	@echo '$(t_sed)	'$@
	@mkdir -p b/lib
	@for f in $(boot0_l); do n=$${f##*/}; printf 'static char const src0_%s[] =\n' $${n%.l}; \
	   LOVE_NO_IMAGE= $(sed_lit) $$f || exit 1; echo ';'; done > $@
.PHONY: lib
lib: b/lib/boot0.h b/lib/baked.h
lcat_love = $(love0) -l l/boot/prel.l
# A FORCED WITNESS KEEPS ITS MTIME, and that is the whole point: make cannot depend on a
# variable's VALUE, so a roster change has to be noticed some other way. Depending on the
# Makefile instead was measured at 90 s and 42 targets for a bare `touch Makefile` -- the
# .mooncc-cat.l -> mooncc0.image -> every moon object chain. Do not simplify this away.
note = if cmp -s $$tf $@ 2>/dev/null; then rm -f $$tf; else mv $$tf $@; echo '$(t_sh)	'$@; fi
# every header below is written straight to $@. .DELETE_ON_ERROR (above) takes the
# half-written one away when a generator dies, which is the whole of the guarantee.
# the baked source: one header, one love0 run. u/lcat.l carries the roster -- which
# files, in which blobs, with what glue -- so a roster change edits a file this depends on.
baked_l = $(wildcard l/boot/*.l) l/holo/holo.l l/holo/x64.l l/holo/a64.l l/holo/rv64.l
b/lib/baked.h: $(baked_l) u/lcat.l $(love0)
	@echo 'LOVE	'$@
	@mkdir -p b/lib
	@$(lcat_love) u/lcat.l > $@
# one file as one literal: the ports and t/front paste these in expression position
lib_h = $(patsubst l/boot/%.l,b/lib/%.h,$(wildcard l/boot/*.l))
holo_h = b/lib/holo.h b/lib/x64.h b/lib/a64.h b/lib/rv64.h
$(lib_h): b/lib/%.h: l/boot/%.l u/lcat.l $(love0)
	@echo 'LOVE	'$@
	@mkdir -p b/lib
	@$(lcat_love) u/lcat.l $< > $@
$(holo_h): b/lib/%.h: l/holo/%.l u/lcat.l $(love0)
	@echo 'LOVE	'$@
	@mkdir -p b/lib
	@$(lcat_love) u/lcat.l $< > $@
b/lib/rune.h: a/rune.l u/lcat.l $(love0)
	@echo 'LOVE	'$@
	@mkdir -p b/lib
	@$(lcat_love) u/lcat.l $< > $@
# the seat laws, one text for every board that runs love (i/mps2, i/virt): their
# main.c splices this literal into its driver tail, so the laws are said once.
b/lib/seat.h: i/seat.l u/lcat.l $(love0)
	@echo 'LOVE	'$@
	@mkdir -p b/lib
	@$(lcat_love) u/lcat.l $< > $@
.PHONY: force_corpus_list
force_corpus_list: ;
# love0 reads this at runtime to find the corpus. $t is a glob, so it is written
# every run; only the phony test_love0 wants it, so the moving mtime costs nothing.
b/lib/corpus.list: force_corpus_list
	@mkdir -p b/lib
	@echo '$t' > $@

b/lib/love_version.h: $(R)/VERSION
	@mkdir -p b/lib
	@printf '#define LvVersion "%s"\n' "$$(cat $(R)/VERSION)" > $@
	@echo '$(t_sh)	'$@

b/lib/readme.bin: $(love0) $(R)/l/boot/post.l $(R)/VERSION
	@mkdir -p b/lib
	@printf 'love %s\n' "$$(cat $(R)/VERSION)" > $@
	@$(love0) -h </dev/null >> $@
	@echo 'LOVE	'$@

ho = b$(hsuf)
h_o = $(love_c:$(R)/%.c=$(ho)/%.o)
host_o = $(host_c:$(R)/%.c=$(ho)/%.o)
# the three a LINK names rather than the directory, one per thing it does without:
# i/nokern.c the kernel's doors where no kmain.c stands under them, i/noblob.c the
# carried archives where no laid object brings them, i/noosv.c the OS word where no
# moonlibc writes it. the mooncc lane takes kart_o + b/src.o + b/moonlibc.o and
# wants none of them; the HCC flavour is gcc and glibc alone, so it takes all three.
seat_o = $(ho)/i/nokern.o $(ho)/i/noblob.o $(ho)/i/noosv.o
hcc = LOVE_NO_IMAGE= $(CC) $(ai_cflags) $(GCDBG) -Dai_tco=$(tco) -fpic -I$(ho) -I. -Il -Ii -Ib/lib
image_ldflags = -Wl,--section-start=.love.image=0x2000000
.PHONY: force_hostcc
force_hostcc: ;
$(ho)/.hostcc: force_hostcc
	@mkdir -p $(ho)
	@tf=$@.$$$$.tmp; printf '%s\n' '$(CC) $(image_ldflags)' > $$tf; \
	 $(note)
host: $(ho)/love $(ho)/love.1 $(ho)/cook.1
love0: $(love0)

# the two states of one binary, as two files: the link lays the raw one, and the bake
# writes the artifact beside it. `bake -o` is what lets these be separate targets at all --
# an in-place bake leaves make no file to name, which is what the old .baked stamp stood in for.
$(ho)/love $(ho)/love.cand: $(ho)/%: $(ho)/%.raw $(ho)/.dist-cat.l
	@echo 'BAKE	'$@
	@$< bake -o $@ -l $(ho)/.dist-cat.l

.PHONY: candidate
candidate: $(ho)/love.cand

$(ho)/liblove.a: $(h_o)
	@echo '$(t_ar)	'$@
	@mkdir -p $(dir $@)
	@rm -f $@; ar rcs $@ $^

# pinned to b/0, never $(ho)/0: love0 is one binary whatever HCC and tco say
# love0 takes the whole hosted surface less the crew catalog, PLUS its own seat --
# i/main0.c, which host_c holds back because only this link has a use for it.
love0_o = $(patsubst $(R)/%.c,b/0/%.o,$(filter-out $(R)/i/cats.c,$(host_c)) $(R)/i/main0.c $(R)/i/nokern.c $(R)/i/noblob.c $(R)/i/noosv.c $(love_c))
b/0/i/main0.o: b/lib/boot0.h
b/0/i/cb.o: l/quay/quay.c l/quay/nif.c l/quay/quay.h
boot_cc = $(CCACHE) $(CC) $(ai_cflags) -fPIE -DLove0 -Dai_tco=0 -Dai_data_section=0 -DLvVersion='"$(love_base)+bootstrap"' -I. -Il -Ii -Ib/lib
.PHONY: force_love0cc
force_love0cc: ;
b/0/.love0cc: force_love0cc
	@mkdir -p $(dir $@)
	@tf=$@.$$$$.tmp; printf '%s\n' '$(boot_cc)' > $$tf; \
	 $(note)
b/0/%.o: $(R)/%.c $(love_h) b/0/.love0cc
	@echo '$(t_cc)	'$@
	@mkdir -p $(dir $@)
	@LOVE_NO_IMAGE= $(boot_cc) -c $< -o $@
# l/love.c -> b/*.o
$(ho)/%.o: $(R)/%.c $(love_h) $(ho)/.hostcc
	@echo '$(t_cc)	'$@
	@mkdir -p $(dir $@)
	@$(hcc) -c $< -o $@

# l.o carries the version string; recompile it when the id changes. love0's twin is
# deliberately not here -- see the -DLvVersion note on boot_cc.
# the baked source rides i/cats.c; main.c bakes the dist roster a bare `love bake` reads
$(ho)/i/cats.o: b/lib/baked.h
$(ho)/i/main.o: b/lib/distlist.h
$(ho)/l/love.o: b/lib/love_version.h
# the carried-blob reader both a carried-source bake and the kernel's ram fs decode with
$(ho)/i/main.o $(ho)/i/ustar.o: $(R)/i/ustar.h
# i/cb.c rides the l/quay sources by unity include -- recompile when they move.
$(ho)/i/cb.o: l/quay/quay.c l/quay/nif.c l/quay/quay.h

moon0 = $(love0) wake b/mooncc0.image mooncc $(GCDBG)
moon0_dep = b/mooncc0.image
# A DRIVING LOVE (`love doom` names itself in LOVE): the artifact IS the bootstrap. b/love0
# becomes a two-line script onto it (image awake: every cat a recipe preloads reopens modules
# the image carries, the kernel verb's own shape), its own mooncc is the moon, the mooncc
# image is never baked and no love0 is compiled -- the tree builds with nothing but the
# binary that carried it. lcat runs on it bare: the prel is already there. rtlove is the
# love that runs a moon-side tool (mkrt) either way.
ifdef LOVE
moon0 = $(LOVE) mooncc $(GCDBG)
moon0_dep =
rtlove = $(LOVE)
rtlove_dep =
lcat_love = $(LOVE)
# ..and the tool lane with them: a rule that RUNS a love-written tool (the man pages, the
# fonts, the page) wants a working love, not this tree's. naming one says which, and mdep
# is the prerequisite that goes with it -- there is nothing to wait for.
m = $(LOVE)
mdep =
$(love0):
	@echo '$(t_sh)	'$@
	@mkdir -p $(dir $@)
	@printf '#!/bin/sh\nexec %s "$$@"\n' '$(LOVE)' > $@
	@chmod 755 $@
else
mdep = $(ho)/love
rtlove = $(love0) wake b/mooncc0.image
rtlove_dep = b/mooncc0.image
$(love0): $(love0_o)
	@echo '$(t_ld)	'$@
	@mkdir -p $(dir $@)
	@LOVE_NO_IMAGE= $(CC) $(ai_cflags) -pie -o $@ $(love0_o)
endif
# THE MOONCC OBJECT LANE: love's own C compiled by mooncc into one odir, worn twice -- at
# the host's arch, and at the cross arch $(xa) names. $(call moonlane,NAME,DIRVAR,CCVAR,
# ARCHVAR), every argument but the first a variable NAME so the body stays deferred; the
# kart shape below is the same idiom. Answers $(1)_love_o, _host_o, _math_o and $(1)_o.
# EVERY OBJECT SITS AT ITS SOURCE'S PATH under the odir, as b/0 and $(k_odir) already
# lay theirs. The sets take different flags, so each rule names its own list and the odir
# needs no prefix to keep l/ev.o and i/ev.o apart -- the tree does that.
define moonlane
$(1)_love_o = $$(love_tu_c:$$(R)/%.c=$$($(2))/%.o)
$(1)_host_o = $$(host_c:$$(R)/%.c=$$($(2))/%.o)
$(1)_math_o = $$(patsubst a/moon/lib/moonlibc/%.c,$$($(2))/moonlibc/%.o,$$(wildcard a/moon/lib/moonlibc/math/*.c))
$(1)_o = $$($(1)_love_o) $$($(1)_host_o) $$($(1)_math_o) $$($(2))/sys.o
# ..and the one this lane's own LINK owes: the fixpoint gates relink these objects without
# b/src.o, so they carry i/noblob.c's empty archives instead. deliberately NOT in $(1)_o
# -- the artifact link takes the laid object and would collide.
$(1)_seat_o = $$($(2))/i/noblob.o
$$($(1)_love_o): $$($(2))/%.o: $$(R)/%.c $$(love_h) $$(moon0_dep)
	@echo 'MOON	'$$@
	@mkdir -p $$(dir $$@)
	@$$($(3)) -D ai_tco=$$(tco) -D LvHaveVersionH -I$$(ho) -I. -Il -Ii -Ib/lib -c $$< $$@
$$($(2))/l/love.o: b/lib/love_version.h   # only this TU carries the version id
$$($(1)_host_o) $$($(1)_seat_o): $$($(2))/%.o: $$(R)/%.c $$(love_h) $$(moon0_dep)
	@echo 'MOON	'$$@
	@mkdir -p $$(dir $$@)
	@$$($(3)) -D ai_tco=$$(tco) -I$$(ho) -I. -Il -Ii -Ib/lib -c $$< $$@
$$($(2))/i/main.o: b/lib/distlist.h
$$($(2))/i/cats.o: b/lib/baked.h
$$($(2))/i/cb.o: l/quay/quay.c l/quay/nif.c l/quay/quay.h
$$($(1)_math_o): $$($(2))/moonlibc/%.o: a/moon/lib/moonlibc/%.c $$(moon0_dep)
	@echo 'MOON	'$$@
	@mkdir -p $$(dir $$@)
	@$$($(3)) -Ia/moon/include -c $$< $$@
# the machine tail rides the host's own cat, one cut for every consumer; only the entry
# names the arch.
$$($(2))/sys.o: b/.mksys-cat.l $$(love0)
	@echo 'HOLO	'$$@
	@mkdir -p $$(dir $$@)
	@LOVE_NO_IMAGE= $$(love0) -l b/.mksys-cat.l -q -e "((cite 'moon 'mksys-$$($(4))) \"$$@\")" && test -s $$@
endef

moon_d = $(ho)/moon
$(eval $(call moonlane,moon,moon_d,moon0,hosta))
mksys_l = a/kore/text.l a/kore/u.l a/kore/asbook.l \
          l/holo/x64.l l/holo/a64.l l/holo/rv64.l \
          l/holo/elf.l l/holo/obj.l a/moon/lib/mksys.l
.PHONY: force_dist_list
force_dist_list: ;
b/.mksys-cat.list: force_dist_list
	@mkdir -p $(dir $@)
	@tf=$@.$$$$.tmp; echo '$(mksys_l)' > $$tf; \
	 $(note)
b/.mksys-cat.l: $(mksys_l) b/.mksys-cat.list
	@echo '$(t_cat)	'$@
	@mkdir -p $(dir $@)
	@cat $(mksys_l) > $@
ifneq ($(HCC),)
$(ho)/love.raw $(ho)/love.cand.raw: $(host_o) $(seat_o) $(ho)/liblove.a $(ho)/.hostcc $(R)/l/love_data.ld
	@echo '$(t_ld)	'$@
	@mkdir -p $(dir $@)
	@$(hcc) -o $@ $(host_o) $(seat_o) $(ho)/liblove.a $(image_ldflags) $(data_ld)
else
moonlibc_src = $(wildcard a/moon/lib/moonlibc/*.c a/moon/lib/moonlibc/*.h \
                        a/moon/lib/moonlibc/*/*.c a/moon/lib/moonlibc/*/*.h)
# b/moonlibc.o LEADS: a job pool fills in prerequisite order, and this one is the long pole
# (three ISAs' runtime members, ~30 s cold) -- behind the TU list it starts as they finish
# and runs alone. ahead of them it rides beside them, and -j loses that time outright.
$(ho)/love.raw $(ho)/love.cand.raw: b/moonlibc.o $(moon_o) b/src.o b/lib/readme.bin $(moonlibc_src)
	@echo 'MOON	'$@
	@mkdir -p $(dir $@)
	@$(moon0) -pie $(moon_o) $(kart_o) b/src.o b/moonlibc.o -freadme=b/lib/readme.bin -o $@
endif

$(ho)/love.1 $(ho)/cook.1 $(ho)/lush.1: $(ho)/%.1: doc/%.md u/mkman.l a/lapiz.l b/lib/love_version.h $(mdep)
	@echo 'LOVE	'$@
	@mkdir -p $(dir $@)
	@$m u/mkman.l doc/$*.md b/lib/love_version.h > $@

lushfiles = a/lush.l
# THE CATS, IN PARTS. three rosters cover almost the same ground -- what kore carries,
# what mooncc carries, what the artifact bakes -- and spelling each out in full is how
# the three drift. the parts are named once here; each roster below is the order it
# wants them in, and a new file joins one part rather than three lists.
kore_head = a/kore/text.l a/kore/u.l a/kore/core.l a/kore/fs.l a/kore/sum.l a/kore/re.l \
  a/kore/sed.l a/kore/awk.l a/kore/expr.l a/kore/bc.l a/kore/proc.l a/kore/less.l \
  a/libra/lint.l a/vi/config.l a/vi/hue.l a/vi/core.l a/vi/vi.l \
  a/kore/diff.l a/kore/patch.l a/dns.l a/ain.l $(lushfiles) \
  a/kore/find.l a/cook.l a/kore/asbook.l a/kore/man.l
# the backends: one file per ISA, then the text faces they share
holo_be = l/holo/x64.l l/holo/a64.l l/holo/thumb2.l l/holo/rv64.l \
  l/holo/thumb1.l l/holo/wasm.l l/holo/wasmfn.l l/holo/text.l l/holo/dialect.l
# the object floor every reader of a backend goes out through
holo_obj = l/holo/elf.l l/holo/obj.l l/holo/link.l
# the compiler over them
moon_mid = a/moon/floor.l a/moon/lex.l a/moon/cpp.l a/moon/parse.l \
  a/moon/val.l a/moon/gen.l a/moon/lib/mksys.l a/moon/moon.l
# the tls stack and the multi-call door that ends kore's cat
kore_net = a/tls/bytes.l a/tls/chacha.l a/tls/poly1305.l a/tls/client.l \
  a/kore/wget.l a/kore/kore.l
# the crew the artifact carries past kore and mooncc
crewfiles = a/sb/merge.l a/sb/http.l a/sb/sb.l a/kiosko/kiosko.l \
  a/gz/gz.l a/tar/tar.l a/tar/tarcmd.l a/gz/gzcmd.l a/cpio/cpio.l \
  a/cpio/cpiocmd.l a/fat/fat.l a/fat/fatcmd.l \
  a/source.l a/lapiz.l \
  a/libra/salt.l a/libra/libra.l a/vi/hueweb.l a/kiosko/serve.l \
  a/rove/rove.l a/rove/story.l a/rove/design.l \
  a/lux/wire.l a/doom.l a/lupa.l
korefiles = $(kore_head) $(holo_obj) l/holo/copy.l $(kore_net)
moonfiles = a/kore/text.l a/kore/u.l a/kore/asbook.l $(holo_be) l/holo/gas.l $(holo_obj) $(moon_mid)
$(ho)/.mooncc-cat.list: force_dist_list
	@mkdir -p $(dir $@)
	@tf=$@.$$$$.tmp; echo '$(moonfiles)' > $$tf; \
	 $(note)
$(ho)/.mooncc-cat.l: $(moonfiles) $(ho)/.mooncc-cat.list
	@echo '$(t_cat)	'$@
	@mkdir -p $(dir $@)
	@cat $(moonfiles) > $@
sbfiles = a/kore/text.l a/kore/diff.l a/dns.l a/sb/merge.l a/sb/http.l a/sb/sb.l
# helm the supervisor -- a prototype init, catted the same way. member order is the
# scope: the unit language, the supervisor over it, the socket over that, the driver last.
helmfiles = a/helm/unit.l a/helm/sup.l a/helm/moor.l a/helm/helm.l
$(ho)/sb: $(sbfiles)
$(ho)/lush: $(lushfiles)
$(ho)/helm: $(helmfiles)
$(ho)/sb $(ho)/lush $(ho)/helm:
	@echo '$(t_cat)	'$@
	@mkdir -p $(dir $@)
	@{ echo '#!/usr/bin/env -S love'; cat $^; } > $@
	@chmod 755 $@
b/mooncc0.image: b/.mooncc-cat.l $(love0)
	@echo 'BAKE	'$@
	@$(love0) -l b/.mooncc-cat.l -e '(? ((bake "$@") = 1) (quit 0) (quit 1))'

distfiles = $(kore_head) $(holo_be) l/holo/decode.l l/holo/gas.l \
            $(holo_obj) l/holo/copy.l $(moon_mid) $(kore_net) $(crewfiles)
$(ho)/.dist.list: force_dist_list
	@mkdir -p $(dir $@)
	@tf=$@.$$$$.tmp; echo '$(distfiles)' > $$tf; \
	 $(note)
$(ho)/.dist-cat.l: $(distfiles) $(ho)/.dist.list
	@echo '$(t_cat)	'$@
	@mkdir -p $(dir $@)
	@cat $(distfiles) > $@
b/lib/distlist.h: Makefile
	@mkdir -p b/lib
	@tf=$@.$$$$.tmp; printf '"%s"\n' '$(distfiles)' > $$tf; \
	 $(note)
.PHONY: dist dist-source dist-seed

dist_ver  := $(love_base)
dist_stamp ?= 0
dist_source = b/dist/love-$(dist_ver).tar.gz
dist-source: $(dist_source)
ifneq ($(HCC),)
dist-seed:
	$(error dist: the HCC flavor is a differential, not the artifact -- drop HCC=)
else
dist-seed: $(ho)/love
endif
dist: dist-source dist-seed   # a release is both

# what a release is not: the benches and the board seats. the wasm seat rides -- a
# laid tree serves its own page (`love serve`) -- and the page's generated files are
# .sbignore's to drop, which selfpack reads too. each nom is matched as a path prefix
# at a segment boundary (u/selfpack.l).
dist_drop = bench
.PHONY: force_src
force_src: ;
$(dist_source): force_src $(love0)
	@echo 'LOVE	'$@
	@mkdir -p $(dir $@)
	@LOVE_NO_IMAGE= LOVE_BUDGET_MB=256 $(love0) u/selfpack.l $@ love-$(dist_ver) $(dist_stamp) $(dist_drop)

b/src.o: $(dist_source) u/mksrc.l b/.mksys-cat.l $(love0)
	@echo 'HOLO	'$@
	@$(love0) -l b/.mksys-cat.l u/mksrc.l $(dist_source) $@ $(hosta)

# this roster must cover what mcsrctext walks (a/moon/moon.l): the carried archives are
# stamped with an identity hashed over include/ and lib/ ENTIRE, so a source file the roster
# misses leaves a stamp no link can match, and every link falls to member-compiling.
rt_slice = $(wildcard a/moon/include/*.h a/moon/include/*/*.h \
                      a/moon/lib/*.l a/moon/lib/*.c \
                      a/moon/lib/moonlibc/*.c a/moon/lib/moonlibc/*.h \
                      a/moon/lib/moonlibc/*/*.c a/moon/lib/moonlibc/*/*.h \
                      a/moon/lib/moonlibc/math/*.c)
b/moonlibc.o: $(rt_slice) u/mkrt.l $(rtlove_dep) $(love0)
	@echo 'HOLO	'$@
	@$(rtlove) u/mkrt.l $@ $(hosta)

xqemu_x64  = qemu-x86_64
xqemu_a64 = qemu-aarch64
xqemu_rv64 = qemu-riscv64
xa ?= $(if $(filter a64,$a),x64,a64)
xqemu  = $(xqemu_$(xa))
ifeq ($(filter $(xa),x64 a64 rv64),)
$(error x-lane: no such arch `$(xa)' -- the roster carries x64 a64 rv64)
endif
xd = b/x-$(xa)
moonx = $(moon0) -t $(xa)
$(eval $(call moonlane,x,xd,moonx,xa))

$(xd)/src.o: $(dist_source) u/mksrc.l b/.mksys-cat.l $(love0)
	@echo 'HOLO	'$@
	@$(love0) -l b/.mksys-cat.l u/mksrc.l $(dist_source) $@ $(xa)
$(xd)/moonlibc.o: $(rt_slice) u/mkrt.l $(rtlove_dep) $(love0)
	@echo 'HOLO	'$@
	@$(rtlove) u/mkrt.l $@ $(xa)
$(xd)/love: $(x_o) $(xd)/src.o $(xd)/moonlibc.o b/lib/readme.bin
	@echo 'MOON	'$@
	@$(moonx) -pie $(x_o) $(xkart_o) $(xd)/src.o $(xd)/moonlibc.o -freadme=b/lib/readme.bin -o $@
fat = b/dist/love-fat
.PHONY: dist-fat
dist-fat: $(ho)/love $(xd)/love u/fatpack.l
	@mkdir -p b/dist
	@$(love0) u/fatpack.l $(fat) $a $(ho)/love $(xa) $(xd)/love
	@chmod +x $(fat)

huefiles = a/vi/config.l a/vi/hue.l u/hue2vim.l
$(ho)/syntax.vim: $(huefiles) $(m)
	@echo 'LOVE	'$@
	@mkdir -p $(dir $@); t=$@.$$$$.tmp; \
	  cat $(huefiles) | env -u LOVE_NO_IMAGE $(m) > $$t && test -s $$t && mv -f $$t $@ \
	    || { rm -f $$t; echo "FAIL: $@ empty (hue2vim.l failed)"; exit 1; }
.PHONY: syntax
syntax: $(ho)/syntax.vim
# --- the distro lane --------------------------------------------------------
# the love-native Linux distro: an initramfs where love is /init. The LFS
# toolchain phase is already solved elsewhere (a gcc-free static love, `make test_raw`), so
# a bootable system is just PACKAGING what is green: love as pid 1, kore as the
# busybox-style userland, lush as the console shell.
#
#   make distro-initramfs   -> b/distro/initramfs.cpio.gz
#   make distro-run         -> boot it under qemu on a stock kernel
#
# The kernel stays the one imported artifact (BZIMAGE, default the host's).

# THE CUT IS OURS END TO END NOW -- kore's find, a/cpio/cpio.l and a/gz/gz.l where the
# host's find | cpio | gzip -9 stood. $(mabs) because the pack runs INSIDE a `cd`, and
# $m is spelled relative to the tree root.
mabs         = $(abspath $m)
distro_dir   = b/distro
distro_root  = $(distro_dir)/root
distro_img   = $(distro_dir)/initramfs.cpio.gz
# the base love MUST be static -- a bare initramfs has no ld.so or glibc. love-raw is it:
# gcc-free, our own linker over moonlibc, and 935K against the baked love's ~11M, which is
# what an initramfs wants carried into RAM. `make test_raw` lays it.
distro_love    = $(wildcard b/love-raw)
# kore applets to expose as argv[0] symlinks (kore dispatches on the basename).
distro_applets = ls cat head tail wc sort uniq grep sed awk find cut tr nl rev cp mv rm \
                 mkdir rmdir ln touch pwd chmod basename dirname seq yes true \
                 false env sleep kill xargs diff

# The host kernel is the default imported artifact; override with `make BZIMAGE=...`.
BZIMAGE ?= /boot/vmlinuz-linux

.PHONY: distro-initramfs distro-run distro-smoke
distro-initramfs: $(distro_img)
$(distro_img): a/init/boot.l $(lushfiles) $(korefiles) $(distro_love)
	@test -n "$(distro_love)" || { echo "distro: no b/love-raw -- run 'make test_raw' to lay it"; exit 1; }
	@echo 'LOVE	'$@
	@rm -rf $(distro_root)
	@mkdir -p $(distro_root)/bin $(distro_root)/lib $(distro_root)/proc $(distro_root)/sys $(distro_root)/dev $(distro_root)/tmp $(distro_root)/a
	@cp a/init/boot.l $(distro_root)/init && chmod 755 $(distro_root)/init
	@cp $(distro_love) $(distro_root)/bin/love && chmod 755 $(distro_root)/bin/love
	@cat $(lushfiles) > $(distro_root)/lib/sh.l
# a/dns.l RIDES ALONG OR THE WHOLE TOOLBOX DIES: a/ain.l, a korefiles member,
# probes for the `dial` nif at load and says (borrow 'dns) when it is absent -- which it is
# in love-raw -- and an initramfs with no /a/dns.l answers that with a scare that takes
# the whole cat down. The symptom is every applet gone, not a quiet nc.
	@cp a/dns.l $(distro_root)/a/dns.l
	@{ echo '#!/bin/love'; cat $(korefiles); } > $(distro_root)/bin/kore && chmod 755 $(distro_root)/bin/kore
	@for a in $(distro_applets); do ln -sf kore $(distro_root)/bin/$$a; done
	@ln -sf kore $(distro_root)/bin/sh
	@ln -sf kore $(distro_root)/bin/lush
	@( cd $(distro_root) && $(mabs) kore find . | $(mabs) cpio -o --quiet ) | $(mabs) gzip > $@
	@echo "  packed $$($(mabs) gzip -l $@ | $(mabs) kore awk 'NR==2{print $$2}') bytes -> $@"

# Direct kernel boot, no bootloader: rdinit=/init makes love pid 1. KVM when the host
# offers it -- TCG is too slow to reach the console inside a smoke window.
distro_accel = $(shell test -e /dev/kvm && echo -enable-kvm -cpu host)
# 2G: love reserves a two-space GC heap at startup, so pid1 love PLUS a forked child
# each need one -- 512M overflows (execve -> ENOMEM). Override with QMEM=.
QMEM ?= 2048
distro_qemu = qemu-system-x86_64 -m $(QMEM) $(distro_accel) -kernel $(BZIMAGE) -initrd $(distro_img) \
              -append "console=ttyS0 earlyprintk=serial,ttyS0 rdinit=/init panic=-1" \
              -serial stdio -display none -no-reboot
distro-run: $(distro_img)
	@test -r "$(BZIMAGE)" || { echo "distro-run: no kernel at $(BZIMAGE) -- set BZIMAGE=..."; exit 1; }
	exec $(distro_qemu)

# Non-interactive smoke: boot, feed `ls /proc` to the console, prove love came up as pid 1
# with /proc mounted and the kore userland running, then kill qemu. the trailing sleep
# holds stdin open, keeping the shell out of an EOF-respawn loop.
distro-smoke: $(distro_img)
	@test -r "$(BZIMAGE)" || { echo "distro-smoke: no kernel at $(BZIMAGE)"; exit 1; }
	@echo "-- booting (10s capture) --"
	@( printf 'ls /proc\n'; sleep 8 ) | timeout 10 $(distro_qemu) 2>/dev/null | tee $(distro_dir)/boot.log || true
	@echo "-- checks --"
	@grep -q "love as PID 1" $(distro_dir)/boot.log && echo "  OK love is pid 1" || { echo "  FAIL not pid 1"; exit 1; }
	@grep -q "mount proc on /proc -> ok" $(distro_dir)/boot.log && echo "  OK /proc mounted" || { echo "  FAIL /proc"; exit 1; }
	@grep -q "start the console shell" $(distro_dir)/boot.log && echo "  OK reached shell handoff" || { echo "  FAIL no shell"; exit 1; }
	@grep -qE "kore ls /proc -> exit 0, [1-9]" $(distro_dir)/boot.log && echo "  OK kore userland runs (ls /proc, forked+captured)" || { echo "  FAIL userland self-check"; exit 1; }
	@echo "-- distro smoke passed --"

ko = b

# the kernel's verbs; its gates are t/test.mk's.
.PHONY: kmain_o run run-$a run-sh run-headless init-container uefi

# love's own mooncc, and the artifact that answers it. the compiler IS the shipped
# binary, so nothing foreign builds the kernel and there is no second cc to name.
# LOVE_NO_IMAGE= leads: an egg-booted love has no verbs.
mooncc = LOVE_NO_IMAGE= $m mooncc
mooncc_dep = $(mdep)

# this machine's metal files, and the three TUs only a kernel has a frontend for.
k_arch_c = $(wildcard $(R)/i/$a/*.c)
k_free_c = $R/i/kmain.c $R/i/blk.c $R/i/hda.c $R/i/sys.c
# the whole kernel compile, in link order: the runtime and its math floor, the console
# engine with its two fonts, moonlibc, the metal, the free trio -- and $(host_c) itself,
# because the kernel runs the same frontend the host does. taking that roster rather than
# copying it is what lets a new i/<app>.c reach the kernel with no rule edit.
k_c = $(love_c) \
  $R/l/quay/cga_8x8.c $R/l/quay/moderndos_8x16.c $R/l/quay/paint.c \
  $(c_c) $(k_arch_c) $(k_free_c) $(host_c)
k_h = $(love_h) $(R)/i/k.h $(R)/i/ustar.h $(wildcard $(R)/i/$a/*.h)

k_odir = $(ko)/$a
k_elf = $(ko)/love-$a.elf
k_pie = $(k_odir)/love.pie

# the lays and the machine tail live under $(k_odir)/$a/ so vec.o and sys.o do not
# collide with the core objects of the same name.
k_lay_o = $(k_odir)/$a/vec.o
k_boot_o = $(k_odir)/$a/boot.o
k_tail_o = $(k_odir)/$a/sys.o
# $(k_free_o) alone is named apart: `make kmain_o` is the ports' door to it.
k_free_o = $(k_free_c:$(R)/%.c=$(k_odir)/%.o)
k_o = $(k_c:$(R)/%.c=$(k_odir)/%.o) $(k_lay_o) $(k_tail_o) \
  $(k_odir)/moonlibc.o $(k_odir)/src.o $(k_doom_o)

kcppflags := \
  -I$(k_odir) \
  -I. -Il -Ii -Ib/lib -I$(R)/l/quay -I$(R) \
  -I$(R)/a/moon/include \
  $(kcppflags)
kcc = $(mooncc) $(kcppflags) -t $a

kernel: $(k_elf)

$(k_odir)/i/cb.o: l/quay/quay.c l/quay/nif.c l/quay/quay.h
$(k_odir)/moonlibc.o: $(rt_slice) u/mkrt.l $m
	@echo 'HOLO	'$@
	@mkdir -p "$(dir $@)"
	@$m u/mkrt.l $@ $a
$(k_odir)/src.o: $(dist_source) u/mksrc.l b/.mksys-cat.l $m
	@echo 'HOLO	'$@
	@mkdir -p "$(dir $@)"
	@LOVE_NO_IMAGE= $m -l b/.mksys-cat.l u/mksrc.l $(dist_source) $@ $a
$(k_pie): $(k_o) $m
	@echo 'MOON	'$@
	@mkdir -p "$(dir $@)"
	@$(mooncc) -pie -t $a $(k_o) -o $@
kproject_l = $R/a/kore/text.l $R/a/kore/u.l $R/a/kore/asbook.l \
  $R/l/holo/elf.l $R/l/holo/obj.l $R/l/holo/link.l $R/u/kproject.l
$(k_odir)/kproject.list: force_dist_list
	@mkdir -p "$(dir $@)"
	@tf=$@.$$$$.tmp; echo '$(kproject_l)' > $$tf; \
	 $(note)
$(k_odir)/kproject.l: $(kproject_l) $(k_odir)/kproject.list
	@echo '$(t_cat)	'$@
	@mkdir -p "$(dir $@)"
	@{ echo "(borrow 'holo)"; cat $R/a/kore/text.l $R/a/kore/u.l; \
	   echo "(borrow 'kore)"; cat $(filter-out $R/a/kore/text.l $R/a/kore/u.l,$(kproject_l)); } > $@

# at the host's own arch there is no second kernel build: $(kart_o) is linked into the
# shipped love already, so the elf is projected out of that binary, and it WAKES the
# image the binary carries. $(k_pie) is the other lane -- a machine this one cannot
# run, built from source, which carries no image and WARMS the egg instead. one gate
# apiece: test_disk rides the projection, test_kernel_a64 the pie.
k_pie_in = $(k_pie)
k_pie_dep =
ifeq ($a,$(hosta))
k_pie_in = $(ho)/love
k_pie_dep = $(mooncc_dep)
endif
$(k_elf): $(k_odir)/kproject.l $(k_pie_in) $(k_pie_dep) $(k_boot_o) $m
	@echo 'HOLO	'$@
	@mkdir -p "$(dir $@)"
	@$m $(k_odir)/kproject.l $(k_pie_in) $(k_boot_o) $@ $a && test -s $@

b/lib/korelist.h: Makefile
	@mkdir -p b/lib
	@tf=$@.$$$$.tmp; printf '"%s"\n' '$(korefiles)' > $$tf; \
	 $(note)

# the crew roster, the same one line: these files are NOT in the kernel's cat, so the
# order is all the kernel carries and the members come off /proc/src when a verb is asked
# for. one line, because a name does not say which file holds it -- story lives in
# a/rove/, xwire in a/lux/wire.l, and sb spans three that must load in order.
b/lib/crewlist.h: Makefile
	@mkdir -p b/lib
	@tf=$@.$$$$.tmp; printf '"%s"\n' '$(crewfiles)' > $$tf; \
	 $(note)

# every $(k_c) source, wherever in the tree it lives, lands under $(k_odir) by its path.
$(k_odir)/%.o: $(R)/%.c $(k_h) $(mooncc_dep) b/lib/baked.h b/lib/distlist.h b/lib/korelist.h b/lib/crewlist.h
	@echo 'MOON	'$@
	@mkdir -p "$(dir $@)"
	@$(kcc) -c $< -o $@

# kmain_o -- the kernel frontend, COMPILED AND NOTHING MORE, at whatever arch the caller's
# `a=` says; the odir is spelled here so a caller never re-derives it.
kmain_o: $(k_free_o)

# THE CARRIED SEAT: the metal objects the one binary links, so `love kernel` projects a
# bootable elf out of the running artifact instead of building a second one. one shape,
# worn once per machine -- $(call kart,ROSTER,DIRVAR,CCVAR,ARCHVAR), every argument but
# the first a variable NAME so the body stays deferred. an arch with no i/<arch>/
# carries no seat and its roster is empty.
kart_inc = -I$(ho) -I. -Il -Ii -Ib/lib -I$R \
  -I$R/l/quay -I$R/a/moon/include
# kmain.c's own bake is the two ROSTERS now -- the kore cat's order, and the crew's, which
# it carries the order of and reads the members of off /proc/src. the egg and the module set
# are i/cats.c's, and that object rides the host lane above.
kart_bake = b/lib/korelist.h b/lib/crewlist.h
define kart
$(1)_h = $$(love_h) $$R/i/k.h $$R/i/ustar.h $$(wildcard $$R/i/$$($(4))/*.h)
$(1)_arch_o = $$(patsubst $$R/%.c,$$($(2))/%.o,$$(wildcard $$R/i/$$($(4))/*.c))
# the console's painter and its fonts: kernel-only draws the host link never had
$(1)_quay_o = $$(patsubst %,$$($(2))/l/quay/%.o,paint cga_8x8 moderndos_8x16)
$(1)_kern_o = $$(k_free_c:$$R/%.c=$$($(2))/%.o)
$(1)_o = $$(if $$($(1)_arch_o),$$($(1)_kern_o) \
  $$($(1)_arch_o) $$($(1)_quay_o) $$($(2))/kvec.o,)
$(1)_lay_l = $$R/a/kore/text.l $$R/a/kore/u.l $$R/a/kore/asbook.l \
  $$R/l/holo/$$($(4)).l $$R/l/holo/elf.l $$R/l/holo/obj.l
# the kernel-only trio, the per-ISA seat and the console draws take one flag set and
# one rule -- named lists, so the frontend's own i/*.o rule above cannot claim them.
$$($(1)_kern_o) $$($(1)_arch_o) $$($(1)_quay_o): $$($(2))/%.o: $$R/%.c $$($(1)_h) $$(kart_bake) $$(moon0_dep)
	@echo 'MOON	'$$@
	@mkdir -p "$$(dir $$@)"
	@$$($(3)) $$(kart_inc) -c $$< $$@
$$($(2))/mkvec.l: $$R/i/mkvec.l $$($(1)_lay_l)
	@echo '$(t_cat)	'$$@
	@mkdir -p "$$(dir $$@)"
	@{ echo "(borrow 'holo)"; cat $$R/a/kore/text.l $$R/a/kore/u.l; \
	   echo "(borrow 'kore)"; cat $$(filter-out $$R/a/kore/text.l $$R/a/kore/u.l,$$($(1)_lay_l)) $$<; } > $$@
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
k_free_c += $R/i/doom.c $R/i/doomsnd.c
kcppflags += -I$(doom_d) -I$R/i/doom -DFEATURE_SOUND
$(k_odir)/doom/%.o: $(doom_d)/%.c $(mooncc_dep)
	@echo 'DOOM	'$@
	@mkdir -p "$(dir $@)"
	@$(kcc) -c $< -o $@
$(k_odir)/doom/wad.o: $R/dl/doom1.wad u/mkblob.l b/.mksys-cat.l $m
	@echo 'HOLO	'$@
	@mkdir -p "$(dir $@)"
	@LOVE_NO_IMAGE= $m -l b/.mksys-cat.l u/mkblob.l $< $@ doom_wad $a
# and the same set on the KART lane, which is where the host's own kernel is
# built (plan C2: the artifact carries it) -- so `make kernel DOOM=1` at $(hosta)
# rides these and the cross odir rides the rows above.
kart_inc += -I$(doom_d) -I$R/i/doom -DFEATURE_SOUND
kart_doom_o = $(patsubst $(doom_d)/%.c,$(moon_d)/doom/%.o,$(doom_c)) \
  $(moon_d)/doom/wad.o
kart_o += $(kart_doom_o)
$(moon_d)/doom/%.o: $(doom_d)/%.c $(moon0_dep)
	@echo 'DOOM	'$@
	@mkdir -p "$(dir $@)"
	@$(moon0) $(kart_inc) -c $< $@
$(moon_d)/doom/wad.o: $R/dl/doom1.wad u/mkblob.l b/.mksys-cat.l $(love0)
	@echo 'HOLO	'$@
	@mkdir -p "$(dir $@)"
	@LOVE_NO_IMAGE= $(love0) -l b/.mksys-cat.l u/mkblob.l $< $@ doom_wad $(hosta)
endif

$(ho)/love.raw $(ho)/love.cand.raw: $(kart_o) b/.doom.flag

# the DOOM flag is a link input no timestamp can see: a witness that changes with it, so
# `make host DOOM=1` after a plain `make host` relinks (and the other way round)
b/.doom.flag: force_dist_list
	@mkdir -p b
	@tf=$@.$$$$.tmp; echo 'DOOM=$(DOOM)' > $$tf; \
	 $(note)

$(k_odir)/l/love.o: b/lib/love_version.h
$(k_odir)/l/love.o: kcppflags += -DLvHaveVersionH

klay_l = $R/a/kore/text.l $R/a/kore/u.l $R/a/kore/asbook.l \
  $R/l/holo/$a.l $R/l/holo/elf.l $R/l/holo/obj.l
$(k_odir)/mkvec.l $(k_odir)/mkboot.l: $(k_odir)/%.l: $R/i/%.l $(klay_l)
	@echo '$(t_cat)	'$@
	@mkdir -p "$(dir $@)"
	@{ echo "(borrow 'holo)"; cat $R/a/kore/text.l $R/a/kore/u.l; \
	   echo "(borrow 'kore)"; cat $(filter-out $R/a/kore/text.l $R/a/kore/u.l,$(klay_l)) $<; } > $@

$(xd)/love: $(xkart_o)

# `test -s`: an empty object is the failure this build cannot see -- it links, and the
# kernel boots into nothing.
$(k_lay_o) $(k_boot_o): $(k_odir)/$a/%.o: $(k_odir)/mk%.l $m
	@echo 'HOLO	'$@
	@mkdir -p "$(dir $@)"
	@$m -l $< -q -e '(lay-$* "$@" "$a")' && test -s $@

# the machine tail rides the host's own cat (flavour-neutral, one cut for every
# consumer); only the entry names the arch.
$(k_tail_o): b/.mksys-cat.l $m
	@echo 'HOLO	'$@
	@mkdir -p "$(dir $@)"
	@$m -l b/.mksys-cat.l -q -e "((cite 'moon 'mksys-$a) \"$@\")" && test -s $@

k_kvm = $(if $(and $(wildcard /dev/kvm),$(filter x64,$a),$(filter x64,$(hosta))),-enable-kvm -cpu host,)
# the sound card: an HDA controller with one output codec, on the host's own audio.
# QAUDIO names qemu's backend (`qemu-system-x86_64 -audiodev help`); none is silent.
QAUDIO ?= pipewire
k_qemu_x64 = -M q35 -serial stdio -device intel-hda -device hda-output,audiodev=snd \
  -audiodev $(QAUDIO),id=snd
k_qemu_a64 = -M virt,gic-version=2 -cpu cortex-a72 -serial stdio -semihosting \
  -device ramfb -device qemu-xhci -device usb-kbd -device usb-mouse
k_qemu_rv64 = -M virt -serial stdio -display none
k_qemu = qemu-system-$(uname_$a) -m 256M $(k_qemu_$a) $(k_kvm)
k_fw = -drive if=pflash,unit=0,format=raw,file=dl/edk2-ovmf/ovmf-code-$(uname_$a).fd,readonly=on

# the emulator is asked for FIRST: a missing qemu refuses before the kernel is built, not
# after. a prerequisite, so every run door shares the one question.
.PHONY: qemu-present
qemu-present:
	@command -v qemu-system-$(uname_$a) >/dev/null 2>&1 || \
	  { echo "run: needs qemu-system-$(uname_$a) on PATH"; exit 1; }
ifeq ($a,x64)
run: run-$a
run-$a: qemu-present $(ko)/esp-$a/EFI/BOOT/$(k_efiname) $(ko)/esp-$a/love.elf dl/edk2-ovmf/ovmf-code-$(uname_$a).fd
	exec $(k_qemu) $(k_fw) -drive format=raw,file=fat:rw:$(ko)/esp-$a
else
run: run-$a
run-$a: qemu-present $(k_elf)
	exec $(k_qemu) -kernel $<
endif
# the serial doors: no firmware, nothing downloaded, and a command line.
run-sh: qemu-present $(k_elf)
	exec $(k_qemu) -kernel $< -append "sh"
run-headless: qemu-present $(k_elf)
	exec $(k_qemu) -kernel $< -display none -no-reboot

init-container: host
	@command -v unshare >/dev/null || { echo "init-container: needs unshare (util-linux)"; exit 1; }
	@echo "-- love as PID 1 in a pid+user+mount namespace --"
	unshare --pid --fork --mount-proc --user --map-root-user -- $m -l a/init/init.l -e "(pid1 0)"

uefi_l = $R/a/kore/text.l $R/a/kore/u.l $R/a/kore/asbook.l \
  $R/l/holo/elf.l $R/l/holo/obj.l $R/l/holo/link.l $R/l/holo/pe.l \
  $R/i/uefi/mkefi.l
# the removable-media path firmware looks for, per arch -- it is the FILENAME that
# picks the loader, so the two ESPs differ in nothing else.
k_efiname_x64 = BOOTX64.EFI
k_efiname_a64 = BOOTAA64.EFI
k_efiname = $(k_efiname_$a)
k_uefid = $(ko)/uefi-$a
k_espd = $(ko)/esp-$a
$(k_uefid)/loader.o: $R/i/uefi/loader.c $(ho)/love
	@echo 'MOON	'$@
	@mkdir -p $(dir $@)
	@$(mooncc) -t $a -c $< $@
$(k_uefid)/$(k_efiname): $(k_uefid)/loader.o $(uefi_l) $m
	@echo 'LOVE	'$@
	@mkdir -p $(dir $@)
	@{ echo "(borrow 'holo)"; cat $(uefi_l); echo '(mkboot "$@" "$a" (list "$<"))'; } | $m
# the ESP: the loader at that path, and the kernel beside it (the loader opens
# "love.elf" on its own volume).
$(k_espd)/EFI/BOOT/$(k_efiname): $(k_uefid)/$(k_efiname)
$(k_espd)/love.elf: $(ko)/love-$a.elf
$(k_espd)/EFI/BOOT/$(k_efiname) $(k_espd)/love.elf:
	@echo '$(t_cp)	'$@
	@mkdir -p $(dir $@)
	@cp $< $@
# the boot line an ESP carries: a firmware door has no -append, so the loader reads
# this file beside love.elf. only the gates ask for one -- `make uefi` ships an ESP
# that comes up in the console shell, which is what a person wants off a usb stick.
$(k_espd)/love.cmd:
	@echo '$(t_sh)	'$@
	@mkdir -p $(dir $@)
	@echo 't/kernel/all.l' > $@
uefi: $(ko)/esp-$a/EFI/BOOT/$(k_efiname) $(ko)/esp-$a/love.elf
	@echo "uefi: $(ko)/esp-$a is an ESP -- copy it to a FAT32 partition, or"
	@echo "      qemu-system-$(uname_$a) -drive format=raw,file=fat:rw:$(ko)/esp-$a ..."

# --- downloads -------------------------------------------------------
dl/edk2-ovmf/ovmf-code-%.fd:
	@echo 'CURL	'$@
	@mkdir -p dl
	@curl -L https://github.com/osdev0/edk2-ovmf-nightly/releases/lat/download/edk2-ovmf.tar.gz | gunzip | tar -C dl -xf -
	@case "$a" in \
		a64) dd if=/dev/zero of=$@ bs=1 count=0 seek=67108864 2>/dev/null;; \
	esac
include $(R)/t/test.mk
#
# THE NEST: the default install is ~/.love, a self-implying home, and what lands in it
# is the BINARY and the things a person reads -- man pages and the vim files. nothing
# else needs to: the loader resolves modules out of the baked image (the modules arc,
# rung 3) and mooncc carries its own headers and runtime (the bare cc door), so a nest
# holding copies of either would be serving nobody.
# ~/.local/bin gets a compat SYMLINK per bin, since PATH already knows it.

# --- install / uninstall --------------------------------------------
PREFIX ?= .love/
VIMPREFIX ?= .vim/
DESTDIR ?= $(HOME)/
# BIN -- the name the interpreter installs under, and the ONE knob for the LÖVE collision
# (Arch's extra/love owns /usr/bin/love and man1/love.1 outright). Nothing below hardcodes
# the command name, so `make install BIN=lovelang` moves the binary, both shims, every
# shebang and the man page together. the PROJECT is still love: lib/love/, liblove,
# l/love.h and l/boot/*.l keep the name -- data paths, not PATH entries.
BIN ?= love
BINUP = $(shell echo '$(BIN)' | tr '[:lower:]' '[:upper:]')
d = $(DESTDIR)/$(PREFIX)
v = $(DESTDIR)/$(VIMPREFIX)

# A shebang-carrying source tool installs as a SYMLINK to the source under the default
# name, so edits land without a reinstall. Under a renamed BIN its own
# `#!/usr/bin/env -S love -l` would re-exec the wrong interpreter, so it installs as a COPY
# with line 1 rewritten -- which is what a package wants anyway. The pattern matches both
# shebang forms, leaving a trailing ` -l` alone.
# the sed these recipes spawn is OURS: kore is the installed binary's own verb now
# (the layered bake). LOVE_NO_IMAGE= (empty = UNSET) leads,
# for $(hcc)'s reason: the root exports it=1 for the corpus, and an egg-booted love has
# no verbs -- `kore` would read as a filename.
korecmd = LOVE_NO_IMAGE= $(ho)/love kore
ifeq ($(BIN),love)
# the chmod repairs the target when the source came through svalbard, which does not carry
# the executable bit -- without it the link resolves to a 644 file and every exec EACCESes.
instool = ln -sf $(abspath $1) $2 && chmod 755 $(abspath $1)
instag = LN
else
instool = $(korecmd) sed '1s|env -S love|env -S $(BIN)|' $1 > $2 && chmod 755 $2
instag = CP
endif

# ONE roster each: the compat-symlink block below reads the same two names, and two
# spellings of a list is how they drift.
binnames = $(BIN) kore sb mooncc cook papel kiosko libra ain lux bao lush
mannames = $(BIN) cook lush
installs = $(patsubst %,$d/bin/%,$(binnames)) \
  $(patsubst %,$d/share/man/man1/%.1,$(mannames)) \
  $v/ftdetect/love.vim $v/syntax/love.vim $v/ftplugin/love.vim

# the plain data install, spelled once -- a dozen rules below wear it.
inst644 = @echo '$(t_cp)	'$(abspath $@); install -D -m 644 $< $@

# the PATH door, nest-only: each bin and man page gets a ~/.local compat symlink, since
# those are already on PATH and manpath. A real PREFIX (a distro) skips them.
ifeq ($(PREFIX),.love/)
compat = $(DESTDIR)/.local
installs += $(patsubst %,$(compat)/bin/%,$(binnames)) \
  $(patsubst %,$(compat)/share/man/man1/%.1,$(mannames))
inln = @echo '$(t_ln)	'$(abspath $@); mkdir -p $(@D); ln -sf $(abspath $<) $@
$(compat)/bin/%: $d/bin/%
	$(inln)
$(compat)/share/man/man1/%.1: $d/share/man/man1/%.1
	$(inln)
endif

install: $(installs)
uninstall:
	@echo '$(t_rm)	'$(abspath $(installs))
	@rm -f $(installs)

# UNSTRIPPED deliberately: stripping drops the symbol table holo lays on purpose, for ~2%
# of a baked binary. binutils strip IS safe on our ELF (every loaded byte has a covering
# section header), so a user who wants it smaller can strip their own.
$d/bin/$(BIN): $(ho)/love
	@echo '$(t_cp)	'$(abspath $@)
	@install -D -m 755 $< $@
# the boot image travels INSIDE the binary (.image is an allocated PROGBITS section, the
# layered crew chain riding it), so the plain-copy install keeps the warm wake and every verb.

# the single-file shebang tools, one shape: the `#!/usr/bin/env -S love -l` line re-execs
# the installed interpreter, and each file's own SEAT fires on its name. papel and libra
# READ their siblings rather than being -l'd beside them -- two tool files cannot both be
# -l'd, since each one's seat would fire on the other's command line -- and they find them
# by READLINK'ing this very symlink back to the source tree, so the link on PATH and the
# crew directory need not be neighbours. libra's siblings are named ((borrow 'lint),
# (borrow 'salt), and (borrow 'lapiz) on the doc verb alone) and ride the baked image.
# each source sits FIRST on its own line: instool reads $<, and a prerequisite added on
# the grouped line below lands ahead of it -- which installs the kore shim as `cook`.
$d/bin/cook:    a/cook.l    $(ho)/love
$d/bin/papel:   a/papel.l  $(ho)/love
$d/bin/kiosko:  a/kiosko/kiosko.l $(ho)/love
$d/bin/libra:   a/libra/libra.l  $(ho)/love
$d/bin/cook $d/bin/papel $d/bin/kiosko $d/bin/libra:
	@echo $(instag)	$(abspath $@)
	@mkdir -p $(@D)
	@$(call instool,$<,$@)

# ain, the netcat clone: the same shebang mechanism, but installed as a COPY rather than a
# symlink, so it takes the rewrite unconditionally. At the default BIN the substitution is
# an identity and the bytes are unchanged.
$d/bin/ain: a/ain.l $(ho)/love
	@echo '$(t_cp)	'$(abspath $@)
	@install -d $(@D)
	@$(korecmd) sed '1s|env -S love|env -S $(BIN)|' $< > $@
	@chmod 755 $@

# kore, the multi-call toolbox: the util picked off the command line or off argv[0] through
# a tool-named symlink. It shadows nothing here -- only `kore` lands on PATH, and the distro
# symlinks the tool names where shadowing is the point.
# A VERB SHIM: the installed binary carries the crew in its own layered image, so
# there is no sibling image and no wake spelling -- the
# picker wakes the crew layer off the `kore` verb, same warm start as ever.
# `n` comes off $0 UNCHASED where `h` is the chased path: a tool symlink must arrive as its
# own name for the argv[0] door, and only the real file's dir has the $(BIN) sibling.
$d/bin/kore: $(MAKEFILE_LIST)
	@echo '$(t_cat)	'$(abspath $@)
	@install -d $(dir $@)
	@{ echo '#!/bin/sh'; \
	   echo 'h=$$(CDPATH= cd -- "$$(dirname -- "$$(readlink -f -- "$$0")")" && pwd)'; \
	   echo 'n=$$(basename -- "$$0")'; \
	   echo 'case "$$n" in kore) LOVE_NO_IMAGE= exec "$$h/$(BIN)" kore "$$@";; *) LOVE_NO_IMAGE= exec "$$h/$(BIN)" kore "$$n" "$$@";; esac'; } > $@
	@chmod 755 $@

# sb 🌱 and lush 🐚, each its own catted script: their sources carry no shebangs, so the
# interpreter line then a plain cat. Each SEAT fires on the installed name -- lush's on its
# basename, so `sh` through a symlink lands too.
$d/bin/sb: $(sbfiles)
$d/bin/lush: $(lushfiles)
$d/bin/sb $d/bin/lush:
	@echo '$(t_cat)	'$(abspath $@)
	@install -d $(dir $@)
	@{ echo '#!/usr/bin/env -S $(BIN)'; cat $^; } > $@
	@chmod 755 $@

# mooncc: the same verb-shim shape -- the compiler is the installed binary's own verb,
# its layer woken by the picker (~ms, the whole-cat re-eval long gone). the home comes
# off the CHASED path (readlink -f): invoked through a ~/.local compat symlink, $0's own
# dir has no $(BIN) sibling -- the nest does.
$d/bin/mooncc: $(MAKEFILE_LIST)
	@echo '$(t_cat)	'$(abspath $@)
	@install -d $(dir $@)
	@{ echo '#!/bin/sh'; \
	   echo 'h=$$(CDPATH= cd -- "$$(dirname -- "$$(readlink -f -- "$$0")")" && pwd)'; \
	   echo 'LOVE_NO_IMAGE= exec "$$h/$(BIN)" mooncc "$$@"'; } > $@
	@chmod 755 $@

# lux, the window manager: its modules catted into one shebang script. Settings ride salt
# (~/.love/etc/lux.l then ./.lux.l), which also names the display and the cookie when
# DISPLAY/XAUTHORITY will not do; mod+q restarts in place by exec'ing this script.
luxfiles = a/lux/core.l a/lux/layout.l a/lux/wire.l a/lux/ewmh.l a/lux/manage.l a/lux/keys.l a/lux/config.l a/lux/lux.l
$d/bin/lux: $(luxfiles)
	@echo '$(t_cat)	'$(abspath $@)
	@install -d $(dir $@)
	@{ echo '#!/usr/bin/env -S $(BIN) -l'; cat $(luxfiles); } > $@
	@chmod 755 $@

# bao, the interactive shell. Unlike cook and ain, l/boot/post.l is DEFINE-ONLY -- main.c
# fires `(shell 0)` on a tty -- so the bin is a tiny launcher that fires it. the module
# rides the binary, so there is nothing to -l and no nest path to get wrong.
$d/bin/bao: $(MAKEFILE_LIST)
	@echo '$(t_cat)	'$(abspath $@)
	@install -d $(dir $@)
	@{ echo '#!/bin/sh'; \
	   echo 'h=$$(CDPATH= cd -- "$$(dirname -- "$$(readlink -f -- "$$0")")" && pwd)'; \
	   echo 'exec "$$h/$(BIN)" -e "((cite '\''cli '\''shell) 0)" "$$@"'; } > $@
	@chmod 755 $@

# the .TH command name follows BIN too (`man lovelang` should not head LOVE(1));
# the other `love`s on that line are the PROJECT and the version string, so they stay.
$d/share/man/man1/$(BIN).1: $(ho)/love.1 $(ho)/love
	@echo '$(t_cp)	'$(abspath $@)
	@install -d $(@D)
	@$(korecmd) sed '1s|"LOVE"|"$(BINUP)"|' $< > $@
	@chmod 644 $@

# the man pages BIN does not rename, and the two hand-written vim files. static
# patterns: an implicit rule would make these intermediate.
$d/share/man/man1/cook.1 $d/share/man/man1/lush.1: $d/share/man/man1/%.1: $(ho)/%.1
	$(inst644)
$v/ftdetect/love.vim $v/ftplugin/love.vim: $v/%/love.vim: vim/%.vim
	$(inst644)
# the syntax is GENERATED (the Makefile) out of a/vi/hue.l's class table and the
# vocabulary this host answers to, so it is installed from b/ like any other artifact.
$v/syntax/love.vim: $(ho)/syntax.vim
	$(inst644)

all: host kernel wasm dist

lint: $(mdep)
	@$m $R/a/libra/libra.l $$(git ls-files '*.l') && echo "lint: parens balance"


crewtools = $(wildcard a/*.l) $(foreach d,$(wildcard a/*),$(wildcard $d/$(notdir $d).l))
sitetools = $(foreach f,$(crewtools),\
  $(if $(wildcard doc/$(notdir $(basename $f)).md doc/misc/$(notdir $(basename $f)).md),,$f))
b/toolmd.stamp: $(sitetools) a/libra/libra.l $(mdep)
	@rm -rf b/toolmd && mkdir -p b/toolmd
	@for f in $(sitetools); do n=$${f##*/}; n=$${n%.l}; \
	   { $m $R/a/libra/libra.l doc $$f && echo && echo "[the source]($$n.src.html)"; } \
	     > b/toolmd/$$n.md || exit 1; done
	@echo "  toolmd: $(words $(sitetools)) crew headers -> b/toolmd/"
	@touch $@
# the source pages and their stylesheet, written into the site papel just built
huesrc = $(crewtools) a/vi/hue.l a/vi/config.l u/hue2web.l $(ho)/love
site: host b/toolmd.stamp
	@$(ho)/love -l a/papel.l -t love -o b/site README.md doc b/toolmd
	@$(MAKE) --no-print-directory b/site/hue.css
b/site/hue.css: $(huesrc)
	@env -u LOVE_NO_IMAGE $(ho)/love $R/u/hue2web.l css > $@
	@for f in $(crewtools); do n=$${f##*/}; n=$${n%.l}; \
	   env -u LOVE_NO_IMAGE $(ho)/love $R/u/hue2web.l src $$f > b/site/$$n.src.html \
	     || exit 1; done
	@echo "  hue2web: $(words $(crewtools)) sources painted -> b/site/*.src.html"
SITEPORT ?= 8080
site-serve: host b/toolmd.stamp
	@$(ho)/love -l a/papel.l -t love -o b/site -s $(SITEPORT) README.md doc b/toolmd

# the wasm artifact, moon's own: love's TUs (plus the horn and the seat's host.c)
# through mooncc -t wasm, linked to one module -- no emcc, no C toolchain. tco=1: the
# vm's tails are return_call, the engines' tail-call law (node 26, firefox 121, chrome
# 112, safari 18), and the corpus runs 1.31x faster than on the trampoline. the loader
# (i/wasm/loader.js) is the runtime under it. NOTHING SHIPS IT any more -- the front
# page carries the machine (the kernel module below) -- so it is laid under b/ and never
# copied out: test_wasm's two checks and horn.html are the whole readership, and each is a
# seam the machine has not grown yet (quay's cells, the horn's ring).
# the emcc build stays as wasm-emcc, a differential and nothing on the page.
wasm_c = $(love_c) $(R)/i/horn.c $(R)/i/wasm/host.c
b/wasm/love.wasm: $(wasm_c) $(lib_h) b/lib/love_version.h $(mooncc_dep)
	@mkdir -p $(dir $@)
	@echo 'MOON	'$@
	@$(mooncc) -t wasm -Dai_tco=1 -DLvHaveVersionH -I. -Il -Ii -Ib/lib -o $@ $(wasm_c)
ifeq ($(NODE),)
wasm: b/wasm/love.wasm
else
wasm: b/wasm/love.wasm b/wasm/love-wasm.image
endif
# by hand, as love.js was: bytes every C edit would otherwise churn. ONE PAIR IS COPIED
# OUT, the machine's, to w/ beside the fonts and the stylesheet -- generated files
# committed for one reason, that github pages serves what it is given and builds nothing.
# the hosted module is a gate's, not a page's, and never leaves b/.
site-wasm: wasm
	@mkdir -p w/wasm
	@echo '$(t_cp)	'w/wasm/love-wasm.wasm
	@cp b/love-wasm.wasm w/wasm/love-wasm.wasm
	@echo '$(t_cp)	'w/wasm/love-wasm.image
	@cp b/wasm/love-wasm.image w/wasm/love-wasm.image
# the wasm inle seat: the kernel the three metal seats link -- kmain and the ramfs, the
# console painter with its fonts, i/sys.c under moonlibc, the host frontend whole -- with
# i/wasm/arch.c for the machine and the source blob as a wasm data object (mksrc.l's
# text lane). one module beside b/love-$a.elf; the runtime rides in by need, and no
# the heap image is baked below. the CPU under it is i/wasm/cpu.mjs, a worker;
# the terminals are i/wasm/inle.mjs (node) and i/wasm/inle.html (the page).
kw_c = $(love_c) $R/l/quay/cga_8x8.c $R/l/quay/moderndos_8x16.c $R/l/quay/paint.c \
  $(k_free_c) $(host_c) $R/i/wasm/arch.c
kw_h = $(love_h) $R/i/k.h $R/i/ustar.h $R/i/asmops.h $R/i/wasm/asmops.h
b/wasm/src.o: $(dist_source) u/mksrc.l b/.mksys-cat.l $m
	@echo 'HOLO	'$@
	@mkdir -p "$(dir $@)"
	@LOVE_NO_IMAGE= $m -l b/.mksys-cat.l u/mksrc.l $(dist_source) $@ wasm
b/love-wasm.wasm: $(kw_c) $(kw_h) b/wasm/src.o b/lib/baked.h b/lib/distlist.h \
  b/lib/korelist.h b/lib/crewlist.h b/lib/love_version.h $(mooncc_dep)
	@echo 'MOON	'$@
	@$(mooncc) -t wasm -Dai_tco=1 -DLvHaveVersionH -I. -Il -Ii -Ib/lib \
	  -Il/quay -Ia/moon/include -o $@ $(kw_c) b/wasm/src.o
wasm-emcc:                       # emcc's love, b/wasm/love.js: the foreign build ccwasm takes
	@$(MAKE) -C i/wasm
# the seat's heap image: the kernel booted once under node with `bake PATH` on the boot
# line -- the egg, the modules and the korecat warm, the seat text run -- written to the
# ramfs and lifted out at the reset. the page fetches it beside the module and the worker
# hands it to k_start; a stale one is refused and the egg bakes, the host's own law.
b/wasm/love-wasm.image: b/love-wasm.wasm i/wasm/cpu.mjs i/wasm/inle.mjs
	@echo 'BAKE	'$@
	@$(NODE) i/wasm/inle.mjs --lift /love.image:$@ b/love-wasm.wasm bake /love.image < /dev/null > b/wasm/bake.log 2>&1 \
	   || { cat b/wasm/bake.log; exit 1; }

clean:
	rm -rf b
	@rm -f t/proof/rocq/*.vo t/proof/rocq/*.vok t/proof/rocq/*.vos t/proof/rocq/*.glob t/proof/rocq/.*.aux
	@[ -d i/wasm ] && $(MAKE) -C i/wasm clean || :
distclean: clean
	rm -rf dl
valg: host
	@cat $t > $(ho)/.valg-corpus.l
	valgrind --error-exitcode=1 --suppressions=$R/u/valgrind.supp $m $(ho)/.valg-corpus.l </dev/null
# the site's faces and its stylesheet, laid and checked in: github pages serves
# the tree as it is, so a generated file still has to be committed
web: fonts w/style.css w/favicon.png index.html
fonts: w/fonts/quay16.woff w/fonts/quay8.woff
w/fonts/quay16.woff: l/quay/moderndos_8x16.c u/mkfont.l $(mdep)
	@echo 'LOVE	'$@
	@mkdir -p $(dir $@)
	@$m u/mkfont.l $< 12 $@ "Quay 16"
w/fonts/quay8.woff: l/quay/cga_8x8.c u/mkfont.l $(mdep)
	@echo 'LOVE	'$@
	@mkdir -p $(dir $@)
	@$m u/mkfont.l $< 6 $@ "Quay 8"
# ..the front page's stylesheet: config.l's tokyo-night through hueweb, over the layout
w/style.css: w/style.l a/vi/config.l a/vi/hueweb.l $(mdep)
	@mkdir -p $(dir $@)
	@env -u LOVE_NO_IMAGE $m w/style.l $@
# ..the favicon: cp437's heart off the 8x8 face, in the palette's red
w/favicon.png: l/quay/cga_8x8.c u/mkicon.l a/vi/config.l $(mdep)
	@mkdir -p $(dir $@)
	@env -u LOVE_NO_IMAGE $m u/mkicon.l $< 3 32 $@
# ..and the front page itself, its island the fragment machine.js drives
index.html: w/index.l i/wasm/machine.html $(mdep)
	@$m w/index.l $@
.PHONY: ulp
ulp:
	@mkdir -p b
	@$(CC) -O2 -o b/ulp $R/u/ulp.c $R/a/moon/lib/moonlibc/math/am.c -lm
	@b/ulp
b/perf.data: host
	cat $t | perf record -o $@ $m
perf: b/perf.data
	exec perf report -i $<
flame: b/flamegraph.svg
b/flamegraph.svg: b/perf.data
	flamegraph -o $@ --perfdata $<
repl: host
	@exec $m
cloc:
	cloc --by-file l i a u test w bench
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

