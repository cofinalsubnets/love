# i/lib -- love as a library. `make -C i/lib` lays b/liblv.a, b/liblv.so and the
# three demos. run from this folder; $(R) is the tree root, which owns the boot
# headers and b/liblove.o -- the runtime partially linked, which is what lets an
# embedder link one file and carry no flags of ours.
R := ../..
include $(R)/common.mk
# b/lib is the tree's generated-header dir; the objects go somewhere of their own.
o = b/lvo

# every compile cd's to $(R) first, so the -I list is root-relative. no flag of our
# own: the seat is compiled exactly as the runtime is, and the FAST ai_typ rides
# through because b/liblove.o carries the sentinel tiling already laid.
cc_lib = LOVE_NO_IMAGE= $(CC) $(ai_cflags) -Dai_tco=$(tco) \
  -fpic -Ib -I. -Il -Ii -Ib/lib -Ii/lib

# the runtime half is the ROOT's, PARTIALLY LINKED: b/liblove.o is love_c with the
# data-sentinel tiling already settled inside it, so the ten TUs are compiled once
# for the tree and an embedder needs no linker script, no --whole-archive and no
# -z nostart-stop-gc. what is left here is the seat -- this folder's two, and the
# three a link with no i/fd.c owes.
core_a = $(R)/b/liblove.o
seat_c = $(addprefix $(R)/i/lib/,lv.c seat.c) $(R)/l/bare.c $(R)/i/alloc.c $(R)/l/nohorn.c
boot_h = $(addprefix $(R)/b/lib/,egg.h p1.h prel.h ev.h post.h)

.DEFAULT_GOAL := default
.PHONY: default clean demo rust go FORCE
default: $(R)/b/liblv.o $(R)/b/liblv.so

FORCE:
$(boot_h): FORCE
	@$(MAKE) -C $(R) $(patsubst $(R)/%,%,$@)

$(core_a): FORCE
	@$(MAKE) -C $(R) $(patsubst $(R)/%,%,$@)

# ..and the whole seat lands as ONE OBJECT beside it, never an archive: an archive
# member is pulled only if something already references it, and nothing references a
# love_nifs row -- the linker finds those through the __start_/__stop_ bracket, which
# is undefined if the member never came in. that is the failure rust's lld reports and
# go's silence hides. an object on the link line has no such rule.
$(R)/b/liblv.o: $(core_a) $(seat_c) lv.h $(boot_h)
	@echo 'LD	'$@
	@mkdir -p $(R)/$(o)
	@cd $(R) && for f in $(patsubst $(R)/%,%,$(seat_c)) ; do \
	   $(cc_lib) -c $$f -o $(o)/`basename $$f .c`.o || exit 1 ; done
	@$(CC) -nostdlib -no-pie -Wl,-r -o $@ $(core_a) $(R)/$(o)/*.o

# the .so's exports are trimmed to lv_* by lv.map: without it a linked-in love
# publishes 390 names, and an ai_ or lvm_ symbol loose in a host's namespace is
# a collision waiting for a second interpreter.
$(R)/b/liblv.so: $(R)/b/liblv.o lv.map
	@echo 'SO	'$@
	@$(CC) -shared -o $@ $(R)/b/liblv.o -Wl,--version-script,lv.map

demo: $(R)/b/liblv.o
	@cd $(R) && $(cc_lib) -o b/lvdemo i/lib/demo.c b/liblv.o
	@cd $(R) && $(cc_lib) -o b/lvtwo i/lib/two.c b/liblv.o

rust: $(R)/b/liblv.o
	@cd rust && LOVE_LIB_DIR=$(abspath $(R)/b) cargo run --release --bin demo

go: $(R)/b/liblv.o
	@cd go && go run ./demo

clean:
	rm -rf $(R)/$(o) $(R)/b/liblv.o $(R)/b/liblv.so $(R)/b/lvdemo $(R)/b/lvtwo
