R ?= .
include $(R)/mk/common.mk

CCACHE ?= $(shell command -v ccache 2>/dev/null)

ifneq ($(words $(CC)),1)
CCACHE :=
endif

# bootstrap interpreter
love0 = out/love0

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
# src/host/main.c names the ones love0 evaluates.
sed_lit = sed \
  -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/^/"/' -e 's/$$/\\n"/'
boot0_l = $(wildcard src/core/boot/*.l) src/core/holo/holo.l src/core/holo/x64.l src/core/holo/a64.l
out/lib/boot0.h: $(boot0_l)
	@echo 'SED	'$@
	@mkdir -p out/lib
	@for f in $(boot0_l); do n=$${f##*/}; printf 'static char const src0_%s[] =\n' $${n%.l}; \
	   LOVE_NO_IMAGE= $(sed_lit) $$f || exit 1; echo ';'; done > $@
.PHONY: lib
lib: out/lib/boot0.h out/lib/baked.h
lcat_love = $(love0) -l src/core/boot/prel.l
# A FORCED WITNESS KEEPS ITS MTIME, and that is the whole point: make cannot depend on a
# variable's VALUE, so a roster change has to be noticed some other way. Depending on the
# Makefile instead was measured at 90 s and 42 targets for a bare `touch Makefile` -- the
# .mooncc-cat.l -> mooncc0.image -> every moon object chain. Do not simplify this away.
note = if cmp -s $$tf $@ 2>/dev/null; then rm -f $$tf; else mv $$tf $@; echo 'SH	'$@; fi
# every header below is written straight to $@. .DELETE_ON_ERROR (above) takes the
# half-written one away when a generator dies, which is the whole of the guarantee.
# the baked source: one header, one love0 run. tools/lcat.l carries the roster -- which
# files, in which blobs, with what glue -- so a roster change edits a file this depends on.
baked_l = $(wildcard src/core/boot/*.l) \
  src/core/boot/glaze/emit.l src/core/boot/glaze/auto.l src/core/boot/glaze/hook.l src/core/boot/glaze/walk.l \
  src/core/holo/holo.l src/core/holo/x64.l src/core/holo/a64.l src/core/holo/rv64.l
out/lib/baked.h: $(baked_l) tools/lcat.l $(love0)
	@echo 'LOVE	'$@
	@mkdir -p out/lib
	@$(lcat_love) tools/lcat.l > $@
# one file as one literal: the ports and test/front paste these in expression position
lib_h = $(patsubst src/core/boot/%.l,out/lib/%.h,$(wildcard src/core/boot/*.l))
holo_h = out/lib/holo.h out/lib/x64.h out/lib/a64.h out/lib/rv64.h
$(lib_h): out/lib/%.h: src/core/boot/%.l tools/lcat.l $(love0)
	@echo 'LOVE	'$@
	@mkdir -p out/lib
	@$(lcat_love) tools/lcat.l $< > $@
$(holo_h): out/lib/%.h: src/core/holo/%.l tools/lcat.l $(love0)
	@echo 'LOVE	'$@
	@mkdir -p out/lib
	@$(lcat_love) tools/lcat.l $< > $@
out/lib/rune.h: src/apps/rune/rune.l tools/lcat.l $(love0)
	@echo 'LOVE	'$@
	@mkdir -p out/lib
	@$(lcat_love) tools/lcat.l $< > $@
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

out/lib/readme.bin: $(love0) $(R)/src/core/boot/post.l $(R)/VERSION
	@mkdir -p out/lib
	@printf 'love %s\n' "$$(cat $(R)/VERSION)" > $@
	@$(love0) -h </dev/null >> $@
	@echo 'LOVE	'$@

ho = out$(hsuf)
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
host: $(ho)/love $(ho)/.love.baked $(ho)/love.1 $(ho)/cook.1
love0: $(love0)

$(ho)/.love.baked $(ho)/.love.cand.baked: $(ho)/.%.baked: $(ho)/% $(ho)/.dist-cat.l
	@echo 'LOVE	'$< "(bake)"
	@$< bake -l $(ho)/.dist-cat.l
	@touch $@

.PHONY: candidate
candidate: $(ho)/.love.cand.baked

$(ho)/liblove.a: $(h_o)
	@echo 'AR	'$@
	@mkdir -p $(dir $@)
	@rm -f $@; ar rcs $@ $^

# pinned to out/0, never $(ho)/0: love0 is one binary whatever HCC and tco say
love0_o = $(patsubst $(R)/%.c,out/0/%.o,$(filter-out $(R)/src/host/cats.c,$(host_c)) $(love_c))
out/0/src/host/main.o: out/lib/boot0.h
out/0/src/host/cb.o: src/core/quay/quay.c src/core/quay/nif.c src/core/quay/quay.h
boot_cc = $(CCACHE) $(CC) $(ai_cflags) -fPIE -DLoveBoot -Dai_tco=0 -Dai_data_section=0 -DAiVersion='"$(love_base)+bootstrap"' -I. -Isrc/core -Isrc/host -Isrc/inle -Iout/lib
.PHONY: force_love0cc
force_love0cc: ;
out/0/.love0cc: force_love0cc
	@mkdir -p $(dir $@)
	@tf=$@.$$$$.tmp; printf '%s\n' '$(boot_cc)' > $$tf; \
	 $(note)
out/0/%.o: $(R)/%.c $(love_h) out/0/.love0cc
	@echo 'CC	'$@
	@mkdir -p $(dir $@)
	@LOVE_NO_IMAGE= $(boot_cc) -c $< -o $@
$(love0): $(love0_o)
	@echo 'LD	'$@
	@mkdir -p $(dir $@)
	@LOVE_NO_IMAGE= $(CC) $(ai_cflags) -pie -o $@ $(love0_o)

# src/core/love.c -> out/*.o
$(ho)/%.o: $(R)/%.c $(love_h) $(ho)/.hostcc
	@echo 'CC	'$@
	@mkdir -p $(dir $@)
	@$(hcc) -c $< -o $@

# l.o carries the version string; recompile it when the id changes. love0's twin is
# deliberately not here -- see the -DAiVersion note on boot_cc.
# the baked source rides src/host/cats.c; main.c bakes the dist roster for the first boot
$(ho)/src/host/cats.o: out/lib/baked.h
$(ho)/src/host/main.o: out/lib/distlist.h
$(ho)/src/core/love.o: out/lib/love_version.h
# the carried-blob reader both the first boot and the kernel's ram fs decode with
$(ho)/src/host/main.o $(ho)/src/host/ustar.o: $(R)/src/host/ustar.h
# src/host/cb.c rides the src/core/quay sources by unity include -- recompile when they move.
$(ho)/src/host/cb.o: src/core/quay/quay.c src/core/quay/nif.c src/core/quay/quay.h

moon0 = $(love0) wake out/mooncc0.image mooncc $(GCDBG)
moon0_dep = out/mooncc0.image
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
$$($(2))/host_main.o: out/lib/distlist.h
$$($(2))/host_cats.o: out/lib/baked.h
$$($(2))/host_cb.o: src/core/quay/quay.c src/core/quay/nif.c src/core/quay/quay.h
$$($(2))/m_%.o: src/apps/moon/lib/math/%.c $$(moon0_dep)
	@echo 'MOON	'$$@
	@mkdir -p $$(dir $$@)
	@$$($(3)) -Isrc/apps/moon/lib/math -Isrc/apps/moon/include -c $$< $$@
# the machine tail rides the host's own cat, one cut for every consumer; only the entry
# names the arch.
$$($(2))/sys.o: out/.mksys-cat.l $$(love0)
	@echo 'HOLO	'$$@
	@mkdir -p $$(dir $$@)
	@LOVE_NO_IMAGE= $$(love0) -l out/.mksys-cat.l -q -e "((from 'moon 'mksys-$$($(4))) \"$$@\")" && test -s $$@
endef

moon_d = $(ho)/moon
$(eval $(call moonlane,moon,moon_d,moon0,hosta))
mksys_l = src/apps/kore/text.l src/apps/kore/u.l src/apps/kore/asbook.l \
          src/core/holo/x64.l src/core/holo/a64.l src/core/holo/rv64.l \
          src/core/holo/elf.l src/core/holo/obj.l src/apps/moon/lib/mksys.l
.PHONY: force_dist_list
force_dist_list: ;
out/.mksys-cat.list: force_dist_list
	@mkdir -p $(dir $@)
	@tf=$@.$$$$.tmp; echo '$(mksys_l)' > $$tf; \
	 $(note)
out/.mksys-cat.l: $(mksys_l) out/.mksys-cat.list
	@echo 'CAT	'$@
	@mkdir -p $(dir $@)
	@cat $(mksys_l) > $@
ifneq ($(HCC),)
$(ho)/love $(ho)/love.cand: $(host_o) $(ho)/liblove.a $(ho)/.hostcc $(R)/src/core/love_data.ld
	@echo 'LD	'$@
	@mkdir -p $(dir $@)
	@$(hcc) -o $@ $(host_o) $(ho)/liblove.a $(image_ldflags) $(data_ld)
else
nolibc_src = $(wildcard src/apps/moon/lib/nolibc/*.c src/apps/moon/lib/nolibc/*.h \
                        src/apps/moon/lib/nolibc/*/*.c src/apps/moon/lib/nolibc/*/*.h)
$(ho)/love $(ho)/love.cand: $(moon_o) out/src.o out/rt.o out/lib/readme.bin $(nolibc_src)
	@echo 'MOON	'$@
	@mkdir -p $(dir $@)
	@$(moon0) -pie $(moon_o) $(kart_o) out/src.o out/rt.o -freadme=out/lib/readme.bin -o $@
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
out/mooncc0.image: out/.mooncc-cat.l $(love0)
	@echo 'LOVE	'$@
	@$(love0) -l out/.mooncc-cat.l -e '(? ((bake "$@") = 1) (quit 0) (quit 1))'

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
            src/apps/libra/salt.l src/apps/libra/libra.l src/apps/vi/hueweb.l src/apps/kiosko/serve.l \
            src/apps/console/console.l
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
dist-seed: $(ho)/.love.baked
endif
dist: dist-source dist-seed   # a release is both

# what a release is not: the benches and the board and wasm seats. the web page and
# its assets are .sbignore's to drop, which selfpack reads too. each nom is matched
# as a path prefix at a segment boundary (tools/selfpack.l).
dist_drop = bench src/port
.PHONY: force_src
force_src: ;
$(dist_source): force_src $(love0)
	@mkdir -p $(dir $@)
	@LOVE_NO_IMAGE= LOVE_BUDGET_MB=256 $(love0) tools/selfpack.l $@ love-$(dist_ver) $(dist_stamp) $(dist_drop)

out/src.o: $(dist_source) tools/mksrc.l out/.mksys-cat.l $(love0)
	@$(love0) -l out/.mksys-cat.l tools/mksrc.l $(dist_source) $@ $(hosta)

rt_slice = $(wildcard src/apps/moon/include/*.h src/apps/moon/include/*/*.h \
                      src/apps/moon/lib/*.l \
                      src/apps/moon/lib/nolibc/*.c src/apps/moon/lib/nolibc/*.h \
                      src/apps/moon/lib/nolibc/*/*.c src/apps/moon/lib/nolibc/*/*.h \
                      src/apps/moon/lib/math/*.c)
out/rt.o: $(rt_slice) tools/mkrt.l out/mooncc0.image $(love0)
	@$(love0) wake out/mooncc0.image tools/mkrt.l $@ $(hosta)

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

$(xd)/src.o: $(dist_source) tools/mksrc.l out/.mksys-cat.l $(love0)
	@$(love0) -l out/.mksys-cat.l tools/mksrc.l $(dist_source) $@ $(xa)
$(xd)/rt.o: $(rt_slice) tools/mkrt.l out/mooncc0.image $(love0)
	@$(love0) wake out/mooncc0.image tools/mkrt.l $@ $(xa)
$(xd)/love: $(x_o) $(xd)/src.o $(xd)/rt.o out/lib/readme.bin
	@echo 'MOON	'$@
	@$(moonx) -pie $(x_o) $(xkart_o) $(xd)/src.o $(xd)/rt.o -freadme=out/lib/readme.bin -o $@
fat = out/dist/love-fat
.PHONY: dist-fat
dist-fat: $(ho)/.love.baked $(xd)/love tools/fatpack.l
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
# --- the distro lane --------------------------------------------------------
# the love-native Linux distro: an initramfs where love is /init. The LFS
# toolchain phase is already solved elsewhere (a gcc-free static love, `make test_raw`), so
# a bootable system is just PACKAGING what is green: love as pid 1, kore as the
# busybox-style userland, lush as the console shell.
#
#   make distro-initramfs   -> out/distro/initramfs.cpio.gz
#   make distro-run         -> boot it under qemu on a stock kernel
#
# The kernel stays the one imported artifact (BZIMAGE, default the host's).

# ⚠ THE CUT IS OURS END TO END NOW -- kore's find, src/apps/cpio/cpio.l and src/apps/gz/gz.l where the
# host's find | cpio | gzip -9 stood. $(mabs) because the pack runs INSIDE a `cd`, and
# $m is spelled relative to the tree root.
mabs         = $(abspath $m)
distro_dir   = out/distro
distro_root  = $(distro_dir)/root
distro_img   = $(distro_dir)/initramfs.cpio.gz
# ⚠ the base love MUST be static -- a bare initramfs has no ld.so or glibc. love-raw is it:
# gcc-free, our own linker over nolibc, and 935K against the baked love's ~11M, which is
# what an initramfs wants carried into RAM. `make test_raw` lays it.
distro_love    = $(wildcard out/love-raw)
# kore applets to expose as argv[0] symlinks (kore dispatches on the basename).
distro_applets = ls cat head tail wc sort uniq grep sed awk find cut tr nl rev cp mv rm \
                 mkdir rmdir ln touch pwd chmod basename dirname seq yes true \
                 false env sleep kill xargs diff

# The host kernel is the default imported artifact; override with `make BZIMAGE=...`.
BZIMAGE ?= /boot/vmlinuz-linux

.PHONY: distro-initramfs distro-run distro-smoke
distro-initramfs: $(distro_img)
$(distro_img): src/apps/init/boot.l $(lushfiles) $(korefiles) $(distro_love)
	@test -n "$(distro_love)" || { echo "distro: no out/love-raw -- run 'make test_raw' to lay it"; exit 1; }
	@echo 'DISTRO	'$@ '(base: $(distro_love))'
	@rm -rf $(distro_root)
	@mkdir -p $(distro_root)/bin $(distro_root)/lib $(distro_root)/proc $(distro_root)/sys $(distro_root)/dev $(distro_root)/tmp
	@cp src/apps/init/boot.l $(distro_root)/init && chmod 755 $(distro_root)/init
	@cp $(distro_love) $(distro_root)/bin/love && chmod 755 $(distro_root)/bin/love
	@cat $(lushfiles) > $(distro_root)/lib/sh.l
# ⚠ src/apps/dns/dns.l RIDES ALONG OR THE WHOLE TOOLBOX DIES: src/apps/ain/ain.l, a korefiles member,
# probes for the `dial` nif at load and says (use 'dns) when it is absent -- which it is
# in love-raw -- and an initramfs with no /src/apps/dns/dns.l answers that with a scare that takes
# the whole cat down. The symptom is every applet gone, not a quiet nc.
	@cp src/apps/dns/dns.l $(distro_root)/src/apps/dns/dns.l
	@{ echo '#!/bin/love'; cat $(korefiles); } > $(distro_root)/bin/kore && chmod 755 $(distro_root)/bin/kore
	@for a in $(distro_applets); do ln -sf kore $(distro_root)/bin/$$a; done
	@ln -sf kore $(distro_root)/bin/sh
	@ln -sf kore $(distro_root)/bin/lush
	@( cd $(distro_root) && $(mabs) kore find . | $(mabs) cpio -o --quiet ) | $(mabs) gzip > $@
	@echo "  packed $$($(mabs) gzip -l $@ | $(mabs) kore awk 'NR==2{print $$2}') bytes -> $@"

# Direct kernel boot, no bootloader: rdinit=/init makes love pid 1. KVM when the host
# offers it -- TCG is too slow to reach the console inside a smoke window.
distro_accel = $(shell test -e /dev/kvm && echo -enable-kvm -cpu host)
# ⚠ 2G: love reserves a two-space GC heap at startup, so pid1 love PLUS a forked child
# each need one -- 512M overflows (execve -> ENOMEM). Override with QMEM=.
QMEM ?= 2048
distro_qemu = qemu-system-x86_64 -m $(QMEM) $(distro_accel) -kernel $(BZIMAGE) -initrd $(distro_img) \
              -append "console=ttyS0 earlyprintk=serial,ttyS0 rdinit=/init panic=-1" \
              -serial stdio -display none -no-reboot
distro-run: $(distro_img)
	@test -r "$(BZIMAGE)" || { echo "distro-run: no kernel at $(BZIMAGE) -- set BZIMAGE=..."; exit 1; }
	exec $(distro_qemu)

# Non-interactive smoke: boot, feed `ls /proc` to the console, prove love came up as pid 1
# with /proc mounted and the kore userland running, then kill qemu. ⚠ the trailing sleep
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

ko = out

# the kernel's verbs; its gates are test/test.mk's.
.PHONY: kmain_o run run-$a run-sh run-headless init-container uefi

# love's own mooncc, and the artifact that answers it. the compiler IS the shipped
# binary, so nothing foreign builds the kernel and there is no second cc to name.
# LOVE_NO_IMAGE= leads: an egg-booted love has no verbs.
mooncc = LOVE_NO_IMAGE= $(ho)/love mooncc
mooncc_dep = $(ho)/.love.baked

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
$(k_odir)/src.o: $(dist_source) tools/mksrc.l out/.mksys-cat.l $m
	@echo 'HOLO	'$@
	@mkdir -p "$(dir $@)"
	@LOVE_NO_IMAGE= $m -l out/.mksys-cat.l tools/mksrc.l $(dist_source) $@ $a
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
$(k_odir)/%.o: $(R)/%.c $(k_h) $(mooncc_dep) out/lib/baked.h out/lib/distlist.h out/lib/korelist.h
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
$(k_odir)/doom/wad.o: $R/dl/doom1.wad tools/mkblob.l out/.mksys-cat.l $m
	@echo 'MKBLOB	'$@
	@mkdir -p "$(dir $@)"
	@LOVE_NO_IMAGE= $m -l out/.mksys-cat.l tools/mkblob.l $< $@ doom_wad $a
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
$(moon_d)/kd_wad.o: $R/dl/doom1.wad tools/mkblob.l out/.mksys-cat.l $(love0)
	@echo 'MKBLOB	'$@
	@mkdir -p "$(dir $@)"
	@LOVE_NO_IMAGE= $(love0) -l out/.mksys-cat.l tools/mkblob.l $< $@ doom_wad $(hosta)
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
$(k_tail_o): out/.mksys-cat.l $m
	@echo 'HOLO	'$@
	@mkdir -p "$(dir $@)"
	@$m -l out/.mksys-cat.l -q -e "((from 'moon 'mksys-$a) \"$@\")" && test -s $@

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
$(k_uefid)/loader.o: $R/src/inle/uefi/loader.c $(ho)/.love.baked
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
#
# THE NEST: the default install is ~/.love, a self-implying home, and what lands in it
# is the BINARY and the things a person reads -- man pages and the vim files. ⚠ nothing
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
# shebang and the man page together. ⚠ the PROJECT is still love: lib/love/, liblove,
# src/core/love.h and src/core/boot/*.l keep the name -- data paths, not PATH entries.
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
# (the layered bake, doc/misc/plan/one-binary.md). ⚠ LOVE_NO_IMAGE= (empty = UNSET) leads,
# for $(hcc)'s reason: the root exports it=1 for the corpus, and an egg-booted love has
# no verbs -- `kore` would read as a filename.
korecmd = LOVE_NO_IMAGE= $(ho)/love kore
ifeq ($(BIN),love)
# ⚠ the chmod repairs the target when the source came through svalbard, which does not carry
# the executable bit -- without it the link resolves to a 644 file and every exec EACCESes.
instool = ln -sf $(abspath $1) $2 && chmod 755 $(abspath $1)
instag = LN
else
instool = $(korecmd) sed '1s|env -S love|env -S $(BIN)|' $1 > $2 && chmod 755 $2
instag = CP
endif

# ⚠ ONE roster each: the compat-symlink block below reads the same two names, and two
# spellings of a list is how they drift.
binnames = $(BIN) kore sb mooncc cook papel kiosko libra ain lux bao lush
mannames = $(BIN) cook lush
installs = $(patsubst %,$d/bin/%,$(binnames)) \
  $(patsubst %,$d/share/man/man1/%.1,$(mannames)) \
  $v/ftdetect/love.vim $v/syntax/love.vim $v/ftplugin/love.vim

# the plain data install, spelled once -- a dozen rules below wear it.
inst644 = @echo 'CP	'$(abspath $@); install -D -m 644 $< $@

# the PATH door, nest-only: each bin and man page gets a ~/.local compat symlink, since
# those are already on PATH and manpath. A real PREFIX (a distro) skips them.
ifeq ($(PREFIX),.love/)
compat = $(DESTDIR)/.local
installs += $(patsubst %,$(compat)/bin/%,$(binnames)) \
  $(patsubst %,$(compat)/share/man/man1/%.1,$(mannames))
inln = @echo 'LN	'$(abspath $@); mkdir -p $(@D); ln -sf $(abspath $<) $@
$(compat)/bin/%: $d/bin/%
	$(inln)
$(compat)/share/man/man1/%.1: $d/share/man/man1/%.1
	$(inln)
endif

install: $(installs)
uninstall:
	@echo 'RM	'$(abspath $(installs))
	@rm -f $(installs)

# UNSTRIPPED deliberately: stripping drops the symbol table holo lays on purpose, for ~2%
# of a baked binary. binutils strip IS safe on our ELF (every loaded byte has a covering
# section header), so a user who wants it smaller can strip their own.
$d/bin/$(BIN): $(ho)/love $(ho)/.love.baked
	@echo 'CP	'$(abspath $@)
	@install -D -m 755 $< $@
# the boot image travels INSIDE the binary (.image is an allocated PROGBITS section, the
# layered crew chain riding it), so the plain-copy install keeps the warm wake and every verb.

# the single-file shebang tools, one shape: the `#!/usr/bin/env -S love -l` line re-execs
# the installed interpreter, and each file's own SEAT fires on its name. papel and libra
# READ their siblings rather than being -l'd beside them -- two tool files cannot both be
# -l'd, since each one's seat would fire on the other's command line -- and they find them
# by READLINK'ing this very symlink back to the source tree, so the link on PATH and the
# crew directory need not be neighbours. libra's siblings are named ((use 'lint),
# (use 'salt), and (use 'lapiz) on the doc verb alone) and ride the baked image.
# ⚠ each source sits FIRST on its own line: instool reads $<, and a prerequisite added on
# the grouped line below lands ahead of it -- which installs the kore shim as `cook`.
$d/bin/cook:    src/apps/cook/cook.l    $(ho)/.love.baked
$d/bin/papel:   src/apps/papel/papel.l  $(ho)/.love.baked
$d/bin/kiosko:  src/apps/kiosko/kiosko.l $(ho)/.love.baked
$d/bin/libra:   src/apps/libra/libra.l  $(ho)/.love.baked
$d/bin/cook $d/bin/papel $d/bin/kiosko $d/bin/libra:
	@echo $(instag)	$(abspath $@)
	@mkdir -p $(@D)
	@$(call instool,$<,$@)

# ain, the netcat clone: the same shebang mechanism, but installed as a COPY rather than a
# symlink, so it takes the rewrite unconditionally. At the default BIN the substitution is
# an identity and the bytes are unchanged.
$d/bin/ain: src/apps/ain/ain.l $(ho)/.love.baked
	@echo 'CP	'$(abspath $@)
	@install -d $(@D)
	@$(korecmd) sed '1s|env -S love|env -S $(BIN)|' $< > $@
	@chmod 755 $@

# kore, the multi-call toolbox: the util picked off the command line or off argv[0] through
# a tool-named symlink. It shadows nothing here -- only `kore` lands on PATH, and the distro
# symlinks the tool names where shadowing is the point.
# A VERB SHIM: the installed binary carries the crew in its own layered image
# (doc/misc/plan/one-binary.md), so there is no sibling image and no wake spelling -- the
# picker wakes the crew layer off the `kore` verb, same warm start as ever.
# ⚠ `n` comes off $0 UNCHASED where `h` is the chased path: a tool symlink must arrive as its
# own name for the argv[0] door, and only the real file's dir has the $(BIN) sibling.
$d/bin/kore: $(MAKEFILE_LIST)
	@echo 'CAT	'$(abspath $@)
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
	@echo 'CAT	'$(abspath $@)
	@install -d $(dir $@)
	@{ echo '#!/usr/bin/env -S $(BIN)'; cat $^; } > $@
	@chmod 755 $@

# mooncc: the same verb-shim shape -- the compiler is the installed binary's own verb,
# its layer woken by the picker (~ms, the whole-cat re-eval long gone). ⚠ the home comes
# off the CHASED path (readlink -f): invoked through a ~/.local compat symlink, $0's own
# dir has no $(BIN) sibling -- the nest does.
$d/bin/mooncc: $(MAKEFILE_LIST)
	@echo 'CAT	'$(abspath $@)
	@install -d $(dir $@)
	@{ echo '#!/bin/sh'; \
	   echo 'h=$$(CDPATH= cd -- "$$(dirname -- "$$(readlink -f -- "$$0")")" && pwd)'; \
	   echo 'LOVE_NO_IMAGE= exec "$$h/$(BIN)" mooncc "$$@"'; } > $@
	@chmod 755 $@

# lux, the window manager: its modules catted into one shebang script. Settings ride salt
# (~/.love/etc/lux.l then ./.lux.l), which also names the display and the cookie when
# DISPLAY/XAUTHORITY will not do; mod+q restarts in place by exec'ing this script.
luxfiles = src/apps/lux/core.l src/apps/lux/layout.l src/apps/lux/wire.l src/apps/lux/ewmh.l src/apps/lux/manage.l src/apps/lux/keys.l src/apps/lux/config.l src/apps/lux/lux.l
$d/bin/lux: $(luxfiles)
	@echo 'CAT	'$(abspath $@)
	@install -d $(dir $@)
	@{ echo '#!/usr/bin/env -S $(BIN) -l'; cat $(luxfiles); } > $@
	@chmod 755 $@

# bao, the interactive shell. Unlike cook and ain, src/core/boot/post.l is DEFINE-ONLY -- main.c
# fires `(shell 0)` on a tty -- so the bin is a tiny launcher that fires it. ⚠ the module
# rides the binary, so there is nothing to -l and no nest path to get wrong.
$d/bin/bao: $(MAKEFILE_LIST)
	@echo 'CAT	'$(abspath $@)
	@install -d $(dir $@)
	@{ echo '#!/bin/sh'; \
	   echo 'h=$$(CDPATH= cd -- "$$(dirname -- "$$(readlink -f -- "$$0")")" && pwd)'; \
	   echo 'exec "$$h/$(BIN)" -e "((from '\''cli '\''shell) 0)" "$$@"'; } > $@
	@chmod 755 $@

# the .TH command name follows BIN too (`man lovelang` should not head LOVE(1));
# the other `love`s on that line are the PROJECT and the version string, so they stay.
$d/share/man/man1/$(BIN).1: $(ho)/love.1 $(ho)/.love.baked
	@echo 'CP	'$(abspath $@)
	@install -d $(@D)
	@$(korecmd) sed '1s|"LOVE"|"$(BINUP)"|' $< > $@
	@chmod 644 $@

# the man pages BIN does not rename, and the two hand-written vim files. ⚠ static
# patterns: an implicit rule would make these intermediate.
$d/share/man/man1/cook.1 $d/share/man/man1/lush.1: $d/share/man/man1/%.1: $(ho)/%.1
	$(inst644)
$v/ftdetect/love.vim $v/ftplugin/love.vim: $v/%/love.vim: vim/%.vim
	$(inst644)
# the syntax is GENERATED (the Makefile) out of src/apps/vi/hue.l's class table and the
# vocabulary this host answers to, so it is installed from out/ like any other artifact.
$v/syntax/love.vim: $(ho)/syntax.vim
	$(inst644)

all: host kernel wasm dist

lint: $(ho)/love
	@$(ho)/love $R/src/apps/libra/libra.l $$(git ls-files '*.l') && echo "lint: parens balance"


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
# the site's faces and its stylesheet, laid and checked in: github pages serves
# the tree as it is, so a generated file still has to be committed
web: fonts assets/web/style.css assets/web/favicon.png index.html
fonts: assets/fonts/quay16.woff assets/fonts/quay8.woff
assets/fonts/quay16.woff: src/core/quay/moderndos_8x16.c tools/mkfont.l $(ho)/.love.baked
	@mkdir -p $(dir $@)
	@$m tools/mkfont.l $< 12 $@ "Quay 16"
assets/fonts/quay8.woff: src/core/quay/cga_8x8.c tools/mkfont.l $(ho)/.love.baked
	@mkdir -p $(dir $@)
	@$m tools/mkfont.l $< 6 $@ "Quay 8"
# ..the front page's stylesheet: config.l's tokyo-night through hueweb, over the layout
assets/web/style.css: web/style.l src/apps/vi/config.l src/apps/vi/hueweb.l $(ho)/.love.baked
	@mkdir -p $(dir $@)
	@env -u LOVE_NO_IMAGE $m web/style.l $@
# ..the favicon: cp437's heart off the 8x8 face, in the palette's red
assets/web/favicon.png: src/core/quay/cga_8x8.c tools/mkicon.l src/apps/vi/config.l $(ho)/.love.baked
	@mkdir -p $(dir $@)
	@env -u LOVE_NO_IMAGE $m tools/mkicon.l $< 3 32 $@
# ..and the front page itself, its island the fragment repl.js drives
index.html: web/index.l src/port/wasm/repl.html $(ho)/.love.baked
	@$m web/index.l $@
.PHONY: ulp
ulp:
	@mkdir -p out
	@$(CC) -O2 -o out/ulp $R/tools/ulp.c $R/src/apps/moon/lib/math/am.c -lm
	@out/ulp
out/perf.data: host
	cat $t | perf record -o $@ $m
perf: out/perf.data
	exec perf report -i $<
flame: out/flamegraph.svg
out/flamegraph.svg: out/perf.data
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

