; --- swd: the bit layer over a wire that records what it is asked ---

(borrow "src/apps/swd.l")
(borrow 'bytes)

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

; a simulated target under the wire's four words. it frames swd a bit at a time -- line resets,
; the jtag-to-swd switch, requests, acks, turnarounds, data and parity -- and hands each transfer
; to h: (h 'ack ap rd a) its ack, (h 'rd ap a) a read's value, (h 'wr ap a v) a write, and
; (h 'badpar ap a) when there, a read's parity to send wrong. until the
; switch it answers nothing; a malformed request locks it out till a line reset, misuse but for
; eight ones (a line reset's start) and the select resent to a port already switched. 'errs is the
; wire's misuse, oldest first: a host driving swdio the target holds, clocking one in while it
; holds it, or taking it back mid-answer; a write's bad parity
(: (swdt-target h)
    (: st {'s 'jtag 'ones 0 'n 0 'acc 0 'k 0 'q () 'own 1 'rst 0 'errs () 'reqs () 'at 0}
       (err e) (pin st 'errs (e . st 'errs))
       (go s) (pin st 's s)
       (from s a k) (pin st 's s, pin st 'acc a, pin st 'k k)
       (bits v n) (map (i \ v >> i & 1) ^n)
       (say q) (pin st 'q q)
       ; a well-formed request's answer: the turnaround and ack, then a read's data and parity
       ; and the turnaround back, or a write's turnaround and its data phase to come
       (reply ap rd a)
        (: ack (h 'ack ap rd a)
           _ (pin st 'reqs ([ap rd a] . st 'reqs))
           (? (ack != 1) (say ([1] + bits ack 3 + [1]), go 'idle)
              (rd = 1) (: v (h 'rd ap a) f (peep h 'badpar (\ ap a 0) ap a)
                          (say ([1] + bits 1 3 + bits v 32 + [(swd-par v ^ f) 1]), go 'idle))
              (say ([1] + bits 1 3 + [1]), pin st 'at [ap a], from 'wdata 0 0)))
       (req r) (: ap (r >> 1 & 1) rd (r >> 2 & 1) a ((r >> 3 & 3) << 2)
                  (? ((r >> 6 & 1) = 0 && (r >> 7 & 1) = 1 && (r >> 5 & 1) = swd-par (r >> 1 & 15)) (reply ap rd a)
                     (r = 0xFF || st 'n = 9 && r = ((0xE79E >> 1) & 0xFF)) (go 'lock)   ; a line reset's start, or the select resent
                     (err 'bad-request, go 'lock)))
       (host b)
        (: was (st 'ones) ones (b = 1 ? (was + 1) 0) _ (pin st 'ones ones)
           _ (pin st 'n (ones >= 50 ? 0 (st 'n + 1)))     ; bits since a line reset
           s (st 's) acc (st 'acc | b << st 'k) k (st 'k + 1)
           (? (ones >= 50) (? (s = 'jtag || s = 'sel) (go 'jtag) (go 'lr))
              (s = 'jtag) (b = 0 && was >= 50 ? (from 'sel 0 1))
              (s = 'sel) (k < 16 ? (from 'sel acc k) (go (acc = 0xE79E ? 'sw 'jtag)))
              (s = 'lr) (go 'idle)
              (s = 'idle) (b = 1 ? (from 'req 1 1))
              (s = 'req) (k < 8 ? (from 'req acc k) (req acc))
              (s = 'wdata)
               (k < 33 ? (from 'wdata acc k)
                  (: v (acc & 0xFFFFFFFF) at (st 'at)
                     _ (acc >> 32 = swd-par v ? (h 'wr <at <>at v) (err 'wdata-parity))
                     (go 'idle)))
              0))
       {'out (b \ st 'own = 1 ? (host b) (err 'out-while-target))
        'in (_ \ (? (st 'own = 1) (err 'in-while-host, 1)
                    (: q (st 'q) _ (say >q) (two? q ? <q 1))))
        'own (b \ ((b = 1 && two? (st 'q) ? (err 'own-early, say ())), pin st 'own b))
        'rst (b \ (pin st 'rst b, peep h 'rst (_ \ 0) b))
        'errs (_ \ rev (st 'errs)) 'reqs (_ \ rev (st 'reqs)) 'state (_ \ st 's)})
   ; registers by (ap a), a read of the debug port's 0 its id; writes kept in order
   (swdt-regs id ack)
    (: r {} wl {'w ()}
       {'ack (\ ap rd a ack)
        'rd (\ ap a (ap = 0 && a = 0 ? id (peep r (ap * 256 + a) 0)))
        'wr (\ ap a v (pin r (ap * 256 + a) v, pin wl 'w ([ap a v] . wl 'w)))
        'writes (_ \ rev (wl 'w))})
   ; the host's side, spelled out bit by bit: the switch, a read and a write by request byte
   (swdt-select w) (swd-bits w -1 56, swd-bits w 0xE79E 16, swd-bits w -1 56, swd-bits w 0 8)
   (swdt-rd w rq) (: _ (swd-bits w rq 8) _ (w 'own 0) _ (swd-sample w 1) ack (swd-sample w 3)
                     v (swd-sample w 32) p (swd-sample w 1) _ (swd-sample w 1) _ (w 'own 1) _ (swd-bits w 0 2)
                     [ack v p])
   (swdt-wr w rq v) (: _ (swd-bits w rq 8) _ (w 'own 0) _ (swd-sample w 1) ack (swd-sample w 3)
                       _ (swd-sample w 1) _ (w 'own 1) _ (swd-bits w v 32) _ (swd-bits w (swd-par v) 1)
                       _ (swd-bits w 0 2) ack))

; before the switch a request is jtag noise: nothing answers, nothing is asked
(: id 0x2BA01477
   h (swdt-regs id 1) w (swdt-target h)
   _ (swd-bits w 0xA5 8) _ (w 'own 0) quiet (swd-sample w 4) _ (w 'own 1)
   s0 (w 'state ())
   ; switched, the debug port's id (0xA5 reads dp 0) and select written (0xB1) then read (0x95)
   _ (swdt-select w) s1 (w 'state ())
   r1 (swdt-rd w 0xA5)
   a2 (swdt-wr w 0xB1 0xF0)
   r3 (swdt-rd w 0x95)
   (test (15 = quiet) ('jtag = s0) ('idle = s1)
         (r1 = [1 id (swd-par id)]) (1 = a2) (r3 = [1 0xF0 (swd-par 0xF0)])
         (h 'writes () = [[0 8 0xF0]]) (w 'reqs () = [[0 1 0] [0 0 8] [0 1 8]])
         (() = w 'errs ())))

; a bad request parity locks the target out, unanswered, till a line reset frees it
(: h (swdt-regs 0x2BA01477 1) w (swdt-target h) _ (swdt-select w)
   bad (swdt-rd w 0x85) s (w 'state ()) still (swdt-rd w 0xA5)
   _ (swd-bits w -1 56) _ (swd-bits w 0 8) back (swdt-rd w 0xA5)
   (test (<bad = 7) ('lock = s) (<still = 7) (back = [1 0x2BA01477 (swd-par 0x2BA01477)])
         (w 'errs () = ['bad-request])))

; a wait answers its ack and no data; the host's turn comes back clean
(: w (swdt-target (swdt-regs 0x2BA01477 2)) _ (swdt-select w)
   r (swdt-rd w 0xA5) _ (swd-bits w 0 8)
   (test (<r = 2) ('idle = w 'state ()) (() = w 'errs ())))

; misuse is the wire's: driving swdio the target holds, taking it back mid-answer, a bad
; write parity -- the write is dropped
(: h (swdt-regs 0x2BA01477 1) w (swdt-target h) _ (swdt-select w)
   _ (w 'own 0) _ (swd-bits w 1 2) _ (w 'own 1)
   _ (swd-bits w 0xA5 8) _ (w 'own 0) _ (swd-sample w 4) _ (w 'own 1) _ (swd-bits w 0 8)
   _ (swd-bits w 0xB1 8) _ (w 'own 0) _ (swd-sample w 5) _ (w 'own 1)
   _ (swd-bits w 0xF0 32) _ (swd-bits w 1 1) _ (swd-bits w 0 2)
   (test (w 'errs () = ['out-while-target 'out-while-target 'own-early 'wdata-parity])
         (() = h 'writes ())))

; swd-xfer against the target: every request it can build parses, parity and all, and answers
(: h (swdt-regs 0x2BA01477 1) w (swdt-target h) _ (swdt-select w)
   qs (map (i \ [(i >> 3 & 1) (i >> 2 & 1) (4 * (i & 3))]) ^16)
   rs (map (q \ swd-xfer w <q (q 1) (q 2) (q 2 + 16 * <q + 0x5A00)) qs)
   id (swd-xfer w 0 1 0 0) sel (swd-xfer w 0 1 8 0)
   (test (w 'reqs () = qs + [[0 1 0] [0 1 8]]) (() = w 'errs ())
         (all (r \ <r = 1) rs) (id = [1 0x2BA01477]) (sel = [1 0x5A08])
         (h 'writes () = map (q \ [<q (q 2) (q 2 + 16 * <q + 0x5A00)]) (filter (q \ q 1 = 0) qs))))

; acks the target answers in turn, then oks
(: (swdt-acks acks)
    (: q {'q acks}
       (pin (swdt-regs 0x2BA01477 1) 'ack (\ ap rd a (: l (q 'q) _ (pin q 'q >l) (two? l ? <l 1))))))

; a wait is asked again; one that never ends answers its ack after 65 asks
(: w (swdt-target (swdt-acks [2 2])) _ (swdt-select w) r (swd-xfer w 0 1 0 0) n #(w 'reqs ())
   v (swdt-target (swdt-acks (map (_ \ 2) ^70))) _ (swdt-select v) s (swd-xfer v 0 0 8 3) m #(v 'reqs ())
   (test (r = [1 0x2BA01477]) (3 = n) (s = [2 ()]) (65 = m) (() = w 'errs ()) (() = v 'errs ())))

; a fault answers its ack, nothing written, and the next transfer is clean; no answer is 7
(: h (swdt-acks [4]) w (swdt-target h) _ (swdt-select w)
   f (swd-xfer w 0 0 8 0xF0) g (swd-xfer w 0 0 8 0xF1)
   u (swd-xfer (swdt-target h) 0 1 0 0)
   (test (f = [4 ()]) (g = [1 0xF1]) (h 'writes () = [[0 8 0xF1]]) (() = w 'errs ()) (<u = 7)))

; a read whose parity comes back wrong answers -1 with what was read
(: w (swdt-target (pin (swdt-regs 0x2BA01477 1) 'badpar (\ ap a 1))) _ (swdt-select w)
   r (swd-xfer w 0 1 0 0)
   (test (r = [-1 0x2BA01477]) (() = w 'errs ())))

; swdt-mem a bus of words by address, 'mem its tablet. a debug port under swdt-target: dpidr
; id; ctrl/stat's power acks answer their asks n reads late; select's bank; ap reads posted to
; rdbuff, the first a stale 0. its ap is a mem-ap over bus, nrst passed on to it: csw (its reset value aps 0) and tar, drw reading and
; writing at tar, which steps by 4 when csw says, wrapping in its 1K block. an ap transfer while
; the power is down faults and sets stickyerr (ctrl/stat bit 5); while it is set every transfer
; faults but reads of dpidr and ctrl/stat and writes of abort, whose bit 2 clears it. 'writes
; is every write the port took, in order
(: (swdt-mem _) (: m {} {'rd (a \ peep m a 0) 'wr (\ a v (pin m a v)) 'mem (_ \ m)})
   (swdt-dp id aps n bus)
    (: st {'ask 0 'left 0 'acks 0 'sel 0 'rb 0 'sticky 0 'w () 'csw (peep aps 0 0) 'tar 0}
       (reg a) ((st 'sel & 0xF0) | a)
       (step _) ((st 'csw >> 4 & 3) = 1 ? (: t (st 'tar) (pin st 'tar ((t - (t & 1023)) | ((t + 4) & 1023)))) 0)
       (apget r) (? (r = 0) (st 'csw) (r = 4) (st 'tar)
                    (r = 12) (: v (bus 'rd (st 'tar)) _ (step ()) v)
                    (peep aps r 0))
       (free? ap rd a) (ap = 0 && (rd = 1 && a < 8 || rd = 0 && a = 0))
       (cs _) (: l (st 'left)
               _ (l > 0 ? (pin st 'left (l - 1)) (pin st 'acks (st 'ask << 1)))
               (st 'ask | st 'acks | st 'sticky << 5))
       {'ack (\ ap rd a (? (free? ap rd a) 1
                           (st 'sticky = 1) 4
                           (ap = 1 && st 'acks != 0xA0000000) (pin st 'sticky 1, 4)
                           1))
        'rd (\ ap a (? (ap = 1) (: v (st 'rb) _ (pin st 'rb (apget (reg a))) v)
                       (a = 0) id
                       (a = 4) (cs ())
                       (a = 12) (st 'rb)
                       0))
        'wr (\ ap a v (: _ (pin st 'w ([ap a v] . st 'w))
                         (? (ap = 1) (: r (reg a)
                                        (? (r = 0) (pin st 'csw v) (r = 4) (pin st 'tar v)
                                           (r = 12) (bus 'wr (st 'tar) v, step ())
                                           0))
                            (a = 0) (v & 4 ? (pin st 'sticky 0) 0)
                            (a = 4) (pin st 'ask (v & 0x50000000), pin st 'left n, pin st 'acks 0)
                            (a = 8) (pin st 'sel v)
                            0)))
        'rst (b \ peep bus 'rst (_ \ 0) b)
        'writes (_ \ rev (st 'w)) 'mem (_ \ bus 'mem ())}))

; the board's ids: an stm32f4's sw-dp, and its ahb-ap
(: f4dp 0x2BA01477 f4ap 0x24770011
   f4aps {0xFC f4ap 0x00 0x23000040 0xF8 0xE00FF003}
   (f4port n) (swdt-dp f4dp f4aps n (swdt-mem ())))

; connect: the switch, dpidr, abort, power asked and polled till both acks, the ap's id
; through bank 0xF0 and rdbuff
(: h (f4port 3) w (swdt-target h) r (swd-connect w)
   (test (r = [f4dp f4ap]) (() = w 'errs ())
         (h 'writes () = [[0 0 0x1E] [0 4 0x50000000] [0 8 0xF0]])
         (w 'reqs () = [[0 1 0] [0 0 0] [0 0 4] [0 1 4] [0 1 4] [0 1 4] [0 1 4] [0 0 8] [1 1 12] [0 1 12]])))

; a posted read: the ap answers the read before, rdbuff this one; swd-ap answers this one, and
; a bank change writes select first
(: h (f4port 0) w (swdt-target h) _ (swd-connect w)
   raw (swd-xfer w 1 1 12 0) buf (swd-dp w 12)
   csw (swd-ap w 0) base (swd-ap w 0xF8)
   _ (swd-apw w 4 0x20000000)
   (test (raw = [1 f4ap]) (buf = [1 f4ap]) (csw = [1 0x23000040]) (base = [1 0xE00FF003])
         (h 'writes () = [[0 0 0x1E] [0 4 0x50000000] [0 8 0xF0] [0 8 0] [0 8 0xF0] [0 8 0] [1 4 0x20000000]])))

; an ap read with the power down faults and sticks: dp reads of the id still answer, the next
; ap transfer faults, and connect's abort clears it
(: h (f4port 0) w (swdt-target h) _ (swdt-select w)
   a (swd-xfer w 1 1 0 0) s (swd-dp w 4) b (swd-dp w 0) c (swd-dpw w 8 0)
   r (swd-connect w)
   (test (a = [4 ()]) (s = [1 0x20]) (b = [1 f4dp]) (c = [4 ()]) (r = [f4dp f4ap]) (() = w 'errs ())))

; no target, swdio pulled high, answers 7: connect scares on the id; power that never comes scares after 101 polls;
; an ap that faults scares naming it
(: e (trap swd-connect {'out (_ \ 0) 'in (_ \ 1) 'own (_ \ 0) 'rst (_ \ 0)} (a \ b \ [a b]))
   w (swdt-target (f4port 1000)) p (trap swd-connect w (a \ b \ [a b]))
   polls #(filter (q \ q = [0 1 4]) (w 'reqs ()))
   f (trap swd-connect (swdt-target (pin (f4port 0) 'ack (\ ap rd a (ap = 1 ? 4 1)))) (a \ b \ [a b]))
   (test (e = ['swd-connect ['id [7 ()]]]) (p = ['swd-power [1 0x50000000]]) (101 = polls)
         (f = ['swd-connect ['ap [4 ()]]])))

; the sim's mem-ap: tar steps within its 1K block, so two words written from 0x3FC land at
; 0x3FC and back at 0x000 of the same block
(: h (f4port 0) w (swdt-target h) _ (swd-connect w)
   _ (swd-apw w 0 0x23000012) _ (swd-apw w 4 0x200003FC)
   _ (swd-xfer w 1 0 12 7) _ (swd-xfer w 1 0 12 8)
   m (h 'mem ())
   (test (7 = m 0x200003FC) (8 = m 0x20000000) (0 = peep m 0x20000400 0)))

; a word written and read back, csw set first and tar after
(: h (f4port 0) w (swdt-target h) _ (swd-connect w) n0 #(h 'writes ())
   v (swd-wr w 0x20000010 0xDEADBEEF) r (swd-rd w 0x20000010)
   (test (v = 0xDEADBEEF) (r = 0xDEADBEEF) (0xDEADBEEF = h 'mem () 0x20000010)
         (drop n0 (h 'writes ()) = [[0 8 0] [1 0 0x23000012] [0 8 0] [1 4 0x20000010] [1 12 0xDEADBEEF]
                                 [0 8 0] [1 0 0x23000012] [0 8 0] [1 4 0x20000010]])))

; runs across 1K boundaries: tar set again at each, every word where it belongs
(: h (f4port 0) w (swdt-target h) _ (swd-connect w)
   ws (map (i \ 0x1000 * i + 7) ^300)
   n (swd-wrs w 0x200003F0 ws)
   m (h 'mem ())
   back (swd-rds w 0x200003F0 300)
   odd (swd-rds w 0x200007FC 2)
   tars (map (e \ e 2) (filter (e \ <e = 1 && e 1 = 4) (h 'writes ())))
   (test (300 = n) (back = ws) (odd = [(ws 259) (ws 260)])
         (all (i \ m (0x200003F0 + 4 * i) = ws i) ^300)
         (tars = [0x200003F0 0x20000400 0x20000800 0x200003F0 0x20000400 0x20000800 0x200007FC 0x20000800])))

; an unaligned address scares before a transfer; a faulting ap scares naming the step
(: h (f4port 0) w (swdt-target h) _ (swd-connect w) n0 #(w 'reqs ())
   u (trap (_ \ swd-rd w 0x20000002) 0 (a \ b \ [a b]))
   n1 #(w 'reqs ())
   on {'f 0}                                  ; armed after connect, whose id read shares drw's bits
   v (swdt-target (pin (f4port 0) 'ack (\ ap rd a (on 'f = 1 && ap = 1 && rd = 1 ? 4 1)))) _ (swd-connect v)
   _ (pin on 'f 1)
   f (trap (_ \ swd-rd v 0x20000000) 0 (a \ b \ [a b]))
   (test (u = ['swd-align 0x20000002]) (n0 = n1) (f = ['swd-read [4 ()]])))

; a cortex-m core over a bus: dhcsr's debug enable and halt (key 0xA05F, else ignored), the
; halt seen in bit 17 and a reset since the last read in bit 25; demcr's reset vector catch;
; aircr's system reset. nrst held keeps it in reset; let go, it reaches its reset vector two
; dhcsr reads later; reset by aircr, at once. there it halts if debug is on and it was told to
; halt or catch the vector, else runs. 'log is what it did and
; every write to it, oldest first
(: (swdt-core m)
    (: st {'en 0 'ch 0 'halt 0 'vc 0 'rs 0 'nrst 0 'pend 0 'log ()}
       (ev e) (pin st 'log (e . st 'log))
       (boot _) (? (st 'en = 1 && (st 'vc = 1 || st 'ch = 1)) (pin st 'halt 1, ev 'caught)
                   (pin st 'halt 0, ev 'runs))
       {'rd (a \ (? (a = 0xE000EDF0)
                     (: p (st 'pend) _ (p > 0 ? (pin st 'pend (p - 1), (p = 1 ? (boot ()) 0)) 0)
                        v (st 'en | st 'ch << 1 | 1 << 16 | st 'halt << 17 | st 'rs << 25) _ (pin st 'rs 0) v)
                     (a = 0xE000EDFC) (st 'vc)
                     (m 'rd a)))
        'wr (\ a v (: _ (ev ['wr a v])
                      (? (a = 0xE000EDF0)
                         (? ((v >> 16) != 0xA05F) (ev 'nokey)
                            (: _ (pin st 'en (v & 1)) _ (pin st 'ch ((v >> 1) & 1))
                               (? (st 'nrst = 1) 0
                                  (st 'en = 1 && st 'ch = 1 && st 'halt = 0) (pin st 'halt 1, ev 'halts)
                                  (st 'ch = 0 && st 'halt = 1) (pin st 'halt 0, ev 'resumes)
                                  0)))
                         (a = 0xE000EDFC) (pin st 'vc (v & 1))
                         (a = 0xE000ED0C) (v = 0x05FA0004 ? (pin st 'rs 1, ev 'sysreset, boot ()) 0)
                         (m 'wr a v))))
        'rst (b \ (? (b = 1) (pin st 'nrst 1, pin st 'halt 0, ev 'reset)
                      (pin st 'nrst 0, pin st 'rs 1, pin st 'pend 2)))
        'mem (_ \ m 'mem ())
        'log (_ \ rev (st 'log)) 'halted (_ \ st 'halt)})
   (f4core n) (: c (swdt-core (swdt-mem ()))
                 [(swdt-target (swdt-dp f4dp f4aps n c)) c]))

; attach: nrst held through connect, halt and vector catch asked, nrst let go, the core
; caught at its reset vector, the catch put back; halted, with the reset seen
(: t (f4core 2) w <t c (t 1)
   ids (swd-attach w) h (swd-halted? w)
   (test (ids = [f4dp f4ap]) (1 = h) (1 = c 'halted ()) (() = w 'errs ())
         (c 'log () = ['reset ['wr 0xE000EDF0 0xA05F0003] ['wr 0xE000EDFC 1] 'caught ['wr 0xE000EDFC 0]])))

; resume lets it go under debug; halt stops it again; run turns debug off, which lets it go,
; and resets it free, nothing caught
(: t (f4core 0) w <t c (t 1) _ (swd-attach w) n0 #(c 'log ())
   _ (swd-resume w) r (swd-halted? w)
   _ (swd-halt w) h (swd-halted? w)
   _ (swd-run w) g (swd-halted? w)
   (test (0 = r) (1 = h) (0 = g) (0 = c 'halted ())
         (drop n0 (c 'log ()) = [['wr 0xE000EDF0 0xA05F0001] 'resumes ['wr 0xE000EDF0 0xA05F0003] 'halts
                                 ['wr 0xE000EDFC 0] ['wr 0xE000EDF0 0xA05F0000] 'resumes ['wr 0xE000ED0C 0x05FA0004]
                                 'sysreset 'runs])))

; a halt that never shows scares after 101 polls, with dhcsr as last read: here a bus that
; reads 0 everywhere
(: w (swdt-target (swdt-dp f4dp f4aps 0 {'rd (a \ 0) 'wr (\ a v 0) 'mem (_ \ {})})) _ (swd-connect w)
   n0 #(w 'reqs ())
   e (trap (_ \ swd-halt w) 0 (a \ b \ [a b]))
   n #(filter (q \ q = [0 1 12]) (drop n0 (w 'reqs ())))     ; rdbuff, once a dhcsr read
   (test (e = ['swd-halt 0]) (n = 102)))

; an stm32f446's flash over a bus: 512K of sectors (16K x4, 64K, 128K x3) reading ones once
; erased; keyr's two keys unlock it, any other write locks it till a reset; cr's lock bit
; locks it. a sector erase keeps sr busy for k reads of sr; program (pg, x32) only clears
; bits; a flash write without pg sets pgserr (bit 7), one at another size pgperr (bit 6), one
; while locked wrperr (bit 4). errors stay till written with a 1. 'log is each erase and
; program, the rest goes to m
(: (swdt-flash m k)
    (: fb 0x08000000 fr 0x40023C00
       st {'lock 1 'keys 0 'stuck 0 'cr 0 'sr 0 'busy 0 'log ()}
       secs {}
       (sec a) (: o (a - fb) (? (o < 65536) (o >> 14) (o < 131072) 4 (5 + ((o - 131072) >> 17))))
       (secmem i) (peep secs i () @ t (t ? t (: n {} (pin secs i n, n))))
       (ev e) (pin st 'log (e . st 'log))
       (err b) (pin st 'sr (st 'sr | b))
       (flash? a) (fb <= a && a < fb + 524288)
       {'rd (a \ (? (flash? a) (peep (secmem (sec a)) a 0xFFFFFFFF)
                    (a = fr + 12) (: b (st 'busy) _ (b > 0 ? (pin st 'busy (b - 1)) 0)
                                     (st 'sr | (b > 0 ? 0x10000 0)))
                    (a = fr + 16) (st 'cr | st 'lock << 31)
                    (m 'rd a)))
        'wr (\ a v
              (? (flash? a)
                  (: cr (st 'cr)
                     (? (st 'lock = 1) (err 16)
                        ((cr & 1) = 0) (err 128)
                        (((cr >> 8) & 3) != 2) (err 64)
                        (: t (secmem (sec a)) (pin t a (peep t a 0xFFFFFFFF & v), ev ['pg a v]))))
                 (a = fr + 4)
                  (? (st 'stuck = 1) 0
                     (st 'lock = 0) (pin st 'stuck 1, pin st 'lock 1)
                     (st 'keys = 0 && v = 0x45670123) (pin st 'keys 1)
                     (st 'keys = 1 && v = 0xCDEF89AB) (pin st 'keys 0, pin st 'lock 0)
                     (pin st 'stuck 1))
                 (a = fr + 12) (pin st 'sr (st 'sr - (st 'sr & v & 0x1F3)))
                 (a = fr + 16)
                  (? ((v >> 31) = 1) (pin st 'lock 1, pin st 'keys 0)
                     (st 'lock = 1) 0
                     (: _ (pin st 'cr v)
                        ((v & 0x10002) = 0x10002
                         ? (: n ((v >> 3) & 15) _ (pin secs n {}) _ (pin st 'busy k) (ev ['erase n]))
                         0)))
                 (m 'wr a v)))
        'rst (b \ (pin st 'stuck 0, pin st 'lock 1, pin st 'keys 0, peep m 'rst (_ \ 0) b))
        'mem (_ \ m 'mem ())
        'log (_ \ rev (st 'log)) 'sr (_ \ st 'sr) 'busy (_ \ st 'busy)})
   ; an f4 under the wire: its id code and size word, its core, its flash busy k polls an erase
   (f4chip k) (: m (swdt-mem ())
                 _ (m 'wr 0xE0042000 0x10006421) _ (m 'wr 0x1FFF7A20 0x02000000)
                 f (swdt-flash (swdt-core m) k)
                 [(swdt-target (swdt-dp f4dp f4aps 0 f)) f]))

; attached, the ids are the board's: an f446 rev a, 512K
(: t (f4chip 3) w <t _ (swd-attach w)
   (test (f4-ids w = [0x10006421 512])))

; the sectors: eight, contiguous, 512K in all
(: (test (#f4-sectors = 8) (f4-sectors 0 = [0 0x08000000 16384]) (f4-sectors 4 = [4 0x08010000 65536])
         (f4-sectors 7 = [7 0x08060000 131072])
         (net (map (k \ k 2) f4-sectors) = 524288)
         (all (i \ f4-sectors i 1 + f4-sectors i 2 = f4-sectors (i + 1) 1) ^7)))

; locked to begin with: a word written is refused with wrperr and nothing changes; a wrong
; key locks it till a reset, where unlock scares; a reset frees it
(: t (f4chip 3) w <t f (t 1) _ (swd-attach w)
   _ (swd-wr w 0x08000000 0) e (f 'sr ()) v (swd-rd w 0x08000000)
   _ (swd-wr w 0x40023C0C 0x1F3)
   _ (swd-wr w 0x40023C04 0x12345678)
   s (trap (_ \ f4-unlock w) 0 (a \ b \ a))
   _ (swd-attach w) u (f4-unlock w)
   (test (16 = e & 16) (v = 0xFFFFFFFF) (s = 'f4-locked) (1 = u)))

; a flash of 40 bytes across sectors 0 and 1: both erased, then the words programmed, padded
; with ones, then locked; read back the same, and the erase kept the flash busy 5 polls
(: t (f4chip 5) w <t f (t 1) _ (swd-attach w)
   s (string (map (i \ (37 * i + 11) % 256) ^40))
   a 0x08003FF0
   r (f4-flash w a s)
   lg (f 'log ())
   q (f4-flash w 0x08008000 "abcdef")         ; six bytes: the word's last two stay erased
   (test (1 = r) (f4-read w a 40 = s) (f4-locked? w)
         ([['erase 0] ['erase 1]] = filter (e \ <e = 'erase) lg)
         (10 = #(filter (e \ <e = 'pg) lg))
         (swd-rd w 0x08004018 = 0xFFFFFFFF)
         (f4-read w 0x08003FF0 3 = snip s 0 3)
         (1 = q) (f4-read w 0x08008000 8 = "abcdef" + string [255 255])))

; erase answers once the flash is idle; program only clears bits: a second write over the
; first without an erase reads their and; f4-flash, erasing first, writes it clean
(: t (f4chip 4) w <t f (t 1) _ (swd-attach w) a 0x08020000
   _ (f4-unlock w) _ (f4-erase w 5) b (f 'busy ())
   _ (f4-write w a (wrle 0xF0F0F0F0 4)) _ (f4-write w a (wrle 0x3C3C3C3C 4))
   x (swd-rd w a)
   r (f4-flash w a (wrle 0x3C3C3C3C 4)) y (swd-rd w a)
   (test (0 = b) (x = 0x30303030) (1 = r) (y = 0x3C3C3C3C)))

; the flash's errors scare: a write at the wrong size, and an erase still busy after its polls
(: t (f4chip 1) w <t f (t 1) _ (swd-attach w) _ (f4-unlock w)
   _ (swd-wr w 0x40023C10 1) _ (swd-wr w 0x08000000 0)
   e (trap (_ \ f4-write w 0x08000000 "abcd") 0 (a \ b \ [a b]))
   v (f4chip 50) x <v _ (swd-attach x) _ (f4-unlock x)
   _ (swd-wr x 0x40023C10 0x10002)
   b (trap (_ \ f4-idle x 10) 0 (a \ b \ [a b]))
   n (f4-idle x 100)
   (test (e = ['f4-flash 64]) (b = ['f4-busy 0x10000]) (n = 0)))

; the v2 layouts: a request's size, its offsets, name, config and count where the uapi puts them
(: cf (gpio-cfg [(gpio-attr 2 4 7)]) rq (gpio-req [5 6 7] "swd" cf)
   (test (592 = #rq) (272 = #cf) (24 = #(gpio-attr 1 4 2)) (16 = #(gpio-vals 0 7))
         ([5 6 7] = map (i \ rdle rq (4 * i) 4) ^3) ("swd" = snip rq 256 259) (0 = rq 259)
         (cf = snip rq 288 560) (3 = rdle rq 560 4) (8 = rdle cf 0 8) (1 = rdle cf 8 4)
         (2 = rdle cf 32 4) (4 = rdle cf 40 8) (7 = rdle cf 48 8)
         (272 = #(gpio-cfg (map (_ \ gpio-attr 2 0 1) ^10)))))

; a gpio chip under the wire, as the kernel answers it, the line levels relayed to a target t:
; clk rising while swdio is an output clocks its level out; a values read while it is an
; input clocks the target's bit in; the config's direction is the target's 'own; nrst low
; holds its reset. it refuses setting an input line ('eperm) and a wrong size ('einval).
; 'calls is what it was asked, oldest first
(: (swdt-gpio t)
    (: st {'v 0 'in 0 'calls ()}
       (call c) (pin st 'calls (c . st 'calls))
       (setlv v) (: was (st 'v) _ (pin st 'v v)
                    _ ((v & 4) != (was & 4) ? (t 'rst ((v & 4) = 0 ? 1 0)) 0)
                    ((was & 1) = 0 && (v & 1) = 1 && st 'in = 0 ? (t 'out ((v >> 1) & 1)) 0))
       (cfg s) (: as (map (i \ snip s (32 + 24 * i) (56 + 24 * i)) ^(rdle s 8 4))
                  inp (any (a \ rdle a 0 4 = 1 && (rdle a 8 8 & 4) != 0 && (rdle a 16 8 & 2) != 0) as)
                  ov (filter (a \ rdle a 0 4 = 2) as)
                  _ (inp != st 'in ? (pin st 'in inp, t 'own (inp ? 0 1)) 0)
                  (two? ov ? (: a <ov m (rdle a 16 8) (setlv ((st 'v - (st 'v & m)) | (rdle a 8 8 & m)))) 0))
       {'open (p \ (call ['open p], 3))
        'close (fd \ call ['close fd])
        'ioctl (\ fd rq s
                 (? (rq = 0xC250B407)
                     (? (#s != 592) 'einval
                        (: _ (call ['line (map (i \ rdle s (4 * i) 4) ^(rdle s 560 4)) (snip s 256 259)])
                           _ (cfg (snip s 288 560))
                           (snip s 0 588 + wrle 4 4)))
                    (rq = 0xC110B40D) (? (#s != 272) 'einval (: _ (cfg s) s))
                    (rq = 0xC010B40F)
                     (? (#s != 16) 'einval
                        (: v (rdle s 0 8) m (rdle s 8 8)
                           (? ((m & 2) != 0 && st 'in = 1) (call 'eperm, 'eperm)
                              (: _ (setlv ((st 'v - (st 'v & m)) | (v & m))) s))))
                    (rq = 0xC010B40E)
                     (? (#s != 16) 'einval
                        (: m (rdle s 8 8)
                           b (st 'in = 1 && (m & 2) != 0 ? (t 'in ()) ((st 'v >> 1) & 1))
                           (wrle ((st 'v - (st 'v & 2)) | (b << 1)) 8 + snip s 8 16)))
                    'enotty))
        'calls (_ \ rev (st 'calls)) 'level (_ \ st 'v)}))

; the whole stack over a gpio chip: attach, the ids, a flash written and read back, nothing
; refused, the target's wire clean, the lines asked for by name and nrst let go at the end
(: t (f4chip 2) g (swdt-gpio <t) w (gpio-wire-on g "/dev/gpiochip9" 5 6 7)
   ids (swd-attach w) fid (f4-ids w)
   s "a flash written over three gpio lines"
   r (f4-flash w 0x08004000 s) back (f4-read w 0x08004000 #s)
   cl (g 'calls ())
   _ (w 'close ())
   (test (ids = [f4dp f4ap]) (fid = [0x10006421 512]) (1 = r) (back = s)
         (<cl = ['open "/dev/gpiochip9"]) (cl 1 = ['line [5 6 7] "swd"]) (!(elem 'eperm cl))
         (() = <t 'errs ()) (4 = (g 'level ()) & 4)
         (g 'calls () @ c (drop (#c - 2) c) = [['close 4] ['close 3]])))

; the chip refuses an input set, and the wire's failures scare: a chip that will not open, and
; lines it will not give
(: g (swdt-gpio (swdt-target (f4port 0))) w (gpio-wire-on g "/dev/gpiochip9" 5 6 7)
   _ (w 'own 0)
   e (g 'ioctl 4 0xC010B40F (gpio-vals 0 7)) z (g 'ioctl 4 0xC010B40F "short")
   o (trap (_ \ gpio-wire-on {'open (p \ 'enoent)} "/dev/nope" 5 6 7) 0 (a \ b \ [a b]))
   l (trap (_ \ gpio-wire-on {'open (p \ 3) 'ioctl (\ fd rq s 'ebusy)} "/dev/gpiochip9" 5 6 7) 0 (a \ b \ [a b]))
   (test (e = 'eperm) (z = 'einval) (o = ['gpio-open 'enoent]) (l = ['gpio-lines 'ebusy])))
