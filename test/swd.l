; --- swd: the bit layer over a wire that records what it is asked ---

(borrow "src/apps/swd.l")

; a wire answering ins in order (1 once they run out), its 'log every event so far
(: (swdt-wire ins)
    (: st {'log () 'q ins}
       (ev e) (pin st 'log (e . st 'log))
       {'out (b \ ev ['out b]) 'own (b \ ev ['own b]) 'rst (b \ ev ['rst b])
        'in (_ \ (: q (st 'q) _ (ev ['in]) _ (pin st 'q >q) (two? q ? <q 1)))
        'log (_ \ rev (st 'log))})
   ; out goes lsb first, n bits of it, a negative's two's complement
   w (swdt-wire ())
   _ (swd-bits w 0xB 4)
   _ (swd-bits w -1 3)
   _ (swd-bits w 0xFF 0)
   ; in builds lsb first, one clock a bit
   r (swdt-wire [1 0 1 1 0 1])
   n (swd-sample r 4)
   rl (r 'log ())
   m (swd-sample r 4)                         ; the rest, then the wire's idle ones
   (test (w 'log () = [['out 1] ['out 1] ['out 0] ['out 1] ['out 1] ['out 1] ['out 1]])
         (13 = n) (rl = [['in] ['in] ['in] ['in]]) (14 = m)
         (0 = swd-sample (swdt-wire ()) 0)
         (0 = swd-par 0) (1 = swd-par 1) (0 = swd-par 3) (1 = swd-par 7)
         (0 = swd-par 0xFFFFFFFF) (0 = swd-par 0x80000001) (1 = swd-par 0x80000000)
         (0 = swd-par -1) (1 = swd-par 0x100000001)))    ; the low 32 bits only
