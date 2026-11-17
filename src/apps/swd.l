; src/apps/swd.l -- arm's serial wire debug, driven a bit at a time over a wire.
; a wire is a tablet of four words: 'out b clocks b out on swdio, 'in clocks a bit in and
; answers it, 'own b turns swdio to the host (1) or the target (0), 'rst b holds nrst low (1)
; or lets it go (0). bits go lsb first
(module (swd swd-bits swd-sample swd-par swd-xfer)
(:
 ; the low n bits of x out, then n bits in as a number
 (swd-bits w x n) (n > 0 ? (w 'out (x & 1), swd-bits w (x >> 1) (n - 1)) 0)
 (swd-sample w n) (foldl (\ v i (v | w 'in () << i)) 0 ^n)
 ; the parity of a word's low 32 bits
 (swd-par x) (: (p x) (x = 0 ? 0 (x & 1 ^ p (x >> 1))) (p (x & 0xFFFFFFFF)))

 ; one transfer to the debug port (ap 0) or an access port (1), read (rd 1) or written, its
 ; register a's bits 2 and 3: [ack v], a read's value or the one written. ack 1 is ok; a wait
 ; (2) is asked again, 64 times at most; a fault (4) or no answer (7) answers its ack, and a
 ; read whose parity is wrong the ack -1
 (swd-xfer w ap rd a v)
  (: ad (a >> 2 & 3)
     rq (1 | ap << 1 | rd << 2 | ad << 3 | swd-par (ap | rd << 1 | ad << 2) << 5 | 1 << 7)
     (go k) (: _ (swd-bits w rq 8) _ (w 'own 0) _ (swd-sample w 1) ack (swd-sample w 3)
               (? (ack = 2 && k > 0) (swd-sample w 1, w 'own 1, swd-bits w 0 8, go (k - 1))
                  (ack != 1) (swd-sample w 1, w 'own 1, [ack ()])
                  (rd = 1) (: x (swd-sample w 32) p (swd-sample w 1) _ (swd-sample w 1) _ (w 'own 1)
                              _ (swd-bits w 0 2)
                              [(p = swd-par x ? ack -1) x])
                  (: _ (swd-sample w 1) _ (w 'own 1) _ (swd-bits w v 32) _ (swd-bits w (swd-par v) 1)
                     _ (swd-bits w 0 2)
                     [ack v])))
     (go 64))
)
) ; module swd
