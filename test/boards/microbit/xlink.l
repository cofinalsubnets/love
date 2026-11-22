; test/boards/microbit/xlink.l -- the micro:bit v2's map for ../boardld.l. the daplink writes
; flash from 0, where the core reads its vector table, so .vectors is named first. RAM is the
; 128 KB at 0x20000000, the stack at its top; .data is stored in flash and runs in RAM (the
; `copy` run). -ram lays it all in RAM for a run over swd: code from its base, .data copied up
; to 0x20010000
(boardld 'thumb2sp 0x20020000
 [['at 0x00000000 (intern ".vectors") 'text 'rodata] ['copy 0x20000000 'data 'bss]]
 [['at 0x20000000 (intern ".vectors") 'text 'rodata] ['copy 0x20010000 'data 'bss]]
 ())
