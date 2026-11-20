; test/boards/nrf52840/xlink.l -- the xiao nrf52840's map for ../boardld.l. the uf2 bootloader
; starts the app at 0x27000, above the mbr and softdevice, and reads its vector table there, so
; .vectors is named first. RAM is the 256 KB at 0x20000000, the stack at its top; .data is
; stored in flash and runs in RAM (the `copy` run). -ram lays it all in RAM for a run over swd:
; code from its base, .data copied up to 0x20010000
(boardld 'thumb2sp 0x20040000
 [['at 0x00027000 (intern ".vectors") 'text 'rodata] ['copy 0x20000000 'data 'bss]]
 [['at 0x20000000 (intern ".vectors") 'text 'rodata] ['copy 0x20010000 'data 'bss]]
 ())
