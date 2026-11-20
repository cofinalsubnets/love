# Raspberry Pi Pico (RP2040) build -- Cortex-M0+ / ARMv6-M, compiled by mooncc -t thumb1.
# No Pico SDK, no CMake, no vendor headers. `make -C test/boards/rp2040` from the project root.
#
# NOTHING FOREIGN TOUCHES THIS IMAGE -- no file, no tool. Every .o is mooncc's or holo's
# (the vector table and crt0 are C in rp2040.c, and boot2 -- the 256-byte stage the mask ROM
# checksums and runs -- is laid by mkboot2.l straight into a named section), rt.o answers the
# __aeabi_* calls v6-M's missing FPU/umull/clz make, rlink.l binds it all over holo's
# ldbare32, and ocopy.l flattens it. gcc's cortex-m0 libgcc was the last foreign file here.
#
# Faces: `make` builds love.elf + love.bin and verifies the segment permissions and the
# boot surface (the boot2 CRC, the vector table's SP and reset entry) -- the three words a
# bricked-looking Pico always traces back to. it builds probe.uf2 too, the swd probe
# (probe.c, usb.c) packed by src/tools/uf2.l for the rom's drive. `make objs` compiles only.
p_tgt      = thumb1
p_be       = thumb1
p_link_be  = thumb1 thumb2
include ../../../src/inle/port.mk

rp_cc = $(MOONCC) -t thumb1 -D __STDC_HOSTED__=0 -I.

objs = $(R)/$(o)/boot2.o $(R)/$(o)/rp2040.o $(R)/$(o)/main.o $(R)/$(o)/busb.o $(R)/$(o)/lm.o $(R)/$(o)/rt.o
robjs = $(filter-out %/boot2.o,$(objs))
pobjs = $(R)/$(o)/boot2.o $(R)/$(o)/rp2040.o $(R)/$(o)/probe.o $(R)/$(o)/usb.o $(R)/$(o)/rt.o

.PHONY: objs bin
default: bin
bin: $(R)/$(o)/love.bin $(R)/$(o)/love-ram.bin $(R)/$(o)/probe.uf2
objs: $(objs) $(pobjs)

$(eval $(call p_obj,main,test/boards/rp2040/main.c,main.c rp2040.h ../battery1.h $(S)/inle/bput.h $(mc),$(rp_cc)))
$(eval $(call p_obj,rp2040,test/boards/rp2040/rp2040.c,rp2040.c rp2040.h $(mc),$(rp_cc)))
$(eval $(call p_obj,probe,test/boards/rp2040/probe.c,probe.c rp2040.h $(mc),$(rp_cc)))
$(eval $(call p_obj,usb,test/boards/rp2040/usb.c,usb.c rp2040.h $(S)/inle/usbcdc.h $(mc),$(rp_cc) -D UCDC_ACM2))
$(eval $(call p_obj,busb,test/boards/rp2040/usb.c,usb.c rp2040.h $(S)/inle/usbcdc.h $(mc),$(rp_cc) -D 'UCDC_PRODUCT="love board"'))

# boot2: 240 payload bytes zero-padded to 252 and CRC-stamped, in .boot2. no gas -- the
# section name IS the interface, and the writer spells it now.
$(eval $(call p_lay,boot2,mkboot2,"test/boards/rp2040/boot2.bin" "$(o)/boot2.o"))
$(R)/$(o)/boot2.o: boot2.bin

# the link is ours: rlink.l drives holo's ldbare32 with the Pico's flash map, in place of
# arm-none-eabi-ld + rp2040.lds. Nothing but our own objects is named on the line.
$(eval $(call p_link,rlink))
$(eval $(p_ocopy))

# Flash R|X, SRAM R|W: rlink.l asserts the first and the sections answer for the second.
# Read back rather than trusted -- nothing here is both writable and executable.
define rp_elf
	@python3 -c "import struct; b=open('$(R)/$(o)/$1','rb').read(); \
	  po,pe,pn = struct.unpack_from('<I',b,28)[0], struct.unpack_from('<H',b,42)[0], struct.unpack_from('<H',b,44)[0]; \
	  ph=[struct.unpack_from('<8I',b,po+i*pe) for i in range(pn)]; \
	  ld=[(p[2],p[6]) for p in ph if p[0]==1]; \
	  wx=[hex(a) for a,f in ld if (f&2) and (f&1)]; \
	  fl=[f for a,f in ld if a==0x10000000]; \
	  ok = fl==[5] and not wx; \
	  print('segments:', ' '.join('%08x %s'%(a,'RWE' if f==7 else 'R E' if f==5 else 'RW ' if f==6 else str(f)) for a,f in ld), '--', 'ok' if ok else 'BAD (w+x: %s)'%wx); \
	  exit(0 if ok else 1)" || { echo "FAIL rp2040 segment permissions"; exit 1; }
endef

# .bin byte offsets ARE flash offsets, so the boot surface is readable straight out of it:
# the ROM checks boot2's CRC before anything else runs, then the vector table at 0x10000100
# must hold an SP inside SRAM and a thumb-bit reset entry inside flash. Any one of the
# three wrong and the board just sits there.
define rp_bin
	@python3 -c "import struct; b=open('$(R)/$(o)/$1','rb').read(); \
	  crc=struct.unpack_from('<I',b,252)[0]; sp,e=struct.unpack_from('<II',b,256); \
	  ok = crc==0x7a4eb274 and 0x20000000<sp<=0x20042000 and (e&1)==1 and 0x10000100<e<0x10200000; \
	  print('boot image: boot2 crc %08x sp %08x entry %08x --'%(crc,sp,e), 'ok' if ok else 'BAD'); \
	  exit(0 if ok else 1)" || { echo "FAIL rp2040 boot image"; exit 1; }
endef

$(R)/$(o)/love.elf: $(objs) $(R)/$(o)/rlink.l $(lv)
	@echo HOLO	$@
	@cd $(R) && out/love $(o)/rlink.l $(o)/love.elf $(objs:$(R)/%=%)
	$(call rp_elf,love.elf)

$(R)/$(o)/love.bin: $(R)/$(o)/love.elf $(R)/$(o)/ocopy.l
	@echo LOVE	$@
	@cd $(R) && out/love $(o)/ocopy.l -O binary $(o)/love.elf $(o)/love.bin
	$(call rp_bin,love.bin)

# the image a board lane runs from sram by the rom's warm entry, the flash never written
$(R)/$(o)/love-ram.elf: $(robjs) $(R)/$(o)/rlink.l $(lv)
	@echo HOLO	$@
	@cd $(R) && out/love $(o)/rlink.l -ram $(o)/love-ram.elf $(robjs:$(R)/%=%)

$(R)/$(o)/love-ram.bin: $(R)/$(o)/love-ram.elf $(R)/$(o)/ocopy.l
	@echo LOVE	$@
	@cd $(R) && out/love $(o)/ocopy.l -O binary $(o)/love-ram.elf $(o)/love-ram.bin
	$(call p_ramchk,$(R)/$(o)/love-ram.bin,0x20042000,0x20020000)

$(R)/$(o)/probe.elf: $(pobjs) $(R)/$(o)/rlink.l $(lv)
	@echo HOLO	$@
	@cd $(R) && out/love $(o)/rlink.l $(o)/probe.elf $(pobjs:$(R)/%=%)
	$(call rp_elf,probe.elf)

$(R)/$(o)/probe.bin: $(R)/$(o)/probe.elf $(R)/$(o)/ocopy.l
	@echo LOVE	$@
	@cd $(R) && out/love $(o)/ocopy.l -O binary $(o)/probe.elf $(o)/probe.bin
	$(call rp_bin,probe.bin)

# the rom's drive takes it as a file; family 0xe48bff56 is the rp2040's
$(R)/$(o)/probe.uf2: $(R)/$(o)/probe.bin $(S)/tools/uf2.l $(lv)
	@echo LOVE	$@
	@cd $(R) && out/love src/tools/uf2.l $(o)/probe.bin $(o)/probe.uf2 0x10000000 0xE48BFF56
