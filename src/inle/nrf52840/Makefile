# xiao nrf52840 build -- firmware compiled end to end by mooncc -t thumb2sp (the nrf52840's
# cortex-m4 has nucleo446's single-precision FPU; f64 softens to __aeabi_* calls, which rt.o
# answers). boot.o is laid by mkboot.l, xlink.l links over holo's ldbare32, ocopy.l
# flattens, and src/tools/uf2.l packs the flat image for the board's uf2 bootloader.
#
# `make` builds firm.uf2 (and .bin/.hex) and verifies the boot surface; that is what
# `make test_nrf52840` gates. `make flash` copies firm.uf2 onto the bootloader's drive
# (a double tap of reset brings it up), mounted at UF2_DRIVE.
p_tgt = thumb2sp
p_be  = thumb2
include ../port.mk

UF2_DRIVE ?= /run/media/$(USER)/XIAO-SENSE
nrf_cc = $(MOONCC) -t thumb2sp -D __STDC_HOSTED__=0 -I.

objs = $(R)/$(o)/nrf52840.o $(R)/$(o)/main.o $(R)/$(o)/lm.o $(R)/$(o)/rt.o $(R)/$(o)/boot.o

.PHONY: nrf52840 flash
default: nrf52840
nrf52840: $(R)/$(o)/firm.uf2

$(eval $(call p_obj,nrf52840,src/inle/nrf52840/nrf52840.c,nrf52840.c nrf52840.h $(S)/inle/bput.h $(mc),$(nrf_cc)))
$(eval $(call p_obj,main,src/inle/nrf52840/main.c,main.c nrf52840.h $(S)/inle/bput.h $(mc),$(nrf_cc)))
$(eval $(call p_lay,boot,mkboot,"$(o)/boot.o"))
$(eval $(call p_link,xlink))
$(eval $(p_ocopy))

$(R)/$(o)/firm.elf: $(objs) $(R)/$(o)/xlink.l $(lv)
	@echo HOLO	$@
	@cd $(R) && out/love $(o)/xlink.l $(o)/firm.elf $(objs:$(R)/%=%)

# .bin byte 0 is flash 0x27000: a valid initial SP inside RAM and a thumb-bit reset entry
# between the app base and the bootloader at 0xF4000
$(R)/$(o)/firm.bin: $(R)/$(o)/firm.elf $(R)/$(o)/ocopy.l
	@echo LOVE	$@
	@cd $(R) && out/love $(o)/ocopy.l -O ihex $(o)/firm.elf $(o)/firm.hex
	@cd $(R) && out/love $(o)/ocopy.l -O binary $(o)/firm.elf $(o)/firm.bin
	@python3 -c "import struct; b=open('$(R)/$(o)/firm.bin','rb').read(); \
	  sp=struct.unpack_from('<I',b,0)[0]; entry=struct.unpack_from('<I',b,4)[0]; \
	  ok = 0x20000000<sp<=0x20040000 and (entry&1)==1 and 0x27000<entry<0xF4000; \
	  print('boot image: sp %08x entry %08x --'%(sp,entry), 'ok' if ok else 'BAD'); \
	  exit(0 if ok else 1)" || { echo "FAIL boot image layout"; exit 1; }

$(R)/$(o)/firm.uf2: $(R)/$(o)/firm.bin $(S)/tools/uf2.l $(lv)
	@echo LOVE	$@
	@cd $(R) && out/love src/tools/uf2.l $(o)/firm.bin $(o)/firm.uf2 0x27000 0xADA52840

flash: $(R)/$(o)/firm.uf2
	@test -d $(UF2_DRIVE) || { echo "no uf2 drive at $(UF2_DRIVE): double tap reset, or set UF2_DRIVE"; exit 1; }
	cp $(R)/$(o)/firm.uf2 $(UF2_DRIVE)/ && sync
