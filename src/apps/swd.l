; src/apps/swd.l -- arm's serial wire debug, driven a bit at a time over a wire.
; a wire is a tablet of four words: 'out b clocks b out on swdio, 'in clocks a bit in and
; answers it, 'own b turns swdio to the host (1) or the target (0), 'rst b holds nrst low (1)
; or lets it go (0). bits go lsb first
(module (swd swd-bits swd-sample swd-par swd-xfer swd-line swd-dp swd-dpw swd-ap swd-apw swd-connect swd-rd swd-rds swd-wr swd-wrs
             swd-halted? swd-wait swd-halt swd-attach swd-resume swd-run
             f4-ids f4-sectors f4-idle f4-locked? f4-unlock f4-lock f4-erase f4-write f4-read f4-flash
             gpio-attr gpio-cfg gpio-req gpio-vals gpio-wire-on gpio-wire)
(borrow 'bytes)
(borrow 'posix)
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

 ; the core's debug registers: dhcsr (its key in each write; debug enable, halt; the halt
 ; seen in bit 17), demcr's reset vector catch, aircr's system reset. debug is turned on in a
 ; write of its own: a halt asked in the same write is undefined, and on an f4 it is lost
 dhcsr 0xE000EDF0 demcr 0xE000EDFC aircr 0xE000ED0C
 (swd-halted? w) ((((swd-rd w dhcsr) >> 17) & 1) = 1)
 (swd-wait w k) (? (swd-halted? w) 1 (k > 0) (swd-wait w (k - 1)) (scare 'swd-halt (swd-rd w dhcsr)))
 (swd-halt w) (: _ (swd-wr w dhcsr 0xA05F0001) _ (swd-wr w dhcsr 0xA05F0003) (swd-wait w 100))
 ; connect under reset: nrst held through the switch, debug on and the reset vector caught
 ; (a halt asked under reset is not kept, so the catch is what stops it), nrst let go, the
 ; halt awaited and the catch put back: connect's ids
 (swd-attach w) (: _ (w 'rst 1) ids (swd-connect w)
                   _ (swd-wr w dhcsr 0xA05F0001) _ (swd-wr w dhcsr 0xA05F0003) _ (swd-wr w demcr 1)
                   _ (w 'rst 0) _ (swd-wait w 100) _ (swd-wr w demcr 0)
                   ids)
 ; the core let go where it stopped, still under debug; or reset and run from the top, free
 (swd-resume w) (: _ (swd-wr w dhcsr 0xA05F0001) 1)
 (swd-run w) (: _ (swd-wr w demcr 0) _ (swd-wr w dhcsr 0xA05F0000) _ (swd-wr w aircr 0x05FA0004) 1)

 ; an stm32f4: its id code and flash size in K
 (f4-ids w) [(swd-rd w 0xE0042000) ((swd-rd w 0x1FFF7A20) >> 16)]
 ; its flash from 0x08000000: sectors of 16K 16K 16K 16K 64K then 128Ks, [n base size] each,
 ; written as x32 words. keyr +4, sr +12 (busy bit 16, errors 0x1F2, each cleared by a 1),
 ; cr +16 (pg 1, ser 2, the sector from bit 3, psize from bit 8, strt bit 16, lock bit 31)
 fl 0x40023C00 fbase 0x08000000
 f4-sectors (: (k i) (i < 4 ? 16384 (i = 4 ? 65536 131072))
               (map (i \ [i (fbase + net (map k ^i)) (k i)]) ^8))
 ; the flash idle, polled k times at most: its status, or a scare with an error's
 (f4-idle w k) (: s (swd-rd w (fl + 12))
                  (? ((s & 0x1F2) != 0) (scare 'f4-flash s)
                     ((s & 0x10000) = 0) s
                     (k > 0) (f4-idle w (k - 1))
                     (scare 'f4-busy s)))
 (f4-locked? w) (((swd-rd w (fl + 16)) & 0x80000000) != 0)
 ; a key pair while unlocked locks the flash till a reset, so only a locked one is given it
 (f4-unlock w) (: _ (f4-locked? w ? (swd-wr w (fl + 4) 0x45670123, swd-wr w (fl + 4) 0xCDEF89AB) 0)
                  (f4-locked? w ? (scare 'f4-locked 0) 1))
 (f4-lock w) (: _ (swd-wr w (fl + 16) 0x80000000) 1)
 (f4-erase w n) (: _ (f4-idle w 1000000) _ (swd-wr w (fl + 12) 0x1F3)
                   _ (swd-wr w (fl + 16) (2 | n << 3 | 2 << 8))
                   _ (swd-wr w (fl + 16) (2 | n << 3 | 2 << 8 | 0x10000))
                   _ (f4-idle w 1000000)
                   (swd-wr w (fl + 16) 0))
 ; the words of s, padded with ones (what erase leaves) to a multiple of 4
 (f4-words s) (: p (s + string (map (_ \ 255) ^((4 - #s % 4) % 4)))
                 (map (i \ rdle p (4 * i) 4) ^(#p // 4)))
 (f4-write w a s) (: _ (f4-idle w 1000000) _ (swd-wr w (fl + 12) 0x1F3)
                     _ (swd-wr w (fl + 16) (1 | 2 << 8))
                     _ (swd-wrs w a (f4-words s))
                     _ (f4-idle w 1000000)
                     (swd-wr w (fl + 16) 0))
 (f4-read w a n) (snip (join "" (map (v \ wrle v 4) (swd-rds w a ((n + 3) // 4)))) 0 n)
 ; erase the sectors s covers from a, write it, lock, read it back: 1, or where it differs first
 (f4-flash w a s)
  (: hit (filter (k \ k 1 < a + #s && a < k 1 + k 2) f4-sectors)
     _ (f4-unlock w)
     _ (map (k \ f4-erase w <k) hit)
     _ (f4-write w a s)
     _ (f4-lock w)
     b (f4-read w a #s)
     (at i) (? (i >= #s) 1 (b i = s i) (at (i + 1)) ['differs (a + i)])
     (at 0))

 ; linux's gpio character device, its v2 uapi: a request of 592 bytes (64 line offsets, the
 ; consumer's name at 256, a config at 288, the line count at 560), its line fd answered at
 ; 588; a config of 272 (flags, then up to 10 attributes of 24 from 32); values 16, bits then
 ; mask. attribute 1 is flags (4 input, 8 output), 2 output values
 (gpio-le n v) (wrle v n)
 (gpio-zs n) (string (map (_ \ 0) ^n))
 (gpio-attr id v m) (gpio-le 4 id + gpio-zs 4 + gpio-le 8 v + gpio-le 8 m)
 (gpio-cfg as) (gpio-le 8 8 + gpio-le 4 #as + gpio-zs 20 + join "" as + gpio-zs (24 * (10 - #as)))
 (gpio-req ls who cf) (join "" (map (gpio-le 4) ls) + gpio-zs (256 - 4 * #ls) + who + gpio-zs (32 - #who)
                       + cf + gpio-le 4 #ls + gpio-zs 28)
 (gpio-vals v m) (gpio-le 8 v + gpio-le 8 m)
 ; a wire over three lines of a chip through io's 'open, 'ioctl and 'close: clk bit 0, dio 1,
 ; nrst 2 (high lets go), all outputs to begin with, nrst high. swdio turns input while the
 ; target holds it, and a values call then masks it out, since setting an input is refused.
 ; a bit goes out with clk low and in at its rise; one comes in read with clk low. closing
; turns all three to inputs first, so nothing is left driving the target
 GetLine 0xC250B407 SetCfg 0xC110B40D GetVals 0xC010B40E SetVals 0xC010B40F
 (gpio-wire-on io chip clk dio rst)
  (: fd (io 'open chip)
     _ (charm? fd ? 0 (scare 'gpio-open fd))
     r (io 'ioctl fd GetLine (gpio-req [clk dio rst] "swd" (gpio-cfg [(gpio-attr 2 4 7)])))
     _ (string? r ? 0 (scare 'gpio-lines r))
     lf (rdle r 588 4)
     st {'v 4 'own 1}
     (ok what r) (string? r ? r (scare what r))
     (put v) (: _ (pin st 'v v) (ok 'gpio-set (io 'ioctl lf SetVals (gpio-vals v (st 'own = 1 ? 7 5)))))
     (lvl v b m) ((v - (v & m)) | (b ? m 0))
     {'out (b \ (: v (lvl (st 'v) (b & 1) 2) _ (put (v - (v & 1))) (put (v | 1))))
      'in (_ \ (: _ (put (st 'v - (st 'v & 1)))
                  g (ok 'gpio-get (io 'ioctl lf GetVals (gpio-vals 0 2)))
                  _ (put (st 'v | 1))
                  (((rdle g 0 1) >> 1) & 1)))
      'own (b \ (: _ (pin st 'own b)
                   _ (ok 'gpio-own (io 'ioctl lf SetCfg (gpio-cfg (b = 1 ? [(gpio-attr 2 (st 'v) 7)]
                                                                  [(gpio-attr 1 4 2) (gpio-attr 2 (st 'v) 5)]))))
                   b))
      'rst (b \ put (lvl (st 'v) (b = 0) 4))
      'close (_ \ (io 'ioctl lf SetCfg (gpio-cfg [(gpio-attr 1 4 7)]), io 'close lf, io 'close fd))})
 ; the device itself
 (gpio-wire chip clk dio rst)
  (gpio-wire-on {'open (p \ openfd p 6) 'ioctl ioctl 'close (fd \ fdopen fd @ p (close p))} chip clk dio rst)
)
) ; module swd
