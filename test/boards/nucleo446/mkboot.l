; test/boards/nucleo446/mkboot.l -- boot.o for the Nucleo-F446RE: the vector table at flash base,
; and semihosting's SYS_EXIT_EXTENDED for the QSMOKE twin. r1 points at (reason, code), r0's code
; pushed first so the reason lands under it at sp. on silicon a bkpt with no debugger locks up
(: (mkboot dst)
   (armboot dst 0 ()
    [['label 'sh_exit]
     ['li 'r1 0x20026]                   ; ADP_Stopped_ApplicationExit
     ['push 'r0] ['push 'r1] ['mov 'r1 'sp]
     ['li 'r0 0x20] ['brk 171]
     ['label 'shx-spin] ['jmp 'shx-spin]]
    '("sh_exit")))
