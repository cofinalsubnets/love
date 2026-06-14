# Shared variables for the host and free (freestanding kernel) builds, and
# for out-of-tree ports (the l-ports repo). Each includer sets R to the
# relative path to the project root before including this file (the root
# Makefile sets R := .) so the paths below resolve from any cwd.
# Per-frontend build output lives under $R/out/<frontend>/.
R ?= .

n = love
x = l
m = $R/out/host/$n
a ?= $(shell uname -m)

# g_tco for the builds that can take it: 1 = the tail-threaded VM (aps tail-jump,
# never return -- `make vmret` verifies it per binary), 0 = the trampoline loop.
# The host runs $(tco). PINNED ELSEWHERE: love0 stays 0 (the deliberate
# trampoline-coverage lane) and the kernel test build stays 0 (hangs at 1 --
# see the K_TEST block in the root Makefile).
tco ?= 1

# the corpus: 00-init's harness first, the root spec second, then the rest
t = $R/test/00-init.$x $R/CLAUDE.$x $(filter-out %/00-init.$x,$(sort $(wildcard $R/test/*.$x)))

g_h = $(wildcard $R/*.h)
g_c = $R/love.c $R/data.c
f_c = $(wildcard $R/font/*.c)
c_c = $(wildcard $R/libc/*.c)

g_cflags = -std=gnu23 -g -O2 -pipe $(EXTRA_CFLAGS) \
  -Wall -Wextra -Werror -Wstrict-prototypes -Wno-unused-parameter \
  -Wmissing-field-initializers -Wno-implicit-fallthrough\
  -falign-functions=16 -fomit-frame-pointer -fno-stack-check -fno-stack-protector \
  -fno-exceptions -fno-asynchronous-unwind-tables \
  -fcf-protection=none
