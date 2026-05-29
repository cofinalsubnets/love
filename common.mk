# Shared variables for the host, kernel, and playdate Makefiles.
# Each includer sets R to the relative path to the project root before
# including this file: the root Makefile sets R := . and subdir Makefiles
# (h/, k/, pd/) set R := .. so the paths below resolve from any cwd.
R ?= .

n = gl
x = g
m = $R/h/b/$n
a ?= $(shell uname -m)

t = $(sort $(wildcard $R/t/*.$x))

g_h = $(wildcard $R/g/*.h)
g_c = $(wildcard $R/g/*.c)
f_c = $(wildcard $R/f/*.c)
c_c = $(wildcard $R/libc/*.c)

g_cflags = -std=gnu23 -g -Os -pipe \
  -Wall -Wextra -Wstrict-prototypes -Wno-unused-parameter \
  -Wmissing-field-initializers \
  -falign-functions -fomit-frame-pointer -fno-stack-check -fno-stack-protector \
  -fno-exceptions -fno-asynchronous-unwind-tables -fno-stack-clash-protection \
  -fcf-protection=none
