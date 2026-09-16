; apps/harp/harp.l -- harp: cycles as patterns, tidal's algebra in love. Pure --
; no port, no clock, no card -- so it rides the corpus on every seat and
; test/law/harp.l asserts the whole thing by querying spans.
;
; A PATTERN IS A FUNCTION FROM A SPAN TO EVENTS: (p b e) -> [ev ..], where b and
; e are cycle positions. That one sentence is the design; every combinator below
; is a change of variable on the query, the answer, or both. There is no event
; list anywhere, so a pattern is infinite, and `fast 3` costs nothing until asked.
;
; an event is [wb we pb pe v]: the WHOLE span the event logically occupies, the
; PART of it this query saw, and the value. the two differ when a query cuts an
; event in half, and the difference is what tells a player which fragments are
; onsets (pb = wb) and which are the tails of something already struck.
;
; times are the tree's exact rationals (`1 /// 3`), never floats: a third of a cycle
; has to land on the same side of a boundary from both directions or `fast 3` drops
; a beat. they are big-aware, so a deep nest of fasts does not lose the denominator.
;
; the value is whatever the caller puts there. the mini-notation makes strings and
; numbers; the control words (hit/note/gain/pan/..) lift those into tablets, which
; merge, which is what makes `#` a set and `jux` a stereo split.
;
; this file shadows prel's `rev` and `every` with the pattern ones (tidal's names,
; and the tree has no other reader here). nothing below may call the list versions.
(module '(harp
  qi qzero qone qhalf qneg qmin qmax qfl qfq qnum
  evwb evwe evpb evpe evv onset? evtime cycles
  hush pure stack slowcat fastcat timecat squeeze fast slow rev late early
  pmap pkeep onsets appl pset whenc every off jux iter palin seg sig super whenmod ply
  sine cosine saw isaw tri square rand range
  degby undeg degbyk undegk sometimesby sometimes degrade euclid euclidr bjork rnd rndk
  ctl with named hit note n gain pan speed cut room legato mini matom lrev cmap)
(:
   ; --- exact cycle time -----------------------------------------------------
   ; the tree's own rationals (love/boot/post.l): `3 /// 4` builds one, + - * / and
   ; < <= = are exact over them and over bignums, `sort` orders them, and `load`
   ; answers (num den). only the two operations the coin does not carry are here.
   ;
   ; EVERY time value is a coin, whole cycles included -- qi is how an integer
   ; becomes one, and nothing below writes a bare one. `load` is why: qfl and qnum
   ; take a coin apart, and a plain integer has no parts to take.
   ; a rational meeting a TRAY answers () -- `+` takes the coin lane before the
   ;   array lane and the rational's method refuses a non-star. so a time crosses
   ;   into frame arithmetic through qnum and never after; see apps/harp/play.l.
   (qi n)     (n /// 1)
   qzero      (0 /// 1)
   qone       (1 /// 1)
   qhalf      (1 /// 2)
   (qneg a)   (qzero - a)
   (qmin a b) (a < b ? a b)
   (qmax a b) (a < b ? b a)
   ; // truncates toward zero, so a negative cycle needs the step down by hand
   (qfl a)    (: p (load a)  n <p  d <>p  t (n // d)
                 (? (t * d = n) t (n < 0) (t - 1) t))
   qfq    (qi * qfl)
   (qnum a)   (load a @ p (<p / <>p))
   ; the same two, on plain integers, with n > 0
   (imod a n) (a % n @ r (r < 0 ? (r + n) r))
   (idiv a n) (a // n @ t (t * n > a ? (t - 1) t))

   ; --- lists, without prel's rev (this file shadows it) --------------------
   (lrev l)   (:- (go l ()) (go l a) (two? l ? (go >l (<l . a)) a))
   (cmap f l) (foldl (a \ x \ a + f x) () l)
   (rept v n) (n > 0 ? (v . rept v (n - 1)))

   ; --- events ---------------------------------------------------------------
   (evwb x)   (x 0)
   (evwe x)   (x 1)
   (evpb x)   (x 2)
   (evpe x)   (x 3)
   (evv x)    (x 4)
   ; an onset is a part that starts where its whole does: the fragment a player strikes
   (onset? x) (x 0 = x 2)
   (evtime f x) [(f (x 0)) (f (x 1)) (f (x 2)) (f (x 3)) (x 4)]

   ; the query span cut at every cycle line. every combinator whose answer depends
   ; on WHICH cycle it is (slowcat, rev, every, squeeze) queries through this, so
   ; the cycle number is never read off a span that straddles two.
   (cycles b e) (b < e ?  (qmin e (qfq b + qone) @ nx ((b . nx) . cycles nx e)))

   ; --- the patterns ---------------------------------------------------------
   hush       (\ b e ())
   ; one event per cycle, the whole cycle wide
   (pure v)   (\ b e (map (\ s (: c (qfq <s) [c (c + qone) <s >s v])) (cycles b e)))
   (stack ps) (\ b e (cmap (p \ p b e) ps))

   ; one pattern per cycle, and each one advances a cycle only when its turn comes:
   ; that offset is the whole difference between slowcat and a stack of shifts.
   (slowcat ps)
    (: n #ps
       (? (n = 0) hush
          (\ b e (cmap (\ s
                        (: c (qfl <s)  i (imod c n)  o (qi (c - (idiv (c - i) n)))
                           p (ps i)
                           (map (evtime (t \ t + o)) (p (<s - o) (>s - o)))))
                       (cycles b e)))))

   (fast n p) (? (n = qzero) hush
                 (n < qzero) (rev (fast (qneg n) p))
                 (\ b e (map (evtime (t \ t / n)) (p (b * n) (e * n)))))
   (slow n p) (n = qzero ? hush (fast (qone / n) p))
   (fastcat ps) (fast (qi #ps) (slowcat ps))

   ; p's cycle squeezed into the window [b0,e0) of every cycle, silence outside it.
   ; this is what gives a step its slot, so it is also what `@` weights.
   (squeeze b0 e0 p)
    (: w (e0 - b0)
       (qzero >= w ? hush
          (\ b e (cmap (\ s
                        (: c  (qfl <s)  cq (qi c)
                           wb (cq + b0)  we (cq + e0)
                           ib (qmax <s wb)  ie (qmin >s we)
                           (fwd t) (cq + (t - wb) / w)
                           (bak u) (wb + (u - cq) * w)
                           (ib < ie ? (map (evtime bak) (p (fwd ib) (fwd ie))))))
                       (cycles b e)))))

   ; steps with weights: [(w . p) ..] laid end to end across one cycle
   (timecat wps)
    (: tot (foldl (a \ x \ a + <x) qzero wps)
       (go acc l) (two? l ?
                   (: x <l  w <x
                      b (acc / tot)  e ((acc + w) / tot)
                    (squeeze b e >x . go (acc + w) >l)))
       (tot = qzero ? hush (stack (go qzero wps))))

   ; a cycle played backwards. the reflection swaps begin and end, so the event's
   ; two spans have to be re-ordered after it or every whole comes out inside out.
   (rev p)
    (\ b e (cmap (\ s
                  (: c (qfl <s)  cq (qi c)  nq (cq + qone)
                     (refl t) (cq + nq - t)
                     (map (x \ evtime refl x @ y [(y 1) (y 0) (y 3) (y 2) (y 4)])
                          (p (refl >s) (refl <s)))))
                 (cycles b e)))

   (late t p)  (\ b e (map (x \ evtime (u \ u + t) x) (p (b - t) (e - t))))
   (early t p) (late (qneg t) p)

   (pmap f p)  (\ b e (map (x \ [(x 0) (x 1) (x 2) (x 3) (f (x 4))]) (p b e)))
   (pkeep f p) (\ b e (filter f (p b e)))
   (onsets p)  (pkeep onset? p)

   ; structure from the left, value from the right: each of a's parts is cut by
   ; whatever b holds under it. `#`, `jux` and `seg` are all this one shape.
   (appl f pa pb)
    (\ b e (cmap (\ x (cmap (\ y (: pb2 (qmax (x 2) (y 2))  pe2 (qmin (x 3) (y 3))
                                  (pb2 < pe2 ? [[(x 0) (x 1) pb2 pe2 (f (x 4) (y 4))]])))
                            (pb (x 2) (x 3))))
                 (pa b e)))

   ; --- control values: a tablet of named parameters -------------------------
   (tcopy t)   (foldl (\ n k (pin n k (t k))) {} (keys t))
   (tset t k v) (tcopy t @ n (pin n k v, n))
   (tmerge a b) (foldl (\ n k (pin n k (b k))) (tcopy a) (keys b))
   ; a bare atom is lifted the first time a control word touches it, and left alone
   ; after: so `hit "bd:2"` keeps the sample index the mini-notation already set.
   (named k p) (pmap (v \ tablet? v ? v (tset {} k v)) p)
   (ctl k v p) (pmap (x \ tset (? (tablet? x) x {}) k v) p)
   (with k f p) (pmap (x \ tset x k (f (x k))) p)
   (pset pa pb) (appl tmerge pa pb)
   hit    (named 's)
   note   (named 'note)
   n      (named 'n)
   gain   (named 'gain)
   pan    (named 'pan)
   speed  (named 'speed)
   cut    (named 'cut)
   room   (named 'room)
   legato (named 'legato)

   ; --- cycle-indexed transforms ---------------------------------------------
   (whenc f g p) (\ b e (cmap (\ s (: c (qfl <s)  q (f c ? (g p) p) (q <s >s)))
                              (cycles b e)))
   (every n g p) (n < 1 ? p (whenc (c \ 0 = imod c n) g p))
   (off t g p)   (stack [p (g (late t p))])
   ; the signature move: the dry pattern hard left, f's copy hard right
   (jux g p)     (stack [(ctl 'pan 0.0 p) (ctl 'pan 1.0 (g p))])
   (iter n p)    (n < 1 ? p (slowcat (map (i \ early (i /// n) p) ^n)))
   (palin p)     (slowcat [p (rev p)])
   ; n equal slices per cycle, each holding whatever p had under it
   (seg n p)     (appl (\ a b b) (fast n (pure 0)) p)
   (super g p)   (stack [p (g p)])
   (whenmod a b g p) (a < 1 ? p (whenc (c \ imod c a >= b) g p))
   ; each event struck n times inside its own span, which is the one repeat that
   ; keeps the sequence's shape: a step that was a quarter cycle stays a quarter
   (ply n p) (? (n < 2) p
                (\ b e (cmap (\ x (: d ((evwe x - evwb x) / qi n)
                                     (mk i) (? (i >= n) ()
                                               (: sb (evwb x + qi i * d)
                                                  se (sb + d)
                                                  pb (qmax sb (evpb x))
                                                  pe (qmin se (evpe x))
                                                  (? (pb < pe)
                                                     ([sb se pb pe (evv x)] . (mk (i + 1)))
                                                     (mk (i + 1)))))
                                     (mk 0)))
                             (p b e))))

   ; --- continuous patterns: a value everywhere, no structure of their own ----
   ; sampled at the middle of whatever span is asked for, so they take their
   ; structure from whatever they are combined with (`# speed (range 1 2 sine)`).
   (sig f)       (\ b e (b < e ? [[b e b e (f (qnum ((b + e) * qhalf)))]]))
   (frac x)      (int x @ t (x - (x < 0.0 ? (t - 1) t)))
   sine          (sig (t \ 0.5 + 0.5 * sin (t * 6.283185307179586)))
   cosine        (sig (t \ 0.5 + 0.5 * cos (t * 6.283185307179586)))
   saw           (sig frac)
   isaw          (sig (t \ 1.0 - frac t))
   tri           (sig (t \ frac t @ u (u < 0.5 ? (u * 2.0) (2.0 - u * 2.0))))
   square        (sig (t \ frac t < 0.5 ? 0.0 1.0))
   rand          (\ b e (b < e ? [[b e b e (rnd ((b + e) * qhalf))]]))
   (range lo hi p) (pmap (v \ lo + (v * (hi - lo))) p)

   ; --- chance ---------------------------------------------------------------
   ; keyed off the event's own whole-begin, so a pattern degrades the same way on
   ; every pass -- a cycle is a place, not a moment, and re-querying it must agree.
   ; murmur3's finalizer over the (numerator, denominator, seed) triple
   (mix32 x) (: a (x & 4294967295)
                b (((a ^ (a >> 16)) * 2246822507) & 4294967295)
                c (((b ^ (b >> 13)) * 3266489909) & 4294967295)
                (c ^ (c >> 16)))
   ; the seed k separates two `?`s that would otherwise see the same span: a step's
   ; own pattern is degraded BEFORE it is squeezed into its slot, so every `?` in a
   ; sequence asks about cycle-begin and would answer alike. mini passes the cursor.
   (rndk k t) (load t @ p (mix32 (<p * 2654435761 + <>p * 2246822519 + k * 668265263)
                           / 4294967296.0))
   (rnd t) (rndk 0 t)
   (degbyk k amt p) (pkeep (x \ amt <= rndk k <x) p)
   (undegk k amt p) (pkeep (x \ amt > rndk k <x) p)
   (degby amt p) (degbyk 0 amt p)
   (undeg amt p) (undegk 0 amt p)
   (sometimesby amt g p) (stack [(degby amt p) (g (undeg amt p))])
   (sometimes g p) (sometimesby 0.5 g p)
   (degrade p)     (degby 0.5 p)

   ; --- euclidean rhythm -----------------------------------------------------
   ; bjorklund's own loop: k groups of [1] and n-k of [0], the shorter list folded
   ; onto the longer until at most one remainder group is left.
   (bjork k n)
    (? (n <= 0 || k <= 0) (rept 0 (n < 0 ? 0 n))
       (k >= n) (rept 1 n)
       (: (go a b) (: la #a  lb #b
                    (lb < 2 ? (foldl (+) () (a + b))
                     (: m  (? (la < lb) la lb)
                        na (map (i \ a i + b i) ^m)
                        nb (la > m ? (drop m a) (drop m b))
                      (go na nb))))
          (go (rept [1] k) (rept [0] (n - k)))))
   (rotl r l) (: n #l (n @ 0 l (map (i \ l (imod (i + r) n)) ^n)))
   (euclidr k n r p)
    (: on (k >= 0)
       bs (rotl r (bjork (abs k) n))
       (n <= 0 ? hush (fastcat (map (b \ b = on ? p hush) bs))))
   (euclid k n p) (euclidr k n 0 p)

   ; --- mini-notation --------------------------------------------------------
   ; "bd*2 [sn cp]@3 <hh oh> bd(3,8,2) ~ sn? cp!2 bd:3"
   ;   juxtaposition  steps across one cycle       *n  n times as fast
   ;   [ ]  a subsequence in one step              /n  n times as slow
   ;   < >  one member per cycle                   @n  this step takes n slots
   ;   ,    stack (inside brackets or at the top)  !n  this step, n times over
   ;   ~    a rest        _  extend the last step  ?   drop it half the time
   ;   (k,n[,r])  euclidean                        :n  a sample index
   ; euclid spreads k onsets as evenly over n slots as they go (bjork, below) and
   ; rotates by r: bd(3,8) |x..x..x.|, bd(5,8) |x.xx.xx.|, bd(3,8,2) |.x..x.x.| --
   ; the same three heard from the third slot. a negative k takes the slots the
   ; figure leaves: bd(-3,8) |.xx.xx.x|. k n r are words here, so they are literals.
   ; the cursor is explicit: every reader takes (s i) and answers (x . i).
   (mspace s i) (: n #s (i < n && 32 >= s i ? (mspace s (i + 1)) i))
   (mwordc? c)  (c >= 48 && c <= 57 || c >= 65 && c <= 90
                 || c >= 97 && c <= 122 || c = 46 || c = 45 || c = 39)
   (mat s i)    (i < #s ? (s i) 0)
   (madv s i c) (c = mat s i ? (i + 1) i)
   (mword s i)  (: (go j) (mwordc? (mat s j) ? (go (j + 1)) j)
                   e (go i)
                   (snip s i e . e))
   ; a decimal word as an exact rational: the digits after the point are the denominator
   (mrat w) (: n #w
               neg !!(n > 0 && 45 = w 0)
               (go j ip fd seen)
                (j >= n ? ((? neg (0 - ip) ip) /// fd)
                 (w j @ 46 (go (j + 1) ip fd 1)
                        c  (go (j + 1) (ip * 10 + c - 48) (? seen (fd * 10) fd) seen)))
               (go neg 0 1 0))
   (mnum? w) (: n #w
                (go j) (? (j >= n) 1
                          (: c (w j)
                             (? (c >= 48 && c <= 57 || c = 46 || c = 45)
                                (go (j + 1)) 0)))
                (n @ 0 0 (go 0)))
   ; a numeric word is a number, anything else the word itself
   ; a whole number comes out as an integer, not as a rational: the value is the
   ; caller's (a note, a sample index), and only the TIMES want the coin
   (matom w) (? (mnum? w) (load (mrat w) @ p (<>p @ 1 <p (<p / <>p))) w)
   (mratat s i) (mword s (mspace s i) @ r (mrat <r . >r))
   (mintat s i) (mratat s i @ r (qfl <r . >r))

   ; a term: a bracket, a rest, an elongation mark, or a word
   (mterm s i)
    (: j (mspace s i)  c (mat s j)
     (c @ 91  (: r (mseq s (j + 1) 93 0) (<r . (madv s >r 93)))
          60  (: r (mseq s (j + 1) 62 1) (<r . (madv s >r 62)))
          126 (hush . (j + 1))
          95  ('elong . (j + 1))
          (mword s j @ r
           ; an unreadable byte is one step of silence, and the cursor still moves
           (#<r @ 0 (hush . j + 1) (pure (matom <r) . >r)))))

   ; a term and its modifier tail -> the steps it contributes, as [(w . p) ..]
   (mstep s i)
    (: t (mterm s i)
       (go p j w reps) (mat s j @
        42 (mratat s (j + 1) @ r (go (fast <r p) >r w reps))
        47 (mratat s (j + 1) @ r (go (slow <r p) >r w reps))
        64 (mratat s (j + 1) @ r (go p >r <r reps))
        33 (mintat s (j + 1) @ r (go p >r w <r))
        63 (j + 1 @ k (mwordc? (mat s k) ?
                       (mratat s k @ r (go (degbyk j (qnum <r) p) >r w reps))
                       (go (degbyk j 0.5 p) k w reps)))
        58 (mword s (j + 1) @ r (go (pmap (v \ tset (tset (tablet 0) 's v) 'n (matom <r)) p)
                                    >r w reps))
       40 (meuc s (j + 1) p @ r (go <r >r w reps))
       (rept (w . p) reps . j))
       (<t @ 'elong ([(qone . 'elong)] . >t) (go <t >t qone 1)))
   (meuc s i p)
    (: a (mintat s i)          j (madv s (mspace s >a) 44)
       b (mintat s j)          k (mspace s >b)
       (? (44 = (mat s k))
          (: c (mintat s (k + 1)) (euclidr <a <b <c p . madv s (mspace s >c) 41))
          (euclidr <a <b 0 p . madv s k 41)))

   ; `_` after a step widens that step rather than adding one
   (mfold l) (:- (go l ()) (go l out)
              (l @- (lrev out)
               ((x . 'elong) . u) 
                (out @- (go u out) (h . i) (go u ((<h + x . >h) . i)))
               (x . u) (go u (x . out))))
   ; the steps up to a close brace or a comma
   (msteps s i cl)
    (: j (mspace s i)  c (mat s j)
     (j >= #s || c = cl || c = 44 ? (() . j)
      (: r (mstep s j)  t (msteps s >r cl) (<r + <t . >t))))
   ; comma groups, then each group laid out: alt=0 lays them across the cycle
   ; (a weighted timecat), alt=1 gives each member a cycle of its own
   (mseq s i cl alt)
    (: (grp i) (: r (msteps s i cl)
                  (? (44 = (mat s >r))
                     (: t (grp (>r + 1)) ((cat [(mfold <r)] <t) . >t))
                     ([(mfold <r)] . >r)))
       g  (grp i)
       ps (map (\ st (? !(two? st) hush
                        (? alt (slowcat (map (\ x >x) st)) (timecat st))))
               <g)
       ((? (1 = #ps) (ps 0) (stack ps)) . >g))
   (mini s) (<(mseq s 0 0 0))))
