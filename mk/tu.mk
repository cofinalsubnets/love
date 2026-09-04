# the core's translation units, in link order. its own file because two builds need it:
# mk/common.mk for every seat, and wasm/Makefile, which is a separate make invocation.
# a seat that links the runtime links all of these.
love_tu = love.c gc.c ev.c io.c map.c snap.c num.c arr.c
