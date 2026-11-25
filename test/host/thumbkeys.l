; test/host/thumbkeys.l -- the arm family's questions of a target, holo's words and the ones
; moon asks of a state, each against a table written by hand.
;   cat test/00-init.l test/host/thumbkeys.l | out/love

(: h (cite 'holo) m (cite 'moon)
   ts '(x64 a64 rv64 rv32 i386 i386m16 thumb1 thumb2 thumb2sp arm xtensa mips)
   (row p) (map (t \ ?(p t)) ts)
   (hrow k) (row (h k))
   (mrow k) (row (t \ (m k {'tgt t})))
   ;                        x64 a64 rv64 rv32 i386 m16 t1 t2 t2sp arm xt mips
   (test (hrow 'thumb?        = '(0 0   0    0    0    0   1  1  1    1   0  0))
         (hrow 'thumb2?       = '(0 0   0    0    0    0   0  1  1    1   0  0))
         (hrow 'thumb-hosted? = '(0 0   0    0    0    0   0  0  0    1   0  0))
         (hrow 'aprofile?     = '(0 0   0    0    0    0   0  0  0    1   0  0))
         (mrow 't32?          = '(0 0   0    0    0    0   1  1  1    1   0  0))
         (mrow 't2c?          = '(0 0   0    0    0    0   0  1  1    1   0  0))
         (mrow 't2?           = '(0 0   0    0    0    0   0  1  1    0   0  0))
         (mrow 't32f?         = '(0 0   0    0    0    0   0  1  1    1   0  0))
         ; hosted is thumb-2 with a kernel: what no bare archive serves
         (hrow 'thumb-hosted? = row (t \ (h 'thumb2? t && !(m 'rtbare? t)))),
    test_fin (),
    puts "thumbkeys: ok -- thumb? thumb2? thumb-hosted? aprofile? and moon's t32? t2c? t2? t32f? answer the table over twelve targets",
    putc 10))
