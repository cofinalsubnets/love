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

; a simulated target under the wire's four words. it frames swd a bit at a time -- line resets,
; the jtag-to-swd switch, requests, acks, turnarounds, data and parity -- and hands each transfer
; to h: (h 'ack ap rd a) its ack, (h 'rd ap a) a read's value, (h 'wr ap a v) a write. until the
; switch it answers nothing; a malformed request locks it out till a line reset. 'errs is the
; wire's misuse, oldest first: a host driving swdio the target holds, clocking one in while it
; holds it, or taking it back mid-answer; a write's bad parity
(: (swdt-target h)
    (: st {'s 'jtag 'ones 0 'acc 0 'k 0 'q () 'own 1 'rst 0 'errs () 'reqs () 'at 0}
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
              (rd = 1) (: v (h 'rd ap a) (say ([1] + bits 1 3 + bits v 32 + [(swd-par v) 1]), go 'idle))
              (say ([1] + bits 1 3 + [1]), pin st 'at [ap a], from 'wdata 0 0)))
       (req r) (: ap (r >> 1 & 1) rd (r >> 2 & 1) a ((r >> 3 & 3) << 2)
                  (? ((r >> 6 & 1) = 0 && (r >> 7 & 1) = 1 && (r >> 5 & 1) = swd-par (r >> 1 & 15)) (reply ap rd a)
                     (err 'bad-request, go 'lock)))
       (host b)
        (: was (st 'ones) ones (b = 1 ? (was + 1) 0) _ (pin st 'ones ones)
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
        'rst (b \ pin st 'rst b)
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
