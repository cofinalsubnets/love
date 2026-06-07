EMCC ?= /usr/lib/emscripten/emcc
# ccache wraps emcc for the per-object compiles below; override with
# `make CCACHE=` to disable. Caching only works because each source is
# compiled separately (-c) -- ccache passes through multi-source links.
CCACHE ?= $(shell command -v ccache 2>/dev/null)
emcc = $(CCACHE) $(EMCC)

# This frontend's build output directory under the top-level out/.
o = ../out/wasm

# g.c was split into per-concern translation units (kernel/*.c); build them all.
g_c = ../gwen.c ../data.c
g_h = $(wildcard ../*.h)

# One object per source so an edit recompiles just that TU (and so ccache
# can cache each compile). Local host.c stays rooted in cwd; shared kernel/*.c
# carry the ../ prefix, mapped into $(o)/ by the patsubst.
host_o = $(o)/host.o
core_o = $(g_c:../%.c=$(o)/%.o)
objs = $(host_o) $(core_o)

# inc/ holds wasm's <data.h> override (no flat code-address space, so it
# resolves data kinds by sentinel ap rather than .gwen_data slot index).
# It must be its own include dir, NOT ".": emcc deprioritizes the compiler's
# cwd in the <...> search path, which would let ../data.h win instead.
CFLAGS = -std=gnu2x -Os -g0 -Dg_tco=0 \
  -Wall -Wno-unused-parameter -Wno-shift-negative-value \
  -fno-exceptions \
  -Iinc -I.. -I../out/lib

EMFLAGS = \
  -sMODULARIZE=1 -sEXPORT_NAME=GwenModule \
	-sASSERTIONS -sSINGLE_FILE=1 \
  -sINITIAL_MEMORY=16MB -sALLOW_MEMORY_GROWTH=1 \
  -sEXPORTED_FUNCTIONS=_gwen_init,_gwen_eval,_gwen_out_ptr,_gwen_out_len,_gwen_out_reset,_malloc,_free \
  -sEXPORTED_RUNTIME_METHODS=ccall,cwrap,UTF8ToString,stringToUTF8,lengthBytesUTF8,HEAPU8,HEAPU32

all: gwen.js

# prelude.h/ev.h are serialized from lib/*.g by the top-level lcat rule;
# host.c assembles them into the bootstrap via G_EGG_PRE/POST (no repl here --
# the browser feeds the REPL through gwen_eval).
../out/lib/egg.h: ../gwen/egg.g
../out/lib/prelude.h: ../gwen/prelude.g
../out/lib/ev.h: ../gwen/ev.g
../out/lib/egg.h ../out/lib/prelude.h ../out/lib/ev.h:
	$(MAKE) -C .. out/lib/$(notdir $@)

# Link step: emcc's link is multi-input, so ccache can't cache it -- use
# bare $(EMCC). EMFLAGS (MODULARIZE, exports, memory) only apply here.
gwen.js: $(objs)
	$(EMCC) $(CFLAGS) $(EMFLAGS) $(objs) -o $@

$(o)/host.o: host.c ../out/lib/egg.h ../out/lib/prelude.h ../out/lib/ev.h $(g_h)
	@mkdir -p $(dir $@)
	$(emcc) $(CFLAGS) -c $< -o $@

$(o)/%.o: ../%.c $(g_h)
	@mkdir -p $(dir $@)
	$(emcc) $(CFLAGS) -c $< -o $@

serve: all
	python3 -m http.server 8000

clean:
	rm -rf gwen.js gwen.wasm $(o)

.PHONY: all serve clean
