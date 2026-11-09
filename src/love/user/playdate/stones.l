; src/love/user/playdate/stones.l -- lore's stones on the playdate. main.c fires (pd-frame ())
; each update: the d-pad walks and turns, the crank looks up and down, A or B kneels and
; chooses. nifs from main.c: (held ()) the buttons down and (pushed ()) the ones fresh this
; frame (left 1 right 2 up 4 down 8 B 16 A 32), (crank ()) its angle or () docked, (lcd f w h)
; a frame of 0xrrggbb pixels dithered onto the screen stretched over it, (cur_set r c) for
; the text laid over it. the picture's pixel is pd-scales' step of the screen's, moved by
; the frame's time (view-gauge).
(borrow 'stones)
(borrow 'view)                          ; clamp, the gauge
(borrow 'walk)                          ; the frame's time
(borrow 'rove)
(borrow 'horn)                          ; the song's rate, its lead and the pacer
(: ; a picture's pixel in the screen's, finest first, the one it wakes at, and a frame's goal
   pd-scales [2 3 4 5 6 8 10] pd-start 2 pd-goal 80.0
   (pd-dims s) [(400 // s) (240 // s)]
   pd-pix (map (s \ pd-dims s @ [w h] (w * h)) pd-scales)
   pd-w (pd-dims (pd-scales pd-start) 0) pd-h (pd-dims (pd-scales pd-start) 1)
   crank-k (pi / 360.0)                 ; a degree of crank looks half a degree
   ; the land built at the least detail and lit at bake, the sun held at noon so it stays built
   pd-detail 0
   pd-at (: st (pins (stones-detail (stones-new pd-w pd-h [(1.0 * 1790812800 + 12.0 * 3600.0) 3600] 7) pd-detail) 'keep-sky 1 'sky-k 3)
            _ (stones-pens st)
            {'st st 'crank () 'song () 'pace () 'full 0 'l0 0
             'gauge (view-gauge pd-pix pd-start pd-goal) 'i pd-start})
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
   ; ..and answers whether it is running low: once full, the lag before the fill under half
   ; the lead and below the last frame's
   (song! _) (: sng (pd-at 'song)
     (? sng (: h (sng 'h) l0 (horn-lag h) ld (song-lead-of (pace! (pd-at 'pace)))
              _ (song-fill h ld (_ \ (cite 'apartment 'apartment-song-feed) sng))
              lw (pd-at 'full && l0 * 2 < ld && l0 < pd-at 'l0)
              (pins pd-at 'l0 l0 'full (pd-at 'full || ld <= horn-lag h), lw))
        (pd-at 'pace) 0
        (: hn (horn song-rate 2 @ q (nom? q ? () q))
           _ (pins pd-at 'pace (pin (pacer ()) 'gap pd-gap) 'song (hn ? ((cite 'apartment 'apartment-song-new) hn (wheel (clock 0)))))
           (song! ()))))
   ; ..sized again for step i: the kept sky is the old size's
   (pd-size st i) (: d (pd-dims (pd-scales i))
     (pin pd-at 'i i, stones-size (pins st 'sky-kept () 'sky-memo ()) (d 0) (d 1 // 2)))
   (pd-frame _) (: t0 (clock 0) lw (song! ()) t1 (clock 0) st (pd-at 'st) h (held ()) p (pushed ()) dlg (charm? (st 'dlg)) sim (st 'sim)
     dc (turned (crank ()))
     go (? dlg (bits p dlg-acts) (cat (bits h walk-acts) (p & 48 ? ['kneel] ())))
     _ (walk-dt st)
     _ (each go (a \ stones-step st a))
     _ (st 'eye = 'walk && !dlg && dc != 0 ? (pin st 'ph (clamp (st 'ph + crank-k * dc) -1.2 1.45)))
     _ (stones-move st)
     _ (pin st 'sim sim)
     d (pd-dims (pd-scales (pd-at 'i)))
     _ (lcd (stones-pens st) (d 0) (d 1))
     j (view-gauged (pd-at 'gauge) (clock 0 - t1) (t1 - t0) lw (clock 0))
     _ (j != pd-at 'i ? (pd-size st j))
     (? (charm? (st 'dlg)) (each ^#acts (i \ (cur_set (10 + i) 17, puts ((i = st 'dlg ? " > " "   ") + acts i + "  "))))
        (st 'done) (cur_set 14 17, puts " out on the plain ")
        (st 'mt < 12.0) (cur_set 29 5, puts " d-pad walks  crank looks  A kneels "))))
