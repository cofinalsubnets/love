# Shared variables for the host and free (freestanding kernel) builds, and
# for out-of-tree ports (the ll-ports repo). Each includer sets R to the
# relative path to the project root before including this file (the root
# Makefile sets R := .) so the paths below resolve from any cwd.
# Per-frontend build output lives under $R/out/<frontend>/.
R ?= .

n = ll
x = l
m = $R/out/host/$n
a ?= $(shell uname -m)

# the corpus: 00-init's harness first, the root spec second, then the rest
t = $R/test/00-init.$x $R/CLAUDE.$x $(filter-out %/00-init.$x,$(sort $(wildcard $R/test/*.$x)))

g_h = $(wildcard $R/*.h)
g_c = $R/ll.c $R/data.c
f_c = $(wildcard $R/font/*.c)
c_c = $(wildcard $R/libc/*.c)

g_cflags = -std=gnu23 -g -O2 -pipe \
  -Wall -Wextra -Werror -Wstrict-prototypes -Wno-unused-parameter \
  -Wmissing-field-initializers -Wno-implicit-fallthrough\
  -falign-functions=16 -fomit-frame-pointer -fno-stack-check -fno-stack-protector \
  -fno-exceptions -fno-asynchronous-unwind-tables \
  -fcf-protection=none
