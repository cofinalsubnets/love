; seams -- where a level built shows the level's plain texture through an opening: a window's
; or a doorway's face with no skin of its own for the way it faces, out of any pit's dark.
; read off the scene a state made, nothing changed; run by hand after an edit,
; `love src/apps/lore/seams.l LEVEL.l`
;   (seams st)       each brush with such faces, in the level's order: {'brush 'src 'lo 'hi 'n
;                    'classes}, src the form that made it or 'doorway, n its faces, classes
;                    the ways they face
;   (seams-say f)    a finding as a line
(module (seams seams seams-say seams-main)
(borrow '(brush world))
(:
 (class n) (? (0.7 < n 1) 'floor (n 1 < -0.7) 'ceiling 'wall)
 (inside p b) (all (k \ b 0 k <= p k && p k <= b 1 k) ^3)
 (mid ps) (map (k \ foldl (\ a p (a + p k)) 0.0 ps / #ps) ^3)
 (seams st) (: sc (st 'sc) lv (st 'lvl) bs (sc 'brushes) srcs (lv 'brushes) pits (peep lv 'pits ())
   (opening? i) (i >= #srcs || peep (bs i) 'opening 0 = 1)
   (bare? f) (: c (class (f 1)) (opening? (f 2) && !(any (e \ e 0 = c) (peep (bs (f 2)) 'skin ())) && !(any (inside (mid (f 0))) pits)))
   t (foldl (\ t f (: i (f 2) (pin t i (class (f 1) . peep t i ())))) {} (filter bare? (brush-faces bs)))
   (map (i \ (: b (bs i) cs (t i)
               {'brush i 'src (i < #srcs ? (peep (srcs i) 'src ()) 'doorway) 'lo (b 'lo) 'hi (b 'hi) 'n #cs
                'classes (filter (c \ elem c cs) ['floor 'wall 'ceiling])}))
        (sort (keys t))))
 (r2 x) (floor (x * 100.0 + 0.5) / 100.0)
 (seams-say f) "brush \(show (f 'brush)) \(show (map r2 (f 'lo))) to \(show (map r2 (f 'hi))): \(show (f 'n)) bare \(show (f 'classes)), \(show (f 'src))"
 seams-usage "usage: love src/apps/lore/seams.l LEVEL.l   (each opening showing the level's plain texture; 1 when any)"
 (dir-of p) (: i (foldl (\ a j (p j = 47 ? j a)) -1 ^#p) (i < 0 ? "./" (snip p 0 (i + 1))))
 (seams-main as) (? (#as != 1) (: _ (say err (seams-usage + "\n")) 2)
   (: lv (world-load <as)
      (? (string? lv) (: _ (say err (lv + "\n")) 2)
         (: fs (seams (world-new 64 40 lv (dir-of <as))) _ (each fs (f \ puts (seams-say f + "\n")))
            (flush out, #fs = 0 ? 0 1)))))
 _ (: s (cite 'verbs 'fire ["seams" "seams.l"]) (two? s ? (quit (seams-main >s)) ())))
) ; module seams
