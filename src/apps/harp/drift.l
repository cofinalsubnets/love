; src/apps/harp/drift.l -- a tonal center that walks the just lattice, steered by the
; phrases played over it, with the error diffused forward as floyd-steinberg does.
;
; every phrase is just intervals over the current center, so it is pure inside. after
; it plays, its TENSION -- where its notes sit in the lattice, each weighted by its
; distance from home -- says which way the center wants to go. the center can only
; land on lattice points (a fifth, a third, a seventh away, or stay), so what it wanted
; and where it went differ; that error is spread over the next few steps by a kernel,
; and the walk is right on average though no step is. two knobs set its character:
;   'lean   signed. above 0 the center follows the notes (the piece travels), below 0
;           it leans away from them, and 0 moves only on the carried error
;   'home   a pull back toward where the walk began, against the comma drift
; and 'cost prices a move by its own distance, so small moves win a close call.

(module '(drift dmoves dkernel dopts dopt minby dflat tension ptones drift-new drift-step
          drift-walk drift-cents drift-pick drift-compose tune phrase-pat drift-song compose-song)
(borrow ((cite 'just) @ m (m ? m "src/apps/harp/just.l")))
(borrow ((cite 'harp) @ m (m ? m "src/apps/harp/harp.l")))
(:
   dzero [0.0 0.0 0.0]
   ; the steps a center may take, as points: stay, the fifths, the major thirds, the
   ; minor thirds (6/5 and its inverse), the harmonic sevenths
   dmoves [[0 0 0] [1 0 0] [-1 0 0] [0 1 0] [0 -1 0] [1 -1 0] [-1 1 0] [0 0 1] [0 0 -1]]
   ; floyd-steinberg's weights, laid along time: 7 3 5 1 sixteenths, nearest first
   dkernel [0.4375 0.3125 0.1875 0.0625]
   ; 'wc 'steer 'fresh are the chooser's: see drift-compose
   dopts {'lean 1.0 'home 0.0 'cost 0.25 'kernel dkernel 'moves dmoves
          'wc 1.0 'steer 1.0 'fresh 2.0}
   (dopt o k) (peep o k (dopts k))
   (minby f l) (foldl (a \ x \ (f x < f a ? x a)) <l >l)

   ; where a phrase's weight lies, relative to its center: the mean of its points,
   ; each weighted by how far out it is. a chord is a list inside the phrase
   ; a phrase's notes in one list, its chords opened
   (dflat l) (? !(two? l) () (coin? <l || !(two? <l)) (<l . dflat >l) (dflat <l + dflat >l))
   (tension rs)
    (: wv (filter (x \ x 1 != 'over) (map (r \ [(lnorm (point r)) (point r)]) (dflat rs)))
       tw (foldl (+) 0.0 (map (x \ x 0) wv))
       (tw = 0.0 ? dzero
          (vscale (1.0 / tw) (foldl vadd dzero (map (x \ vscale (x 0) (x 1)) wv)))))

   ; a walk's state: where the center is, its pitch, and the error still owed to the
   ; steps ahead, one vector per kernel weight
   (drift-new o) {'pos [0 0 0] 'tonic 1 'queue (map (_ \ dzero) (dopt o 'kernel))
                  'move [0 0 0] 'want dzero 'tension dzero}

   ; one phrase played over st: the next state
   (drift-step o st rs)
    (: t    (tension rs)
       q    (st 'queue)
       want (vsub (vadd (vscale (dopt o 'lean) t) <q) (vscale (dopt o 'home) (st 'pos)))
       (score m) (vsub want m @ d (vdot d d + dopt o 'cost * lnorm m))
       m    (minby score (dopt o 'moves))
       err  (vsub want m)
       q2   (map (p \ vadd <p (vscale >p err)) (zip (>q + [dzero]) (dopt o 'kernel)))
       pos  (vadd (st 'pos) m)
       {'pos pos 'tonic (near (unpoint pos)) 'queue q2 'move m 'want want 'tension t})

   ; n phrases, taken round from ps: the state each one plays under
   (drift-walk o ps n)
    (: (go st i) (i >= n ? () (st . go (drift-step o st (ps (i % #ps))) (i + 1)))
       (go (drift-new o) 0))
   (drift-cents st) (cents (st 'tonic))
   ; a phrase's notes as absolute lattice points, over a center at pos
   (ptones pos rs) (map (r \ vadd pos (point r)) (dflat rs))

   ; the walk choosing its own phrases from a vocabulary: each step scores every
   ; phrase over the new center and plays the best --
   ;   'wc     per note it shares with the phrase before, as absolute points: what
   ;           makes a move of the center sound connected
   ;   'steer  signed: how far to favour a phrase pulling along what the walk still
   ;           owes (above 0, momentum) or against it (below 0, the walk turns)
   ;   'fresh  what repeating the last phrase costs
   ; answers [state phrase] per step
   ; one choice: the phrase to play over st's center after prev, [phrase its-points]
   ; or [() ()] at the start; answers the same pair for the phrase chosen
   (drift-pick o st prev vocab)
    (: owed (vsub <(st 'queue) (vscale (dopt o 'home) (st 'pos)))
       (score ph) (dopt o 'wc * #(filter (p \ elem p (prev 1)) (ptones (st 'pos) ph))
                   + dopt o 'steer * vdot (tension ph) owed
                   - (ph = prev 0 ? (dopt o 'fresh) 0.0))
       best (minby (ph \ 0.0 - score ph) vocab)
       [best (ptones (st 'pos) best)])
   (drift-compose o vocab n)
    (: (go st prev i) (i >= n ? ()
                         (drift-pick o st prev vocab @ pk
                            ([st (pk 0)] . go (drift-step o st (pk 0)) pk (i + 1))))
       (go (drift-new o) [() ()] 0))

   ; --- into harp ------------------------------------------------------------------
   ; ratios over a center become 'note, semitones from middle c; a tablet keeps its
   ; other keys and gives its 'ji
   (tune t p)
    (pmap (v \ (: r (tablet? v ? (v 'ji) v) s (semis (t * r))
                  (tablet? v ? (pin (foldl (n \ k \ pin n k (v k)) {} (keys v)) 'note s)
                     {'note s})))
          p)
   ; a phrase as one cycle: its members in turn, a list among them sounding together
   (phrase-pat t rs)
    (: (one r) (note (pure (semis (t * r))))
       (fastcat (map (r \ (coin? r || !(two? r)) ? (one r) (stack (map one r))) rs)))
   ; n cycles, a phrase each, every one over the center the walk gave it
   (drift-song o ps n)
    (drift-walk o ps n @ w
       (slowcat (map (i \ phrase-pat (w i 'tonic) (ps (i % #ps))) ^n)))
   (compose-song o vocab n)
    (slowcat (map (x \ phrase-pat (x 0 'tonic) (x 1)) (drift-compose o vocab n))))
) ; module drift
