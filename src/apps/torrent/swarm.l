; src/apps/torrent/swarm.l -- the download: a swarm of peer connections, each a task, over
; one shared state. a piece is picked for a peer from a deadline window ahead of the
; playhead first, in order, and rarest-first past it; its blocks are asked all at once,
; it is checked against its sha1 when whole, and laid into the files in place. what is
; had is offered back: an interested peer is unchoked while a slot is free, and its
; requests are answered from the files.
;
;   (swarm-new m dir)        -> the state: the files laid under dir, the pieces already
;                               there checked and had
;   (swarm-run t peers opts) -> 1 when every piece is had | why not
;     opts: 'max (peers at once, 30) 'window (pieces ahead of the playhead, 8) 'stop (as
;           many pieces had as this, and done: every piece unless said)
;           'tick (f t), every second, for a progress line
;           'listen a listener, its peers taken too   'slots (peers unchoked at once, 8)
;           'seed 1: stay when every piece is had, until (pin t 'quit 1)
;   (swarm-add! t peers)     more peers to dial, each address once
;   (swarm-head! t i)        moves the playhead to piece i
;   (swarm-port t f from)    -> [port bytes]: file f's bytes from byte `from` on, in order, a
;                               read parking until the next piece is had and checked; the
;                               playhead follows the reader. a fresh call replaces the last
(module (swarm swarm-new swarm-run swarm-add! swarm-head! swarm-spans swarm-read swarm-had swarm-port)
(borrow 'bytes)
(borrow 'metainfo)
(borrow 'peerwire)
(:
 blk 16384
 (close q) (cite 'posix 'close q)
 ; --- the files: a piece's bytes as runs [path offset length] over them -----------
 (swarm-spans t off n)
  (: (go fs off n acc) (? (n < 1 || atom? fs) (rev acc)
                          (: f <fs p (f 0) len (f 1) at (f 2)
                             (? (off < at + len)
                                (: o (off - at) k (min n (len - o))
                                   (go >fs (off + k) (n - k) ([(t 'root + join "/" p) o k] . acc)))
                                (go >fs off n acc))))
     (go (t 'm 'files) off n ()))
 (sw-write path off s) (cite 'posix 'openfd path 4 @ fd
                         (charm? fd && 0 <= fd ?
                            (: _ (cite 'posix 'lseek fd off 0) q (fdopen fd) (say q s, flush q, close q, 1))))
 (sw-read path off n) (cite 'posix 'openfd path 0 @ fd
                        (charm? fd && 0 <= fd ?
                           (: _ (cite 'posix 'lseek fd off 0) q (fdopen fd)
                              (go acc have) (? (n <= have) (join "" (rev acc))
                                               (: b (see q) (? (b = -1) (join "" (rev acc))
                                                               (: x (string b + chug q) (go (x . acc) (have + #x))))))
                              r (go () 0)
                              (close q, snip r 0 n))))
 ; a piece's bytes into its runs, in turn
 (sw-lay-piece d spans) (: (go l at) (atom? l ? 1 (: s <l (sw-write (s 0) (s 1) (snip d at (at + s 2)), go >l (at + s 2))))
                          (go spans 0))
 (sw-block t i b n) (cats (map ([p o k] \ sw-read p o k) (swarm-spans t (i * t 'm 'plen + b) n)))
 (swarm-read t i) (sw-block t i 0 (tpiece-len (t 'm) i))
 ; every file made, at its length, its directories first -> the paths that held bytes before
 (sw-lay t) (: old {}
               (each (t 'm 'files) ([p n _] \ (: path (t 'root + join "/" p) st (cite 'posix 'stat path)
                                                 (two? st && 0 < <st ? (pin old path 1),
                                                  mkdirs (dirname path),
                                                  cite 'posix 'truncate path n 1))),
                old))
 ; the pieces already on disk, each checked against its sha1, had
 (sw-check t old) (: m (t 'm)
   (each ^(m 'count) (i \ (any (s \ peep old (s 0) 0) (swarm-spans t (i * m 'plen) (tpiece-len m i))
                            && hex2b (sha1 (swarm-read t i)) = m 'pieces i ? (sw-had! t i)))))
 (sw-had! t i) (pin (t 'have) i 1, pin (t 'log) (t 'had) i, pin t 'had (t 'had + 1))
 (mkdirs p) (: ws (split "/" p)
              (go l at) (two? l ? (: d (at + <l) (0 < #d ? (cite 'posix 'mkdir d 493) 0, go >l (d + "/"))) 0)
              (go ws ""))
 (dirname p) (: k (: (go i) (i < 0 || p i = 47 ? i (go (i - 1))) (go (#p - 1))) (0 < k ? (snip p 0 k) "."))
 (swarm-new m dir)
  (: n (m 'count)
     t (pins {} 'm m 'root (dir + "/") 'have (cask n) 'busy (cask n) 'avail (cask n) 'log {}
            'had 0 'head 0 'window 8 'down 0 'up 0 'peers 0 'live 0 'open 0 'slots 8 'why ""
            'left () 'tried {} 'tasks ())
     (sw-check t (sw-lay t), t))
 (swarm-had t) (t 'had)
 (swarm-head! t i) (pin t 'head i)
 ; our bitfield: a bit a piece, the first piece the high bit of the first byte
 (sw-bitfield t) (: n (t 'm 'count)
                   (string (map (k \ foldl (a \ j \ (a * 2 + (k * 8 + j < n ? (peep (t 'have) (k * 8 + j) 0) 0))) 0 ^8)
                                ^((n + 7) // 8))))

 ; --- the picker -------------------------------------------------------------------
 (sw-free? t bf i) (peep (t 'have) i 0 = 0 && peep (t 'busy) i 0 = 0 && pw-has? bf i)
 (sw-pick t bf) (: n (t 'm 'count) h (t 'head) w (t 'window)
   (win i) (? (n <= i || h + w <= i) -1 (sw-free? t bf i) i (win (i + 1)))
   (rare i best bc) (? (n <= i) best
                       (sw-free? t bf i) (peep (t 'avail) i 0 @ a (a < bc ? (rare (i + 1) i a) (rare (i + 1) best bc)))
                       (rare (i + 1) best bc))
   (win h @ i (0 <= i ? i (rare 0 -1 256))))
 (sw-count! t bf d) (each ^(t 'm 'count) (i \ pw-has? bf i ? (pin (t 'avail) i (max 0 (min 255 (peep (t 'avail) i 0 + d))))))

 ; --- a peer, dialled or dialling us: one loop either way ---------------------------
 ; we say interested while short of a piece, take a piece at a time while unchoked, unchoke
 ; an interested peer while a slot is free and answer its requests, and tell every peer of
 ; each piece had
 (sw-talk t c)
  (: m (t 'm) n (m 'count)
     st (pins {} 'bf (cask ((n + 7) // 8)) 'choked 1 'piece -1 'got 0 'buf {}
              'want 0 'choking 1 'told (t 'had) 'heard (clock 0) 'said (clock 0))
     (send k p) (pw-send c k p, pin st 'said (clock 0))
     _ (pin t 'live (t 'live + 1))
     _ (0 < t 'had ? (send 5 (sw-bitfield t)))
     _ (t 'had < n ? (send 2 ""))
     (ask! _) (st 'piece < 0 && !(st 'choked) ?
                (sw-pick t (st 'bf) @ i
                   (0 <= i ? (: k (tpiece-len m i)
                                (pins st 'piece i 'got 0 'buf {},
                                 pin (t 'busy) i 1,
                                 each ^((k + blk - 1) // blk) (b \ pw-request c i (b * blk) (min blk (k - b * blk))))))))
     (drop! _) (st 'piece @ i (0 <= i ? (pin (t 'busy) i 0, pin st 'piece -1)))
     (choke! _) (? !(st 'choking) (send 0 "", pin st 'choking 1, pin t 'open (t 'open - 1)))
     ; between messages: the pieces had since, a slot for a peer that wants one, a keepalive
     (tend _) (: now (clock 0)
                 (each ^(t 'had - st 'told) (k \ send 4 (wrbe (t 'log (st 'told + k)) 4)),
                  pin st 'told (t 'had),
                  st 'want && st 'choking && t 'open < t 'slots ? (send 1 "", pin st 'choking 0, pin t 'open (t 'open + 1)),
                  90000 < now - st 'said ? (pw-wr c (wrbe 0 4), pin st 'said now)))
     (serve! p) (: i (rdbe p 0 4) b (rdbe p 4 4) k (rdbe p 8 4)
                  (!(st 'choking) && i < n && peep (t 'have) i 0 && 0 < k <= 131072 && b + k <= tpiece-len m i ?
                     (send 7 (wrbe i 4 + wrbe b 4 + sw-block t i b k), pin t 'up (t 'up + k))))
     (both? _) (t 'had = n && all (i \ pw-has? (st 'bf) i) ^n)
     (loop _) (pw-next c 5000 @ msg
        (? (msg = 'gone) "gone"
           (msg = ()) (? (120000 < clock 0 - st 'heard) "quiet" (tend (), loop ()))
           (: _ (pin st 'heard (clock 0))
              (? (msg = 'alive) (tend (), loop ())
                 (msg 0 @
                   0 (pin st 'choked 1, drop! (), loop ())
                   1 (pin st 'choked 0, ask! (), loop ())
                   2 (pin st 'want 1, tend (), loop ())
                   3 (pin st 'want 0, choke! (), loop ())
                   4 (rdbe (msg 1) 0 4 @ i (i < n ?
                        (pin (st 'bf) (i // 8) (peep (st 'bf) (i // 8) 0 | 128 >> i % 8),
                         pin (t 'avail) i (min 255 (peep (t 'avail) i 0 + 1)))), ask! (), both? () ? "both whole" (loop ()))
                   5 (pin st 'bf (msg 1), sw-count! t (msg 1) 1, ask! (), both? () ? "both whole" (loop ()))
                   6 (serve! (msg 1), tend (), loop ())
                   7 (: pl (msg 1) i (rdbe pl 0 4) b (rdbe pl 4 4 // blk)
                        (? (i != st 'piece) (loop ())
                           (: _ (pin (st 'buf) b (snip pl 8 #pl)) _ (pin st 'got (st 'got + 1))
                              _ (pin t 'down (t 'down + #pl - 8))
                              (st 'got = (tpiece-len m i + blk - 1) // blk ?
                                 (sw-done! t st i, ask! (), tend (), both? () ? "both whole" (loop ()))
                                 (loop ())))))
                   (loop ()))))))
     r (loop ())
     (drop! (), !(st 'choking) ? (pin t 'open (t 'open - 1)), sw-count! t (st 'bf) -1, pin t 'live (t 'live - 1), pw-close c, r))
 (sw-dial t p) (: m (t 'm) c (pw-dial (p 0) (p 1) (m 'hash) (t 'id) 10000)
                 (tablet? c ? (sw-talk t c) c))
 ; a piece whole: checked, laid in place, and had -- or dropped to be asked again
 (sw-done! t st i)
  (: m (t 'm) n (tpiece-len m i) d (cats (map (b \ peep (st 'buf) b "") ^((n + blk - 1) // blk)))
     ok (#d = n && hex2b (sha1 d) = m 'pieces i)
     (ok ? (sw-lay-piece d (swarm-spans t (i * m 'plen) n))
        (pin t 'why ("piece " + show i + " failed its hash")),
      pin (t 'busy) i 0, pins st 'piece -1 'buf {},
      ok ? (sw-had! t i)))

 ; --- the ordered port: a pipe, its writer a task that waits on each piece in turn ---
 (swarm-port t f from)
  (: m (t 'm) fl (m 'files f) at (fl 2) len (fl 1)
     pp (pipe 0) r (fdopen <pp) w (fdopen >pp)
     (feed off) (? (len <= off) (close w)
                   (: abs (at + off) i (abs // m 'plen) ps (i * m 'plen)
                      (? (peep (t 'have) i 0 = 0) (swarm-head! t i, rest 100, feed off)
                         (: d (swarm-read t i)
                            e (min #d (at + len - ps))
                            chunk (snip d (abs - ps) e)
                            (say w chunk, flush w, feed (off + #chunk))))))
     _ (peep t 'feeder () @ () 0 old (freeze old))
     (pin t 'feeder (twirl (_ \ feed from) ()), [r (len - from)]))
 ; --- the run: peers on tasks, more dialled as some end, those that dial us taken -----
 (sw-task! t f) (pin t 'tasks (twirl f () . t 'tasks))
 ; peers to dial, each address once
 (swarm-add! t ps) (each ps (p \ (show p) @ k (peep (t 'tried) k 0 ? 0 (pin (t 'tried) k 1, pin t 'left (t 'left + [p])))))
 (sw-more! t mx) (? (mx <= t 'peers || atom? (t 'left) || t 'had = t 'm 'count) 0
                    (: p <(t 'left)
                       (pin t 'left >(t 'left),
                        pin t 'peers (t 'peers + 1),
                        sw-task! t (_ \ (sw-dial t p, pin t 'peers (t 'peers - 1))),
                        sw-more! t mx)))
 (sw-listen t l mx)
  (: (take s) (pw-greet s (t 'm 'hash) (t 'id) 10000 @ c (tablet? c ? (sw-talk t c) c))
     (go _) (: _ (await l) s (accept l)
               _ (? !(hot? s) 0
                    (mx <= t 'peers) (close s)
                    (: _ (pin t 'peers (t 'peers + 1))
                       (sw-task! t (_ \ (take s, pin t 'peers (t 'peers - 1))))))
               (go ()))
     (sw-task! t go))
 (swarm-run t peers opts)
  (: mx (peep opts 'max 30) tick (peep opts 'tick (_ \ 0)) l (peep opts 'listen ())
     seed (peep opts 'seed 0)
     _ (pins t 'window (peep opts 'window 8) 'id (peep opts 'id "-LV0300-000000000000")
             'slots (peep opts 'slots 8))
     _ (swarm-add! t peers)
     _ (hot? l ? (sw-listen t l mx))
     stop (peep opts 'stop (t 'm 'count))
     (wait k) (? (peep t 'quit 0) 1
                 (!seed && stop <= t 'had) 1
                 (t 'peers = 0 && atom? (t 'left) && !(hot? l) && t 'had < t 'm 'count)
                   ("every peer is gone, " + show (t 'had) + " of " + show (t 'm 'count) + " pieces had")
                 (: _ (sw-more! t mx) _ (rest 1000) (tick t, wait (k + 1))))
     r (wait 0)
     (each (t 'tasks) freeze, r))
)) ; module swarm
