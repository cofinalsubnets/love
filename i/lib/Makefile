# i/lib -- love as a library. `make -C i/lib` lays b/liblv.a, b/liblv.so and the
# three demos. run from this folder; $(R) is the tree root, which owns the boot
# headers. NOT b/liblove.a: that archive is the same ten TUs, but compiled for the
# artifact's own link, and this one wants -Dai_data_section=0 so a foreign build
# system needs no -Wl,-T of ours. one flag, one extra compile of the runtime.
R := ../..
include $(R)/common.mk
# b/lib is the tree's generated-header dir; the objects go somewhere of their own.
o = b/lvo

# -Dai_data_section=0 is the whole reason a foreign build needs no linker script:
# the data sentinels tile by comparison instead of by section, which is the lane
# the wasm target already takes. measured level on the apply microbenchmark.
# every compile cd's to $(R) first, so the -I list is root-relative.
cc_lib = LOVE_NO_IMAGE= $(CC) $(ai_cflags) -Dai_tco=$(tco) -Dai_data_section=0 \
  -fpic -Ib -I. -Il -Ii -Ib/lib -Ii/lib

# the runtime half is the ROOT's: b/liblove-nosec.a is love_c on the one flag this
# seat needs, laid by the same recipe as b/liblove.a. so the ten TUs are compiled
# once for the tree and a file joining the roster reaches here by itself. what is
# left here is the seat -- this folder's two, and the three a link with no i/fd.c owes.
core_a = $(R)/b/liblove-nosec.a
seat_c = $(addprefix $(R)/i/lib/,lv.c seat.c) $(R)/l/bare.c $(R)/i/alloc.c $(R)/l/nohorn.c
boot_h = $(addprefix $(R)/b/lib/,egg.h p1.h prel.h ev.h post.h)

.DEFAULT_GOAL := default
.PHONY: default clean demo rust go FORCE
default: $(R)/b/liblv.a $(R)/b/liblv.so

FORCE:
$(boot_h): FORCE
	@$(MAKE) -C $(R) $(patsubst $(R)/%,%,$@)

$(core_a): FORCE
	@$(MAKE) -C $(R) $(patsubst $(R)/%,%,$@)

$(R)/b/liblv.a: $(core_a) $(seat_c) lv.h $(boot_h)
	@echo 'LIB	'$@
	@mkdir -p $(R)/$(o)
	@cd $(R) && for f in $(patsubst $(R)/%,%,$(seat_c)) ; do \
	   $(cc_lib) -c $$f -o $(o)/`basename $$f .c`.o || exit 1 ; done
	@cp $(core_a) $@
	@ar rs $@ $(R)/$(o)/*.o

# the .so's exports are trimmed to lv_* by lv.map: without it a linked-in love
# publishes 390 names, and an ai_ or lvm_ symbol loose in a host's namespace is
# a collision waiting for a second interpreter.
$(R)/b/liblv.so: $(R)/b/liblv.a lv.map
	@echo 'SO	'$@
	@$(CC) -shared -o $@ -Wl,--whole-archive $(R)/b/liblv.a -Wl,--no-whole-archive \
	  -Wl,--version-script,lv.map

demo: $(R)/b/liblv.a
	@cd $(R) && $(cc_lib) -o b/lvdemo i/lib/demo.c b/liblv.a -Wl,-z,nostart-stop-gc
	@cd $(R) && $(cc_lib) -o b/lvtwo i/lib/two.c b/liblv.a -Wl,-z,nostart-stop-gc

rust: $(R)/b/liblv.a
	@cd rust && LOVE_LIB_DIR=$(abspath $(R)/b) cargo run --release --bin demo

go: $(R)/b/liblv.a
	@cd go && go run ./demo

clean:
	rm -rf $(R)/$(o) $(R)/b/liblv.a $(R)/b/liblv.so $(R)/b/lvdemo $(R)/b/lvtwo
