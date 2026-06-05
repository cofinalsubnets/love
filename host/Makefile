# Host build. Run from project root via `make host`, or directly via
# `cd host && make`. Outputs (binary, libs, manpage, the bootstrap gl0, and
# the gl0-generated boot.h / repl.h / vt.h) all land in $(R)/b/host/.
R := ..
include $(R)/common.mk

# This frontend's build output directory under the top-level b/.
o = $(R)/b/host

h_o = $(g_c:$(R)/%.c=$(o)/%.o)
# -I$(o) is first so $(o)/vt.h (generated below) shadows the portable
# kernel/vt.h; nothing else in $(o)/ collides with a kernel/ header.
cc = $(CC) $(g_cflags) -fpic -I$(o) -I$(R) -I$(R)/kernel -I.
# ccache wraps gl0's per-object compiles (override with `make CCACHE=` to disable).
CCACHE ?= $(shell command -v ccache 2>/dev/null)
# Pins the gwen_data_vt sentinel order on every final link (see the script).
vt_ld = $(R)/kernel/vt.ld
ldflags = -Wl,-T,$(vt_ld)
# vt.o is the data-sentinel TU (kernel/vt.c). tools/gen_data_vt.g reflects its
# gwen_data_vt.NN section sizes into $(o)/vt.h, whose g_typ() shifts instead
# of doing the portable header's two link-time divides. Every object depends
# on it (below) except vt.o itself, which bootstraps from kernel/vt.h -- it
# never calls g_typ, so the stride it records doesn't depend on which it sees.
vt_h = $(o)/vt.h
# Prelude-less bootstrap interpreter, one-shot compiled against the fallback
# kernel/vt.h (no -I$(o)), used to run the gwen build tools (tools/*.g) that
# generate the headers below -- so it needs none of those headers itself,
# breaking the circularity. Gets its prelude at runtime via the cli -l flag.
gl0 = $(o)/gl0

.PHONY: default boot.h repl.h prelude.h clean
default: $(o)/$n $(o)/lib$n.so $(o)/$n.1

# Phony aliases so free/playdate/rp2040 builds can request the generated
# headers via `make -C ../host boot.h` / `repl.h` / `prelude.h` without
# having to spell out the $(o)/ output path from another cwd.
boot.h: $(o)/boot.h
repl.h: $(o)/repl.h
prelude.h: $(o)/prelude.h

clean:
	rm -rf $(o)

$(o)/lib$n.a: $(h_o)
	@echo AR	$@
	@mkdir -p $(dir $@)
	@ar rcs $@ $^

$(o)/lib$n.so: $(o)/lib$n.a $(vt_ld)
	@echo LD	$@
	@mkdir -p $(dir $@)
	@$(cc) $(ldflags) -shared -o $@ -Wl,--whole-archive $(o)/lib$n.a -Wl,--no-whole-archive -lm

# The data-sentinel TU bootstraps from the portable header (no $(o)/vt.h
# prerequisite -- that would be circular, since $(o)/vt.h is reflected out
# of this object). Its explicit recipe overrides the pattern rules below.
$(o)/kernel/vt.o: $(R)/kernel/vt.c $(g_h)
	@echo CC	$@
	@mkdir -p $(dir $@)
	@$(cc) -c $< -o $@

# Bootstrap interpreter (fallback header, no compiled-in prelude). Built
# per-object into $(o)/0/ -- separate from the final gl's optimized $(o)/*.o,
# since these use the fallback header (no -I$(o)) + -DGL_BOOTSTRAP -- so ccache
# caches each TU and an edit recompiles just that file. No -I$(o)/$(vt_h)
# dependency: $(o)/vt.h is generated *by* gl0, so it must not need it.
gl0_cc = $(CCACHE) $(CC) $(g_cflags) -DGL_BOOTSTRAP -I$(R) -I$(R)/kernel -I.
gl0_o = $(o)/0/main.o $(g_c:$(R)/%.c=$(o)/0/%.o)
$(o)/0/main.o: main.c $(g_h)
	@echo CC	$@
	@mkdir -p $(dir $@)
	@$(gl0_cc) -c $< -o $@
$(o)/0/%.o: $(R)/%.c $(g_h)
	@echo CC	$@
	@mkdir -p $(dir $@)
	@$(gl0_cc) -c $< -o $@
$(gl0): $(gl0_o) $(vt_ld)
	@echo LD	$@
	@mkdir -p $(dir $@)
	@$(CC) $(g_cflags) $(ldflags) -o $@ $(gl0_o) -lm

$(o)/vt.h: $(o)/kernel/vt.o $(gl0) $(R)/tools/gen_data_vt.$x $(R)/kernel/prelude.$x
	@echo GEN	$@
	@$(gl0) -l $(R)/kernel/prelude.$x $(R)/tools/gen_data_vt.$x $< -o $@

# kernel/*.c (and any other root-level *.c) -> $(o)/<dir>/*.o
$(o)/%.o: $(R)/%.c $(g_h) $(vt_h)
	@echo CC	$@
	@mkdir -p $(dir $@)
	@$(cc) -c $< -o $@

# local host/*.c -> $(o)/*.o
$(o)/%.o: %.c $(g_h) $(vt_h)
	@echo CC	$@
	@mkdir -p $(dir $@)
	@$(cc) -c $< -o $@

$(o)/$n: main.c $(o)/lib$n.a $(o)/boot.h $(o)/repl.h $(vt_h) $(vt_ld)
	@echo CC	$@
	@mkdir -p $(dir $@)
	@$(cc) $(ldflags) -o $@ main.c $(o)/lib$n.a -lm

# boot.g is assembled from prelude.g + ev.g (the egg wrapper + the bootstrap
# that compiles the gwen compiler with the C ev, recompiles with itself, and
# installs it) by tools/mkboot.g on gl0. boot.h / repl.h then re-serialize the
# source into a C string literal via lcat.g. All bif-only -> run on gl0.
$(o)/boot.g: $(gl0) $(R)/tools/mkboot.$x $(R)/kernel/prelude.$x $(R)/kernel/ev.$x
	@echo GEN	$@
	@mkdir -p $(dir $@)
	@$(gl0) -l $R/kernel/prelude.$x $(R)/tools/mkboot.$x $(R)/kernel/prelude.$x $(R)/kernel/ev.$x >$@

$(o)/repl.h: $(gl0) $(R)/tools/lcat.$x $(R)/kernel/repl.$x
	@echo GEN	$@
	@mkdir -p $(dir $@)
	@$(gl0) -l $R/kernel/prelude.$x $(R)/tools/lcat.$x $(R)/kernel/repl.$x >$@

$(o)/boot.h: $(gl0) $(R)/tools/lcat.$x $(o)/boot.$x
	@echo GEN	$@
	@mkdir -p $(dir $@)
	@$(gl0) -l $R/kernel/prelude.$x $(R)/tools/lcat.$x $(o)/boot.$x >$@

$(o)/prelude.h: $(gl0) $(R)/tools/lcat.$x $R/kernel/prelude.$x
	@echo GEN	$@
	@mkdir -p $(dir $@)
	@$(gl0) -l $R/kernel/prelude.$x $(R)/tools/lcat.$x $R/kernel/prelude.$x >$@

$(o)/$n.1: $(o)/$n manpage.$x
	@echo GEN	$@
	@$m < manpage.$x > $@
