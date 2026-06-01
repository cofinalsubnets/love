# Shared variables for the host, kernel, and playdate Makefiles.
# Each includer sets R to the relative path to the project root before
# including this file: the root Makefile sets R := . and subdir Makefiles
# (h/, k/, pd/) set R := .. so the paths below resolve from any cwd.
R ?= .

n = gl
x = g
m = $R/host/b/$n
a ?= $(shell uname -m)

t = $(sort $(wildcard $R/test/*.$x))

g_h = $(wildcard $R/core/*.h)
g_c = $(wildcard $R/core/*.c)
f_c = $(wildcard $R/font/*.c)
c_c = $(wildcard $R/libc/*.c)

g_cflags = -std=gnu23 -g -O2 -pipe \
  -Wall -Wextra -Werror -Wstrict-prototypes -Wno-unused-parameter \
  -Wmissing-field-initializers \
  -falign-functions -fomit-frame-pointer -fno-stack-check -fno-stack-protector \
  -fno-exceptions -fno-asynchronous-unwind-tables \
  -fcf-protection=none
