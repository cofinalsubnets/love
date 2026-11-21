# micro:bit v2 build -- firmware compiled end to end by mooncc -t thumb2sp (the nrf52833's
# cortex-m4 has the single-precision FPU; f64 softens to __aeabi_* calls, which rt.o
# answers). boot.o is laid by mkboot.l, xlink.l links over holo's ldbare32 at flash 0, and
# ocopy.l flattens to the .hex the daplink's drive takes.
#
# `make` builds firm.hex (and .bin) and verifies the boot surface; that is what
# `make test_microbit` gates. `make flash` copies firm.hex onto the daplink's drive,
# mounted at MICROBIT_DRIVE.
p_tgt = thumb2sp
p_be  = thumb2
include ../../../src/inle/port.mk

MICROBIT_DRIVE ?= /run/media/$(USER)/MICROBIT
mb_cc = $(MOONCC) -t thumb2sp -D __STDC_HOSTED__=0 -I.

objs = $(R)/$(o)/microbit.o $(R)/$(o)/main.o $(R)/$(o)/song.o $(R)/$(o)/tonerun.o $(R)/$(o)/lm.o $(R)/$(o)/rt.o $(R)/$(o)/boot.o

.PHONY: microbit flash
default: microbit
microbit: $(R)/$(o)/firm.bin $(R)/$(o)/firm-ram.bin

$(eval $(call p_obj,microbit,test/boards/microbit/microbit.c,microbit.c microbit.h $(S)/inle/bput.h $(mc),$(mb_cc)))
$(eval $(call p_obj,main,test/boards/microbit/main.c,main.c microbit.h song.h $(S)/love/audio/tones.h ../battery.h $(S)/inle/bput.h $(mc),$(mb_cc)))
$(eval $(call p_obj,song,test/boards/microbit/song.c,song.c song.h $(S)/love/audio/tones.h $(mc),$(mb_cc)))
$(eval $(call p_obj,tonerun,src/love/audio/tonerun.c,$(S)/love/audio/tonerun.c $(S)/love/audio/tones.h $(mc),$(mb_cc)))
$(eval $(call p_lay,boot,mkboot,"$(o)/boot.o"))
$(eval $(call p_link,xlink))
$(eval $(p_ocopy))

$(R)/$(o)/firm.elf: $(objs) $(R)/$(o)/xlink.l $(lv)
	@echo HOLO	$@
	@cd $(R) && out/love $(o)/xlink.l $(o)/firm.elf $(objs:$(R)/%=%)

# .bin byte 0 is flash 0: a valid initial SP inside the 128 KB of RAM and a thumb-bit reset
# entry inside the 512 KB of flash
$(R)/$(o)/firm.bin: $(R)/$(o)/firm.elf $(R)/$(o)/ocopy.l
	@echo LOVE	$@
	@cd $(R) && out/love $(o)/ocopy.l -O ihex $(o)/firm.elf $(o)/firm.hex
	@cd $(R) && out/love $(o)/ocopy.l -O binary $(o)/firm.elf $(o)/firm.bin
	@python3 -c "import struct; b=open('$(R)/$(o)/firm.bin','rb').read(); \
	  sp=struct.unpack_from('<I',b,0)[0]; entry=struct.unpack_from('<I',b,4)[0]; \
	  ok = 0x20000000<sp<=0x20020000 and (entry&1)==1 and 0x40<=entry<0x80000; \
	  print('boot image: sp %08x entry %08x --'%(sp,entry), 'ok' if ok else 'BAD'); \
	  exit(0 if ok else 1)" || { echo "FAIL boot image layout"; exit 1; }

# the image a board lane runs from sram over swd, the flash never written
$(R)/$(o)/firm-ram.elf: $(objs) $(R)/$(o)/xlink.l $(lv)
	@echo HOLO	$@
	@cd $(R) && out/love $(o)/xlink.l -ram $(o)/firm-ram.elf $(objs:$(R)/%=%)

$(R)/$(o)/firm-ram.bin: $(R)/$(o)/firm-ram.elf $(R)/$(o)/ocopy.l
	@echo LOVE	$@
	@cd $(R) && out/love $(o)/ocopy.l -O binary $(o)/firm-ram.elf $(o)/firm-ram.bin
	$(call p_ramchk,$(R)/$(o)/firm-ram.bin,0x20020000,0x20010000)

flash: $(R)/$(o)/firm.bin
	@test -d $(MICROBIT_DRIVE) || { echo "no daplink drive at $(MICROBIT_DRIVE): mount it, or set MICROBIT_DRIVE"; exit 1; }
	cp $(R)/$(o)/firm.hex $(MICROBIT_DRIVE)/ && sync
