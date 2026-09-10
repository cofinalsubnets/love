EMCC ?= /usr/lib/emscripten/emcc
# ccache wraps emcc for the per-object compiles below (`make CCACHE=` disables). It only
# caches because each source compiles separately -- ccache passes multi-source links through.
CCACHE ?= $(shell command -v ccache 2>/dev/null)
emcc = $(CCACHE) $(EMCC)

# This frontend's build output directory under the top-level b/.
o = ../../b/wasm

# the whole core, off the one roster: a list spelled again here goes stale the next time
# a TU is added, and a short g_c compiles a fraction of the core into a link that still
# works until it does not. common.mk carries love_tu, so this reads the membership the
# rest of the tree reads. g_h is core whole, so every object keeps a header dep.
R := ../..
include $(R)/common.mk
g_c = $(patsubst %,../../l/%,$(love_tu)) ../../a/moon/lib/moonlibc/math/am.c \
      ../../i/horn.c
g_h = $(wildcard ../../l/*.h)

# One object per source, so an edit recompiles just that TU and ccache can cache each.
# Local host.c stays rooted in cwd; shared kernel/*.c carry ../../, mapped in by the patsubst.
host_o = $(o)/host.o
core_o = $(g_c:../../%.c=$(o)/%.o)
objs = $(host_o) $(core_o)

CFLAGS = -std=gnu2x -O2 -g0 -Dai_tco=0 \
  -Wall -Wno-unused-parameter -Wno-shift-negative-value \
  -fno-exceptions \
  -I../.. -I../../love -I../../i -I../../b/lib

EMFLAGS = \
  -sMODULARIZE=1 -sEXPORT_NAME=Love \
	-sASSERTIONS -sSINGLE_FILE=1 \
  -sINITIAL_MEMORY=16MB -sALLOW_MEMORY_GROWTH=1 \
  -sEXPORTED_FUNCTIONS=_ai_init,_ai_eval,_ai_out_ptr,_ai_out_len,_ai_out_reset,_ai_mirror,_ai_palette,_ai_unfold,_ai_key,_ai_runnable,_ai_alive,_ai_horn_rate,_ai_horn_chans,_ai_horn_drain,_malloc,_free \
  -sEXPORTED_RUNTIME_METHODS=ccall,cwrap,UTF8ToString,stringToUTF8,lengthBytesUTF8,HEAPU8,HEAPU32

# a failed recipe takes its half-written target with it -- else a 0-byte artifact carries a
# fresh mtime and the next make calls it up to date. the root does not include this file,
# so it is said here. see ../../Makefile.
.DELETE_ON_ERROR:

all: $(o)/love.js

# these are serialized from l/boot/*.l by the top-level lcat rule; host.c assembles them into
# the bootstrap via G_EGG_PRE/POST -- no repl here, the browser feeds it through ai_eval.
../../b/lib/egg.h: ../../l/boot/egg.l
../../b/lib/post.h: ../../l/boot/post.l
../../b/lib/p1.h: ../../l/boot/p1.l
../../b/lib/prel.h: ../../l/boot/prel.l
../../b/lib/ev.h: ../../l/boot/ev.l
../../b/lib/egg.h ../../b/lib/post.h ../../b/lib/p1.h ../../b/lib/prel.h ../../b/lib/ev.h ../../b/lib/love_version.h:
	$(MAKE) -C $(R) b/lib/$(notdir $@)

# love.c bakes the version string (its __has_include of love_version.h), so recompile it
# when ./VERSION moves -- else the browser banner keeps whatever id love.o last saw.
# ..and the version header lands on the TU that carries the id. the path is the one
# core_o's patsubst actually makes: ../../l/love.c -> $(o)/l/love.o. Spelled l/ this
# rule named a target nothing builds, so the dependency was simply not there.
$(o)/l/love.o: ../../b/lib/love_version.h

# the link is multi-input, so ccache cannot cache it -- bare $(EMCC), and EMFLAGS apply only
# here. the page rides the machine now (w/wasm/love-wasm.*), so this build lands
# under b/ only: the differential beside ours, never the artifact.
emlink = $(EMCC) $(CFLAGS) $(EMFLAGS) $(objs) -o $@

$(o)/love.js: $(objs)
	@echo 'LD	'$@
	@mkdir -p $(dir $@)
	@$(emlink)

# what test_wasm asks for: the link, out of tree.
.PHONY: gate
gate: $(o)/love.js

$(o)/host.o: host.c ../../b/lib/egg.h ../../b/lib/post.h ../../b/lib/p1.h ../../b/lib/prel.h ../../b/lib/ev.h $(g_h)
	@echo 'CC	'$@
	@mkdir -p $(dir $@)
	@$(emcc) $(CFLAGS) -c $< -o $@

$(o)/%.o: ../../%.c $(g_h)
	@echo 'CC	'$@
	@mkdir -p $(dir $@)
	@$(emcc) $(CFLAGS) -c $< -o $@

serve: all
	python3 -m http.server 8000

# SINGLE_FILE=1 embeds the wasm into love.js, so no standalone .wasm is ever emitted.
clean:
	rm -rf $(o)

.PHONY: all serve clean
