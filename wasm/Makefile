EMCC ?= /usr/lib/emscripten/emcc
# ccache wraps emcc for the per-object compiles below; override with
# `make CCACHE=` to disable. Caching only works because each source is
# compiled separately (-c) -- ccache passes through multi-source links.
CCACHE ?= $(shell command -v ccache 2>/dev/null)
emcc = $(CCACHE) $(EMCC)

# This frontend's build output directory under the top-level b/.
o = ../b/wasm

# g.c was split into per-concern translation units (kernel/*.c); build them all.
g_c = ../gwen.c ../vt.c
g_h = $(wildcard ../*.h)

# One object per source so an edit recompiles just that TU (and so ccache
# can cache each compile). Local host.c stays rooted in cwd; shared kernel/*.c
# carry the ../ prefix, mapped into $(o)/ by the patsubst.
host_o = $(o)/host.o
core_o = $(g_c:../%.c=$(o)/%.o)
objs = $(host_o) $(core_o)

# inc/ holds wasm's <vt.h> override (no flat code-address space, so it
# resolves data kinds by sentinel ap rather than .gwen_data_vt slot index).
# It must be its own include dir, NOT ".": emcc deprioritizes the compiler's
# cwd in the <...> search path, which would let ../vt.h win instead.
CFLAGS = -std=gnu2x -Os -g0 -Dg_tco=0 \
  -Wall -Wno-unused-parameter -Wno-shift-negative-value \
  -fno-exceptions \
  -Iinc -I.. -I../b/lib

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
../b/lib/prelude.h: ../gwen/prelude.g
../b/lib/ev.h: ../gwen/ev.g
../b/lib/prelude.h ../b/lib/ev.h:
	$(MAKE) -C .. b/lib/$(notdir $@)

# Link step: emcc's link is multi-input, so ccache can't cache it -- use
# bare $(EMCC). EMFLAGS (MODULARIZE, exports, memory) only apply here.
gwen.js: $(objs)
	$(EMCC) $(CFLAGS) $(EMFLAGS) $(objs) -o $@

$(o)/host.o: host.c ../b/lib/prelude.h ../b/lib/ev.h $(g_h)
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
