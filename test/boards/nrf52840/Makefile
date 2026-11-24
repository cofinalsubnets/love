# xiao nrf52840 build -- firmware compiled end to end by mooncc -t thumb2sp (the nrf52840's
# cortex-m4 has nucleo446's single-precision FPU; f64 softens to __aeabi_* calls, which rt.o
# answers). boot.o is laid by mkboot.l, xlink.l links over holo's ldbare32, ocopy.l
# flattens, and src/tools/uf2.l packs the flat loader for the board's uf2 bootloader.
#
# `make` builds loader.uf2, the app the flash holds, and firm-ram.bin, the battery for sram,
# with firm-ram.pkt, the bytes loader.c takes, and verifies both; that is what `make
# test_nrf52840` gates. `make flash` copies loader.uf2 onto the bootloader's drive (134 baud
# on the loader's port, or a double tap of reset, brings it up), mounted at UF2_DRIVE.
p_tgt = thumb2sp
p_be  = thumb2
include ../../../src/inle/port.mk

UF2_DRIVE ?= /run/media/$(USER)/XIAO-SENSE
nrf_cc = $(MOONCC) -t thumb2sp -D __STDC_HOSTED__=0 -I.

objs  = $(R)/$(o)/nrf52840.o $(R)/$(o)/main.o $(R)/$(o)/usb.o $(R)/$(o)/lm.o $(R)/$(o)/lmf.o $(R)/$(o)/rt.o $(R)/$(o)/boot.o
lobjs = $(R)/$(o)/nrf52840.o $(R)/$(o)/loader.o $(R)/$(o)/usbl.o $(R)/$(o)/rt.o $(R)/$(o)/boot.o
uc    = usb.c nrf52840.h $(S)/inle/usbcdc.h $(mc)

.PHONY: nrf52840 flash
default: nrf52840
nrf52840: $(R)/$(o)/loader.uf2 $(R)/$(o)/firm-ram.pkt

$(eval $(call p_obj,nrf52840,test/boards/nrf52840/nrf52840.c,nrf52840.c nrf52840.h ../crt0.h $(S)/inle/bput.h $(mc),$(nrf_cc)))
$(eval $(call p_obj,main,test/boards/nrf52840/main.c,main.c nrf52840.h ../battery.h $(S)/inle/bput.h $(mc),$(nrf_cc)))
$(eval $(call p_obj,loader,test/boards/nrf52840/loader.c,loader.c nrf52840.h $(S)/inle/bput.h $(mc),$(nrf_cc)))
$(eval $(call p_obj,usb,test/boards/nrf52840/usb.c,$(uc),$(nrf_cc)))
$(eval $(call p_obj,usbl,test/boards/nrf52840/usb.c,$(uc),$(nrf_cc) -D LOADER))
$(eval $(call p_lay,boot,mkboot,"$(o)/boot.o",../armboot.l))
$(eval $(call p_link,xlink,../boardld.l))
$(eval $(p_ocopy))

$(R)/$(o)/loader.elf: $(lobjs) $(R)/$(o)/xlink.l $(lv)
	@echo HOLO	$@
	@cd $(R) && out/love $(o)/xlink.l $(o)/loader.elf $(lobjs:$(R)/%=%)

# .bin byte 0 is flash 0x27000: an initial SP at sram's top and a thumb-bit reset entry between
# the app base and the bootloader at 0xF4000
$(R)/$(o)/loader.bin: $(R)/$(o)/loader.elf $(R)/$(o)/ocopy.l
	@echo LOVE	$@
	@cd $(R) && out/love $(o)/ocopy.l -O binary $(o)/loader.elf $(o)/loader.bin
	@python3 -c "import struct; b=open('$(R)/$(o)/loader.bin','rb').read(); \
	  sp=struct.unpack_from('<I',b,0)[0]; entry=struct.unpack_from('<I',b,4)[0]; \
	  ok = sp==0x20040000 and (entry&1)==1 and 0x27000<entry<0xF4000; \
	  print('boot image: sp %08x entry %08x, %d bytes --'%(sp,entry,len(b)), 'ok' if ok else 'BAD'); \
	  exit(0 if ok else 1)" || { echo "FAIL boot image layout"; exit 1; }

$(R)/$(o)/loader.uf2: $(R)/$(o)/loader.bin $(S)/tools/uf2.l $(lv)
	@echo LOVE	$@
	@cd $(R) && out/love src/tools/uf2.l $(o)/loader.bin $(o)/loader.uf2 0x27000 0xADA52840

$(R)/$(o)/firm-ram.elf: $(objs) $(R)/$(o)/xlink.l $(lv)
	@echo HOLO	$@
	@cd $(R) && out/love $(o)/xlink.l -ram $(o)/firm-ram.elf $(objs:$(R)/%=%)

$(R)/$(o)/firm-ram.bin: $(R)/$(o)/firm-ram.elf $(R)/$(o)/ocopy.l
	@echo LOVE	$@
	@cd $(R) && out/love $(o)/ocopy.l -O binary $(o)/firm-ram.elf $(o)/firm-ram.bin
	$(call p_ramchk,$(R)/$(o)/firm-ram.bin,0x20040000,0x20010000)

# what the loader takes: 'L', the length, the bytes, their sum, each word little-endian. the
# bytes end below the loader's ram at 0x2003c000
$(R)/$(o)/firm-ram.pkt: $(R)/$(o)/firm-ram.bin
	@python3 -c "import struct; b=open('$(R)/$(o)/firm-ram.bin','rb').read(); \
	  open('$(R)/$(o)/firm-ram.pkt','wb').write(b'L'+struct.pack('<I',len(b))+b+struct.pack('<I',sum(b)&0xFFFFFFFF)); \
	  ok = 0x20000000+len(b) <= 0x2003C000; \
	  print('ram packet: %d bytes for sram, %d room --'%(len(b),0x3C000), 'ok' if ok else 'BAD'); \
	  exit(0 if ok else 1)" || { rm -f $(R)/$(o)/firm-ram.pkt; echo "FAIL ram packet"; exit 1; }

flash: $(R)/$(o)/loader.uf2
	@test -d $(UF2_DRIVE) || { echo "no uf2 drive at $(UF2_DRIVE): 134 baud on the loader's port or a double tap of reset, or set UF2_DRIVE"; exit 1; }
	cp $(R)/$(o)/loader.uf2 $(UF2_DRIVE)/ && sync
