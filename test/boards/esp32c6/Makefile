# esp32-c6 build -- the battery compiled end to end by mooncc -t rv32 (rv32imac, soft float)
# and linked by it at hp sram, one image the rom loader lays from its uart: no flash, no
# bootloader, no crt0.
#
# `make` builds firm.elf and verifies where it loads; that is what `make test_esp32c6`
# gates. test_esp32c6_board runs it on the chip through src/tools/esprom.l.
include ../../../src/inle/port.mk

c6_src = test/boards/esp32c6/c6.c test/boards/esp32c6/main.c test/boards/esp32c6/gauge.c \
  src/apps/moon/lib/rt.c src/apps/moon/lib/moonlibc/math/lm.c

.PHONY: esp32c6
default: esp32c6
esp32c6: $(R)/$(o)/firm.elf

# the gauge's pixel table, xbell's magma in linear light at a quarter of full
$(R)/$(o)/gauge.h: mkgauge.l $(S)/tools/xbell.l $(lv)
	@echo LOVE	$@
	@mkdir -p $(R)/$(o)
	@cd $(R) && out/love test/boards/esp32c6/mkgauge.l src/tools/xbell.l $(o)/gauge.h 250

# one load inside the 512 KB of hp sram, below the rom's own at its top, the entry inside it
$(R)/$(o)/firm.elf: c6.c main.c gauge.c $(R)/$(o)/gauge.h ../battery.h $(S)/inle/bput.h $(S)/apps/moon/lib/rt.c $(S)/apps/moon/lib/moonlibc/math/lm.c $(lv)
	@echo MOON	$@
	@mkdir -p $(R)/$(o)
	@cd $(R) && $(MOONCC) -t rv32 -os none -nostdlib -D __STDC_HOSTED__=0 -Ttext 0x40800000 \
	  -I$(o) -Isrc/apps/moon/lib/moonlibc/math -Isrc/apps/moon/include -o $(o)/firm.elf $(c6_src)
	@python3 -c "import struct; b=open('$(R)/$(o)/firm.elf','rb').read(); \
	  e,po,n=struct.unpack_from('<I',b,24)[0],struct.unpack_from('<I',b,28)[0],struct.unpack_from('<H',b,44)[0]; \
	  ph=[struct.unpack_from('<8I',b,po+32*i) for i in range(n)]; ld=[p for p in ph if p[0]==1]; \
	  ok = b[18]==243 and ld and all(0x40800000<=p[2] and p[2]+p[5]<=0x40870000 for p in ld) \
	    and any(p[2]<=e<p[2]+p[4] for p in ld); \
	  print('boot image: entry %08x, %d load(s) --'%(e,len(ld)), 'ok' if ok else 'BAD'); \
	  exit(0 if ok else 1)" || { echo "FAIL boot image layout"; exit 1; }
