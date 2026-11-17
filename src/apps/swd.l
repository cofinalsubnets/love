; src/apps/swd.l -- arm's serial wire debug, driven a bit at a time over a wire.
; a wire is a tablet of four words: 'out b clocks b out on swdio, 'in clocks a bit in and
; answers it, 'own b turns swdio to the host (1) or the target (0), 'rst b holds nrst low (1)
; or lets it go (0). bits go lsb first
(module (swd swd-bits swd-sample swd-par)
(:
 ; the low n bits of x out, then n bits in as a number
 (swd-bits w x n) (n > 0 ? (w 'out (x & 1), swd-bits w (x >> 1) (n - 1)) 0)
 (swd-sample w n) (foldl (\ v i (v | w 'in () << i)) 0 ^n)
 ; the parity of a word's low 32 bits
 (swd-par x) (: (p x) (x = 0 ? 0 (x & 1 ^ p (x >> 1))) (p (x & 0xFFFFFFFF)))
)
) ; module swd
