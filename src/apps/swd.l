; src/apps/swd.l -- arm's serial wire debug, driven a bit at a time over a wire.
; a wire is a tablet of four words: 'out b clocks b out on swdio, 'in clocks a bit in and
; answers it, 'own b turns swdio to the host (1) or the target (0), 'rst b holds nrst low (1)
; or lets it go (0). bits go lsb first
(module (swd swd-bits swd-sample swd-par swd-xfer swd-line swd-dp swd-dpw swd-ap swd-apw swd-connect swd-rd swd-rds swd-wr swd-wrs)
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

 ; the switch: a line reset, the jtag-to-swd sequence, a line reset again, then idle
 (swd-line w) (w 'own 1, swd-bits w -1 56, swd-bits w 0xE79E 16, swd-bits w -1 56, swd-bits w 0 8)

 ; the debug port's registers by address, each [ack v]; an access port's (apsel 0) through
 ; select's bank. an ap read is posted, its value the next one's, so rdbuff (dp 12) answers it
 (swd-dp w a) (swd-xfer w 0 1 a 0)
 (swd-dpw w a v) (swd-xfer w 0 0 a v)
 (swd-ap w a) (: s (swd-dpw w 8 (a & 0xF0)) r (<s = 1 ? (swd-xfer w 1 1 a 0) s) (<r = 1 ? (swd-dp w 12) r))
 (swd-apw w a v) (: s (swd-dpw w 8 (a & 0xF0)) (<s = 1 ? (swd-xfer w 1 0 a v) s))

 ; the port up: the switch, its id, abort clearing the sticky flags, both power domains asked
 ; and their acks awaited, 100 polls at most, then the access port's id: [dpidr apidr], or a
 ; scare naming the step and what it answered
 (swd-connect w)
  (: _ (swd-line w) id (swd-dp w 0)
     _ (<id = 1 ? 0 (scare 'swd-connect ['id id]))
     _ (swd-dpw w 0 0x1E)
     _ (swd-dpw w 4 0x50000000)
     (up k) (: c (swd-dp w 4)
               (? (<c = 1 && (c 1 & 0xA0000000) = 0xA0000000) 1
                  (k > 0) (up (k - 1))
                  (scare 'swd-power c)))
     _ (up 100)
     ap (swd-ap w 0xFC)
     (<ap = 1 ? [(id 1) (ap 1)] (scare 'swd-connect ['ap ap])))

 ; memory through the ahb-ap in 32-bit words. csw sets the size and tar's step, 4 after each
 ; drw access but only within tar's 1K block, so a run sets tar again at each boundary. a
 ; run's reads are posted: each drw read answers the one before, rdbuff the last
 csw 0x23000012
 (swd-ok what r) (<r = 1 ? (r 1) (scare what r))
 (swd-at a) ((a & 3) = 0 ? a (scare 'swd-align a))
 (swd-rds w a n)
  (: _ (swd-at a)
     _ (swd-ok 'swd-csw (swd-apw w 0 csw))
     (run a n) (n < 1 ? ()
                (: k (min n ((1024 - (a & 1023)) // 4))
                   _ (swd-ok 'swd-tar (swd-apw w 4 a))
                   vs (map (_ \ swd-ok 'swd-read (swd-xfer w 1 1 12 0)) ^k)
                   last (swd-ok 'swd-read (swd-dp w 12))
                   (>vs + [last] + run (a + 4 * k) (n - k))))
     (run a n))
 (swd-rd w a) <(swd-rds w a 1)
 ; a run of words written from a, answering how many
 (swd-wrs w a vs)
  (: _ (swd-at a)
     _ (swd-ok 'swd-csw (swd-apw w 0 csw))
     _ (swd-ok 'swd-tar (swd-apw w 4 a))
     (run a vs k) (!(two? vs) ? k
                   (: _ ((a & 1023) = 0 && k > 0 ? (swd-ok 'swd-tar (swd-apw w 4 a)) 0)
                      _ (swd-ok 'swd-write (swd-xfer w 1 0 12 <vs))
                      (run (a + 4) >vs (k + 1))))
     (run a vs 0))
 (swd-wr w a v) (: _ (swd-wrs w a [v]) v)
)
) ; module swd
