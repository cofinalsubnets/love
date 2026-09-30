; src/apps/harp/wander.l -- phrases in just intervals over a center that drifts
; (src/apps/harp/drift.l), rendered to a .wav, with the walk printed as it went.
;
;   love src/apps/harp/wander.l [LEAN [HOME [CYCLES [OUT.wav]]]]
;
; LEAN is signed: 1 follows the phrases up the lattice, -1 leans away, 0 moves only
; on what the kernel carries. HOME pulls the center back against the drift.
(borrow ((cite 'harp) @ m (m ? m "src/apps/harp/harp.l")))
(borrow "src/apps/harp/play.l")
(borrow "src/apps/harp/just.l")
(borrow "src/apps/harp/drift.l")
(:
   ; a major arpeggio, a minor one, then a triad under a ninth and a harmonic seventh
   phrases [[1 (5 /// 4) (3 /// 2) (15 /// 8)]
            [1 (6 /// 5) (3 /// 2) (9 /// 5)]
            [[(1 /// 2) (5 /// 8) (3 /// 4)] (9 /// 8) (7 /// 4)]]
   (num s d) (string? s ? (read s @ v (charm? v ? v d)) d)

   (wander-main as)
    (: lean (num (as 0) 1.0) home (num (as 1) 0.1) n (num (as 2) 16)
       path (string? (as 3) ? (as 3) "out/harp-wander.wav")
       o    {'lean (1.0 * lean) 'home (1.0 * home)}
       _    (each (drift-walk o phrases n)
                  (st \ (say out $ (show (st 'pos) + "  " + show (st 'tonic)
                                    + "  " + show (int (drift-cents st)) + "c\n"))))
       song (pset (drift-song o phrases n) (hit (pure "tri")))
       (harp-wav song 0 n 48000 0.5 24000 11000.0 path,
        say out $ path + "\n", 0)))

(: s (cite 'verbs 'fire ["harp-wander" "wander.l"])
   (two? s ? (quit (wander-main >s))))
