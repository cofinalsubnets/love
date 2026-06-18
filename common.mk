# Shared variables for the host and free (freestanding kernel) builds, and
# for out-of-tree ports (the l-ports repo). Each includer sets R to the
# relative path to the project root before including this file (the root
# Makefile sets R := .) so the paths below resolve from any cwd.
# Per-frontend build output lives under $R/out/<frontend>/.
R ?= .

m = $R/out/host/ai
a ?= $(shell uname -m)

# clang is the default host/ai0 compiler (every dev machine here has it; mac's
# `cc` is clang anyway, and the kernel build already defaults KCC=clang). NB: a
# plain `CC ?= clang` is a no-op -- make ships a built-in default `CC = cc` (origin
# `default`, not `undefined`), so `?=` never fires. Override the built-in default
# explicitly while still honoring an env/CLI `CC=` (origin command line/environment):
# `make CC=gcc`, or a static-musl build `make STATIC=1 CC=musl-clang` (see hsuf).
ifeq ($(origin CC),default)
CC = clang
endif

# ai_tco for the builds that can take it: 1 = the tail-threaded VM (aps tail-jump,
# never return -- `make vmret` verifies it per binary), 0 = the trampoline loop.
# The host runs $(tco). PINNED ELSEWHERE: ai0 stays 0 (the deliberate
# trampoline-coverage lane) and the kernel test build stays 0 (hangs at 1 --
# see the K_TEST block in the root Makefile).
tco ?= 1

# the corpus: 00-init's harness first, the spec second, then the rest
t = $R/test/00-init.l $R/test/spec.l $(filter-out %/00-init.l %/spec.l,$(sort $(wildcard $R/test/*.l)))

ai_h = $(wildcard $R/*.h)
ai_c = $R/ai.c
f_c = $(wildcard $R/font/*.c)
c_c = $(wildcard $R/libc/*.c)

# -std spelling: clang accepts `gnu23` only from ~clang 18 (Xcode 16). Older Apple
# clang on an old mac wants `gnu2x` (the pre-final spelling). Probe $(CC) once and
# fall back, so the host builds on whatever clang the machine ships.
ai_std := $(shell printf 'int main(void){return 0;}' | $(CC) -std=gnu23 -x c -c -o /dev/null - 2>/dev/null && echo gnu23 || echo gnu2x)

ai_cflags = -std=$(ai_std) -g -O2 -pipe $(EXTRA_CFLAGS) \
  -Wall -Wextra -Werror -Wstrict-prototypes -Wno-unused-parameter \
  -Wmissing-field-initializers -Wno-implicit-fallthrough\
  -falign-functions=16 -fomit-frame-pointer -fno-stack-check -fno-stack-protector \
  -fno-exceptions -fno-asynchronous-unwind-tables
# -fcf-protection (Intel CET) is x86-only -- Apple/arm clang rejects it as an
# error. Keep it on every non-Darwin build (Linux x86 + the cross kernels take
# it as before); macOS does without (it has no CET to turn off).
ifneq ($(shell uname -s),Darwin)
ai_cflags += -fcf-protection=none
endif
