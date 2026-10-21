; src/love/user/playdate/stones.l -- lore's stones on the playdate. main.c fires (pd-frame ())
; each update: the d-pad walks and turns, the crank looks up and down, A or B kneels and
; chooses. nifs from main.c: (held ()) the buttons down and (pushed ()) the ones fresh this
; frame (left 1 right 2 up 4 down 8 B 16 A 32), (crank ()) its angle or () docked, (lcd f w h)
; a frame of 0xrrggbb pixels dithered onto the screen at twice its size, (cur_set r c) for
; the text laid over it.
(borrow 'stones)
(borrow 'view)                          ; clamp
(borrow 'walk)                          ; the frame's time
(borrow 'rove)                          ; the song's rate, its lead and the pacer
(: pd-w 100 pd-h 60
   crank-k (pi / 360.0)                 ; a degree of crank looks half a degree
   ; the land built at the least detail and lit at bake, the sun held at noon so it stays built
   pd-detail 0
   pd-at (: st (pins (stones-detail (stones-new pd-w pd-h [(1.0 * 1790812800 + 12.0 * 3600.0) 3600] 7) pd-detail) 'keep-sky 1 'sky-k 3)
            _ (stones-pens st)
            {'st st 'crank () 'song () 'pace ()})
   walk-acts [[1 'turn-left] [2 'turn-right] [4 'forward] [8 'back]]
   dlg-acts [[4 'forward] [8 'back] [48 'choose]]
   (bits m ks) (map (k \ k 1) (filter (k \ m & k 0) ks))
   ; the crank's turn since the last frame, in degrees either way
   (turned c) (: c0 (pd-at 'crank) _ (pin pd-at 'crank c)
     (charm? c && charm? c0 ? ((c - c0 + 540) % 360 - 180) 0))
   ; the song opens on the first frame, never at bake, and is fed up to its lead before each
   ; paint: the lead outlasts the paint, and the ring outlasts the lead. the pacer starts at a
   ; paint's guess, so the first fill outlasts the first paint
   pd-gap 1500.0
   (song! _) (: sng (pd-at 'song)
     (? sng (: T0 (clock 0) l0 (horn-lag (sng 'h)) gp (pace! (pd-at 'pace)) ld (song-lead-of gp)
               k (song-fill (sng 'h) ld (_ \ (cite 'apartment 'apartment-song-feed) sng))
               n (peep pd-at 'n 0) _ (pin pd-at 'n (n + 1))
               G (gauge 0)
               (n < 60 ? (trail ("song gap " + show (int gp) + " lead " + show ld + " lag " + show l0 + " -> " + show (horn-lag (sng 'h)) + " feeds " + show k + " ms " + show (clock 0 - T0)
                                 + " pool " + show (G 0) + " heap " + show (G 1) + " peak " + show (G 5) + " old " + show (G 8) + " major " + show (G 12)))))
        (pd-at 'pace) ()
        (: hn (horn song-rate 2 @ q (nom? q ? () q))
           _ (hn ? (: A (cite 'apartment) P (cite 'play) dv ((A 'drone-voice) ()) n 735 ix (iota n)
                      (ms f) (: t0 (clock 0) _ (each ^10 f) (clock 0 - t0))
                      y (dv 1 ix)
                      a (ms (_ \ dv 1 ix)) b (ms (_ \ (P 'mixdown) [dv] 0 n)) c (ms (_ \ (P 'pack) [y y] n 5200.0))
                      pk ((P 'pack) [y y] n 5200.0)
                      d (ms (_ \ say hn pk)) e (ms (_ \ y * 1.5)) Y (iota 7350 * 1.0) e2 (ms (_ \ Y * 1.5)) e3 (ms (_ \ 1.5 * 2.5)) f (ms (_ \ sin y)) h (ms (_ \ floor y))
                      (trail ("ten: drone " + show a + " mix " + show b + " say " + show d + " mul " + show e + " mul10x " + show e2 + " scalar " + show e3 + " sin " + show f + " floor " + show h + " pinv " + show (cite 'guts 'pinv) + " tones " + show (cite 'dsp 'tones)))))
           _ (pins pd-at 'pace (pin (pacer ()) 'gap pd-gap) 'song (hn ? ((cite 'apartment 'apartment-song-new) hn (wheel (clock 0)))))
           (song! ()))))
   (pd-frame _) (: _ (song! ()) st (pd-at 'st) h (held ()) p (pushed ()) dlg (charm? (st 'dlg)) sim (st 'sim)
     dc (turned (crank ()))
     go (? dlg (bits p dlg-acts) (cat (bits h walk-acts) (p & 48 ? ['kneel] ())))
     _ (walk-dt st)
     _ (each go (a \ stones-step st a))
     _ (st 'eye = 'walk && !dlg && dc != 0 ? (pin st 'ph (clamp (st 'ph + crank-k * dc) -1.2 1.45)))
     _ (stones-move st)
     _ (pin st 'sim sim)
     _ (lcd (stones-pens st) pd-w pd-h)
     (? (charm? (st 'dlg)) (each ^#acts (i \ (cur_set (10 + i) 17, puts ((i = st 'dlg ? " > " "   ") + acts i + "  "))))
        (st 'done) (cur_set 14 17, puts " out on the plain ")
        (st 'mt < 12.0) (cur_set 29 5, puts " d-pad walks  crank looks  A kneels "))))
