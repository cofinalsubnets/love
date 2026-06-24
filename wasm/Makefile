EMCC ?= /usr/lib/emscripten/emcc
# ccache wraps emcc for the per-object compiles below; override with
# `make CCACHE=` to disable. Caching only works because each source is
# compiled separately (-c) -- ccache passes through multi-source links.
CCACHE ?= $(shell command -v ccache 2>/dev/null)
emcc = $(CCACHE) $(EMCC)

# This frontend's build output directory under the top-level out/.
o = ../out/wasm

# g.c was split into per-concern translation units (kernel/*.c); build them all.
g_c = ../ai.c
g_h = $(wildcard ../*.h)

# One object per source so an edit recompiles just that TU (and so ccache
# can cache each compile). Local host.c stays rooted in cwd; shared kernel/*.c
# carry the ../ prefix, mapped into $(o)/ by the patsubst.
host_o = $(o)/host.o
core_o = $(g_c:../%.c=$(o)/%.o)
objs = $(host_o) $(core_o)

CFLAGS = -std=gnu2x -O2 -g0 -Dai_tco=0 \
  -Wall -Wno-unused-parameter -Wno-shift-negative-value \
  -fno-exceptions \
  -I.. -I../out/lib

EMFLAGS = \
  -sMODULARIZE=1 -sEXPORT_NAME=Ai \
	-sASSERTIONS -sSINGLE_FILE=1 \
  -sINITIAL_MEMORY=16MB -sALLOW_MEMORY_GROWTH=1 \
  -sEXPORTED_FUNCTIONS=_ai_init,_ai_eval,_ai_out_ptr,_ai_out_len,_ai_out_reset,_malloc,_free \
  -sEXPORTED_RUNTIME_METHODS=ccall,cwrap,UTF8ToString,stringToUTF8,lengthBytesUTF8,HEAPU8,HEAPU32

all: ai.js

# prel.h/ev.h are serialized from lib/*.g by the top-level lcat rule;
# host.c assembles them into the bootstrap via G_EGG_PRE/POST (no repl here --
# the browser feeds the REPL through ai_eval).
../out/lib/egg.h: ../ai/egg.l
../out/lib/prel.h: ../ai/prel.l
../out/lib/ev.h: ../ai/ev.l
../out/lib/egg.h ../out/lib/prel.h ../out/lib/ev.h ../out/lib/ai_version.h:
	$(MAKE) -C .. out/lib/$(notdir $@)

# ai.o bakes the version string (ai_version.h, via ai.c's __has_include), so
# regenerate it through the parent (force_version) and recompile ai.o when the
# id changes -- mirrors the host build's l.o relink. Without this the browser
# banner (ai-version) drifts to whatever revision ai.o was last built at.
#
# The committed ai.js is ALWAYS built from a tree that ai.js itself dirties, so
# `git describe --dirty` would brand the page banner "-dirty" in perpetuity --
# cosmetic, but it reads as broken. Map it to "-wasm" in a wasm-local copy (same
# revision, honest "this is the browser build"); a clean tree just keeps the bare
# id. Compile ai.o against it -- -I$(o) wins the "ai_version.h" quote-include
# over ../out/lib, so the host build's honest -dirty is untouched.
$(o)/ai_version.h: ../out/lib/ai_version.h
	@mkdir -p $(dir $@)
	@sed 's/-dirty"/-wasm"/' $< > $@

$(o)/ai.o: ../ai.c $(g_h) $(o)/ai_version.h
	@mkdir -p $(dir $@)
	$(emcc) -I$(o) $(CFLAGS) -c $< -o $@

# Link step: emcc's link is multi-input, so ccache can't cache it -- use
# bare $(EMCC). EMFLAGS (MODULARIZE, exports, memory) only apply here.
ai.js: $(objs)
	$(EMCC) $(CFLAGS) $(EMFLAGS) $(objs) -o $@

$(o)/host.o: host.c ../out/lib/egg.h ../out/lib/prel.h ../out/lib/ev.h $(g_h)
	@mkdir -p $(dir $@)
	$(emcc) $(CFLAGS) -c $< -o $@

$(o)/%.o: ../%.c $(g_h)
	@mkdir -p $(dir $@)
	$(emcc) $(CFLAGS) -c $< -o $@

serve: all
	python3 -m http.server 8000

# clean only the build intermediates ($(o) = ../out/wasm). ai.js is a TRACKED,
# committed artifact (the .githooks pre-commit keeps it fresh), so clean must
# NOT delete it -- doing so left a spurious `D wasm/ai.js` after every top-level
# `make clean`. (l.wasm was a dead pre-rename name; SINGLE_FILE=1 embeds the
# wasm into ai.js, so no standalone .wasm is ever emitted.)
clean:
	rm -rf $(o)

.PHONY: all serve clean
