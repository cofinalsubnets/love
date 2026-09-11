# Playdate build. Run from the project root via `make -C i/playdate`, or
# directly via `cd i/playdate && make`. Output lands in $(R)/b/playdate/
# ($n.pdx at the top). Requires PLAYDATE_SDK_PATH for the C_API headers, the
# simulator, and pdc, which bundles the .pdx.
#
# NOTHING FOREIGN COMPILES OR LINKS THE DEVICE HALF. mooncc -t thumb2sp builds
# every object, pdglue.c included -- it owns pd_api.h and flattens the SDK to a
# word-only seam -- and our own linker binds them: -Ttext 0 because link_map.ld
# names no address at all, --emit-relocs so the ABS32 sites survive for a loader
# that places the image where it likes, -nostdlib because the six moonlibc
# members and rt.c beside them are the whole runtime this seat wants. la rides
# pooled ABS32 words on this target, which is what makes the relocation table
# complete: a MOVW/MOVT pair is an absolute no loader slides by adding to a
# word, and the linker refuses --emit-relocs on a seat that emits one.
# pdglue.c also stands in for the SDK's setup.c here (the entry and the malloc
# trio). The simulator pdex.so stays an ordinary host gcc shared object, and
# there setup.c is the SDK's again, so `make sim` runs with no cross tools.
#
# Both halves bake the same program: the egg bootstrap (b/lib lcat headers,
# delegated to the root), a/rune.l as a registered module, and cas.l (this
# folder, lcat'd locally) driving the workbench. See main.c + pdglue.c.
R := ../..
include $(R)/common.mk

o = $(R)/b/playdate
n = love
pd_sdk = $(PLAYDATE_SDK_PATH)
CCACHE ?= $(shell command -v ccache 2>/dev/null)

# mooncc's flags for the device C (run from $(R): its system include dir is
# CWD-relative, the SDK's is absolute). TARGET_PLAYDATE gates main.c's newlib
# stubs and pdglue.c's setup.c half. ai_data_section=0: the sentinel tiling
# l/love.h's ai_typ reads wants the link to place love.data.NN, and this seat
# lays one flat text run, so l/love.h asks the sentinels by name here.
# ai_horn_seat: i/horn.c takes k_horn_* as its device rather than hunting a kernel's.
# a fact about the LINK -- this roster supplies the door -- and the reason it cannot be
# read off __ai_osv is that a board has no OS to have a word about. it also keeps the
# ALSA and OSS lanes out of the compile, which want open/ioctl/getenv and would be a
# link error here rather than a device this seat could ever reach.
mc_flags = -t thumb2sp -D ai_tco=1 -D __STDC_HOSTED__=0 -D TARGET_PLAYDATE=1 -D TARGET_EXTENSION=1 -D ai_data_section=0 -D ai_horn_seat=1 \
  -Ii/playdate -Ib/playdate -I. -Il -Ib/lib -Il/quay -Ia/moon/include -I$(pd_sdk)/C_API
# our own link. -Ttext 0 is where link_map.ld puts .text, which is the only thing
# that script says about placement; --emit-relocs keeps the R_ARM_ABS32 sites so
# the loader can slide them; -nostdlib makes an owed nom past our own runtime a
# diagnostic rather than a hunt for a libc this seat would not want.
mc_ld = -t thumb2sp -Ttext 0 -nostdlib --emit-relocs
# the same link at a second base. test_playdate diffs the two images and holds the
# relocation table to being exactly the words that moved -- complete and minimal, which
# is the whole of what a loader placing this image somewhere else leans on. Nothing
# else builds it, and it never rides the pdx.
mc_ld_alt = -t thumb2sp -Ttext 0x100000 -nostdlib --emit-relocs

# the lcat lib headers this frontend bakes (produced by the root's rules on
# love0, delegated below so a standalone make works from a clean tree)
lib_hs = $(patsubst %,$(R)/b/lib/%.h,egg prel ev rune)
pd_h = $(love_h) $(wildcard $(R)/l/quay/*.h) $(o)/cas.h $(lib_hs)

# the split: mooncc carries l/love.c + am + quay + main.c; gcc carries pdglue.c
# (the pd_api.h owner) + the SDK's setup.c. the sim build compiles everything
# hosted, so pd_src keeps the full wildcard.
pd_local_c = $(wildcard *.c)
# love_c already carries the codecs (common.mk's core_tu = love_tu + love_codec),
# so naming them again here is one roster too many -- and the second one pointed at
# src/, which the flatten retired.
# l/bare.c is the null seat: this frontend supplies main and pdglue supplies the
# heap, so the doors i/fd.c carries on a hosted love have nobody here to answer them.
# i/horn.c where the boards take l/nohorn.c: this device has a speaker, so it answers
# ai_horn_writen for real -- see ai_horn_seat in the flags below, and k_horn_* in main.c.
pd_shared_c = $(love_c) $(f_c) $(R)/l/bare.c $(R)/i/horn.c
# the bare-metal runtime, and the whole of it. the six moonlibc string members every
# port takes (i/port.mk's libc_m, out of the same source -- there is no second libc
# in this tree), plus rt.c: the calls mooncc's own lowering makes where the machine
# has no instruction, which on an sp-only fpu is every f64 op. these ride the same
# $(o)/%.o pattern as the love objects, so they mirror their source paths.
pd_bare_c = $(addprefix $(R)/a/moon/lib/moonlibc/string/,\
  memchr.c memcmp.c memcpy.c memmove.c memset.c strlen.c) $(R)/a/moon/lib/rt.c
# the simulator is a hosted .so and keeps the SDK's setup.c: there pdglue.c leaves the
# shim and the malloc trio to it, and the host libc answers the rest.
pd_sdk_c = $(pd_sdk)/C_API/buildsupport/setup.c
pd_src = $(pd_local_c) $(pd_shared_c) $(pd_sdk_c)
mc_shared_o = $(pd_shared_c:$(R)/%.c=$(o)/%.o)
pd_bare_o = $(pd_bare_c:$(R)/%.c=$(o)/%.o)
pd_o = $(o)/main.o $(mc_shared_o) $(pd_bare_o) $(o)/pdglue.o

# a failed recipe takes its half-written target with it -- else a 0-byte artifact
# carries a fresh mtime and the next make calls it up to date. this makefile stands
# alone (the root does not include it), so it says so itself. see ../../Makefile.
.DELETE_ON_ERROR:

# probe: the DEVICE main, and nothing that wants the SDK. main.c reaches the seat
# through pdglue.h, which is a word-only seam over <stddef.h>, so mooncc compiles it
# with no foreign tool -- which makes this the one playdate lane that can run anywhere
# and therefore the one that can FAIL. test_playdate runs it before it decides whether
# it has an SDK to do the rest with.
.PHONY: default sim clean probe alt
default: $(o)/$n.pdx
probe: $(o)/main.o
alt: $(o)/pdex-alt.elf

sim: $(o)/$n.pdx
	@$(pd_sdk)/bin/PlaydateSimulator $^

clean:
	rm -rf $(o)

# delegate the lib headers and the host binary (which lcats cas.l) to the root.
# each one needs FORCE: a rule with NO prerequisites fires only when its target
# is MISSING, so an existing-but-STALE header was served forever and the root's
# own up-to-date check never got asked. b/lib/rune.h froze that way -- nothing
# else in the tree regenerates it -- and when a/rune.l grew the
# (leave ()) that registers the module, the baked image kept the sealless
# header and the workbench died on `;; no-module rune`. the root decides
# staleness; our job is only to ask it every time.
.PHONY: FORCE
FORCE:
$(lib_hs): FORCE
	@$(MAKE) -C $(R) b/lib/$(@F)
$(m): FORCE
	@$(MAKE) -C $(R) b/love

# cas.l -> C string literal, atomically (a 0-byte header would silently drop
# the whole demo -- same discipline as the root's lcat_h)
$(o)/cas.h: cas.l $(R)/u/lcat.l | $(m)
	@echo LOVE	$@
	@mkdir -p $(o)
	@$(m) $(R)/u/lcat.l cas.l > $@.tmp && test -s $@.tmp && mv -f $@.tmp $@ \
	  || { rm -f $@.tmp; echo "FAIL: $@ empty"; exit 1; }

$(o)/$n.pdx: $(o)/Source/pdex.elf $(o)/Source/pdex.so $(o)/Source/love-pd.img
	@echo PDC	$@
	@$(pd_sdk)/bin/pdc -sdkpath $(pd_sdk) $(o)/Source $@

# the qemu-baked heap image rides the pdx as a data file; i/mps2's imgpd
# bakes AND wake-checks it (FORCE keeps the delegation live -- mps2's own
# deps decide whether the bake re-runs). An empty image ships too: the
# device just egg-boots (and the 64-bit sim always does).
$(R)/b/mps2/love-pd.img: FORCE
	@$(MAKE) --no-print-directory -C $(R)/i/mps2 imgpd
FORCE:

$(o)/Source/love-pd.img: $(R)/b/mps2/love-pd.img
	@echo CP	$@
	@mkdir -p $(dir $@)
	@cp $< $@

$(o)/Source/pdex.%: $(o)/pdex.%
	@echo CP	$@
	@mkdir -p $(dir $@)
	@cp $< $@

# the mooncc half: main.c + the shared runtime + quay
$(o)/main.o: main.c pdglue.h $(pd_h) | $(m)
	@echo MOON	$@
	@mkdir -p $(o)
	@cd $(R) && LOVE_NO_IMAGE= b/love mooncc $(mc_flags) -c i/playdate/main.c b/playdate/main.o
$(o)/%.o: $(R)/%.c $(pd_h) | $(m)
	@echo MOON	$@
	@mkdir -p $(dir $@)
	@cd $(R) && LOVE_NO_IMAGE= b/love mooncc $(mc_flags) -c $*.c b/playdate/$*.o
# the SDK boundary -- ours too, now: pdglue.c is the one file that includes pd_api.h,
# and mooncc reads it (the header wants -Wno-unknown-pragmas from gcc and nothing at
# all from us). It is not under the $(R) pattern above: it lives here, not in the tree.
$(o)/pdglue.o: pdglue.c pdglue.h | $(m)
	@echo MOON	$@
	@mkdir -p $(o)
	@cd $(R) && LOVE_NO_IMAGE= b/love mooncc $(mc_flags) -c i/playdate/pdglue.c b/playdate/pdglue.o

$(o)/pdex.elf: $(pd_o) | $(m)
	@echo MOON	$@
	@cd $(R) && LOVE_NO_IMAGE= b/love mooncc $(mc_ld) $(pd_o:$(R)/%=%) -o b/playdate/pdex.elf
$(o)/pdex-alt.elf: $(pd_o) | $(m)
	@echo MOON	$@
	@cd $(R) && LOVE_NO_IMAGE= b/love mooncc $(mc_ld_alt) $(pd_o:$(R)/%=%) -o b/playdate/pdex-alt.elf

# the simulator .so: a single-shot hosted build of the same sources
$(o)/pdex.so: $(pd_src) $(o)/cas.h
	@echo CC	$@
	@mkdir -p $(o)
	@$(CCACHE) gcc -g -O1 -shared -fPIC -Dai_tco=0 -DTARGET_SIMULATOR=1 -DTARGET_EXTENSION=1 -Dai_horn_seat=1 \
	  -I. -I$(o) -I$(R) -I$(R)/l -I$(R)/b/lib -I$(R)/l/quay -I$(pd_sdk)/C_API \
	  -o $@ $(pd_src) -lm

.PRECIOUS: $(o)/%.elf
