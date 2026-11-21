; test/boards/rp2040/rlink.l -- the Raspberry Pi Pico's map for ../boardld.l. the mask ROM reads
; the first 256 bytes of flash (0x10000000) as a checksummed second stage (mkboot2.l), then jumps
; to the vector table at 0x10000100. both addresses are the silicon's, so the map names them, and
; .boot2 must be first or the checksum reads the wrong bytes; flash is R|X. the stack tops the
; 264 KB SRAM; .data is stored in flash and runs in SRAM (the `copy` run). -ram lays it all in
; SRAM for the rom's warm entry, with no boot2: code from its base, .data copied up to
; 0x20020000, clear of the rom's own scratch at the top
(boardld 'thumb1 0x20042000
 [['at 0x10000000 '(flags 5) (intern ".boot2")]
  ['at 0x10000100 (intern ".vectors") 'text 'rodata]
  ['copy 0x20000000 'data 'bss]]
 [['at 0x20000000 (intern ".vectors") 'text 'rodata] ['copy 0x20020000 'data 'bss]]
 ())
