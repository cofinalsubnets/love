# shared variables for the host, kernel and board builds. an includer sets R to the project
# root first, so these resolve from any cwd; output lands in $R/out/<frontend>/.
R ?= .
S = $(R)/src

# the recipe tag column is `@echo 'MOON<TAB>'$@`, and the quote is load-bearing: a bare tab
# only separates argv, which echo rejoins with a space. one line per target and nothing else,
# paths relative to the tree (`make install` excepted, its artifact landing outside it).
# the tag names the tool that RAN: `love seed` and `love serve` arm the build (src/apps/source.l's
# src-arm) so a recipe's `cat` is kore's and its shell is lush; LOVE_ARMED is the arm's word.
armed  := $(if $(LOVE_ARMED),1,)
t_sh   := $(if $(armed),LUSH,SH)
t_cat  := $(if $(armed),KORE,CAT)
t_sed  := $(if $(armed),KORE,SED)
t_ld   := $(if $(armed),MOON,LD)
t_cc   := $(if $(armed),MOON,CC)
t_ar   := $(if $(armed),KORE,AR)
t_cp   := $(if $(armed),KORE,CP)
t_rm   := $(if $(armed),KORE,RM)
t_ln   := $(if $(armed),KORE,LN)

m = $R/out$(hsuf)/love
# the gates' shell: lush aboard the love under test, so the loves a gate runs fork warm.
# -g puts PATH first: a bare grep or tar is the GNU one a gate holds ours against
gsh = $m lush -g
# the HOST's arch, which $a is not: a cross lane overrides $a on the command line, and
# anything under out reading $a then lays a cross artifact into the host tree.
# `uname -m` is not the ISA word either -- the BSDs say amd64 for x86_64, freebsd arm64 and
# netbsd evbarm for aarch64, and evbarm names a 32-bit port too, so there the ISA has to come
# from `uname -p`. flat ifeqs: cook reads `else ifeq` as a bare else and drops the condition.
uname_m := $(shell uname -m)
hosta := $(uname_m)
ifeq ($(uname_m),evbarm)
hosta := $(shell uname -p)
endif
ifeq ($(hosta),x86_64)
hosta := x64
endif
ifeq ($(hosta),amd64)
hosta := x64
endif
ifeq ($(hosta),aarch64)
hosta := a64
endif
ifeq ($(hosta),arm64)
hosta := a64
endif
ifeq ($(hosta),riscv64)
hosta := rv64
endif
# `?=` MAKES A RECURSIVE VARIABLE, so `a ?= $(shell uname -m)` re-forks uname at every
# reference; the simply-expanded $(hosta) keeps the override and spends one fork for the tree.
a ?= $(hosta)

# what the world calls the machine, where the arch word is the holo backend's name and the
# mksys suffix. read by COMPUTED NAME only, so a grep for a row finds nothing: $(uname_$a)
# names qemu-system-* and the ovmf image, $(uname_$(xa)) is test_fat's key into the fat
# prefix's `uname -m` case, whose arms src/tools/fatpack.l spells with every name for one ISA.
uname_x64  = x86_64
uname_a64  = aarch64
uname_rv64 = riscv64

# THE VERSION is ./VERSION and the whole of it, moving only when a release does. no VCS suffix
# anywhere, so the tarball name, love_version.h and `.comment` carry one string -- which is
# what lets love0's stamp agree with a real one (see boot_cc).
love_base := $(shell cat $R/VERSION 2>/dev/null || echo 0)

# checkout or unpacked release? `git -C DIR` walks UP, so the test is for THIS tree's own .git
# and never an ancestor's. one reader, the DEFAULT GOAL: a checkout wants the fast gate for its
# edit loop, an unpacked release wants the product.
in_git := $(wildcard $R/.git)

# the BUILD STAMP orders two builds of one VERSION: the commit time of HEAD in seconds, or an
# unpacked release's own STAMP, which selfpack writes into every archive and no tree tracks
love_stamp := $(if $(wildcard $R/STAMP),$(shell cat $R/STAMP),$(if $(in_git),$(shell git -C $R log -1 --format=%ct 2>/dev/null || echo 0),0))

# $(CC) is the ambient compiler and the tree names no favourite: mooncc builds everything but
# love0, which by definition cannot be built by the compiler it exists to bootstrap.

# WHO LINKS `love`: mooncc by default, and the whole vm with it. HCC=1 takes the $(CC) lane,
# the one differential a foreign cc still gets and the only build that puts one on the vm at
# ai_tco=1, where ai_musttail is live (doc/misc/moon-c-gaps.md). its own tree, out/cc, because
# the two loves are the same path otherwise; $m follows it so a test runs the one you asked for.
override HCC := $(filter-out 0,$(HCC))

# ai_tco: 1 = the tail-threaded VM (aps tail-jump, never return -- `make vmret` verifies it per
# binary), 0 = the trampoline loop. the host runs $(tco); the kernel lane and the wasm seat take
# src/love/love.h's own default of 1, wasm's return_call being worth 1.31x. PINNED to 0 on love0
# (the deliberate trampoline-coverage lane) and the two seats with no sibcall, mps2's thumb1
# face and the playdate simulator.
tco ?= 1

# tco earns a tree the way HCC does: a tco=0 love is a different binary at the same path, so
# sharing out would rebuild the world each make and a test would run whichever flavour came
# last. DOOM earns one on the same reading -- two extra TUs and a flag on every kernel TU.
hsuf := $(if $(HCC),/cc,)$(if $(DOOM),/doom,)$(if $(filter 0,$(tco)),/tco0,)

# the corpus: the harness first, the spec second, then uu.l -- front-loaded EXPLICITLY so its
# dependents (uukind*, uulay, uupatch, uuwm*) see it whatever the collation orders, a locale
# `ls` putting uukind* first. glaze-x86 and glaze-hook execute native machine code, so they
# ride their own arch-guarded targets, never the arch-neutral corpus.
t = $R/test/00-init.l $R/test/spec.l $R/test/uu.l $(filter-out %/00-init.l %/spec.l %/glaze-x86.l %/glaze-hook.l %/uu.l,$(sort $(wildcard $R/test/*.l)))

# the runtime's own headers, and src/love/ is the roster: kernel mode's k.h and the per-ISA
# asmops sit under src/inle/, so a touch on one of those rebuilds no love object.
love_h = $(wildcard $S/love/*.h)
# the core rides its own math floor, no libm anywhere; love.c broke into TUs so the biggest is
# not the whole build's critical path. a LINK ORDER, so it stays named where the other sets
# glob -- $(wildcard) answers readdir order.
love_tu = love.c gc.c ev.c task.c io.c map.c snap.c num.c arr.c
# ..and snap.c reaches the codec unconditionally to pack an image's code segment, so a seat
# that links the runtime links it: the one library in lib/ the core itself calls.
love_codec = lib/gz.c
core_tu = $(love_tu) $(love_codec)
love_tu_c = $(patsubst %,$S/love/%,$(core_tu))
love_c = $(love_tu_c) $S/apps/moon/lib/moonlibc/math/am.c
# the per-ISA set ONE machine's build takes; the directory is the roster, empty on an arch with
# no seat, which is what the rebuild gates read to skip their kernel half.
hosta_c = $(wildcard $S/inle/$(hosta)/*.c)
# ..and the surface over the interface: src/love/ less the core, the board seat (bare.c, nohorn.c)
# and noblob.c, which a LINK names for itself, plus lib/'s nif libraries. user and kernel
# mode both take it -- moonlibc's __ai_sys is the one door under it, whoever answers. drop a
# src/love/<app>.c in and its nifs register with no rule edit.
host_c = $(filter-out $(addprefix $S/love/,$(love_tu) bare.c nohorn.c noblob.c),$(wildcard $S/love/*.c)) \
         $(filter-out $S/love/$(love_codec),$(wildcard $S/love/lib/*.c))
# the tree cuts at moonlibc's interface: src/love/ is everything over it, src/love/user/ the seats
# where another kernel answers, and src/inle/ kernel mode, where we do. quay draws into a buffer
# and names no device, so it is over the door. paint.c (32bpp) and nif.c (the love door) are
# per-seat -- a 1-bit device wants neither, the host unity-includes nif.c -- so a seat that
# wants one NAMES it rather than taking it here.
f_c = $(filter-out %/paint.c %/nif.c,$(wildcard $S/love/quay/*.c))
# inle's libc is moonlibc's, named member by member; os.c is the map every syscall reaches it
# through, and a negative __ai_osv (written at kmain) takes the __ai_inle arm, src/inle/sys.c
# answering the canonical numbers in C. mooncc builds the kernel, so it builds the kernel's
# libc too -- no second copy to drift. this is src/love/posix.c's closure plus the members love.c's
# hosted compile reaches (the mmap family behind the W^X arena's runtime branch, refused
# -ENOSYS on metal). core.c stays OUT: malloc, the process entry and the std streams are all
# the kernel's, and src/inle/sys.c answers its four seat symbols instead (environ, stdout/stderr,
# the sigaction restorer).
# NAMING A MEMBER HERE IS A DECISION, and stdio was the one weighed: printf writes fd 1 itself
# and src/inle/sys.c is seat-blind, so a seated task's C-level printf reaches the console where its
# port reaches the pipe -- the divergence src/inle/sys.c documents.
c_c = $(addprefix $S/apps/moon/lib/moonlibc/string/,memchr.c memcmp.c memcpy.c memmove.c memset.c strlen.c) \
  $(addprefix $S/apps/moon/lib/moonlibc/sys/,read.c write.c birth.c \
    chdir.c chmod.c chown.c clock_gettime.c close.c dup2.c fcntl.c fork.c fstat.c getcwd.c \
    ftruncate.c getgid.c getpgrp.c getpid.c getpriority.c getrlimit.c getrusage.c getuid.c setrlimit.c ioctl.c kevent.c kill.c kqueue.c \
    link.c lseek.c lstat.c madvise.c mkdir.c mmap.c mount.c mprotect.c munmap.c open.c pipe.c poll.c raise.c readlink.c \
    rename.c rmdir.c setpgid.c setsid.c stat.c statfs.c symlink.c sysconf.c sysctl.c umask.c uname.c fsync.c fdatasync.c \
    unlink.c unshare.c utimensat.c waitpid.c) \
  $(addprefix $S/apps/moon/lib/moonlibc/dirent/,closedir.c opendir.c readdir.c) \
  $(addprefix $S/apps/moon/lib/moonlibc/signal/,grantpt.c posix_openpt.c ptsname.c \
    sigaction.c sigaddset.c sigemptyset.c signal.c signalfd.c sigprocmask.c \
    tcgetattr.c tcsetattr.c tcsetpgrp.c unlockpt.c) \
  $(addprefix $S/apps/moon/lib/moonlibc/proc/,atexit.c execv.c execvp.c exit.c fexecve.c) \
  $(addprefix $S/apps/moon/lib/moonlibc/env/,getenv.c setenv.c unsetenv.c) \
  $(addprefix $S/apps/moon/lib/moonlibc/stdio/,fflush.c femit.c pad.c semit.c) \
  $S/apps/moon/lib/moonlibc/fmt/fprintf.c \
  $S/apps/moon/lib/moonlibc/os.c

# CANCEL MAKE'S LEX RULE. `.l` is Lex's extension, so a built-in `%.c: %.l` stands over every
# source in this tree, and where a `<name>.l` sits beside a real `<name>.c` make runs lex on
# it, fails, and DELETES THE C. an empty recipe unmakes the rule.
%.c: %.l
%.r: %.l
%.ln: %.l
.l.c:
.l.r:
.l.ln:

# the dialect we target, and mooncc's own aim -- doc/misc/moon-c-gaps.md is the ledger.
cstd := c11

# these ride the AMBIENT cc and nothing else: the mooncc recipes take none of them, so what
# they read is the hosted half (love0's objects), never the kernel's own C.
cflags = -std=$(cstd) -g -O2 -pipe $(EXTRA_CFLAGS) \
  -Wall -Wextra -Wstrict-prototypes -Wno-unused-parameter \
  -Wmissing-field-initializers -Wno-implicit-fallthrough\
  -falign-functions=16 -fno-stack-protector
# -fcf-protection (Intel CET) is x86-only; the other seats take it as a no-op.
cflags += -fcf-protection=none
# a strict -std sets __STRICT_ANSI__ and glibc then hides its POSIX half, which src/love/main.c
# owes clock_gettime and kill to, so the level is asked for by name. but it is GLIBC'S ask: a
# BSD header defaults to its whole surface and reads this as a NARROWING -- freebsd drops
# __BSD_VISIBLE the moment it is defined, taking MSG_DONTWAIT, SOCK_CLOEXEC and the pty
# quartet, with no additive macro to win them back.
ifeq ($(filter FreeBSD NetBSD,$(shell uname -s)),)
cflags += -D_POSIX_C_SOURCE=200809L
endif
# the data-sentinel tiling src/love/love.h's ai_typ reads (src/love/love.c's DSENT), on every ld/lld link.
data_ld = -Wl,-T,$S/love/love_data.ld
