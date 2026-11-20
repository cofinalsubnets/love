# Raspberry Pi Pico 2 (RP2350, Arm) build -- Cortex-M33 with the single-precision FPU, compiled
# END TO END by mooncc -t thumb2sp. No Pico SDK, no CMake, no vendor headers.
#
# boot.o (the vector table, the image definition, crt0, the fault shim) is laid from holo IR by
# mkboot.l, rlink.l links over holo's ldbare32, ocopy.l flattens, and src/tools/uf2.l packs the
# rom's drive file. usb.c is ../rp2040's, built against rp2350.h: the two chips' usb blocks
# are one.
#
# Faces: `make` builds firm.uf2 (the battery) and probe.uf2 (../rp2040/probe.c) and verifies the boot surface (the vector table's SP and reset
# entry, the image definition inside the first 4 KB) -- what a board that sits in bootsel
# always traces back to.
p_tgt = thumb2sp
p_be  = thumb2
include ../../../src/inle/port.mk

rp_cc = $(MOONCC) -t thumb2sp -D __STDC_HOSTED__=0 -D RP2350 -I.

objs = $(R)/$(o)/rp2350.o $(R)/$(o)/main.o $(R)/$(o)/usb.o $(R)/$(o)/lm.o $(R)/$(o)/rt.o $(R)/$(o)/boot.o
pobjs = $(R)/$(o)/rp2350.o $(R)/$(o)/probe.o $(R)/$(o)/pusb.o $(R)/$(o)/rt.o $(R)/$(o)/boot.o

.PHONY: rp2350
default: rp2350
rp2350: $(R)/$(o)/firm.uf2 $(R)/$(o)/firm-ram.uf2 $(R)/$(o)/probe.uf2

$(eval $(call p_obj,rp2350,test/boards/rp2350/rp2350.c,rp2350.c rp2350.h $(S)/inle/bput.h $(mc),$(rp_cc)))
$(eval $(call p_obj,main,test/boards/rp2350/main.c,main.c rp2350.h ../battery.h $(S)/inle/bput.h $(mc),$(rp_cc)))
$(eval $(call p_obj,usb,test/boards/rp2040/usb.c,../rp2040/usb.c rp2350.h $(S)/inle/usbcdc.h $(mc),$(rp_cc) -D 'UCDC_PRODUCT="love board"'))
# the swd probe, ../rp2040's, on this chip
$(eval $(call p_obj,probe,test/boards/rp2040/probe.c,../rp2040/probe.c rp2350.h $(mc),$(rp_cc)))
$(eval $(call p_obj,pusb,test/boards/rp2040/usb.c,../rp2040/usb.c rp2350.h $(S)/inle/usbcdc.h $(mc),$(rp_cc) -D UCDC_ACM2))

$(eval $(call p_lay,boot,mkboot,"$(o)/boot.o"))

$(eval $(call p_link,rlink))
$(eval $(p_ocopy))

$(R)/$(o)/firm.elf: $(objs) $(R)/$(o)/rlink.l $(lv)
	@echo HOLO	$@
	@cd $(R) && out/love $(o)/rlink.l $(o)/firm.elf $(objs:$(R)/%=%)

$(R)/$(o)/probe.elf: $(pobjs) $(R)/$(o)/rlink.l $(lv)
	@echo HOLO	$@
	@cd $(R) && out/love $(o)/rlink.l $(o)/probe.elf $(pobjs:$(R)/%=%)

# .bin byte offsets ARE flash offsets: an initial SP inside SRAM, a thumb-bit reset entry
# inside flash, and the image definition's start marker and image type in the first 4 KB
# the image a board lane runs from sram: a uf2 at sram's base, which the rom runs there, the
# flash never written
$(R)/$(o)/firm-ram.elf: $(objs) $(R)/$(o)/rlink.l $(lv)
	@echo HOLO	$@
	@cd $(R) && out/love $(o)/rlink.l -ram $(o)/firm-ram.elf $(objs:$(R)/%=%)

$(R)/$(o)/firm-ram.bin: $(R)/$(o)/firm-ram.elf $(R)/$(o)/ocopy.l
	@echo LOVE	$@
	@cd $(R) && out/love $(o)/ocopy.l -O binary $(o)/firm-ram.elf $(o)/firm-ram.bin
	$(call p_ramchk,$(R)/$(o)/firm-ram.bin,0x20082000,0x20040000)

$(R)/$(o)/firm-ram.uf2: $(R)/$(o)/firm-ram.bin $(S)/tools/uf2.l $(lv)
	@echo LOVE	$@
	@cd $(R) && out/love src/tools/uf2.l $(o)/firm-ram.bin $(o)/firm-ram.uf2 0x20000000 0xE48BFF59

$(R)/$(o)/%.bin: $(R)/$(o)/%.elf $(R)/$(o)/ocopy.l
	@echo LOVE	$@
	@cd $(R) && out/love $(o)/ocopy.l -O binary $(o)/$*.elf $(o)/$*.bin
	@python3 -c "import struct; b=open('$@','rb').read(); \
	  sp,e=struct.unpack_from('<II',b,0); \
	  ws=[struct.unpack_from('<I',b,i)[0] for i in range(0,min(len(b),4096)-4,4)]; \
	  blk=[i for i in range(len(ws)-1) if ws[i]==0xffffded3 and ws[i+1]==0x10210142]; \
	  ok = 0x20000000<sp<=0x20082000 and (e&1)==1 and 0x10000000<e<0x10400000 and blk; \
	  print('boot image: sp %08x entry %08x image def at %s --'%(sp,e,hex(4*blk[0]) if blk else 'none'), 'ok' if ok else 'BAD'); \
	  exit(0 if ok else 1)" || { echo "FAIL rp2350 boot image"; exit 1; }

# the rom's drive takes it as a file; family 0xe48bff59 is the rp2350's, arm secure
$(R)/$(o)/%.uf2: $(R)/$(o)/%.bin $(S)/tools/uf2.l $(lv)
	@echo LOVE	$@
	@cd $(R) && out/love src/tools/uf2.l $(o)/$*.bin $(o)/$*.uf2 0x10000000 0xE48BFF59
