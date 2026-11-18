; src/apps/swd.l -- arm's serial wire debug over a wire, of two kinds. a bit wire is a tablet
; of four words: 'out b clocks b out on swdio, 'in clocks a bit in and answers it, 'own b
; turns swdio to the host (1) or the target (0), 'rst b holds nrst low (1) or lets it go (0);
; bits go lsb first. a probe wire moves whole transfers: 'xfer [[rq wdata] ..] answers
; [[ack rdata par] ..] (a batch stops at its first ack not 1, the rest answering 0), 'line
; [bytes n] clocks n raw bits, 'rst b as a bit wire's, 'clock hz answers the rate set. the
; love swd probe and cmsis-dap are probe wires
(module (swd swd-bits swd-sample swd-par swd-xfer1 swd-xfer swd-batch swd-line swd-wake swd-noack swd-select swd-dp swd-dpw swd-use swd-ap swd-apw swd-connect swd-mdconnect swd-rd swd-rds swd-wr swd-wrs
             swd-halted? swd-wait swd-halt swd-attach swd-resume swd-run
             f4-ids f4-sectors f4-idle f4-locked? f4-unlock f4-lock f4-erase f4-write f4-read f4-flash
             nrf-ids nrf-idle nrf-erase nrf-write nrf-flash
             gpio-attr gpio-cfg gpio-req gpio-vals gpio-wire-on gpio-wire probe-wire-on probe-wire dap-wire-on dap-wire)
(borrow 'bytes)
(borrow 'posix)
(:
 ; the low n bits of x out, then n bits in as a number
 (swd-bits w x n) (n > 0 ? (w 'out (x & 1), swd-bits w (x >> 1) (n - 1)) 0)
 (swd-sample w n) (foldl (\ v i (v | w 'in () << i)) 0 ^n)
 ; the parity of a word's low 32 bits
 (swd-par x) (: (p x) (x = 0 ? 0 (x & 1 ^ p (x >> 1))) (p (x & 0xFFFFFFFF)))

 ; one attempt over a bit wire, the request byte rq read (rd 1) or writing v: [ack x par],
 ; a read's word and parity bit when its ack is 1
 (swd-xfer1 w rq rd v)
  (: _ (swd-bits w rq 8) _ (w 'own 0) _ (swd-sample w 1) ack (swd-sample w 3)
     (? (ack != 1) (swd-sample w 1, w 'own 1, [ack () ()])
        (rd = 1) (: x (swd-sample w 32) p (swd-sample w 1) _ (swd-sample w 1) _ (w 'own 1)
                    _ (swd-bits w 0 2)
                    [ack x p])
        (: _ (swd-sample w 1) _ (w 'own 1) _ (swd-bits w v 32) _ (swd-bits w (swd-par v) 1)
           _ (swd-bits w 0 2)
           [ack () ()])))
 ; a probe wire moves transfers, a bit wire bits
 (swd-probe? w) (elem 'xfer (keys w))
 ; one transfer to the debug port (ap 0) or an access port (1), read (rd 1) or written, its
 ; register a's bits 2 and 3: [ack v], a read's value or the one written. ack 1 is ok; a wait
 ; (2) is asked again after 8 idle clocks, 64 times at most; a fault (4) or no answer (7)
 ; answers its ack, and a read whose parity is wrong the ack -1
 (swd-rq ap rd a) (: ad (a >> 2 & 3) (1 | ap << 1 | rd << 2 | ad << 3 | swd-par (ap | rd << 1 | ad << 2) << 5 | 1 << 7))
 (swd-xfer w ap rd a v)
  (: rq (swd-rq ap rd a)
     pw (swd-probe? w)
     (go k) (: r (pw ? <(w 'xfer [[rq (rd = 1 ? 0 v)]]) (swd-xfer1 w rq rd v)) ack <r
               (? (ack = 2 && k > 0) (pw || swd-bits w 0 8, go (k - 1))
                  (ack != 1) [ack ()]
                  (rd = 1) [(r 2 = swd-par (r 1) ? ack -1) (r 1)]
                  [ack v]))
     (go 64))
 ; transfers [[ap rd a v] ..] in order: [[ack x] ..] as swd-xfer's, ending at the first ack
 ; not 1. a probe wire takes them 64 to a batch, and a wait is asked again from the transfer
 ; that waited, the rest of its batch unclocked; a bit wire takes them one at a time
 (swd-batch w ts)
  (: (one ts acc) (? !(two? ts) (rev acc)
                     (: r (swd-xfer w <(<ts) (<ts 1) (<ts 2) (<ts 3))
                        (<r = 1 ? (one >ts (r . acc)) (rev (r . acc)))))
     (bat ts k acc)
      (? !(two? ts) (rev acc)
         (: c (snip ts 0 64)
            rs (w 'xfer (map (t \ [(swd-rq <t (t 1) (t 2)) (t 1 = 1 ? 0 (t 3))]) c))
            (walk c rs i acc)
             (? !(two? c) (bat (snip ts i #ts) 64 acc)
                (: t <c r <rs ack <r
                   (? (ack = 1 && t 1 = 1)
                       (r 2 = swd-par (r 1) ? (walk >c >rs (i + 1) ([1 (r 1)] . acc)) (rev ([-1 (r 1)] . acc)))
                      (ack = 1) (walk >c >rs (i + 1) ([1 (t 3)] . acc))
                      (ack = 2 && (i > 0 || k > 0)) (bat (snip ts i #ts) (i > 0 ? 64 (k - 1)) acc)
                      (rev ([ack ()] . acc)))))
            (walk c rs 0 acc)))
     (swd-probe? w ? (bat ts 64 ()) (one ts ())))

 ; the switch: a line reset, the jtag-to-swd sequence, a line reset again, then idle; to a
 ; probe the same 136 bits as bytes, lsb first
 ones (string (map (_ \ 255) ^7))
 (swd-line w)
  (swd-probe? w ? (w 'line [(ones + string [0x9E 0xE7] + ones + string [0]) 136])
     (w 'own 1, swd-bits w -1 56, swd-bits w 0xE79E 16, swd-bits w -1 56, swd-bits w 0 8))

 ; dp v2's multidrop. the wake from dormant: 8 ones, the 128-bit selection alert, 4 zeros, the
 ; swd activation code, a line reset and idle, as bytes lsb first
 swd-wake (string [0xFF 0x92 0xF3 0x09 0x62 0x95 0x2D 0x85 0x86 0xE9 0xAF 0xDD 0xE3 0xA2 0x0E 0xBC 0x19
                   0xA0 0xF1 0xFF 0xFF 0xFF 0xFF 0xFF 0xFF 0xFF 0x00])
 ; a write whose ack no one drives, over a bit wire: the request, five clocks the host does not
 ; drive (turnaround, ack, turnaround), the word, its parity, idle
 (swd-noack w rq v)
  (: _ (swd-bits w rq 8) _ (w 'own 0) _ (swd-sample w 5) _ (w 'own 1)
     (swd-bits w v 32, swd-bits w (swd-par v) 1, swd-bits w 0 2))
 ; the wake, then targetsel (dp 0xC) naming the one target that answers until the next line
 ; reset: its tinstance, partno and designer as the target's own targetid lays them
 (swd-select w ts)
  (swd-probe? w ? (w 'line [swd-wake (8 * #swd-wake)], w 'xfer [[0x99 ts 'noack]], 1)
     (: _ (w 'own 1) _ (map (i \ swd-bits w (swd-wake i) 8) ^#swd-wake) _ (swd-noack w 0x99 ts) 1))

 ; the debug port's registers by address, each [ack v]; an access port's through select's bank:
 ; apsel 0's, or with the wire's 'ap set (swd-use) the adiv6 ap at that base, whose adiv5 map
 ; lies at base + 0xD00 and select takes the address's top 28 bits. an ap read is posted, its
 ; value the next one's, so rdbuff (dp 12) answers it
 (swd-dp w a) (swd-xfer w 0 1 a 0)
 (swd-dpw w a v) (swd-xfer w 0 0 a v)
 (swd-use w base) (pin w 'ap base, w)
 (swd-sel w a) (w 'ap @ b (charm? b ? (: f (b + 0xD00 + a) (swd-dpw w 8 (f - (f & 15)))) (swd-dpw w 8 (a & 0xF0))))
 (swd-ap w a) (: s (swd-sel w a) r (<s = 1 ? (swd-xfer w 1 1 a 0) s) (<r = 1 ? (swd-dp w 12) r))
 (swd-apw w a v) (: s (swd-sel w a) (<s = 1 ? (swd-xfer w 1 0 a v) s))

 ; the port up: the switch, its id, abort clearing the sticky flags, both power domains asked
 ; and their acks awaited, 100 polls at most, then the access port's id: [dpidr apidr], or a
 ; scare naming the step and what it answered
 (swd-connect w) (swd-line w, swd-up w)
 ; a multidrop target's connect: the wake and its targetsel in place of the switch
 (swd-mdconnect w ts) (swd-select w ts, swd-up w)
 ; dpidr first, as a dp v2 must after its select, then abort, the power, the ap's id
 (swd-up w)
  (: id (swd-dp w 0)
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
                   rs (swd-batch w (map (_ \ [1 1 12 0]) ^k + [[0 1 12 0]]))
                   vs (map (r \ swd-ok 'swd-read r) rs)
                   _ (#vs = k + 1 || swd-ok 'swd-read [0 ()])
                   (>vs + run (a + 4 * k) (n - k))))
     (run a n))
 (swd-rd w a) <(swd-rds w a 1)
 ; a run of words written from a, answering how many: each 1K block's drw writes one batch
 (swd-wrs w a vs)
  (: _ (swd-at a)
     _ (swd-ok 'swd-csw (swd-apw w 0 csw))
     (run a vs k) (!(two? vs) ? k
                   (: m (min #vs ((1024 - (a & 1023)) // 4))
                      _ (swd-ok 'swd-tar (swd-apw w 4 a))
                      rs (swd-batch w (map (v \ [1 0 12 v]) (snip vs 0 m)))
                      _ (map (r \ swd-ok 'swd-write r) rs)
                      _ (#rs = m || swd-ok 'swd-write [0 ()])
                      (run (a + 4 * m) (snip vs m #vs) (k + m))))
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
 ; (a halt asked under reset is not kept, so the catch is what stops it), the catch read back
 ; before nrst goes, since a write is posted and a reset drops one still in flight, nrst let
 ; go, the halt awaited and the catch put back: connect's ids
 (swd-attach w) (: _ (w 'rst 1) ids (swd-connect w)
                   _ (swd-wr w dhcsr 0xA05F0001) _ (swd-wr w dhcsr 0xA05F0003) _ (swd-wr w demcr 1)
                   c (swd-rd w demcr)
                   _ ((c & 1) = 1 ? 0 (scare 'swd-catch c))
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
 ; erase the sectors s covers from a, write it, lock, read it back: 1, or where it differs first.
 ; nothing to write, or bytes past the flash, scare before the chip is touched: an empty
 ; write would erase nothing and read back the same
 (f4-flash w a s)
  (: _ (!(string? s) || #s = 0 ? (scare 'f4-empty a))
     _ (!(fbase <= a && a + #s <= fbase + net (map (k \ k 2) f4-sectors)) ? (scare 'f4-range [a #s]))
     hit (filter (k \ k 1 < a + #s && a < k 1 + k 2) f4-sectors)
     _ (f4-unlock w)
     _ (map (k \ f4-erase w <k) hit)
     _ (f4-write w a s)
     _ (f4-lock w)
     b (f4-read w a #s)
     (at i) (? (i >= #s) 1 (b i = s i) (at (i + 1)) ['differs (a + i)])
     (at 0))

 ; an nrf52: its part, and its flash from 0 in pages, both from the ficr (codepagesize
 ; +0x10, codesize +0x14 in pages); written through the nvmc: ready +0x400 (bit 0), config
 ; +0x504 (1 writes, 2 erases, 0 reads), erasepage +0x508 taking a page's address
 ficr 0x10000000 nv 0x4001E000
 (nrf-ids w) [(swd-rd w (ficr + 0x100)) (swd-rd w (ficr + 0x10)) (swd-rd w (ficr + 0x14))]
 (nrf-idle w k) (? ((swd-rd w (nv + 0x400) & 1) = 1) 1 (k > 0) (nrf-idle w (k - 1)) (scare 'nrf-busy 0))
 (nrf-mode w m) (nrf-idle w 100000, swd-wr w (nv + 0x504) m)
 (nrf-erase w a) (nrf-mode w 2, swd-wr w (nv + 0x508) a, nrf-mode w 0)
 (nrf-write w a s) (nrf-mode w 1, swd-wrs w a (f4-words s), nrf-mode w 0)
 ; erase the pages s covers from a, write it, read it back: 1, or where it differs first;
 ; nothing to write, or bytes past the flash, scare before the chip is touched
 (nrf-flash w a s)
  (: ids (nrf-ids w) ps (ids 1)
     _ (!(string? s) || #s = 0 ? (scare 'nrf-empty a))
     _ (!(0 <= a && a + #s <= ps * ids 2) ? (scare 'nrf-range [a #s]))
     _ (map (p \ nrf-erase w (ps * p)) (drop (a // ps) ^((a + #s - 1) // ps + 1)))
     _ (nrf-write w a s)
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

 ; a probe wire over a byte link through io's 'send s and 'recv n (exactly n bytes) and
 ; 'close: the love swd probe's commands, every answer a length the command foretells.
 ; 'T' rq [w32 when rq writes] answers ack, then w32 and a parity byte for a read whose ack
 ; is 1; 'N' rq w32 is a write whose ack is not read, answering nothing (dp v2's targetsel);
 ; 'B' n16 and its bytes, 'R' b and 'Z' answer nothing; 'C' hz32 answers hz32, 'E' ends a
 ; batch with 'e', 'I' answers the probe's name
 (probe-wire-on io)
  (: (one it) (? (#it = 3 && it 2 = 'noack) ("N" + string [<it] + wrle (it 1) 4)
                 ((<it >> 2 & 1) = 1) ("T" + string [<it])
                 ("T" + string [<it] + wrle (it 1) 4))
     (answers its acc)
      (? !(two? its) (io 'recv 1 = "e" ? (rev acc) (scare 'probe-batch (rev acc)))
         (#<its = 3) (answers >its ([() () ()] . acc))
         (: a (io 'recv 1 0) rd ((<(<its) >> 2 & 1) = 1)
            (rd && a = 1 ? (: d (io 'recv 5) (answers >its ([a (rdle d 0 4) (d 4)] . acc)))
               (answers >its ([a () ()] . acc)))))
     {'xfer (its \ (io 'send (join "" (map one its) + "E"), answers its ()))
      'line (bn \ io 'send ("B" + wrle (bn 1) 2 + snip (bn 0) 0 ((bn 1 + 7) // 8)))
      'rst (b \ io 'send ("R" + string [b]))
      'clock (hz \ (io 'send ("C" + wrle hz 4), rdle (io 'recv 4) 0 4))
      'id (_ \ (io 'send "I", io 'recv 8))
      'close (_ \ (io 'send "Z", io 'close ()))})
 ; the probe on its serial device, raw: 8 bits, no parity, no echo, no line discipline, a
 ; read waiting for a byte. it must name itself
 (probe-wire path)
  (: fd (openfd path 6)
     _ (charm? fd ? 0 (scare 'probe-open fd))
     t (termios fd)
     cf ((t 2 - (t 2 & 0x80000170)) | 0x8B0)          ; less crtscts, csize, cstopb, parenb; cs8 cread clocal
     cc (map (i \ i = 5 ? 0 (i = 6 ? 1 (t (5 + i)))) ^17)   ; vtime 0, vmin 1
     e (settermios fd ([0 0 cf 0 (t 4)] + cc))
     _ (nom? e ? (scare 'probe-tty e) 0)
     p (fdopen fd)
     (rdn k acc) (k = 0 ? (join "" (rev acc)) (see p @ c (c = -1 ? (scare 'probe-eof k) (rdn (k - 1) (string [c] . acc)))))
     w (probe-wire-on {'send (s \ (say p s, flush p)) 'recv (k \ rdn k ()) 'close (_ \ close p)})
     id (w 'id 0)
     (id = "lovswd1\n" ? w (scare 'probe-id id)))

 ; a cmsis-dap wire over a link of reports through io's 'send s (a command, padded to its
 ; report), 'recv () (a whole reply) and 'close: daplink and its kin, over swd. dap_transfer
 ; answers an ap read's own value, its posted read seen to, so the wire keeps each back and
 ; answers the one before, as the port does; rdbuff answers the last either way. a batch goes
 ; 12 transfers a report. a write whose ack no one reads (multidrop's targetsel) it cannot send
 (dap-wire-on io)
  (: st {'rb 0}
     (ask s) (: _ (io 'send s) r (io 'recv ()) (#r > 0 && r 0 = s 0 ? r (scare 'dap-reply [(s 0) r])))
     (ok what r) (r 1 = 0 ? 1 (scare what r))
     (one it) (: q (<it >> 1 & 1 | (<it >> 2 & 1) << 1 | (<it >> 3 & 3) << 2)
                 (? (#it = 3) (scare 'dap-noack (it 1)) (q & 2) (string [q]) (string [q] + wrle (it 1) 4)))
     ; a report's answers: [ack v par] for each done, the ack it stopped on (-1 a bad parity),
     ; then 0s
     (got its n last r at i)
      (? !(two? its) ()
         (i < n) (: rq <<its
                    (? ((rq >> 2 & 1) = 0) ([1 () ()] . got >its n last r at (i + 1))
                       (: v (rdle r at 4) b ((rq >> 1 & 1) = 1 ? (st 'rb @ b (pin st 'rb v, b)) v)
                          ([1 b (swd-par b)] . got >its n last r (at + 4) (i + 1)))))
         (i = n) ([(last & 8 ? -1 (last & 7)) () ()] . got >its n last r at (i + 1))
         ([0 () ()] . got >its n last r at (i + 1)))
     (xfer its) (? !(two? its) ()
                   (: h (take 12 its) r (ask (string [5 0 #h] + join "" (map one h)))
                      a (got h (r 1) (r 2) r 3 0)
                      (all (x \ <x = 1) a ? (a + xfer (drop 12 its)) (a + map (_ \ [0 () ()]) (drop 12 its)))))
     (line s n) (n > 0 ? (: k (min n 256) m ((k + 7) // 8)
                            (ok 'dap-line (ask (string [0x12 (k & 255)] + snip s 0 m)), line (snip s m #s) (n - k))) 1)
     w {'xfer xfer
        'line (bn \ line <bn (bn 1))
        'rst (b \ (ask (string [0x10 (b = 1 ? 0 0x80) 0x80] + wrle 0 4), 1))
        'clock (hz \ (ok 'dap-clock (ask (string [0x11] + wrle hz 4)), hz))
        'id (_ \ (ask (string [0 2]) @ r (snip r 2 (2 + r 1))))
        'close (_ \ (ask (string [3]), io 'close ()))}
     _ (ask (string [2 1]) 1 = 1 ? 0 (scare 'dap-connect 0))
     _ (ok 'dap-config (ask (string [4 0] + wrle 64 2 + wrle 0 2)))
     _ (ok 'dap-swd (ask (string [0x13 0])))
     w)
 ; daplink's hid interface: a report of 64 bytes, written behind report id 0
 (dap-wire path)
  (: fd (openfd path 6)
     _ (charm? fd ? 0 (scare 'dap-open fd))
     p (fdopen fd)
     (rdn k acc) (k = 0 ? (join "" (rev acc)) (see p @ c (c = -1 ? (scare 'dap-eof k) (rdn (k - 1) (string [c] . acc)))))
     (dap-wire-on {'send (s \ (say p (string [0] + s + string (map (_ \ 0) ^(64 - #s))), flush p))
                   'recv (_ \ rdn 64 ()) 'close (_ \ close p)}))
)
) ; module swd
