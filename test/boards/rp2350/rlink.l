; test/boards/rp2350/rlink.l -- the Pico 2 (RP2350, Arm)'s map for ../boardld.l. no boot2: the
; rom sets up flash itself and finds the image definition mkboot.l lays behind the vector table,
; both in .vectors at flash base. the stack tops the 520 KB SRAM; .data is stored in flash and
; runs in SRAM (the `copy` run). -ram lays it all in SRAM, for a uf2 the rom runs there: code
; from its base, .data copied up to 0x20040000
(boardld 'thumb2sp 0x20082000
 [['at 0x10000000 (intern ".vectors") 'text 'rodata] ['copy 0x20000000 'data 'bss]]
 [['at 0x20000000 (intern ".vectors") 'text 'rodata] ['copy 0x20040000 'data 'bss]]
 ())
