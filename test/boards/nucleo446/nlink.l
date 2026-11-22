; test/boards/nucleo446/nlink.l -- the Nucleo-F446RE's map for ../boardld.l. code lives in the
; 512 KB flash at 0x08000000, RAM is the 128 KB SRAM at 0x20000000, and .data is stored in flash
; but runs in SRAM (the `copy` run). .vectors is named first by hand: the core fetches SP and
; reset from flash base, and its ALLOC-only flags would file it after the code. .startup rides
; text, reached through the reset word. -ram lays it all in SRAM for a run over swd: code from
; its base, .data copied up to 0x20010000
(boardld 'thumb2sp 0x20020000
 [['at 0x08000000 (intern ".vectors") 'text 'rodata] ['copy 0x20000000 'data 'bss]]
 [['at 0x20000000 (intern ".vectors") 'text 'rodata] ['copy 0x20010000 'data 'bss]]
 ())
