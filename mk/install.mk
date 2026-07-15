# mk/install.mk -- install / uninstall
#
# Fragment of the root Makefile (split out 2026-07-15). Included by ./Makefile,
# which is invoked from the project root; paths resolve from there. Shared vars
# live in common.mk. Every recipe here is unchanged from the single-file Makefile.

# --- install / uninstall --------------------------------------------
PREFIX ?= .local/
VIMPREFIX ?= .vim/
DESTDIR ?= $(HOME)/
d = $(DESTDIR)/$(PREFIX)
v = $(DESTDIR)/$(VIMPREFIX)
installs = \
  $d/bin/ai \
  $d/bin/kore \
  $d/bin/aicc \
  $d/bin/cook \
  $d/bin/ain \
  $d/bin/lux \
  $d/bin/bao \
  $d/share/man/man1/ai.1 \
  $d/share/man/man1/cook.1 \
  $d/lib/ai/prel.l \
  $d/lib/ai/ev.l \
  $d/lib/ai/bao.l \
  $d/lib/ai/aicc.image \
  $d/lib/libai.a \
  $d/lib/libai.so \
  $d/include/ai.h \
  $v/ftdetect/ai.vim \
  $v/syntax/ai.vim \
  $v/ftplugin/ai.vim

install: $(installs)
uninstall:
	@echo RM	$(abspath $(installs))
	@rm -f $(installs)

$d/include/ai.h: ai.h
	@echo CP	$(abspath $@)
	@install -D -m 644 $< $@

$d/lib/ai/%.l: ai/%.l
	@echo CP	$(abspath $@)
	@install -D -m 644 $< $@

# the embeddable libs install GLIBC always: a musl-compiled archive poisons a
# glibc link (the sigsetjmp note in the host block), and a musl .so is useless
# to a dynamic (glibc) consumer. Under STATIC=1 the canonical out/host (glibc)
# tree is built on demand by a sub-make.
glibc_ho = out/host
ifneq ($(glibc_ho),$(ho))
$(glibc_ho)/libai.a $(glibc_ho)/libai.so: force_hostcc
	@$(MAKE) --no-print-directory STATIC=0 $@
endif

$d/lib/libai.a: $(glibc_ho)/libai.a
	@echo CP	$(abspath $@)
	@install -D -m 644 $< $@

$d/lib/libai.so: $(glibc_ho)/libai.so
	@echo CP	$(abspath $@)
	@install -D -m 755 -s $< $@

$d/bin/ai: $(ho)/ai $(ho)/ai.baked
	@echo CP	$(abspath $@)
	@install -D -m 755 -s $< $@
# the boot image travels INSIDE the binary (.image is an allocated PROGBITS section, so the
# stripped install keeps it; strip removes only the symbol table -- .text/.rodata vaddrs are
# unchanged, so the image's lvm-table indices and base-delta still resolve, and a bad match
# just falls back to a normal egg boot).

# cook: the build tool (crew/cook/cook.l) installed as an executable `cook` on PATH.
# Its `#!/usr/bin/env -S ai -l` shebang re-execs the installed `ai` to load it,
# then it discovers a Makefile/Cookfile/Cards.l in the cwd. Installed as a SYMLINK
# to the source so edits to crew/cook/cook.l are picked up without a reinstall.
$d/bin/cook: crew/cook/cook.l
	@echo LN	$(abspath $@)
	@mkdir -p $(@D)
	@ln -sf $(abspath $<) $@

# ain: the netcat clone (tools/ain.l). Same shebang-script mechanism as cook
# (`#!/usr/bin/env -S ai -l` re-execs the installed `ai` to load it); the SEAT
# form inside the file finds its own name on the command line and fires.
$d/bin/ain: tools/ain.l
	@echo CP	$(abspath $@)
	@install -D -m 755 $< $@

# kore: the multi-call toolbox -- ONE catted script (busybox's trick), the util
# picked off the command line (`kore diff A B`, `kore nc H P`, `kore make`, `kore as ..`)
# or off argv[0] through a tool-named symlink. Shadows nothing on the host: only
# `kore` lands on PATH; the distro symlinks the tool names when shadowing is the
# point. The tool files' SEATs stay quiet inside the cat (no file of theirs sits
# in the program seat), so crew/kore/kore.l's dispatcher is the one thing firing.
$d/bin/kore: $(korefiles)
	@echo AI	$(abspath $@)
	@install -d $(dir $@)
	@{ echo '#!/usr/bin/env -S ai'; cat $(korefiles); } > $@
	@chmod 755 $@

# aicc: the C compiler, ITS OWN app (doc/cc.md). The installed bin is a WAKE SHIM:
# it boots the baked aicc IMAGE next door (--wake, ~ms) and fires cc-main on the
# args -- the whole-cat re-eval (~1.3 s at every compile) is paid ONCE, at bake.
# The image is baked by the build binary against the build cat (below); strip
# keeps .text/.rodata vaddrs, so the stripped installed ai wakes it fine -- but
# it IS binary-specific (anchor-checked), so image and binary always install
# from the same build. Kept OUT of the kore cat so a cc edit never forces an kore
# rebuild and vice versa.
$d/bin/aicc: $(MAKEFILE_LIST)
	@echo AI	$(abspath $@)
	@install -d $(dir $@)
	@{ echo '#!/bin/sh'; \
	   echo 'h=$$(CDPATH= cd -- "$$(dirname -- "$$0")" && pwd)'; \
	   echo 'exec "$$h/ai" --wake "$$h/../lib/ai/aicc.image" -e "(cc-main (cuup (cup cmdline)))" "$$@"'; } > $@
	@chmod 755 $@
$d/lib/ai/aicc.image: $(ho)/aicc.image
	@echo CP	$(abspath $@)
	@install -D -m 644 $< $@

# lux: the window manager (crew/lux/*.l), the seven modules catted into one shebang
# script. DISPLAY picks the socket, ~/.Xauthority the cookie (crew/lux/config.l);
# mod+q restarts in place by exec'ing this same script.
luxfiles = crew/lux/core.l crew/lux/layout.l crew/lux/wire.l crew/lux/ewmh.l crew/lux/manage.l crew/lux/keys.l crew/lux/config.l crew/lux/lux.l
$d/bin/lux: $(luxfiles)
	@echo AI	$(abspath $@)
	@install -d $(dir $@)
	@{ echo '#!/usr/bin/env -S ai -l'; cat $(luxfiles); } > $@
	@chmod 755 $@

# bao: the interactive shell. Unlike crew/cook/ain, ai/bao.l is DEFINE-ONLY (the
# launch `(bao 0)` is normally fired by main.c on a tty), so the bin is a tiny
# relocatable launcher: it loads the installed bao.l next door and fires it.
$d/bin/bao: $(MAKEFILE_LIST)
	@echo AI	$(abspath $@)
	@install -d $(dir $@)
	@{ echo '#!/bin/sh'; \
	   echo 'h=$$(CDPATH= cd -- "$$(dirname -- "$$0")" && pwd)'; \
	   echo 'exec "$$h/ai" -l "$$h/../lib/ai/bao.l" -e "(bao 0)" "$$@"'; } > $@
	@chmod 755 $@

$d/share/man/man1/ai.1: $(ho)/ai.1
	@echo CP	$(abspath $@)
	@install -D -m 644 $< $@

$d/share/man/man1/cook.1: $(ho)/cook.1
	@echo CP	$(abspath $@)
	@install -D -m 644 $< $@

$v/ftdetect/ai.vim: vim/ftdetect.vim
	@echo CP	$(abspath $@)
	@install -D -m 644 $< $@

$v/syntax/ai.vim: vim/syntax.vim
	@echo CP	$(abspath $@)
	@install -D -m 644 $< $@

$v/ftplugin/ai.vim: vim/ftplugin.vim
	@echo CP	$(abspath $@)
	@install -D -m 644 $< $@
