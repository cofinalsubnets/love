# esp32 build -- the battery compiled end to end by mooncc -t xtensa (call0, soft float) for the
# classic (firm.elf) and the s3 (firm-s3.elf), each code at iram and data at dram, as the rom's
# loader lays them from its serial: no bootloader, no crt0, the flash never written.
#
# `make` builds both and verifies where they load; that is what `make test_esp32` gates.
# test_esp32_board and test_esp32s3_board run them after holo's law, through src/tools/esprom.l.
include ../../../src/inle/port.mk

x_src = test/boards/esp32/esp32.c test/boards/esp32/main.c \
  src/apps/moon/lib/rt.c src/apps/moon/lib/moonlibc/math/lm.c src/apps/moon/lib/moonlibc/math/lmf.c
x_dep = esp32.c main.c ../battery.h $(S)/inle/bput.h $(S)/apps/moon/lib/rt.c $(S)/apps/moon/lib/moonlibc/math/lm.c $(S)/apps/moon/lib/moonlibc/math/lmf.c $(lv)
x_cc = $(MOONCC) -t xtensa -nostdlib -D __STDC_HOSTED__=0 -Isrc/apps/moon/lib/moonlibc/math -Isrc/apps/moon/include

.PHONY: esp32
default: esp32
esp32: $(R)/$(o)/firm.elf $(R)/$(o)/firm-s3.elf

# the loads: code inside iram TEXT_LO..TEXT_HI, data inside dram DATA_LO..DATA_HI, the entry in
# the code. the s3's iram and dram are one sram on two buses, so its code ends below its data's
# alias there
x_chk = python3 -c "import struct,sys; b=open(sys.argv[1],'rb').read(); tl,th,dl,dh=[int(a,16) for a in sys.argv[2:6]]; \
  e,po,n=struct.unpack_from('<I',b,24)[0],struct.unpack_from('<I',b,28)[0],struct.unpack_from('<H',b,44)[0]; \
  ph=[struct.unpack_from('<8I',b,po+32*i) for i in range(n)]; ld=[p for p in ph if p[0]==1 and p[5]]; \
  tx=[p for p in ld if p[6]&1]; dt=[p for p in ld if not p[6]&1]; \
  ok = b[18]==94 and tx and all(tl<=p[2] and p[2]+p[5]<=th for p in tx) and all(dl<=p[2] and p[2]+p[5]<=dh for p in dt) \
    and any(p[2]<=e<p[2]+p[4] for p in tx); \
  print('%s: entry %08x, code %d bytes, data %d --'%(sys.argv[1].split('/')[-1],e,sum(p[5] for p in tx),sum(p[5] for p in dt)), 'ok' if ok else 'BAD'); \
  exit(0 if ok else 1)"

$(R)/$(o)/firm.elf: $(x_dep)
	@echo MOON	$@
	@mkdir -p $(R)/$(o)
	@cd $(R) && $(x_cc) -Ttext 0x40080000 -Tdata 0x3FFB0000 -o $(o)/firm.elf $(x_src)
	@$(x_chk) $(R)/$(o)/firm.elf 40080000 400A0000 3FFB0000 3FFE0000 || { echo "FAIL esp32 image layout"; exit 1; }

$(R)/$(o)/firm-s3.elf: $(x_dep)
	@echo MOON	$@
	@mkdir -p $(R)/$(o)
	@cd $(R) && $(x_cc) -D ESP32S3 -Ttext 0x40378000 -Tdata 0x3FCA0000 -o $(o)/firm-s3.elf $(x_src)
	@$(x_chk) $(R)/$(o)/firm-s3.elf 40378000 40390000 3FCA0000 3FCD0000 || { echo "FAIL esp32s3 image layout"; exit 1; }
