# teensy 4.1 (i.mx rt1062): the inle kernel, kmain over this board's drivers, all compiled by
# mooncc. `make -C src/inle/teensy41` from the project root. boot.o (the rom-facing flexspi,
# ivt and vector blocks, crt0, the asm helpers) is laid from holo ir by mkboot.l, the baked
# image by mkimg.l; tlink.l links over holo's ldbare32 and ocopy.l writes the .hex and .bin,
# so the port owes no gas, ld, linker script or objcopy. qemu-arm only bakes the image.
# the build checks the boot image: the fcfb tag at 0, the ivt at 0x1000, a thumb-bit entry.
# `make loader` builds loader.c, a flash image that takes the kernel into the psram over usb,
# and `make ram` that kernel, love-ram.pkt: the same objects linked at the psram's base
p_tgt = thumb2
p_be  = thumb2
include ../port.mk

.PHONY: kernel flash psramtest flashpsram loader ram flashloader
default: kernel

# boot.o: the ROM-facing FlexSPI/IVT/vector blocks, crt0 and the asm helpers, laid from
# holo IR -- no gas. src/inle/mps2/mkstart.l is the same shape with one section,
# test/boards/rp2040/mkboot2.l the named-section one.
$(eval $(call p_lay,boot,mkboot,"$(o)/boot.o"))

# the link is ours: tlink.l drives holo's ldbare32 with the XIP flash map, in place of
# arm-none-eabi-ld + teensy41.lds.
$(eval $(call p_link,tlink))
$(eval $(p_ocopy))

# the .bin is what `make flash` writes and the check, its byte offsets flash offsets; the
# .hex is the same image for a loader that wants one
define te_flat
	@echo LOVE	$@
	@cd $(R) && out/love $(o)/ocopy.l -O ihex $(o)/$1.elf $(o)/$1.hex
	@cd $(R) && out/love $(o)/ocopy.l -O binary $(o)/$1.elf $(o)/$1.bin
	@python3 -c "import sys,struct; b=open('$(R)/$(o)/$1.bin','rb').read(); \
	  fcfb=struct.unpack_from('<I',b,0)[0]; ivt=struct.unpack_from('<I',b,0x1000)[0]; \
	  entry=struct.unpack_from('<I',b,0x1004)[0]; \
	  ok = fcfb==0x42464346 and ivt==0x432000D1 and (entry&1)==1 and 0x60000000<entry<0x60800000; \
	  print('boot image: FCFB@0 %08x IVT@1000 %08x entry %08x --'%(fcfb,ivt,entry), 'ok' if ok else 'BAD'); \
	  sys.exit(0 if ok else 1)" || { echo "FAIL boot image layout"; exit 1; }
endef
# kmain over these drivers, linked from the arm love's own objects (the root's xa=arm
# lane), so the image that love bakes is the one this wakes
k_cc = $(MOONCC) -t arm -D tco=1 -Iout -I. -Isrc/love -Isrc/inle -Iout/lib -Isrc/love/quay -Isrc/apps/moon/include
k_hdr = $(addprefix $(R)/out/lib/,baked.h distlist.h korelist.h crewlist.h seat.h tasks.h)
k_inle = kmain sys hda
k_ih = $(wildcard $(S)/inle/*.h)                  # kboot.h lays the record kern.c fills
k_brd = kern teensy41 usb sd psram
k_objs = $(k_inle:%=$(R)/$(o)/%.o) $(k_brd:%=$(R)/$(o)/%.o) $(R)/$(o)/boot.o $(R)/$(o)/love-img.o
$(foreach u,$(k_inle),$(eval $(call p_obj,$u,src/inle/$u.c,$(S)/inle/$u.c $(k_ih) $(mc) $(k_hdr),$(k_cc))))
$(foreach u,$(k_brd),$(eval $(call p_obj,$u,src/inle/teensy41/$u.c,$u.c teensy41.h psram.h $(k_ih) $(mc),$(k_cc))))
$(k_hdr) $(R)/out/rt/arm.list $(R)/out/x-arm/o.list $(R)/out/x-arm/o/love/noblob.o $(R)/out/.kore-cat.l: FORCE
	@$(MAKE) --no-print-directory -C $(R) xa=arm $(patsubst $(R)/%,%,$@)
# the image: the arm love relinked over noblob.o, as the kernel is, so the carried-c digests
# agree; it bakes a cat under qemu-arm: kore's, so lush and the tools are there at boot
# (k_src=out/teensy41/lib-cat.l bakes the lib alone). baked under LOVE_NO_GLAZE: a cortex-m has
# no a32 state, so it cannot enter an arm native's stub, and the cat's last form refuses a bake
# that loaded the glaze
k_src = out/.kore-cat.l
k_cat = $(o)/k-cat.l
$(R)/$(o)/lib-cat.l: Makefile
	@mkdir -p $(dir $@)
	@printf '\n(cite (quote verbs) (quote mark) ())\n' > $@
$(R)/$(k_cat): $(R)/$(k_src) Makefile
	@mkdir -p $(dir $@)
	@{ cat $(R)/$(k_src); printf '\n(? (cite (quote glaze)) (puts "k-cat: the glaze is loaded, and a cortex-m cannot enter its natives", putc 10, quit 1) 0)\n'; } > $@
k_xo = $(R)/out/x-arm/o.list $(R)/out/x-arm/o/love/noblob.o
$(R)/$(o)/baker: $(k_xo) $(lv)
	@echo MOON	$@
	@mkdir -p $(dir $@)
	@cd $(R) && $(MOONCC) -t arm $$(cat out/x-arm/o.list) out/x-arm/o/love/noblob.o -o $(o)/baker
$(R)/$(o)/love.img: $(R)/$(o)/baker $(R)/$(k_cat)
	@echo BAKE	$@ "(qemu-arm)"
	@cd $(R) && LOVE_NO_IMAGE=1 LOVE_NO_GLAZE=1 qemu-arm $(o)/baker bake -l $(k_cat) $(o)/love.img > $(o)/bake.log 2>&1 \
	   && test -s $(o)/love.img || { tail -20 $(R)/$(o)/bake.log; exit 1; }
$(eval $(call p_lay,love-img,mkimg,"$(o)/love.img" "$(o)/love-img.o"))
$(R)/$(o)/love-img.o: $(R)/$(o)/love.img
kernel: $(R)/$(o)/love.hex
$(R)/$(o)/love.elf: $(k_objs) $(R)/out/rt/arm.list $(k_xo) $(R)/$(o)/tlink.l $(lv)
	@echo HOLO	$@
	@cd $(R) && out/love $(o)/tlink.l $(o)/love.elf $(k_objs:$(R)/%=%) $$(cat out/x-arm/o.list) \
	   out/x-arm/o/love/noblob.o $$(cat out/rt/arm.list) $$(cat out/rt/arm.list)
$(R)/$(o)/love.hex: $(R)/$(o)/love.elf $(R)/$(o)/ocopy.l
	$(call te_flat,love)

# the resident loader, the flash's image when kernels come over usb: one write, then none
$(eval $(call p_obj,loader,src/inle/teensy41/loader.c,loader.c teensy41.h psram.h $(S)/inle/bput.h $(mc),$(k_cc)))
$(eval $(call p_obj,usb-l,src/inle/teensy41/usb.c,usb.c teensy41.h $(k_ih) $(mc),$(k_cc) -D TE_LOADER))
l_objs = $(R)/$(o)/loader.o $(R)/$(o)/teensy41.o $(R)/$(o)/usb-l.o $(R)/$(o)/psram.o $(R)/$(o)/boot.o
loader: $(R)/$(o)/loader.hex
$(R)/$(o)/loader.elf: $(l_objs) $(R)/$(o)/tlink.l $(lv)
	@echo HOLO	$@
	@cd $(R) && out/love $(o)/tlink.l $(o)/loader.elf $(l_objs:$(R)/%=%)
$(R)/$(o)/loader.hex: $(R)/$(o)/loader.elf $(R)/$(o)/ocopy.l
	$(call te_flat,loader)
flashloader: $(R)/$(o)/loader.hex
	cd $(R) && out/love src/tools/halfkay.l write $(o)/loader.bin

# the kernel for the psram: the flash kernel's objects under tlink.l's -ram map, flattened, and
# wrapped as the loader takes it: 'L', the length, the bytes, their sum, each word little-endian.
# the check: a stack in ocram2, a thumb entry inside the bytes, and under 4 MB of them
ram: $(R)/$(o)/love-ram.pkt
$(R)/$(o)/love-ram.elf: $(k_objs) $(R)/out/rt/arm.list $(k_xo) $(R)/$(o)/tlink.l $(lv)
	@echo HOLO	$@
	@cd $(R) && out/love $(o)/tlink.l -ram $(o)/love-ram.elf $(k_objs:$(R)/%=%) $$(cat out/x-arm/o.list) \
	   out/x-arm/o/love/noblob.o $$(cat out/rt/arm.list) $$(cat out/rt/arm.list)
$(R)/$(o)/love-ram.pkt: $(R)/$(o)/love-ram.elf $(R)/$(o)/ocopy.l
	@echo LOVE	$@
	@cd $(R) && out/love $(o)/ocopy.l -O binary $(o)/love-ram.elf $(o)/love-ram.bin
	@python3 -c "import struct; b=open('$(R)/$(o)/love-ram.bin','rb').read(); \
	  sp,e=struct.unpack_from('<II',b,0); end=0x70000000+len(b); \
	  ok = 0x20200000<sp<=0x20280000 and (e&1)==1 and 0x70000000<e<end and len(b)<(4<<20); \
	  open('$(R)/$(o)/love-ram.pkt','wb').write(b'L'+struct.pack('<I',len(b))+b+struct.pack('<I',sum(b)&0xFFFFFFFF)); \
	  print('psram image: sp %08x entry %08x, %d bytes --'%(sp,e,len(b)), 'ok' if ok else 'BAD'); \
	  exit(0 if ok else 1)" || { echo "FAIL psram image layout"; exit 1; }

# flash the kernel to a connected teensy 4.1 (the button, or 134 baud, enters the loader)
flash: $(R)/$(o)/love.hex
	cd $(R) && out/love src/tools/halfkay.l write $(o)/love.bin

# the psram smoke test, no bake: probes and pattern-tests the flexspi2 chips, says so on the
# uart. `make psramtest` then `make flashpsram`
$(eval $(call p_obj,psram-test,src/inle/teensy41/psram-test.c,psram-test.c psram.h teensy41.h $(S)/inle/bput.h $(mc),$(k_cc)))
pt_objs = $(R)/$(o)/psram.o $(R)/$(o)/psram-test.o $(R)/$(o)/teensy41.o $(R)/$(o)/boot.o
psramtest: $(R)/$(o)/psram-test.hex
flashpsram: $(R)/$(o)/psram-test.hex
	cd $(R) && out/love src/tools/halfkay.l write $(o)/psram-test.bin
$(R)/$(o)/psram-test.elf: $(pt_objs) $(R)/$(o)/tlink.l $(lv)
	@echo HOLO	$@
	@cd $(R) && out/love $(o)/tlink.l $(o)/psram-test.elf $(pt_objs:$(R)/%=%)
$(R)/$(o)/psram-test.hex: $(R)/$(o)/psram-test.elf $(R)/$(o)/ocopy.l
	@echo LOVE	$@
	@cd $(R) && out/love $(o)/ocopy.l -O ihex $(o)/psram-test.elf $(o)/psram-test.hex
	@cd $(R) && out/love $(o)/ocopy.l -O binary $(o)/psram-test.elf $(o)/psram-test.bin
