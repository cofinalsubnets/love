# host/build.mk -- the host (POSIX CLI) build, out/host. Was host/Makefile.
#
# Fragment of the root Makefile (split out 2026-07-15). Included by ./Makefile,
# which is invoked from the project root; paths resolve from there. Shared vars
# live in common.mk. Every recipe here is unchanged from the single-file Makefile.

# ====================================================================
# host (POSIX CLI) build -- outputs under out/host. Was host/Makefile.
# ====================================================================
# The DEFAULT flavor owns out/host; the other flavor builds in its own hsuf'd
# tree (common.mk: out/host-glibc when musl is the default, out/host-musl when
# it isn't), so a musl build never overwrites glibc objects -- musl's bare
# `sigsetjmp` vs glibc's `__sigsetjmp` macro would otherwise poison a cross-libc
# relink. The .hostcc stamp below catches the IN-PLACE flips (musl-clang
# appearing/vanishing changes what out/host means). The bootstrap (ai0) + the
# generated out/lib/*.h headers stay PINNED to canonical out/host paths and
# plain $(CC): ai0 never goes musl.
ho = out/host$(hsuf)
h_o = $(ai_c:$(R)/%.c=$(ho)/%.o)
# host/*.c: per-app host-nif files (auto-globbed, auto-registered via AI_NIF).
# Linked DIRECTLY into the binary (not via libai.a) so the ai_nifs section is
# never archive-collected. Drop a host/<app>.c in and it builds -- no rule edit.
host_o = $(patsubst host/%.c,$(ho)/host/%.o,$(wildcard host/*.c))
# the host runs $(tco) (common.mk; default 1 = tail-threaded, vmret-checked);
# ai0 below stays pinned 0, the deliberate trampoline-coverage lane.
# (-I$(ho) -Iout/lib for the generated egg/cli headers.)
# host_cc: STATIC picks musl-clang unless CC was set explicitly (the musl-gcc
# fallback below); ai0 and the lib tools stay on plain $(CC) either way.
host_cc = $(if $(STATIC),$(if $(cc_user),$(CC),musl-clang),$(CC))
hcc = $(host_cc) $(ai_cflags) -Dai_tco=$(tco) -fpic -I$(ho) -I. -Iout/lib
# whole-archive flag differs by linker (ld64 vs GNU ld); ai_typ is now a plain
# compare in ai.h, so there is no data.ld / generated data.h on any platform.
ifeq ($(shell uname -s),Darwin)
so_archive = -Wl,-force_load,$(ho)/libai.a       # ld64's whole-archive
# the host contract (ai_clock, ai_fd_port_vt, ai_stdin/out/err -- defined in
# host/main.c, linked into `ai` itself, NOT the archive) is UNRESOLVED in the .so
# by design: the loading executable provides it. GNU ld allows that by default;
# ld64 rejects undefined symbols in a dylib unless told to defer them.
so_undef = -Wl,-undefined,dynamic_lookup
else
so_archive = -Wl,--whole-archive $(ho)/libai.a -Wl,--no-whole-archive
endif
# STATIC=1 links a fully static `ai` against musl (and skips libai.so, which a
# static build can't produce) -- the OPT-IN portable-binary lane (was briefly
# the Linux default; demoted 2026-07-07, the why lives in common.mk's flavor
# block): the binary runs on ANY Linux distro regardless of
# glibc version AND still does DNS -- static *glibc* can't resolve hostnames
# (getaddrinfo needs NSS via dlopen, impossible when static), but musl resolves
# itself, so ain's `connect host port` works. Costs +1% size (~55K of text, the
# whole libc; the ~4M baked image dwarfs it) at the same test-corpus speed.
# musl-clang is clang (matches our clang default) + the musl libc -- the clean
# path. VALIDATED: fully static, `ldd` = not-a-dynamic-executable, runs,
# getaddrinfo baked in, full corpus green. `make STATIC=1` builds in its own
# out/host-musl tree -- no need to clean between flavors.
# musl is Linux-only -- this is the Linux portable-binary artifact, NOT the mac
# build (mac = a native Apple-clang build).
# FALLBACK: `STATIC=1 CC=musl-gcc` works too but is a gcc wrapper; on Arch its
# spec injects a phantom `-latomic_asneeded` (we use no real atomics -- only
# volatile sig_atomic_t flags), so it needs an empty stub on the link path:
#   ar rcs /tmp/libatomic_asneeded.a; make STATIC=1 CC=musl-gcc EXTRA_CFLAGS=-L/tmp
ifneq ($(STATIC),)
host_ldflags = -static
# the musl-clang wrapper injects LINK flags (-fuse-ld, -L…) into every clang call,
# incl. -c compiles, where clang warns "unused during compilation" -> our -Werror
# makes it fatal. Silence that one (harmless; gcc ignores unknown -Wno-*).
ai_cflags += -Wno-unused-command-line-argument
endif
# .hostcc -- the tree's compiler+link identity, content-stamped (cmp keeps the
# mtime when nothing changed). Every host object and the link depend on it, so
# an in-place flavor flip (musl-clang installed/removed flips what out/host
# means; an explicit CC=) rebuilds the tree instead of relinking mixed-libc
# objects (the sigsetjmp poison above -- a loud link error at best).
.PHONY: force_hostcc
force_hostcc: ;
$(ho)/.hostcc: force_hostcc
	@mkdir -p $(ho)
	@printf '%s\n' '$(host_cc) $(host_ldflags)' > $@.tmp
	@if cmp -s $@.tmp $@ 2>/dev/null; then rm -f $@.tmp; else mv $@.tmp $@; echo SH $@; fi
host: $(ho)/ai $(ho)/ai.baked $(if $(STATIC),,$(ho)/libai.so) $(ho)/ai.1 $(ho)/cook.1
ai0: $(ai0)

# dock: launch the steering dock (port/inle/serve.l) from a stable COPY out/host/dock,
# so `adopt` can rebuild the canonical out/host/ai in place without ETXTBSY (the RELINK
# writes the exe file in place; the bake itself is rename-safe). loads the full crew -- the probe ladder
# (judge), the server (serve), and the self-modify loop (drive + the model proposer patch).
# PORT overrides the mooring; bind loopback and firewall/tunnel it -- it evals what it reads.
.PHONY: dock
DOCK_PORT ?= 7620
dock: host
	@cp $(ho)/ai $(ho)/dock
	exec $(ho)/dock -l port/inle/judge.l -l port/inle/serve.l -l port/inle/drive.l -l port/inle/patch.l -e "(dock $(DOCK_PORT))"
# the default BOOT IMAGE: `$< --bake` boots the freshly-linked binary, snapshots the post-warm
# heap (the glaze baked in, x86-64), and lays it back into the binary's OWN .image section --
# host/image.c copies the exe, pwrites the blob at the section's file offset, and atomically
# renames over the original (no objcopy/objdump, ETXTBSY-proof: a new inode, so anyone still
# executing keeps the old one). A plain `ai` then wakes it at ~4 ms cold start (glazed by
# default) instead of eval'ing the egg (~230 ms). The load is an OPTIMIZATION -- main.c falls
# back to a normal egg boot on any mismatch, so a stale bake is never fatal, only slower.
# (~1.5 s to bake: the glaze self-tests native-compile; paid once per ai rebuild, not per run.)
# The .baked STAMP carries the dependency (the bake mutates the binary itself); a static
# pattern so the CANDIDATE bakes by the same recipe at its side path.
$(ho)/ai.baked $(ho)/ai.cand.baked: %.baked: %
	@echo BAKE	$<
	@$< --bake
	@touch $@


# candidate: build + bake the NEXT GENERATION at the side path out/host/ai.cand.
# nothing executes that name, so the in-place bake can never hit ETXTBSY -- a
# rebuild succeeds no matter who is running `ai` (a repl, a test, the dock's own
# client). gate it with `make test m=$(ho)/ai.cand` (m routes the whole corpus;
# ai0 is independent), then promote on green with an ATOMIC RENAME (a new inode:
# executing processes keep the old one) -- the dock's `adopt` does exactly this.
# on a red gate the canonical binary is UNTOUCHED; the failed candidate dies at
# the side path like a to-space that never flips.
.PHONY: candidate
candidate: $(ho)/ai.cand.baked


# rm the archive first: `ar r` REPLACES/ADDS but never REMOVES, so a renamed/dropped
# source (e.g. love.c -> ai.c) would leave a stale .o in the archive -> multiple-
# definition at link. the rm rebuilds it fresh, so a rename no longer needs `make clean`.
$(ho)/libai.a: $(h_o)
	@echo AR	$@
	@mkdir -p $(dir $@)
	@rm -f $@; ar rcs $@ $^

$(ho)/libai.so: $(ho)/libai.a
	@echo LD	$@
	@mkdir -p $(dir $@)
	@$(hcc) -shared -o $@ $(so_archive) $(so_undef)

# Bootstrap interpreter, compiled against the fallback top-level data.h (no
# -I$(ho)) + -DGL_BOOTSTRAP -Dai_tco=0 (also exercises the non-threaded trampoline
# dispatch). Runs the l build tools that generate the lcat headers, so it can't
# depend on those; instead it #includes the sed-wrapped $(gl0_h) (cli0 + the baked
# prel/ev/egg/repl + the test corpus), all produced without an interpreter --
# hence -Iout/lib. Per-object into $(ho)/0/ so ccache caches each TU.
gl0_cc = $(CCACHE) $(CC) $(ai_cflags) -DGL_BOOTSTRAP -Dai_tco=0 -I. -Iout/lib
ai0_o = out/host/0/main.o $(ai_c:$(R)/%.c=out/host/0/%.o)   # PINNED (not $(ho)/0)
out/host/0/main.o: host/main.c $(ai_h) $(gl0_h)
	@echo CC	$@
	@mkdir -p $(dir $@)
	@$(gl0_cc) -c $< -o $@
out/host/0/%.o: $(R)/%.c $(ai_h)
	@echo CC	$@
	@mkdir -p $(dir $@)
	@$(gl0_cc) -c $< -o $@
$(ai0): $(ai0_o)
	@echo LD	$@
	@mkdir -p $(dir $@)
	@$(CC) $(ai_cflags) -o $@ $(ai0_o)

# ai.c -> out/host/*.o
$(ho)/%.o: $(R)/%.c $(ai_h) $(ho)/.hostcc
	@echo CC	$@
	@mkdir -p $(dir $@)
	@$(hcc) -c $< -o $@

# l.o carries the version string (ai_version.h); relink it when the id changes.
$(ho)/ai.o $(ho)/0/ai.o: out/lib/ai_version.h
# host/main.o bakes the lcat lib headers inline (egg + prel/ev/cli/bao -- bao is the
# baked shell core now, subsuming the old repl.h). Now that it rides the host/*.c
# glob (compiled once, not recompiled on every link, as the old inline `$(hcc)
# main.c` did), recompile it when any baked header changes.
$(ho)/host/main.o: out/lib/egg.h out/lib/prel.h out/lib/ev.h out/lib/cli.h out/lib/bao.h out/lib/post.h out/lib/uu.h $(holo_h) $(glaze_h)
# host/cb.c rides port/quay/quay.c by unity include -- recompile when the engine moves.
$(ho)/host/cb.o: port/quay/quay.c port/quay/quay.h

# host/main.c (auto-globbed into $(host_o)) carries main() + the egg, assembled
# inline via G_EGG_PRE/POST. No separate main.c compile -- it rides the host/*.c
# glob now; the recompile-on-header-change dep is the line just above.
# one link rule, two names: `ai` (canonical) and `ai.cand` (the CANDIDATE -- the next
# generation built at a side path nothing executes, so the RELINK can never hit
# ETXTBSY no matter who is running `ai`; see the candidate target below).
$(ho)/ai $(ho)/ai.cand: $(host_o) $(ho)/libai.a $(ho)/.hostcc out/lib/egg.h out/lib/prel.h out/lib/ev.h out/lib/cli.h out/lib/bao.h out/lib/post.h out/lib/uu.h $(holo_h) $(glaze_h)
	@echo CC	$@
	@mkdir -p $(dir $@)
	@$(hcc) -o $@ $(host_o) $(ho)/libai.a $(host_ldflags)

$(ho)/ai.1: doc/ai.1 out/lib/ai_version.h
	@echo SED	$@
	@mkdir -p $(dir $@)
	@v=$$(sed -n 's/.*AI_VERSION "\(.*\)"/\1/p' out/lib/ai_version.h); \
	 sed "s/@VERSION@/$$v/" doc/ai.1 > $@

$(ho)/cook.1: doc/cook.1 out/lib/ai_version.h
	@echo SED	$@
	@mkdir -p $(dir $@)
	@v=$$(sed -n 's/.*AI_VERSION "\(.*\)"/\1/p' out/lib/ai_version.h); \
	 sed "s/@VERSION@/$$v/" doc/cook.1 > $@

