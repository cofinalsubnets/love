# FIXME shrink the comments in this file and then also shrink the contents as much as possible
# inle/port.mk -- the shape every bare-metal port shares. Included by inle/<x>/Makefile,
# each of which is run from its own folder (`make -C inle/<x>`); $(R) is the project root,
# and mooncc's system include dir is CWD-relative, so every compile cd's to $(R) first.
#
# Set before including: p_tgt (mooncc's -t backend) and p_be (the holo backend .l the lays
# splice in; p_link_be if the link wants a different set). Optional: lib_h + p_hdrs, the
# lcat'd headers to delegate to the root.
#
# Answers: R o MOONCC lv, .DELETE_ON_ERROR, clean, FORCE and its three delegations, the
# lay_l/link_l/copy_l cats, the am.o and ocopy.l rules, and the p_obj/p_lay/p_link shapes.

R := ../..
# the shared variables, love_tu among them: a port reads the membership rather than
# restating it, since nothing in a makefile can see that a list has grown.
include $(R)/common.mk
p_dir = $(notdir $(CURDIR))
o = out/$(p_dir)
# mooncc is love's own verb. MOONCC is the command as run FROM $(R); lv is the file it
# needs, which is the baked artifact -- out/love is that file now, where a stamp stood in.
# LOVE_NO_IMAGE= leads (the guard against an exported egg): an egg-booted love has no verbs.
MOONCC = LOVE_NO_IMAGE= out/love mooncc
lv = $(R)/out/love

# a failed recipe takes its half-written target with it -- else a 0-byte artifact carries a
# fresh mtime and the next make calls it up to date. the root does not include these
# makefiles, so it is said here rather than inherited. see ../../Makefile.
.DELETE_ON_ERROR:

# the include sits above the port's own rules, so name the goal rather than letting the
# first target win it. every port points `default` at its own artifact.
.DEFAULT_GOAL := default
.PHONY: default clean FORCE

clean:
	rm -rf $(R)/$(o)

# FORCE, never a bare prerequisite-less rule: that fires only when the target is MISSING,
# so a stale header or binary is served forever. and the explicit binary rules also block
# make's builtin `%: %.o` -- out/love.o sits beside the binary, and a bare prerequisite
# let the builtin "relink" love from that lone object, then delete the half-made result.
FORCE:
# lib_hR is what an OBJECT depends on; p_hdrs only widens what gets delegated, for a
# header some faces want and the rest must not rebuild for.
lib_hR = $(addprefix $(R)/,$(lib_h))
ifneq ($(strip $(lib_h) $(p_hdrs)),)
$(sort $(lib_hR) $(addprefix $(R)/,$(p_hdrs))): FORCE
	@$(MAKE) -C $(R) $(patsubst $(R)/%,%,$@)
endif
$(lv): FORCE
	@$(MAKE) -C $(R) out/love

# the holo cats. the backend text is named explicitly: a frontend bakes holo with the
# NATIVE backend only, and a port must not care which machine it is building on.
p_link_be ?= $(p_be)
p_be_l    = $(addprefix $(R)/love/holo/,$(addsuffix .l,$(p_be)))
p_lnbe_l  = $(addprefix $(R)/love/holo/,$(addsuffix .l,$(p_link_be)))
# THE FLOOR IS CATTED, THEN SPLICED. text.l and u.l reopen module 'kore, so their
# names (uread, udie ..) do not walk for whoever comes after -- and every driver below
# reads them bare. So the cats emit (borrow 'kore) once the two files have registered it,
# the Makefile's klink recipe exactly.
kore_l = $(R)/apps/kore/text.l $(R)/apps/kore/u.l
lay_l  = $(kore_l) $(R)/apps/kore/asbook.l \
  $(R)/love/holo/elf.l $(R)/love/holo/obj.l
link_l = $(kore_l) $(R)/apps/kore/asbook.l \
  $(p_lnbe_l) $(R)/love/holo/elf.l $(R)/love/holo/obj.l $(R)/love/holo/link.l
copy_l = $(link_l) $(R)/love/holo/copy.l
# the same lists spelled from $(R), which is where the cats run
lay_lc  = $(subst $(R)/,,$(lay_l))
kore_lc = $(subst $(R)/,,$(kore_l))
be_lc   = $(subst $(R)/,,$(p_be_l))

# the runtime a bare seat links: love_tu's seven translation units and love_codec's pair
# (common.mk names both). a port compiles every one under its own <x>_cc, since love.c
# owes the other six and snap.c owes the codecs. love_m is the object stems, love_dep what
# each one watches.
# ..plus love/bare.c, the answers a seat with no inle/fd.c gives to the runtime's own doors,
# and love/nohorn.c, the horn's refusal where there is no card. only a bare seat links
# either: everything else carries inle/fd.c, whose bodies are the real ones, and two of
# them in one link is a collision that says so. a board that grows a speaker drops
# nohorn for inle/horn.c, which answers ai_horn_writen itself -- out/front is the link that
# shows the shape.
love_m   = $(basename $(love_tu) $(love_codec)) bare nohorn
love_dep = $(love_h) $(lib_hR) $(lv)
love_o   = $(addprefix $(R)/$(o)/,$(addsuffix .o,$(love_m)))

# ..and the seat's heap beside them: inle/alloc.c answers ai_alloc over malloc and free,
# which is what a board whose memory is already those wants. it is not in love_m because
# that list is compiled out of love/ and this answer is the seat's, not the runtime's -- a
# board with a heap of its own defines ai_alloc and names no alloc.o, and a board that
# names neither fails to link, which is the right answer for a runtime with nowhere to
# put its pools. $1 is the board's own <x>_cc, $2 an object-stem suffix.
define p_heap
$$(eval $$(call p_obj,alloc$2,inle/alloc.c,$$(R)/inle/alloc.c $$(love_dep),$1))
endef
heap_o = $(R)/$(o)/alloc.o

# moonlibc's pure members: the libc a bare-metal seat gets, the same six the kernel takes
# (common.mk) out of the same source -- there is no second libc in this tree. A port
# lays them with a foreach over libc_m under its own <x>_cc. -Iapps/moon/include is
# owed: the members open with impl.h, whose hosted declarations cost compile time and
# nothing else -- the six owe ONE symbol between them (memmove's memcpy), and it is one
# of the six.
libc_m    = memchr memcmp memcpy memmove memset strlen
libc_dep  = $(R)/apps/moon/lib/moonlibc/impl.h $(lv)
libc_o    = $(addprefix $(R)/$(o)/,$(addsuffix .o,$(libc_m)))

# the am math floor: the one object every port compiles exactly alike.
$(R)/$(o)/am.o: $(R)/apps/moon/lib/moonlibc/math/am.c $(lv)
	@echo 'MOON	'$@
	@mkdir -p $(R)/$(o)
	@cd $(R) && $(MOONCC) -t $(p_tgt) -Iapps/moon/lib/moonlibc/math -Iapps/moon/include -c apps/moon/lib/moonlibc/math/am.c $(o)/am.o

# the compiler runtime: the calls mooncc's own lowering makes where the machine has no
# instruction (v6-M has neither FPU nor umull nor clz nor a variable 64-bit shift; a
# single-precision FPU softens f64 alone). Only the thumb ports name it -- an rv64 or x64
# seat has the hardware, and an object named on a link line rides it whole.
$(R)/$(o)/rt.o: $(R)/apps/moon/lib/rt.c $(lv)
	@echo 'MOON	'$@
	@mkdir -p $(R)/$(o)
	@cd $(R) && $(MOONCC) -t $(p_tgt) -Iapps/moon/include -c apps/moon/lib/rt.c $(o)/rt.o

# p_ocopy -- the flatten, for the ports that ship a .bin/.hex: love/holo/copy.l reads the
# linked ELF and writes objcopy's two output formats, byte for byte (`kore objcopy` is the
# same code with a name). Takes no argument; a port that links its own ELF and stops there
# (virt, mps2) never asks for it.
define p_ocopy
$$(R)/$$(o)/ocopy.l: $$(copy_l)
	@echo 'CAT	'$$@
	@mkdir -p $$(R)/$$(o)
	@{ echo "(borrow 'holo)"; cat $$(kore_l); echo "(borrow 'kore)"; \
	   cat $$(filter-out $$(kore_l),$$(copy_l)); echo '(objcopy >argv)'; } > $$@
endef

# p_obj -- one compiled object. $1 stem, $2 the source from $(R), $3 the prerequisites,
# $4 the compile command (a port's own <x>_cc, plus any -D this object alone wants).
define p_obj
$$(R)/$$(o)/$1.o: $3
	@echo 'MOON	'$$@
	@mkdir -p $$(R)/$$(o)
	@cd $$(R) && $4 -c $2 $$(o)/$1.o
endef

# p_lay -- one object laid from holo IR, so no assembler runs. $1 stem, $2 the mk*.l driver
# (whose name is the function too), $3 that function's arguments.
define p_lay
$$(R)/$$(o)/$1.o: $2.l $$(p_be_l) $$(lay_l) $$(lv)
	@echo 'HOLO	'$$@
	@mkdir -p $$(R)/$$(o)
	@cd $$(R) && { echo "(borrow 'holo)"; cat $$(be_lc) $$(kore_lc); echo "(borrow 'kore)"; \
	  cat $$(filter-out $$(kore_lc),$$(lay_lc)) inle/$$(p_dir)/$2.l; \
	  echo '($2 $3)'; } | out/love
endef

# p_link -- the link driver's cat. $1 its stem. an explicit target, never a pattern rule:
# a pattern-MADE prerequisite is an INTERMEDIATE make deletes after the link, and the cat
# would then run again on every build.
define p_link
$$(R)/$$(o)/$1.l: $1.l $$(link_l)
	@echo 'CAT	'$$@
	@mkdir -p $$(R)/$$(o)
	@{ echo "(borrow 'holo)"; cat $$(kore_l); echo "(borrow 'kore)"; \
	   cat $$(filter-out $$(kore_l),$$(link_l)) $$<; } > $$@
endef
