; src/apps/net/tcp.l -- tcp over ip.l (rfc 9293's machine): the handshake both ways, data both
; ways, fin in either order, rst, retransmission on an rtt estimate (rfc 6298, karn's rule),
; windows both ways with a zero-window probe, segments out of order held and joined, slow
; start and halving on loss (rfc 5681, no sack). a connection is a tcb tablet the caller holds;
; every call is a step, so a socket door is a port over these
;   (tcp-on st)                    the stack takes protocol 6
;   (tcp-listen st port) (tcp-accept st port) -> a tcb now established, or ()
;   (tcp-unlisten st port now)     the port shut, its connections not yet accepted reset
;   (tcp-connect st ip port now)   -> a tcb in syn-sent
;   (tcp-write st t b now)         -> the bytes taken, at most the send buffer's room
;   (tcp-read st t now)            -> what has arrived, "" for none yet, () once the peer's fin
;                                     is read past
;   (tcp-close st t now)           a fin once what was written is sent
;   (tcp-abort st t now)           a rst, and the tcb gone
;   (tcp-state t) (tcp-err t)      'established and kin; () or 'reset 'refused 'timeout
;   (tcp-room t)                   what the send buffer would take now
(module (tcp tcp-on tcp-listen tcp-unlisten tcp-listening? tcp-accept tcp-connect tcp-write
         tcp-read tcp-close tcp-abort tcp-state tcp-err tcp-room seq-d)
(borrow '(bytes net))
(:
   fin 1  syn 2  rst 4  psh 8  ack 16
   mss0 1460  rbuf 65535  sbuf 65536  rto0 1000  rto-min 200  rto-max 60000  tries 12
   M 4294967296
   ; b - a as a signed 32-bit distance
   (seq-d b a) (((b - a + 6442450944) % M) - 2147483648)
   (sq v) (v % M)
   (has f x) ((f & x) != 0)
   (tcp-state t) (t 'st)
   (tcp-err t) (t 'err)
   (tcp-room t) (sbuf - #(t 'sb))
   (gone st t) (pull (st 'tcbs) (t 'key) 0, pin t 'st 'closed)
   (win t) (max 0 (rbuf - t 'rbn))

   ; --- out ---------------------------------------------------------------------------
   (raw st src sp dst dp fl sq0 ak wn b opts now)
    (: h (wrbe sp 2 + wrbe dp 2 + wrbe sq0 4 + wrbe ak 4 + string [((5 + #opts // 4) << 4) fl]
          + wrbe wn 2 + zbytes 4 + opts)
       s (h + b)
       c (ip-sum (ip-pseudo src dst 6 #s + s))
       (ip-send-from st src dst 6 (snip s 0 16 + wrbe c 2 + snip s 18 #s) now))
   (out st t fl sq0 b now)
    (: w (win t)
       _ (pin t 'awin w)
       (raw st (t 'lip) (t 'lp) (t 'rip) (t 'rp) fl sq0 (has fl ack ? (t 'rnxt) 0) w b
            (has fl syn ? (string [2 4] + wrbe mss0 2) "") now))
   (ack-now st t now) (out st t ack (t 'nxt) "" now)
   ; max is the highest sent, which a go-back leaves where it was
   (top t) (0 < seq-d (t 'nxt) (t 'max) ? (pin t 'max (t 'nxt)) 0)
   (arm t now) (t 'tmr = 0 ? (pin t 'tmr (now + t 'rto)) 0)
   ; what the window lets go: data from nxt, then a fin once the data is gone
   (output st t now)
    (: S (t 'st)
       (? (!(elem S '(established close-wait fin-wait-1 last-ack closing)) || t 'fsent) 0
          (: off (seq-d (t 'nxt) (t 'una))
             room (min (t 'wnd) (t 'cwnd) - off)
             n (min (#(t 'sb) - off) (min room (t 'mss)))
             (? (0 < n)
                  (: sq0 (t 'nxt)
                     _ (t 'rtts < 0 ? (pin t 'rtts sq0, pin t 'rtt0 now) 0)
                     (pin t 'nxt (sq (sq0 + n)), top t,
                      out st t (ack | psh) sq0 (snip (t 'sb) off (off + n)) now,
                      arm t now,
                      output st t now))
                (t 'fin && off = #(t 'sb))
                  (: sq0 (t 'nxt)
                     (pin t 'fsent 1, pin t 'fq 1, pin t 'fseq sq0, pin t 'nxt (sq (sq0 + 1)), top t,
                      pin t 'st (S @ 'established 'fin-wait-1 'close-wait 'last-ack _ S),
                      out st t (ack | fin) sq0 "" now,
                      arm t now))
                (t 'wnd = 0 && off = 0 && off < #(t 'sb)) (arm t now)   ; the probe's timer
                0))))

   ; --- a tcb ---------------------------------------------------------------------------
   (tcb st lip rip rp lp S iss)
    (: k (rip + wrbe rp 2 + wrbe lp 2)
       t {'key k 'st S 'lip lip 'rip rip 'rp rp 'lp lp 'iss iss 'una iss 'nxt (sq (iss + 1)) 'max (sq (iss + 1)) 'wnd mss0 'sb ""
          'fin 0 'fsent 0 'fq 0 'fseq 0 'irs 0 'rnxt 0 'rb () 'rbn 0 'ooo {} 'pfin 0 'pmoved 0 'mss mss0
          'srtt 0 'rttv 0 'rto rto0 'rtts -1 'rtt0 0 'tmr 0 'n 0 'cwnd (2 * mss0) 'ssth 65535
          'dup 0 'err () 'tw 0 'awin rbuf 'lst ()}
       (pin (st 'tcbs) k t, t))
   (next-iss st) (st 'iss @ i (pin st 'iss (sq (i + 64000 + net-rand st % 1000)), i))
   (tcp-on st)
    (: _ (pin st 'tcbs {}) _ (pin st 'lsn {}) _ (pin st 'eph 49152)
       _ (pin st 'iss (net-rand st)) _ (pin st 'msl 1000)
       (pin (st 'proto) 6 tcp-in, pin st 'ticks (tcp-tick . st 'ticks)))
   (tcp-listen st port) (pin (st 'lsn) port (peep (st 'lsn) port ()))
   (tcp-listening? st port) (peep (st 'lsn) port 'none != 'none)
   (tcp-unlisten st port now)
    (: q (peep (st 'lsn) port ())
       _ (pull (st 'lsn) port 0)
       ; the handshakes still under way go too
       h (filter (t \ t 'lst = port && t 'st = 'syn-rcvd) (map (k \ st 'tcbs k) (keys (st 'tcbs))))
       (each (q + h) (t \ tcp-abort st t now)))
   (tcp-accept st port)
    (peep (st 'lsn) port () @ (t . r) (pin (st 'lsn) port r, t) _ ())
   (tcp-connect st ip port now)
    (: lp (st 'eph) _ (pin st 'eph (lp = 65535 ? 49152 (lp + 1)))
       t (tcb st (ip-src st ip) ip port lp 'syn-sent (next-iss st))
       (out st t syn (t 'iss) "" now, pin t 'rtts (t 'iss), pin t 'rtt0 now, arm t now, t))
   (tcp-write st t b now)
    (? (!(elem (t 'st) '(established close-wait)) || t 'fin) 0
       (: n (min #b (sbuf - #(t 'sb)))
          (pin t 'sb (t 'sb + snip b 0 n), output st t now, n)))
   (tcp-read st t now)
    (: d (join "" (rev (t 'rb)))
       w0 (t 'awin)
       _ (pin t 'rb (), pin t 'rbn 0)
       ; a window that opened past two segments is said at once
       _ (elem (t 'st) '(established fin-wait-1 fin-wait-2) && w0 < 2 * t 'mss && 2 * t 'mss <= win t
            ? (ack-now st t now) 0)
       (? (0 < #d) d (t 'pfin) () ""))
   (tcp-close st t now)
    (t 'st @ 'syn-sent (gone st t)
             _ (pin t 'fin 1, output st t now))
   (tcp-abort st t now)
    (elem (t 'st) '(closed time-wait) ? (gone st t)
       (out st t (rst | ack) (t 'nxt) "" now, gone st t))

   ; --- in --------------------------------------------------------------------------------
   ; a reply to a segment no tcb takes
   (rst-for st me src sp dp sq0 ak fl n now)
    (has fl rst ? 0
       (has fl ack ? (raw st me dp src sp rst ak 0 0 "" "" now)
          (raw st me dp src sp (rst | ack) 0 (sq (sq0 + n + (has fl syn ? 1 0) + (has fl fin ? 1 0))) 0 "" "" now)))
   (opt-mss o)
    (: n #o
       (go i) (? (n <= i || o i = 0) mss0 (o i = 1) (go (i + 1)) (n < i + 2 || o (i + 1) < 2) mss0
                 (o i = 2 && i + 4 <= n) (min mss0 (rdbe o (i + 2) 2))
                 (go (i + o (i + 1))))
       (go 0))
   (tcp-in st src dst s now)
    (? (#s < 20 || ip-sum (ip-pseudo src dst 6 #s + s) != 0) 0
       (: sp (rdbe s 0 2) dp (rdbe s 2 2) sq0 (rdbe s 4 4) ak (rdbe s 8 4)
          off ((s 12 >> 4) * 4) fl (s 13) wn (rdbe s 14 2)
          b (snip s off #s) o (snip s 20 off)
          t (peep (st 'tcbs) (src + wrbe sp 2 + wrbe dp 2) ())
          (? (t != ()) (seg st t fl sq0 ak wn b o now)
             (has fl syn && !(has fl ack) && !(has fl rst) && tcp-listening? st dp)
               (: t (tcb st dst src sp dp 'syn-rcvd (next-iss st))
                  (pin t 'irs sq0, pin t 'rnxt (sq (sq0 + 1)), pin t 'mss (opt-mss o), pin t 'wnd wn,
                   pin t 'lst dp, pin t 'rtt0 now,
                   out st t (syn | ack) (t 'iss) "" now, arm t now))
             (rst-for st dst src sp dp sq0 ak fl #b now))))

   ; an rtt sample (rfc 6298): srtt, its variance, rto clamped
   (rtt t r)
    (? (t 'srtt = 0) (pin t 'srtt r, pin t 'rttv (r // 2), rto-set t)
       (pin t 'rttv ((3 * t 'rttv + abs (t 'srtt - r)) // 4),
        pin t 'srtt ((7 * t 'srtt + r) // 8),
        rto-set t))
   (rto-set t) (pin t 'rto (min rto-max (max rto-min (t 'srtt + max 1 (4 * t 'rttv)))))

   (seg st t fl sq0 ak wn b o now)
    (: S (t 'st)
       (? (S = 'syn-sent) (syn-sent st t fl sq0 ak wn o now)
          (has fl rst) (in-win? t sq0 0 ? (rst-in st t) 0)
          (has fl syn)
            ((S = 'syn-rcvd && sq0 = t 'irs) ? (out st t (syn | ack) (t 'iss) "" now) (ack-now st t now))
          (!(has fl ack)) 0
          (: n (#b + (has fl fin ? 1 0))
             (? (!(in-win? t sq0 n)) (S = 'time-wait && has fl fin ? (tw-again st t now) (ack-now st t now))
                (acked st t ak wn #b now,
                 elem (t 'st) '(established fin-wait-1 fin-wait-2) && 0 < n ? (data st t sq0 b (has fl fin) now) 0,
                 output st t now)))))
   ; a segment of n beginning at s0 touches the receive window (rfc 9293's four cases)
   (in-win? t s0 n)
    (: w (max 1 (win t)) d (seq-d s0 (t 'rnxt))
       (n = 0 ? (0 <= d && d < w) (d < w && 0 < d + n)))
   ; past our own fin's ack the user has nothing left to hear: a rst only ends it
   (rst-in st t)
    (t 'st @ 'syn-rcvd (pin t 'err 'refused, gone st t)
             ('time-wait || 'closing || 'last-ack) (gone st t)
             _ (pin t 'err 'reset, gone st t))
   (tw-again st t now) (ack-now st t now, pin t 'tw (now + 2 * st 'msl))
   (syn-sent st t fl sq0 ak wn o now)
    (: good (has fl ack && ak = t 'nxt)
       (? (has fl ack && !good) (has fl rst ? 0 (raw st (t 'lip) (t 'lp) (t 'rip) (t 'rp) rst ak 0 0 "" "" now))
          (has fl rst) (good ? (pin t 'err 'refused, gone st t) 0)
          (!(has fl syn)) 0
          (: _ (pin t 'irs sq0) _ (pin t 'rnxt (sq (sq0 + 1))) _ (pin t 'mss (opt-mss o)) _ (pin t 'wnd wn)
             (? good (pin t 'una ak, pin t 'st 'established, pin t 'tmr 0, pin t 'n 0,
                      rtt t (max 1 (now - t 'rtt0)), pin t 'rtts -1, ack-now st t now, output st t now)
                (pin t 'st 'syn-rcvd, out st t (syn | ack) (t 'iss) "" now)))))

   ; the ack field: what it takes off the send buffer, the timer, the window and cwnd
   (acked st t ak wn nb now)
    (: d (seq-d ak (t 'una)) over (seq-d ak (t 'max))
       (? (t 'st = 'syn-rcvd)
            (? (0 < d && over <= 0)
                 (: l (t 'lst)
                    (pin t 'una ak, pin t 'st 'established, pin t 'wnd wn, pin t 'tmr 0, pin t 'n 0,
                     rtt t (max 1 (now - t 'rtt0)),
                     tcp-listening? st l ? (pin (st 'lsn) l ((st 'lsn) l + [t])) 0))
               (raw st (t 'lip) (t 'lp) (t 'rip) (t 'rp) rst ak 0 0 "" "" now))
          (0 < d && over <= 0)
            (: fa (t 'fq && ak = sq (t 'fseq + 1))
               k (d - (fa ? 1 0))
               (pin t 'sb (snip (t 'sb) (min k #(t 'sb)) #(t 'sb)),
                pin t 'una ak, 0 < seq-d ak (t 'nxt) ? (pin t 'nxt ak) 0, fa ? (pin t 'fsent 1) 0, pin t 'wnd wn, pin t 'dup 0, pin t 'n 0,
                (t 'rtts >= 0 && 0 < seq-d ak (t 'rtts)) ? (rtt t (max 1 (now - t 'rtt0)), pin t 'rtts -1) 0,
                pin t 'cwnd (t 'cwnd < t 'ssth ? (t 'cwnd + t 'mss) (t 'cwnd + max 1 (t 'mss * t 'mss // t 'cwnd))),
                pin t 'tmr (ak = t 'max ? 0 (now + t 'rto)),
                fa ? (t 'st @ 'fin-wait-1 (pin t 'st 'fin-wait-2)
                             'closing (pin t 'st 'time-wait, pin t 'tw (now + 2 * st 'msl))
                             'last-ack (gone st t)
                             _ 0) 0))
          (d = 0 && nb = 0 && ak != t 'max && wn = t 'wnd)
            (pin t 'dup (t 'dup + 1),
             t 'dup = 3 ? (halve t, pin t 'nxt (t 'una), pin t 'rtts -1, output-one st t now) 0)
          (d = 0) (pin t 'wnd wn)
          0))
   (flight t) (seq-d (t 'max) (t 'una))
   (halve t) (pin t 'ssth (max (2 * t 'mss) (flight t // 2)), pin t 'cwnd (t 'ssth))
   ; one segment again from una, then the rest as the window had it
   (output-one st t now)
    (: c (t 'cwnd) _ (pin t 'cwnd (t 'mss)) _ (pin t 'fsent (t 'fsent && seq-d (t 'nxt) (t 'fseq) > 0))
       (output st t now, pin t 'cwnd c))

   ; data and fin: in order taken, ahead of it held, behind it cut
   (data st t s0 b f now)
    (: d (seq-d s0 (t 'rnxt))
       _ ((0 < d) ? (hold t s0 b f) (take t (snip b (min #b (0 - d)) #b) f))
       _ (pull-held t)
       _ (ack-now st t now)
       (pmove st t now))
   ; the peer's fin, taken, moves the state once
   (pmove st t now)
    ((t 'pfin && !(t 'pmoved)) ? (pin t 'pmoved 1,
       (t 'st @ 'established (pin t 'st 'close-wait)
                'fin-wait-1 (pin t 'st 'closing)
                'fin-wait-2 (pin t 'st 'time-wait, pin t 'tw (now + 2 * st 'msl))
                _ 0)) 0)
   (hold t s0 b f)
    (peep (t 'ooo) s0 () @ [ob of] (#ob < #b ? (pin (t 'ooo) s0 [b f]) 0)
                           _ (pin (t 'ooo) s0 [b f]))
   (take t b f)
    (? (t 'pfin) 0
       (: _ (0 < #b ? (pin t 'rb (b . t 'rb), pin t 'rbn (t 'rbn + #b), pin t 'rnxt (sq (t 'rnxt + #b))) 0)
          (f ? (pin t 'pfin 1, pin t 'rnxt (sq (t 'rnxt + 1))) 0)))
   ; the held segments that now reach rnxt, joined; the ones behind it dropped
   (pull-held t)
    (: (go ks moved)
        (? (atom? ks) (moved ? (pull-held t) 0)
           (: k <ks
              d (seq-d k (t 'rnxt))
              (? (0 < d) (go >ks moved)
                 (t 'ooo k @ [b f]
                    (pull (t 'ooo) k 0,
                     (0 - d < #b || f) ? (take t (snip b (min #b (0 - d)) #b) f) 0,
                     go >ks 1)))))
       (t 'pfin ? 0 (go (keys (t 'ooo)) 0)))

   ; --- the clock --------------------------------------------------------------------------
   (tcp-tick st now)
    (each (map (k \ st 'tcbs k) (keys (st 'tcbs)))
      (t \ (? (t 'st = 'time-wait) (t 'tw <= now ? (gone st t) 0)
              (0 < t 'tmr && t 'tmr <= now) (expire st t now)
              0)))
   (expire st t now)
    (: k (t 'n + 1)
       _ (pin t 'n k)
       _ (pin t 'rto (min rto-max (2 * t 'rto)))
       _ (pin t 'tmr 0)
       _ (pin t 'rtts -1)
       (? (tries < k) (pin t 'err 'timeout, gone st t)
          (t 'st = 'syn-sent) (out st t syn (t 'iss) "" now, arm t now)
          (t 'st = 'syn-rcvd) (out st t (syn | ack) (t 'iss) "" now, arm t now)
          (flight t = 0 && t 'wnd = 0)
            ; the probe: one byte past the closed window, which the peer drops and acks again
            (pin t 'n 0,
             0 < #(t 'sb) ? (out st t (ack | psh) (t 'nxt) (snip (t 'sb) 0 1) now, pin t 'nxt (sq (t 'nxt + 1)), top t) 0,
             arm t now)
          (halve t, pin t 'cwnd (t 'mss), pin t 'nxt (t 'una),
           pin t 'fsent (t 'fsent && seq-d (t 'una) (t 'fseq) > 0),
           output st t now,
           arm t now)))
)
) ; module tcp
