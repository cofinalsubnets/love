; src/apps/torrent/swarm.l -- the download: a swarm of peer connections, each a task, over
; one shared state. a piece is picked for a peer from a deadline window ahead of the
; playhead first, in order, and rarest-first past it; its blocks are asked all at once,
; it is checked against its sha1 when whole, and laid into the files in place.
;
;   (swarm-new m dir)        -> the state: the metainfo, the files laid under dir
;   (swarm-run t peers opts) -> 1 when every piece is had | why not
;     opts: 'max (peers at once, 30) 'window (pieces ahead of the playhead, 8) 'stop (as
;           many pieces had as this, and done: every piece unless said)
;           'tick (f t), every second, for a progress line
;   (swarm-head! t i)        moves the playhead to piece i
(module (swarm swarm-new swarm-run swarm-head! swarm-spans swarm-read swarm-had)
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
 (swarm-read t i) (: m (t 'm) (cats (map ([p o k] \ sw-read p o k) (swarm-spans t (i * m 'plen) (tpiece-len m i)))))
 ; every file made, at its length, its directories first
 (sw-lay t) (each (t 'm 'files) ([p n _] \ (: path (t 'root + join "/" p)
                                              (mkdirs (dirname path),
                                               cite 'posix 'truncate path n 1))))
 (mkdirs p) (: ws (split "/" p)
              (go l at) (two? l ? (: d (at + <l) (0 < #d ? (cite 'posix 'mkdir d 493) 0, go >l (d + "/"))) 0)
              (go ws ""))
 (dirname p) (: k (: (go i) (i < 0 || p i = 47 ? i (go (i - 1))) (go (#p - 1))) (0 < k ? (snip p 0 k) "."))
 (swarm-new m dir)
  (: n (m 'count)
     t (pins {} 'm m 'root (dir + "/") 'have (cask n) 'busy (cask n) 'avail (cask n)
            'had 0 'head 0 'window 8 'down 0 'peers 0 'live 0 'why "")
     (sw-lay t, t))
 (swarm-had t) (t 'had)
 (swarm-head! t i) (pin t 'head i)

 ; --- the picker -------------------------------------------------------------------
 (sw-free? t bf i) (peep (t 'have) i 0 = 0 && peep (t 'busy) i 0 = 0 && pw-has? bf i)
 (sw-pick t bf) (: n (t 'm 'count) h (t 'head) w (t 'window)
   (win i) (? (n <= i || h + w <= i) -1 (sw-free? t bf i) i (win (i + 1)))
   (rare i best bc) (? (n <= i) best
                       (sw-free? t bf i) (peep (t 'avail) i 0 @ a (a < bc ? (rare (i + 1) i a) (rare (i + 1) best bc)))
                       (rare (i + 1) best bc))
   (win h @ i (0 <= i ? i (rare 0 -1 256))))
 (sw-count! t bf d) (each ^(t 'm 'count) (i \ pw-has? bf i ? (pin (t 'avail) i (max 0 (min 255 (peep (t 'avail) i 0 + d))))))

 ; --- a peer: dial, say interested, then take a piece at a time while unchoked ------
 (sw-peer t p)
  (: m (t 'm) c (pw-dial (p 0) (p 1) (m 'hash) (t 'id) 10000)
     (? !(tablet? c) c
        (: st (pins {} 'bf (cask ((m 'count + 7) // 8)) 'choked 1 'piece -1 'got 0 'buf {})
           _ (pw-send c 2 "")
           _ (pin t 'live (t 'live + 1))
           (ask! _) (st 'piece < 0 && !(st 'choked) ?
                      (sw-pick t (st 'bf) @ i
                         (0 <= i ? (: n (tpiece-len m i)
                                      (pins st 'piece i 'got 0 'buf {},
                                       pin (t 'busy) i 1,
                                       each ^((n + blk - 1) // blk) (b \ pw-request c i (b * blk) (min blk (n - b * blk))))))))
           (drop! _) (st 'piece @ i (0 <= i ? (pin (t 'busy) i 0, pin st 'piece -1)))
           (loop _) (pw-next c 120000 @ msg
              (? (atom? msg) (msg = 'alive ? (loop ()) "quiet")
                 (msg 0 @
                   0 (pin st 'choked 1, drop! (), loop ())
                   1 (pin st 'choked 0, ask! (), loop ())
                   4 (rdbe (msg 1) 0 4 @ i (i < m 'count ?
                        (pin (st 'bf) (i // 8) (peep (st 'bf) (i // 8) 0 | 128 >> i % 8),
                         pin (t 'avail) i (min 255 (peep (t 'avail) i 0 + 1)))), ask! (), loop ())
                   5 (pin st 'bf (msg 1), sw-count! t (msg 1) 1, ask! (), loop ())
                   7 (: pl (msg 1) i (rdbe pl 0 4) b (rdbe pl 4 4 // blk)
                        (? (i != st 'piece) (loop ())
                           (: _ (pin (st 'buf) b (snip pl 8 #pl)) _ (pin st 'got (st 'got + 1))
                              _ (pin t 'down (t 'down + #pl - 8))
                              (st 'got = (tpiece-len m i + blk - 1) // blk ?
                                 (sw-done! t st i, ask! (), t 'had = m 'count ? "done" (loop ()))
                                 (loop ())))))
                   (loop ()))))
           r (loop ())
           (drop! (), sw-count! t (st 'bf) -1, pin t 'live (t 'live - 1), pw-close c, r))))
 ; a piece whole: checked, laid in place, and had -- or dropped to be asked again
 (sw-done! t st i)
  (: m (t 'm) n (tpiece-len m i) d (cats (map (b \ peep (st 'buf) b "") ^((n + blk - 1) // blk)))
     ok (#d = n && hex2b (sha1 d) = m 'pieces i)
     (ok ? (sw-lay-piece d (swarm-spans t (i * m 'plen) n))
        (pin t 'why ("piece " + show i + " failed its hash")),
      pin (t 'busy) i 0, pins st 'piece -1 'buf {},
      ok ? (pin (t 'have) i 1, pin t 'had (t 'had + 1))))

 ; --- the run: peers on tasks, more dialled as some end ------------------------------
 (swarm-run t peers opts)
  (: mx (peep opts 'max 30) tick (peep opts 'tick (_ \ 0))
     _ (pins t 'window (peep opts 'window 8) 'id (peep opts 'id "-LV0300-000000000000"))
     q (pins {} 'left peers 'tasks ())
     (more! _) (? (mx <= t 'peers || atom? (q 'left)) 0
                  (: p <(q 'left)
                     (pin q 'left >(q 'left),
                      pin t 'peers (t 'peers + 1),
                      pin q 'tasks (twirl (_ \ (sw-peer t p, pin t 'peers (t 'peers - 1))) () . q 'tasks),
                      more! ())))
     stop (peep opts 'stop (t 'm 'count))
     (wait k) (? (stop <= t 'had) 1
                 (t 'peers = 0 && atom? (q 'left)) ("every peer is gone, " + show (t 'had) + " of " + show (t 'm 'count) + " pieces had")
                 (: _ (more! ()) _ (rest 1000) (tick t, wait (k + 1))))
     r (wait 0)
     (each (q 'tasks) freeze, r))
)) ; module swarm
