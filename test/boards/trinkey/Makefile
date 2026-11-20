# adafruit neokey trinkey m0 (atsamd21e18) build -- cortex-m0+ / armv6-m, compiled by mooncc -t
# thumb1, linked by tlink.l over holo's ldbare32 into sram, flattened by ocopy.l. `make -C
# test/boards/trinkey` from the project root builds the two stages and verifies their layout:
# firm-ram.bin, what the uf2 bootloader's sam-ba writes high in sram and starts, and stage2.pkt,
# what a host then sends that first stage for sram's base. the flash is never written
p_tgt      = thumb1
p_be       = thumb1
p_link_be  = thumb1 thumb2
include ../../../src/inle/port.mk

tk_cc = $(MOONCC) -t thumb1 -D __STDC_HOSTED__=0 -I.

# the second stage's objects, their sections .s2-prefixed for tlink.l's map
s1objs = $(R)/$(o)/samd21.o $(R)/$(o)/main.o $(R)/$(o)/usb.o
s2objs = $(R)/$(o)/bat2.o $(R)/$(o)/rt2.o
objs = $(s1objs) $(s2objs)

.PHONY: objs bin
default: bin
bin: $(R)/$(o)/firm-ram.bin $(R)/$(o)/stage2.pkt
objs: $(objs)

$(eval $(call p_obj,samd21,test/boards/trinkey/samd21.c,samd21.c samd21.h $(mc),$(tk_cc)))
$(eval $(call p_obj,main,test/boards/trinkey/main.c,main.c samd21.h ../battery1.h $(S)/inle/bput.h $(mc),$(tk_cc)))
$(eval $(call p_obj,usb,test/boards/trinkey/usb.c,usb.c samd21.h $(S)/inle/usbcdc.h $(mc),$(tk_cc) -D UCDC_RXN=512))
$(eval $(call p_obj,bat,test/boards/trinkey/bat.c,bat.c ../battery1.h $(S)/inle/bput.h $(mc),$(tk_cc)))

$(eval $(call p_link,tlink))
$(eval $(p_ocopy))

$(R)/$(o)/%2.o: $(R)/$(o)/%.o $(R)/$(o)/ocopy.l
	@echo LOVE	$@
	@cd $(R) && out/love $(o)/ocopy.l --prefix-alloc-sections=.s2 $(o)/$*.o $(o)/$*2.o

$(R)/$(o)/firm.elf: $(objs) $(R)/$(o)/tlink.l $(lv)
	@echo HOLO	$@
	@cd $(R) && out/love $(o)/tlink.l $(o)/firm.elf $(objs:$(R)/%=%)

$(R)/$(o)/firm.flat: $(R)/$(o)/firm.elf $(R)/$(o)/ocopy.l
	@echo LOVE	$@
	@cd $(R) && out/love $(o)/ocopy.l -O binary $(o)/firm.elf $(o)/firm.flat

# the flat image from sram's base cut in two. the first stage: sp at its base, a thumb entry
# inside it, ending below the double tap, its .data and .bss below it with 1 KB of stack. the
# second: its sections inside the room laid for it, sent padded to that room as 'L', length,
# bytes, sum, each word little-endian
$(R)/$(o)/firm-ram.bin $(R)/$(o)/stage2.pkt: $(R)/$(o)/firm.flat
	@python3 -c "import struct; f=open('$(R)/$(o)/firm.flat','rb').read(); e=open('$(R)/$(o)/firm.elf','rb').read(); \
	  so,se,sn,si=struct.unpack_from('<I',e,32)[0],struct.unpack_from('<H',e,46)[0],struct.unpack_from('<H',e,48)[0],struct.unpack_from('<H',e,50)[0]; \
	  sh=[struct.unpack_from('<10I',e,so+i*se) for i in range(sn)]; st=sh[si]; \
	  nm=lambda h: e[st[4]+h[0]:e.index(b'\\0',st[4]+h[0])].decode(); \
	  s2=0x20000000; s2end=0x20004400; s1=0x20005800; \
	  end2=max([h[3]+h[5] for h in sh if nm(h).startswith('.s2.')] or [s2]); \
	  low=max([h[3]+h[5] for h in sh if nm(h) in ('.data','.bss')] or [s2end]); \
	  b=f[s1-s2:]; p=f[:s2end-s2].ljust(s2end-s2,b'\\0'); \
	  sp,en=struct.unpack_from('<II',b,0); end=s1+len(b); \
	  ok = sp==s1 and (en&1)==1 and s1<en<end and end<=0x20007F00 and end2<=s2end and low<=s1-1024; \
	  open('$(R)/$(o)/firm-ram.bin','wb').write(b); \
	  open('$(R)/$(o)/stage2.pkt','wb').write(b'L'+struct.pack('<I',len(p))+p+struct.pack('<I',sum(p)&0xFFFFFFFF)); \
	  print('ram image: first stage sp %08x entry %08x, %d of %d bytes, data and bss to %08x; second %d of %d bytes --'%(sp,en,len(b),0x20007F00-s1,low,end2-s2,s2end-s2), 'ok' if ok else 'BAD'); \
	  exit(0 if ok else 1)" || { rm -f $(R)/$(o)/firm-ram.bin $(R)/$(o)/stage2.pkt; echo "FAIL trinkey image layout"; exit 1; }
