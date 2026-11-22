; test/boards/trinkey/tlink.l -- the trinkey's map for ../boardld.l: sram only, in two stages.
; the first is what the uf2 bootloader's sam-ba loads, above the bootloader's own data and stack
; (its sp starts at 0x20002de0) and below its double-tap word at the top. the second, the
; objects whose sections carry the .s2 prefix, is laid at sram's base, which the bootloader
; holds until the first stage runs, and comes over the first stage's usb console. the first
; stage's .data and .bss are copied between them, its stack under it
(: s2 0x20000000 s2end 0x20004400 s1 0x20005800
   (boardld 'thumb1 s1 ()
    [['at s2 (intern ".s2.text") (intern ".s2.rodata") (intern ".s2.data") (intern ".s2.bss")]
     ['at s1 (intern ".vectors") 'text 'rodata]
     ['copy s2end 'data 'bss]]
    [["__s2_base__" s2] ["__s2_end__" s2end]]))
