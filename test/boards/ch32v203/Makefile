# ch32v203 build -- the qt py's blink, all mooncc -t rv32 (rv32imac), linked at 0 where the
# chip runs from out of reset; no crt0, no vector table, no interrupts.
#
# `make` builds firm.elf and firm.bin and verifies the image; that is what `make test_ch32v203`
# gates. test_ch32v203_board writes it through the mask rom's usb isp by src/tools/wchisp.l.
include ../../../src/inle/port.mk

ch_src = test/boards/ch32v203/boot.c test/boards/ch32v203/blink.c

.PHONY: ch32v203
default: ch32v203
ch32v203: $(R)/$(o)/firm.bin

$(eval $(p_ocopy))

# boot.c first, so _start is the image's first word
$(R)/$(o)/firm.elf: boot.c blink.c $(lv)
	@echo MOON	$@
	@mkdir -p $(R)/$(o)
	@cd $(R) && $(MOONCC) -t rv32 -os none -nostdlib -D __STDC_HOSTED__=0 -Ttext 0 \
	  -Isrc/apps/moon/include -o $(o)/firm.elf $(ch_src)

# one load at 0 inside the 32 KB of flash, the entry at 0, its first word lui sp into sram
$(R)/$(o)/firm.bin: $(R)/$(o)/firm.elf $(R)/$(o)/ocopy.l
	@echo LOVE	$@
	@cd $(R) && out/love $(o)/ocopy.l -O binary $(o)/firm.elf $(o)/firm.bin
	@python3 -c "import struct; b=open('$(R)/$(o)/firm.elf','rb').read(); n=len(open('$(R)/$(o)/firm.bin','rb').read()); \
	  e,po,k=struct.unpack_from('<I',b,24)[0],struct.unpack_from('<I',b,28)[0],struct.unpack_from('<H',b,44)[0]; \
	  ph=[struct.unpack_from('<8I',b,po+32*i) for i in range(k)]; ld=[p for p in ph if p[0]==1]; \
	  w=struct.unpack_from('<I',open('$(R)/$(o)/firm.bin','rb').read(),0)[0]; \
	  ok = b[18]==243 and e==0 and len(ld)==1 and ld[0][2]==0 and 0<n<=32768 and w&0xfff==0x137 and w>>12==0x20003; \
	  print('boot image: entry %08x, %d bytes, first word %08x --'%(e,n,w), 'ok' if ok else 'BAD'); \
	  exit(0 if ok else 1)" || { echo "FAIL boot image layout"; exit 1; }
