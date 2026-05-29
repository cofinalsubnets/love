# Host build. Run from project root via `make h`, or directly via
# `cd h && make`. Outputs (binary, libs, manpage, lcat, and the
# lcat-generated boot.h / repl.h) all land in $(R)/h/b/.
R := ..
include $(R)/common.mk

h_o = $(g_c:$(R)/%.c=b/%.o)
cc = $(CC) $(g_cflags) -fpic -I$(R) -I$(R)/g -I. -Ib

.PHONY: default boot.h repl.h clean
default: b/$n b/lib$n.so b/$n.1

# Phony aliases so kernel/playdate builds can request the generated
# headers via `make -C ../h boot.h` / `repl.h`.
boot.h: b/boot.h
repl.h: b/repl.h

clean:
	rm -rf b

b/lib$n.a: $(h_o)
	@echo AR	$@
	@mkdir -p $(dir $@)
	@ar rcs $@ $^

b/lib$n.so: b/lib$n.a
	@echo LD	$@
	@mkdir -p $(dir $@)
	@$(cc) -shared -o $@ -Wl,--whole-archive $^ -Wl,--no-whole-archive -lm

# g/*.c (and any other root-level *.c) -> b/<dir>/*.o
b/%.o: $(R)/%.c $(g_h)
	@echo CC	$@
	@mkdir -p $(dir $@)
	@$(cc) -c $< -o $@

# local h/*.c -> b/*.o
b/%.o: %.c $(g_h)
	@echo CC	$@
	@mkdir -p $(dir $@)
	@$(cc) -c $< -o $@

b/$n: main.c b/lib$n.a b/boot.h b/repl.h
	@echo CC	$@
	@mkdir -p $(dir $@)
	@$(cc) -o $@ main.c b/lib$n.a -lm

b/lcat: lcat.c $(h_o)
	@echo CC	$@
	@mkdir -p $(dir $@)
	@$(cc) -o $@ $^ -lm

b/repl.h: b/lcat $(R)/$x/repl.$x
	@echo GEN	$@
	@mkdir -p $(dir $@)
	@cat $(R)/$x/repl.$x | b/lcat >$@

b/boot.h: b/lcat $(R)/$x/boot.$x
	@echo GEN	$@
	@mkdir -p $(dir $@)
	@cat $(R)/$x/boot.$x | b/lcat >$@

b/$n.1: b/$n manpage.$x
	@echo GEN	$@
	@$m < manpage.$x > $@
