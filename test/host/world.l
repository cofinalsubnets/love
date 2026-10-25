; test/host/world.l -- a world level and its file, headless: reading, drawing, light,
; doors, walls, reload on change, the car, the sign, the shots.
; not in the corpus: a crew module. run: cat test/00-init.l test/host/world.l | out/love

(borrow 'world)
(borrow 'mesh)
(borrow 'neon)
(borrow 'posix)
(borrow 'view)     ; pi
(borrow 'brush)
(borrow 'vec)      ; mag
(: world-kb (view-bind view-binds world-binds))   ; a key's code -> its action

(: (rows s) (: (go i k) (i + 2 <= #s ? (go (i + 1) (k + ("\r\n" = snip s i (i + 2)))) k) (1 + go 0 0))
   hall (world-load "test/lore/hall.l")
   (at w h) (world-new w h hall "test/lore/")
   (px f st x y) (peep f (y * st 'w + x) 0)
   (lum c) ((c >> 16 & 255) + (c >> 8 & 255) + (c & 255))
   (steps st k n) (each ^n (_ \ (world-step st (world-kb k), world-move st)), st)
   (lv s) (world-read ("(level \"t\" " + s + ")"))
   (put p s) (: q (open p "w") (say q s, close q)))

; the hall: the door between its rooms found in their shared wall
(test (tablet? hall) (hall 'name = "the test hall") (#(hall 'rooms) = 2) (#(hall 'strips) = 4)
      (hall 'doors 0 'ax = 'z) (hall 'doors 0 'a = 12.4) (hall 'doors 0 'b = 12.6)
      (hall 'start 'at = [0.0 1.0]) (#(hall 'posters) = 1) (hall 'signs 0 'text = "LOUNGE"))
; levels that will not read say why, and what a word takes
(test (has? (world-read "(room 0 0 1 1 2)") "(room [x y z] [x y z])") (string? (lv "")) (has? (lv "") "needs a room")
      (has? (lv "(room [0 0] [1 1 2])") "(room [x y z] [x y z])")
      (has? (lv "(room [0 0 0] [1 2 1]) (lamp [0 0 0])") "lamp")
      (has? (lv "(room [0 0 0] [1 2 1]) (bulb [0 1 0] 1)") "(rgb r g b)")
      (has? (lv "(room [0 0 0] [1 2 1]) (solid (box [0 1 0] [1 1 1]))") "no inside")
      (has? (lv "(room [0 0 0] [2 2 2]) (door [5 0 5] 1 2)") "between two rooms")
      (tablet? (lv "(room [0 0 0] [2 2 2]) (room [0 0 2.2] [2 2 4]) (door [1 0 2.1] 1 2)"))
      (lv "(room [0 0 0] [2 2 2]) (room [2.2 0 0] [4 2 2]) (door [2.1 0 1] 1 2)" 'doors 0 'ax = 'x)
      (has? (lv "(room [0 0 0] [2 2 2]) (box [0 0 0] [1 1 1])") "not a part")
      (has? (world-read "(level \"t\" (room [0 0 0] [2 2 2])") "not finished")
      (has? (world-read "(room [0 0 0] [2 2 2])") "last form")
      (string? (world-load "/nonexistent/level.l")))
; textures: a brush's skin by face; a bad layer said back; a wall's texture stands on its brush's foot
(: tx "(: rust (texture 32 32 1 '((fill (rgb 0.4 0.2 0.1)) (noise 3 0.2)))) "
   (lt s) (world-read (tx + "(level \"t\" " + s + ")"))
   st (world-new 8 8 (lt "(skin {'walls rust} (room [0 1 0] [2 3.6 2]))") "")
   pk (st 'sc 'chunks 0 'pk) cs (pk 'cols) (c k i) (peep (cs k) i 0.0)
   wall (filter (i \ mag (c 6 i) < 0.1) ^(pk 'n))
   two (world-read (tx + "(: moss (texture 16 16 1 '((fill (rgb 0.2 0.4 0.1)))))
                         (level \"t\" (skin {'walls rust} (room [0 0 0] [2 2 2])) (skin {'floor moss 'walls rust} (room [0 0 2.2] [2 2 4])))"))
   ; ..a floor laid a quarter turn and shifted half a metre: u runs with z, v back along x
   lp (world-new 8 8 (lt "(skin {'floor (laid rust 90 [0 0.5])} (room [0 0 0] [2 2 2]))") "" 'sc 'chunks 0 'pk)
   (lc k i) (peep (lp 'cols k) i 0.0) flr (filter (i \ lc 6 i > 0.9) ^(lp 'n))
 (test (map (t \ t 'name) (hall 'textures) = ['wall 'floor 'ceiling 'door]) (hall 'textures 0 'm = 1.3)
       (#(at 8 8 'sc 'texs) = 5)
       (lt "(skin {'walls rust 'floor rust} (room [0 0 0] [2 2 2]))" 'brushes 0 'skin = [['wall 0] ['floor 0]])
       (lt "(room [0 0 0] [2 2 2]) (skin {'all rust} (solid (box [0 0 0] [1 2 1])))" 'brushes 1 'skin
        = [['wall 0] ['floor 0] ['ceiling 0]])
       (map (t \ t 'name) (two 'textures) = [0 1]) (two 'brushes 1 'skin = [['wall 0] ['floor 1]])
       ; ..each face drawn with the texture its skin names: moss on the second room's floor
       (: ts (world-new 8 8 two "" 'sc 'chunks 0 'pk 'tris) (aany (peep ts (iota (#ts // 4) * 4 + 3) -1 = 1)))
       (has? (lv "(skin {'walls (texture 32 32 1 '((fill 1) (stripes 4 2 (grey 0.5))))} (room [0 0 0] [2 2 2]))")
             "in a texture, (stripes 4 2 (grey 0.5)) -- it reads (stripes every w slant PAINT)")
       (has? (lv "(skin {'walls (texture 32 32 0 '((fill 1)))} (room [0 0 0] [2 2 2]))") "(texture width height metres LAYERS)")
       (has? (lv "(skin {'walls 3} (room [0 0 0] [2 2 2]))") "(skin {")
       (lt "(skin {'floor (laid rust 90 [0 0.5])} (room [0 0 0] [2 2 2]))" 'brushes 0 'skin = [['floor 0 [90.0 [0.0 0.5]]]])
       (lt "(textures {'floor (laid rust 45 [1 0])}) (room [0 0 0] [2 2 2])" 'textures 0 'lay = [45.0 [1.0 0.0]])
       (has? (lv "(skin {'floor (laid rust 'x [0 0])} (room [0 0 0] [2 2 2]))") "(laid TEXTURE degrees [du dv])")
       (two? flr) (all (i \ abs (lc 3 i - 32.0 * lc 2 i) < 1e-6 && abs (lc 4 i - (16.0 - 32.0 * lc 0 i)) < 1e-6) flr)
       ; the level's textures, then a grid each for floor ceiling door and wall it lacks
       (#(st 'sc 'texs) = 5) (two? wall)
       (all (i \ c 1 i > 1.01 || mag (c 4 i - 32.0) < 1e-6) wall) (any (i \ c 1 i < 1.01) wall)))
; the frame: half the pixel rows in cells, deterministic, 256 and 24-bit, kitty's pixels
(: st (at 80 48) f (world-frame st) f2 (world-frame st)
   deep (world-frame (pin (at 80 48) 'deep 1))
   kit (world-frame (world-size (pin (at 80 48) 'kitty 1) 80 24))
 (test (rows f = 24) (f = f2) (rows deep = 24) (f != deep)
       (has? f "38;5;") (has? deep "38;2;") (has? kit "_Ga=T") (has? kit "i=7,")))
; the light: a failing strip mostly on; the door's lamps red while shut, green once open
(: st (at 80 48) f (world-pens st) sc (st 'sc)
   up (world-pens (pins (at 80 48) 'ph 1.2 'pz 5.0))
   ks (map (t \ world-ks sc (t / 10.0) [0.0]) ^600)
   bad (map (k \ k 2) ks)
   open (world-ks sc 0.0 [1.0])
   east (world-pens (pins (at 80 48) 'th (pi / 2.0) 'pz 7.0 'px -0.6))
   (pink? c) ((c >> 16 & 255) > (c >> 8 & 255) + 40 && (c & 255) > (c >> 8 & 255))
   n #(sc 'lights)
 (test (n = 10) (40 < lum (px f st 40 44)) (700 < foldl max2 0 (map (i \ lum (peep up i 0)) ^(80 * 48)))
       (any (k \ k < 0.5) bad) (all (k \ 0.0 <= k <= 1.0) bad) (300 < #(filter (k \ k = 1.0) bad))
       (all (k \ k 0 = 1.0 && k (n - 4) = 1.0 && k (n - 3) = 0.0) ks)
       (open (n - 4) = 0.0) (open (n - 3) = 1.0)
       (any pink? (map (i \ peep east i 0) ^(80 * 48)))))
; the door opens as the player nears; the doorway stops a walk until open, walls always
(: far (at 80 48) _ (each ^20 (_ \ world-move far))
   near (pins (at 80 48) 'pz 10.5) _ (each ^5 (_ \ world-move near))
   opened (pins (at 80 48) 'pz 10.5) _ (each ^40 (_ \ world-move opened))
   shut (pins (at 80 48) 'pz 12.0)
   walk (pins (at 80 48) 'pz 11.0)
   _ (steps walk 107 80)
   wall (steps (pins (at 80 48) 'th (pi / 2.0)) 107 40)
   back (steps (at 80 48) 106 40)
 (test (far 'doors = [0.0]) (0.0 < near 'doors 0 < 1.0) (opened 'doors = [1.0])
       !(world-free? shut 0.0 12.5) (world-free? opened 0.0 12.5) !(world-free? opened 0.8 12.5)
       (13.5 < walk 'pz) (walk 'pz < 16.5)
       (wall 'px < 1.2) (0.85 < wall 'px) (body-r <= back 'pz)))
; a changed file rebuilds the scene, the player kept; a broken save keeps the last level and says why
(: p ("/tmp/worldtest-" + show (getpid 0) + ".l")
   _ (put p "(level \"a\" (room [0 0 0] [4 3 4]) (strip-light [2 3 2]))")
   st (world-watch (pins (world-new 40 24 (world-load p) "/tmp/") 'path p 'px 2.5 'pz 1.5))
   a (world-watch st 'lvl 'name)
   _ (put p "(level \"b\" (room [0 0 0] [4 3 4]) (strip-light [1 3 1]) (strip-light [3 3 3]))")
   b (world-watch st) got (b 'lvl 'name) nl #(b 'sc 'lights) where [(b 'px) (b 'pz)] said (b 'msg) e0 (b 'err)
   _ (put p "(level \"c\" (room [0 0")
   c (world-watch b)
   _ (unlink p)
 (test (a = "a") (got = "b") (nl = 2) (where = [2.5 1.5]) (has? said "again") (e0 = 0)
       (c 'lvl 'name = "b") (c 'err = 1) (string? (c 'msg)) (has? (world-frame c) "not finished")))
; repeat and mirror: twenty pilasters of two brushes each; a pilaster stops a walk, under a
; buttress's slope is air; the start's height and pitch; p shows where the player stands
(: ribs (lv """(room [-5 0 0] [5 5 32])
               (mirror-x 0 (repeat 10 [0 0 3.2] [(solid (box [-5 0 1.3] [-4.7 5 1.9]))
                                                 (cut [-4.7 3.2 0] [-4.1 5 0] [-4.1 5 1] (solid (box [-5 3.2 1.3] [-4.1 5 1.9])))]))""")
   mir (lv "(room [-5 0 0] [5 3 5]) (mirror-x 0 [(start [-2 0 1] 30 0) (solid (box [-5 0 1] [-4 3 2]))])")
   rs (world-new 40 24 ribs "")
   walk (steps (pins rs 'px -3.0 'pz 1.6 'th (0.0 - pi / 2.0)) 107 40)
   up (world-new 40 24 (lv "(room [0 0 0] [4 3 4]) (start [1 0.5 1] 90 10)") "")
   pos (world-frame (pin (world-new 40 24 hall "test/lore/") 'pos 1))
 (test (#(ribs 'brushes) = 41) (#(mir 'brushes) = 3) (mir 'brushes 2 'shape 'box 0 = [4.0 0.0 1.0])
       (mir 'start 'at = [-2.0 1.0]) (has? (lv "(room [0 0 0] [1 1 1]) (mirror-x 'y [(strip-light [0 1 0])])") "(mirror-x c PARTS)")
       (has? (lv "(room [0 0 0] [1 1 1]) (repeat 2 1 [(strip-light [0 1 0])])") "(repeat n [dx dy dz] PARTS)")
       (walk 'px > -4.7 + body-r - 0.01) (walk 'px < -4.2)
       (brush-medium (rs 'sc 'brushes) [-4.85 2.0 1.6] = 0) (brush-medium (rs 'sc 'brushes) [-4.6 3.3 1.6] = 1)
       (up 'py = 0.5 + eye-h) (mag (up 'ph - 10.0 * pi / 180.0) < 1e-9) (mag (up 'th - pi / 2.0) < 1e-9)
       (has? pos "(start [0.0 0.0 1.0] 0.0 0.0)") (tablet? (world-load "src/apps/lore/levels/station.l"))))
; a bin: solid at its foot, hollow up top and open on every side there, capped, a sign on each
; side; a window: glass between two rooms that stops a walk where its sill does not, and a lamp
; in the room within a room lights that room
(: tq "(: m (texture 8 8 1 '((fill 0.5)))) "
   (lq s) (world-read (tq + "(level \"t\" " + s + ")"))
   bl (lq "(room [0 0 0] [4 3 4]) (bin [2 0 2] 0.6 0.45 0.95 m m)")
   bb (world-new 8 8 bl "" 'sc 'brushes) (bm x y z) (brush-medium bb [x y z])
   wl (lq "(room [0 0 0] [4 3 4]) (room [0 0 4.3] [4 3 8]) (window [1 0 3.95] [3 2.5 4.35] m) (start [2 0 3] 0 0)")
   ws (world-new 8 8 wl "")
   nest (lq "(room [0 0 0] [10 3 10]) (room [2 0 2] [5 3 5]) (strip-light [3.5 3 3.5])")
   ns (world-new 8 8 nest "") lp (ns 'sc 'lights 0 'lamps 0 'keep)
 (test (bm 2.0 0.3 2.0 = 0) (bm 2.0 0.75 2.0 = 1) (bm 2.29 0.75 2.0 = 1) (bm 2.0 0.75 2.22 = 1) (bm 2.0 0.97 2.0 = 0)
       (bm 2.0 0.3 2.27 = 1) (#(bl 'decals) = 4) (#(bl 'panes) = 0)
       (#(wl 'panes) = 1) (world-free? ws 2.0 3.5) (!(world-free? ws 2.0 4.15)) (world-free? ws 3.5 4.15 = 0)
       (#(ws 'sc 'panes) = 1) (peep (ws 'sc 'panes 0 'pk 'tris) 3 0 = -3)
       (lp 0 < 3.5 && 3.5 < lp 2 && lp 1 < 3.5 && 3.5 < lp 3) (lp 2 < 8.0)))
; a sconce: a wedge on its wall, solid by the wall at its face, air past its sloping back
; and before its face; mirrored it stands on the far wall looking back; each a lamp. a
; level's ambient: none by default, a wrong colour refused
(: scq "(: m (texture 8 8 1 '((fill 0.5)))) " (scr s) (world-read (scq + "(level \"t\" " + s + ")"))
   scl (scr "(room [0 0 0] [4 3 4]) (sconce [0 1.5 2] [1 0 0] [0 0 1] 1 m) (mirror-x 2 [(sconce [0 1.5 1] [1 0 0] [0 0 1] 1 m)])")
   scb (world-new 8 8 scl "" 'sc 'brushes) (scm x y z) (brush-medium scb [x y z])
 (test (#(scl 'sconces) = 3) (scm 0.05 1.5 1.95 = 0) (scm 0.2 1.5 1.8 = 1) (scm 0.1 1.5 2.05 = 1) (scm 0.05 2.2 1.95 = 1)
       (scl 'sconces 2 'np 0 = 3.0) (#(world-new 8 8 scl "" 'sc 'lights) >= 3)
       (has? (scr "(room [0 0 0] [1 1 1]) (sconce [0 0 0] [1 0 0] [0 0 1] 1 5)") "(sconce [x y z]")
       (scr "(room [0 0 0] [1 1 1]) (ambient (rgb 0.5 0.4 0.3))" 'ambient = [0.5 0.4 0.3])
       (scr "(room [0 0 0] [1 1 1])" 'ambient = [0.0 0.0 0.0])
       (has? (scr "(room [0 0 0] [1 1 1]) (ambient 3)") "(ambient (rgb r g b))")))
; a pick: the ray through the screen's middle out of the room at its far wall, the room's
; form said; a part in a mirror's list told its place there, both it and its twin; a path
; finds its form's text, and a path to no form none
(: pks "(level \"t\" (room [0 0 0] [4 3 4]) (mirror-x 2 [(solid (box [0 0 1] [1 3 2]))]) (start [2 0 2] 0 0))"
   pkl (world-read pks) pkh (world-pick (world-new 160 100 pkl "") 80 50)
   (pkt p) (world-span pks p @ () () q (snip pks (q 0) (q 1)))
 (test (pkh 'src = [2]) (mag (pkh 'p 2 - 4.0) < 1e-9) (pkl 'brushes 1 'src = [3 2 1]) (pkl 'brushes 2 'src = [3 2 1])
       (pkt [3 2 1] = "(solid (box [0 0 1] [1 3 2]))") (pkt [2] = "(room [0 0 0] [4 3 4])") (pkt [9] = ()) (pkt [3 2 7] = ())))
; ..an orb in the air and a strip light under the ceiling picked before the room behind them
(: ops "(level \"t\" (room [0 0 0] [4 3 4]) (start [2 0 1] 0 0) (orb [2 1.6 3] 0.3 (texture 8 8 1 '((fill 1))) 1) (strip-light [2 2.4 3]))"
   opw (world-new 160 100 (world-read ops) "") ob (world-pick opw 80 50) sb (world-pick opw 80 16)
 (test (ob 'src = [4]) (mag (ob 'p 2 - 2.7) < 1e-2) (sb 'src = [5]) (mag (sb 'p 1 - 2.35) < 1e-6)
       (world-pick opw 80 90 'src = [2])))
; the editor, on a window with no screen: vi on a level's text, ctrl-w w gives the scene the
; keys, a click on the scene puts vi on the form that made what it hit, and a frame paints
; the scene on the left and vi's text on the right
(: edv ((cite 'vi) 'vi-open "")
   _ ((cite 'vi) 'vload edv ["(level \"t\"" "  (room [0 0 0] [4 3 4])" "  (start [2 0 2] 0 0))"] "t.l")
   edw {'w 320 'h 160 'paper (cask (320 * 160 * 4))} ed (edit-new edw edv "")
   _ (edit-events ed [['down 29] ['down 17] ['text "w"] ['up 17] ['up 29] ['down 17] ['text "w"] ['up 17]])
   edf (ed 'focus)
   _ (edit-events ed [['press 1 80 80] ['release 1 80 80]])
   _ (edit-paint ed) edp (edw 'paper)
   (lit? x0 x1 y0 y1) (any (y \ any (x \ peep edp (4 * (y * 320 + x) + 1) 0 != 0) (drop x0 ^x1)) (drop y0 ^y1))
 (test (edf = 'scene) (edv 'row = 1) (edv 'col = 2) (lit? 0 160 0 160) (lit? 160 320 0 16)))
; a drag on the scene, shift held so it runs across the wall faced: the form it took outlined,
; its own numbers moved as far, and the scene read again with it there; dragged back, as it was
(: dgv ((cite 'vi) 'vi-open "")
   _ ((cite 'vi) 'vload dgv ["(level \"t\"" "  (room [0 0 0] [4 3 6])" "  (solid (box [1 0 3] [3 3 3.5]))" "  (start [2 0 2] 0 0))"] "t.l")
   dgw {'w 320 'h 160 'paper (cask (320 * 160 * 4))} dg (edit-new dgw dgv "") dgl (dg 'lay)
   dx (dgl 'sw // 2) dy (dgl 'ph // 2)
   _ (edit-events dg [['down 42] ['press 1 dx dy] ['move (dx + 20) dy] ['release 1 (dx + 20) dy]])
   dl1 (dgv 'lines 2) dlo (dg 'st 'lvl 'brushes 1 'shape 'box 0)
   dink (net (edit-outline dg (world-pens (dg 'st)) = 16756784))
   _ (edit-events dg [['press 1 (dx + 20) dy] ['move dx dy] ['release 1 dx dy] ['up 42]])
   dl2 (dgv 'lines 2)
 (test (dl1 = "  (solid (box [1.25 0 3] [3.25 3 3.5]))") (dlo 0 > 1.05) (dink > 20)
       (dl2 = "  (solid (box [1 0 3] [3 3 3.5]))") (dg 'drag = ())
       (world-read "(level \"t\" (room [0 0 0] [4 3 6]) (move [1 0 0.5] (solid (box [0 0 1] [1 3 2]))) (start [2 0 2] 0 0))" 'brushes 1 'shape 'box 0 = [1.0 0.0 1.5])))
; ..and an orb in the air the same: chosen, outlined, its numbers moved and read again moved
(: obv ((cite 'vi) 'vi-open "")
   _ ((cite 'vi) 'vload obv ["(level \"t\"" "  (room [0 0 0] [4 3 6])" "  (orb [2 1.6 3.5] 0.3 (texture 8 8 1 '((fill 1))) 1)" "  (start [2 0 2] 0 0))"] "t.l")
   obw {'w 320 'h 160 'paper (cask (320 * 160 * 4))} ob (edit-new obw obv "") obl (ob 'lay)
   ox (obl 'sw // 2) oy (obl 'H // 2)
   _ (edit-events ob [['down 42] ['press 1 ox oy] ['move (ox + 20) oy] ['release 1 (ox + 20) oy] ['up 42]])
   oink (net (edit-outline ob (world-pens (ob 'st)) = 16756784))
 (test (obv 'lines 2 = "  (orb [2.3 1.6 3.5] 0.3 (texture 8 8 1 '((fill 1))) 1)") (oink > 20)
       (ob 'st 'lvl 'orbs 0 'at 0 > 2.05)))
; ..a book in moves and a turn stepped comes out of them, its own numbers and bearing turned,
; and reads as the wrapped one turned would
(: bkv ((cite 'vi) 'vi-open "")
   bkf "(move [0.15 0 -0.15] (turn 90 [-27.35 7.4] (move [0.8 0 0.25] (book [-28.15 1 7.15] 160))))"
   _ ((cite 'vi) 'vload bkv ["(level \"t\"" "  (room [-30 0 4] [-24 3 10])" ("  " + bkf) "  (start [-27 0 5] 0 0))"] "t.l")
   bkw {'w 320 'h 160 'paper (cask (320 * 160 * 4))} bk (edit-new bkw bkv "")
   _ (edit-events bk [['down 29] ['down 17] ['text "w"] ['up 17] ['up 29] ['down 17] ['text "w"] ['up 17]])
   _ (pin bk 'sel [3]) _ (edit-events bk [['down 52] ['text "."] ['up 52]])
   (bkn t) (cats (map (b \ (: p (b 'shape 'prism) [(p 0) (p 1)] + cats (p 2))) >(world-read ("(level \"t\" (room [-30 0 4] [-24 3 10]) " + t + ")") 'brushes)))
   bka (bkn ("(turn 15 [-27.2 7.25] " + bkf + ")")) bkb (bkn "(book [-27.2 1 7.25] -95)")
 (test (bkv 'lines 2 = "  (book [-27.2 1 7.25] -95)") (bk 'sel = [3]) (#bka = #bkb) (8 < #bka)
       (all (i \ mag (bka i - bkb i) < 1e-9) ^#bka)))
; a click on a ball looked at takes it into the hands and the click let go keeps it; held
; pressed half a second and let go, it flies along the look at the hardest; taken again
; and the right button pressed, it falls where it was held
(: (bht n) (: lv (world-read "(level \"t\" (room [0 0 0] [10 5 14]) (ball [5 0 3]) (start [5 0 1.5] 0 0))")
             st (world-new 160 100 lv "")
             (go k) (? (k < 1) st (: _ (pin st 'dt 0.05) _ (world-move st) (go (k - 1))))
             _ (go 2) _ (pin st 'ph (-44.6 * pi / 180.0)) _ (world-mouse st 'press 1) _ (world-mouse st 'release 1)
             (go n))
   bh (bht 3) bb (bh 'balls 0) bhp (bb 'p) bhk (bb 'held)
   _ (pin bh 'ph 0.6) _ (world-mouse bh 'press 1) bwp (: _ (each ^10 (_ \ (pin bh 'dt 0.05, world-move bh))) (bb 'p))
   _ (world-mouse bh 'release 1) bv (bb 'v) bvp (: _ (each ^6 (_ \ (pin bh 'dt 0.05, world-move bh))) (bb 'p))
   bd (bht 3) db (bd 'balls 0) dp (db 'p) _ (world-mouse bd 'press 3)
   dq (: _ (each ^60 (_ \ (pin bd 'dt 0.05, world-move bd))) (db 'p))
 (test (bhk = 1) (mag (bhp 2 - 1.95) < 1e-9) (bwp 1 < bhp 1 + 1.0) (bb 'held = 0)
       (mag (bv 2 - 11.0 * cos 0.6) < 1e-6) (mag (bv 1 - 11.0 * sin 0.6) < 1e-6) (bvp 2 > 4.0)
       (db 'held = 0) (mag (dq 0 - dp 0) < 0.05) (mag (dq 2 - dp 2) < 0.05) (mag (dq 1 - 0.12) < 0.02)))
; a plush lies where it is put facing its bearing, a turn swinging that on, its model read
; from its file and set on the floor, the ball it is taken for half its height; one whose file
; will not read is a ball. a click takes it like a ball, held it looks back at the player,
; and thrown it lands upright and stops
(: (pud t) (world-read ("(level \"t\" (room [0 0 0] [10 5 14]) " + t + " (start [5 0 1.5] 0 0))"))
   pua (pud "(plush [5 0 3] 180 \"mouse.glb\")") pub (pud "(turn 90 [5 3] (plush [5 0 3] 180 \"mouse.glb\"))")
   pus (world-new 80 50 pua "src/apps/lore/levels/") pm (pus 'sc 'plushes 0) pk (pm 'pk) pt (pk 'tris) pb (pus 'balls 0) py0 (pb 'p 1)
   pno (world-new 80 50 (pud "(plush [5 0 3] 0 \"none.glb\")") "test/lore/")
   plo (map (k \ amin (pk 'cols k)) ^3) phi (map (k \ amax (pk 'cols k)) ^3) r (pm 'r)
   (pgo k) (each ^k (_ \ (pin pus 'dt 0.05, world-move pus)))
   _ (pgo 2) _ (pin pus 'ph (-38.0 * pi / 180.0)) _ (world-mouse pus 'press 1) _ (world-mouse pus 'release 1)
   _ (pgo 2) ph1 (pb 'held) phq (pb 'q) _ (pin pus 'ph 0.4) _ (world-mouse pus 'press 1) _ (pgo 4) _ (world-mouse pus 'release 1)
   _ (pgo 80) pq (pb 'q) pp (pb 'p)
 (test (pua 'plushes 0 'at = [5.0 0.0 3.0]) (pua 'plushes 0 'deg = 180.0) (pub 'plushes 0 'deg = 270.0) (pua 'plushes 0 'file = "mouse.glb")
       (pb 'kind = 'plush) (0.05 < r) (r < 0.3) (py0 = r) (pb 'r = r) (1000 < pk 'n) (amax pt = pk 'n - 1) (amin pt = -1)
       (mag (plo 1 + r) < 1e-6) (mag (phi 1 - r) < 1e-6) (foldl max 0.0 (map abs [(plo 0) (phi 0) (plo 2) (phi 2)]) = pm 'w)
       (pno 'balls 0 'r = 0.12) (pno 'sc 'plushes 0 'r = 0.12)
       (ph1 = 1) (mag (phq 0 - cos (0.5 * pi)) < 1e-9) (pb 'held = 0) (pb 'rest = 1)
       (pq 1 = 0.0) (pq 3 = 0.0) (pp 2 > 5.0) (mag (pp 1 - r) < 0.03)))
; a void is open air with no walls, gravity weakens up it by the table, and walking out
; against its edge rings, not again for a moment, and turns the walk back; a room's wall never does
(: vlv (world-read "(level \"t\" (void [0 0 0] [10 40 10]) (solid (box [3 19.8 3] [7 20 7])) (gravity [[2 9.8] [18 2.0]]) (start [5 0 5] 90 0))")
   vst (world-new 80 50 vlv "test/lore/")
   (vgo k) (each ^k (_ \ (pin vst 'dt (1.0 / 30.0), world-move vst)))
   (vtop k) (: y0 (vst 'py) _ (world-step vst 'jump) (go i m) (i = k ? m (: _ (vgo 1) (go (i + 1) (max m (vst 'py - y0))))) (go 0 0.0))
   vlo (vtop 40) _ (pins vst 'px 5.0 'pz 5.0 'py (20.0 + eye-h) 'fv 0.0) _ (vgo 2) vhi (vtop 150)
   _ (pins vst 'px 9.0 'pz 5.0 'th (0.5 * pi))
   (vwalk k) (each ^k (_ \ (world-step vst 'forward, pin vst 'dt (1.0 / 30.0), world-move vst)))
   _ (vwalk 6) vw0 (peep vst 'ward-at ()) _ (vwalk 6) vw1 (vst 'ward-at) _ (vwalk 12) vbx (vst 'px) _ (vwalk 60) vw2 (vst 'ward-at)
   rst (world-new 80 50 (world-read "(level \"t\" (room [0 0 0] [10 5 10]) (start [9 0 5] 90 0))") "test/lore/")
   _ (each ^30 (_ \ (world-step rst 'forward, pin rst 'dt (1.0 / 30.0), world-move rst)))
 (test (vlv 'voids = [[[0.0 0.0 0.0] [10.0 40.0 10.0]]]) (vlv 'gravity = [[2.0 9.8] [18.0 2.0]])
       (string? (world-read "(level \"t\" (void [0 0 0] [1 1 1]) (gravity [[1]]))"))
       ((world-read "(level \"t\" (void [0 0 0] [1 1 1]) (skylight (rgb 0.3 0.3 0.4)))") 'skylight = [0.3 0.3 0.4])
       (string? (world-read "(level \"t\" (void [0 0 0] [1 1 1]) (skylight 3))"))
       (mag (vlo - 4.4 * 4.4 / 19.6) < 0.1) (mag (vhi - 4.4 * 4.4 / 4.0) < 0.3)
       (vw0 = ()) (vw1 != ()) (vbx < 9.3) (vw2 > vw1) (vw2 - vw1 > 0.7) (peep rst 'ward-at () = ())))
; a stair shallower than a body is walked at a walk, floating steps too, at a slow frame's
; strides too, and one too tall is not
(: (sgo t) (sgo-at t (1.0 / 30.0) 45)
   (sgo-at t dt n) (: sl (world-read ("(level \"t\" (room [0 0 0] [4 6 12]) " + t + " (start [2 0 1] 0 0))"))
     ss (world-new 80 50 sl "test/lore/")
     _ (each ^n (_ \ (world-step ss 'forward, pin ss 'dt dt, world-move ss))) [(ss 'pz) (ss 'py - eye-h)])
   (steps h y) (foldl (\ a i (a + " (solid (box [0 " + show y + " " + show (3.0 + 0.25 * i) + "] [4 " + show (y + h * (i + 1)) + " 12]))")) "" ^10)
   sa (sgo (steps 0.18 0)) sb (sgo ("(air (box [0 -2 3] [4 0 12]))" + steps 0.18 0)) sc (sgo (steps 0.32 0)) sd (sgo-at (steps 0.18 0) 0.2 8)
 (test (sa 0 > 5.5) (sa 1 > 1.7) (sb 1 > 1.7) (sc 0 < 3.0) (sc 1 = 0.0) (sd 0 > 5.5) (sd 1 > 1.7)))
; a landing sinks the eye as hard as it hit and thumps as its floor feels, a jump scuffs; a jump
; is taken a moment after leaving an edge but not later, one pressed a moment before landing is
; kept for it, and a head stopped on a ceiling jumps no more
(: lt "(feel 'soft (texture 8 8 1 '((fill 0.5))))"
   ll (world-read ("(level \"t\" (room [0 0 0] [10 6 10]) (skin {'floor " + lt + "} (solid (box [6 0 0] [10 1 10])))"
                   + " (solid (box [0 2.6 7] [3 6 10])) (start [2 0 3] 270 0))"))
   ls (world-new 80 50 ll "test/lore/")
   (lgo k) (each ^k (_ \ (pin ls 'dt (1.0 / 30.0), world-move ls)))
   (lput x y z) (pins ls 'px x 'py (y + eye-h) 'pz z 'fv 0.0 'sfx () 'jq -9.0)
   (lcry _) (map (q \ q 0) (peep ls 'sfx ()))
   _ (lgo 3) _ (world-step ls 'jump) _ (lgo 40) lc0 (lcry ()) ld0 (ls 'dip 0)
   _ (lput 8.0 3.0 5.0) _ (lgo 40) lc1 (lcry ())
   (ledge late) (: _ (lput 6.3 1.0 5.0) _ (lgo 2)
     (go i) (? (i > 30 || ls 'py - eye-h < 0.999) i (: _ (world-step ls 'forward) _ (lgo 1) (go (i + 1))))
     _ (go 0) _ (lgo late) _ (world-step ls 'jump) (ls 'fv))
   lk1 (ledge 1) lk6 (ledge 6)
   _ (lput 2.0 1.2 3.0) (lfall i) (? (i > 60 || ls 'py - eye-h < 0.15) i (: _ (lgo 1) (lfall (i + 1))))
   _ (lfall 0) _ (world-step ls 'jump) _ (lgo 3) lq (ls 'fv) lqy (ls 'py - eye-h)
   _ (lput 1.5 0.0 8.5) _ (lgo 2) _ (world-step ls 'jump) (lhead i) (? (i > 30 || ls 'fv = 0.0) i (: _ (lgo 1) (lhead (i + 1))))
   lh (lhead 0) lhy (ls 'py - eye-h) _ (world-step ls 'jump) lh2 (ls 'fv)
 (test (lc0 = ["land hard 0" "hop"]) (ld0 > 0.02) (lc1 = ["land soft 1"]) (string? (world-read "(level \"t\" (feel 'squish (texture 8 8 1 '((fill 0.5)))))"))
       (lk1 = 4.4) (lk6 < 0.0) (lq > 0.0) (lqy > 0.0) (lh < 30) (lhy > 0.2) (lh2 = 0.0)))
; a body caught under something, as a landing may leave it, walks out away from it and not
; further in, nor along it
(: cw (world-new 80 50 (world-read "(level \"t\" (room [0 0 0] [6 5 6]) (solid (box [0 1.2 0] [2 5 6])) (start [2.1 0 3] 90 0))") "test/lore/")
 (test !(world-free? cw 2.05 3.0) (world-free? cw 2.2 3.0) !(world-free? cw 2.1 3.1)
       (: _ (each ^10 (_ \ (world-step cw 'forward, pin cw 'dt (1.0 / 30.0), world-move cw))) (cw 'px > 2.9))))
; ..f in the scene flies: forward through a wall a walker stops at, space up and no fall; f
; again walks, and falls to the floor
(: flv ((cite 'vi) 'vi-open "")
   _ ((cite 'vi) 'vload flv ["(level \"t\"" "  (room [0 0 0] [4 3 8])" "  (solid (box [0 0 3] [4 3 3.5]))" "  (start [2 0 2] 0 0))"] "t.l")
   flw {'w 320 'h 160 'paper (cask (320 * 160 * 4))} fl (edit-new flw flv "") fs (fl 'st)
   (frames a n) (? (n < 1) fs (: _ (pin fs 'dt 0.05) _ (world-step fs a) _ (world-move fs) (frames a (n - 1))))
   (key s c) (edit-events fl [['down c] ['text s] ['up c]])
   _ (edit-events fl [['down 29] ['down 17] ['text "w"] ['up 17] ['up 29] ['down 17] ['text "w"] ['up 17]])
   wz (: _ (frames 'forward 40) (fs 'pz))
   _ (key "f" 33) on (fs 'fly)
   fz (: _ (frames 'forward 8) (fs 'pz))
   fy (: _ (frames 'jump 3) (fs 'py))
   hy (: _ (frames 'strafe-left 5) (fs 'py))
   _ (key "f" 33)
   gy (: _ (frames 'back 40) (fs 'py))
 (test (wz < 3.0) (on = 1) (fz > 3.6) (fy > 2.5) (mag (hy - fy) < 1e-9) (fs 'fly = 0) (mag (gy - 1.6) < 0.05)))
; the plan: tab shows it from above about the player; shift and a drag begun in a room
; draws another as high, after the level's parts, and chooses it; a drag on its edge moves
; that wall, one inside it moves it; tab puts the plan away
(: plv ((cite 'vi) 'vi-open "")
   _ ((cite 'vi) 'vload plv ["(level \"t\"" "  (room [0 0 0] [4 3 4])" "  (start [2 0 2] 0 0))"] "t.l")
   plw {'w 320 'h 160 'paper (cask (320 * 160 * 4))} pl (edit-new plw plv "")
   _ (edit-events pl [['down 29] ['down 17] ['text "w"] ['up 17] ['up 29] ['down 17] ['text "w"] ['up 17] ['down 15] ['up 15]])
   pp (pl 'plan) _ (pin pp 'k 8.0)
   _ (edit-events pl [['down 42] ['press 1 96 96] ['move 144 64] ['release 1 144 64] ['up 42]])
   pl1 (plv 'lines 3) ps (pl 'sel)
   _ (edit-events pl [['press 1 144 80] ['move 152 80] ['release 1 152 80]])
   pl2 (plv 'lines 3)
   _ (edit-events pl [['press 1 120 80] ['move 136 80] ['release 1 136 80]])
   pl3 (plv 'lines 3)
   _ (edit-events pl [['press 1 112 80] ['move 120 80] ['release 1 120 80]])
   pl4 (plv 'lines 3) _ (edit-paint pl) plp (plw 'paper)
   (pix x y) (peep plp (4 * (y * 320 + x) + 2) 0)
   _ (edit-events pl [['down 15] ['up 15]])
 (test (pp 'c = [2.0 2.0]) (pp 'fl = 0.0) (pl1 = "  (room [3 0 1] [6 3 3]))") (ps = [4]) (pl2 = "  (room [3 0 1] [6.5 3 3]))")
       (pl3 = "  (room [4 0 1] [7.5 3 3]))") (pl4 = "  (room [4.5 0 1] [7.5 3 3]))") (#(pl 'st 'lvl 'brushes) = 2) (pix 4 4 = 22) (pix 80 80 != 22) (pl 'plan = ())))
; a turn swings its parts clockwise from above: a box a quarter round still a box, off the
; square a prism, a bearing on as far, a room only by quarters; the editor's . and , step the
; chosen form 15 degrees, < and > 90, in a (turn ..) whose degrees go on and come out at
; nothing; r swings it after the pointer, a click keeping it and esc letting it go; a mirror's
; twin stepped turns the way it is seen
(: (trd t) (world-read ("(level \"t\" (room [-4 0 -4] [4 3 4]) " + t + ")"))
   tqa (trd "(turn 90 [0 0] (solid (box [1 0 0] [2 1 1])))") tqb (trd "(turn 45 [0 0] (solid (box [1 0 0] [2 1 1])))")
   tqc (trd "(turn 30 [0 0] (start [0 0 1] 10 0))") tqd (trd "(turn 30 [0 0] (room [0 0 0] [1 1 1]))")
   tpr (tqb 'brushes 1 'shape 'prism)
   tv ((cite 'vi) 'vi-open "")
   _ ((cite 'vi) 'vload tv ["(level \"t\"" "  (room [0 0 0] [8 3 6])" "  (solid (box [3 0 3] [5 1 4]))" "  (start [4 0 0.5] 0 0))"] "t.l")
   tw {'w 320 'h 160 'paper (cask (320 * 160 * 4))} te (edit-new tw tv "")
   (tkey c s) [['down c] ['text s] ['up c]]
   _ (edit-events te [['down 29] ['down 17] ['text "w"] ['up 17] ['up 29] ['down 17] ['text "w"] ['up 17] ['press 1 80 100] ['release 1 80 100]])
   _ (edit-events te (tkey 52 ".")) tl1 (tv 'lines 2) _ (edit-events te (tkey 52 ".")) tl2 (tv 'lines 2) tsh (te 'st 'lvl 'brushes 1 'shape)
   _ (edit-events te (tkey 52 ">")) tl3 (tv 'lines 2)
   _ (edit-events te (tkey 51 "," + tkey 51 "," + tkey 51 "<")) tl4 (tv 'lines 2)
   _ (edit-events te (tkey 19 "r" + [['move 80 100] ['move 120 100]])) tsw (te 'drag 'dl)
   _ (edit-events te [['down 1] ['up 1]]) _ (edit-events te [['down 27] ['up 27]]) tl5 (tv 'lines 2) tse (te 'sel)
   _ (edit-events te (tkey 19 "r" + [['move 80 100] ['move 120 100] ['press 1 120 100] ['release 1 120 100]])) tl6 (tv 'lines 2)
   mv ((cite 'vi) 'vi-open "")
   _ ((cite 'vi) 'vload mv ["(level \"t\"" "  (room [0 0 0] [8 3 6])" "  (mirror-x 4 [(solid (box [1 0 3] [2 1 4]))])" "  (start [4 0 0.5] 0 0))"] "t.l")
   mw {'w 320 'h 160 'paper (cask (320 * 160 * 4))} me (edit-new mw mv "")
   _ (edit-events me [['down 29] ['down 17] ['text "w"] ['up 17] ['up 29] ['down 17] ['text "w"] ['up 17]])
   _ (edit-events me [['press 1 140 100] ['release 1 140 100]]) mx (take 4 (me 'st 'lvl 'brushes (me 'sb) 'xf))
   _ (edit-events me (tkey 52 ".")) ml (mv 'lines 2)
 (test (tqa 'brushes 1 'shape 'box = [[0.0 0.0 -2.0] [1.0 1.0 -1.0]]) (tpr 0 = 0.0) (tpr 1 = 1.0) (#(tpr 2) = 4)
       (mag (tpr 2 1 0 - 1.4142135623730951) < 1e-9) (mag (tqc 'start 'deg - 40.0) < 1e-9) (has? tqd "a quarter at a time")
       (tl1 = "  (turn 15 [4 3.5] (solid (box [3 0 3] [5 1 4])))") (tl2 = "  (turn 30 [4 3.5] (solid (box [3 0 3] [5 1 4])))")
       (two? (tsh 'prism)) (tl3 = "  (turn 120 [4 3.5] (solid (box [3 0 3] [5 1 4])))") (tl4 = "  (solid (box [3 0 3] [5 1 4]))")
       (tsw = 45.0) (tl5 = tl4) (tse = [3]) (tl6 = "  (turn 45 [4 3.5] (solid (box [3 0 3] [5 1 4])))")
       (mx = [-1.0 0.0 0.0 1.0]) (ml = "  (mirror-x 4 [(turn -15 [1.5 3.5] (solid (box [1 0 3] [2 1 4])))])")))
; a mirror's twin dragged moves as dragged, its form's numbers moved the other way; ctrl-z undoes it
; and ctrl-r does it again; a click on the plan takes the first thing under the cut; the
; pane with the keys has a line round it; q on the scene leaves only twice in a second
(: mtv ((cite 'vi) 'vi-open "")
   _ ((cite 'vi) 'vload mtv ["(level \"t\"" "  (room [0 0 0] [8 3 4])" "  (mirror-x 4 [(solid (box [1 0 1] [2 3 2]))])" "  (solid (box [6 0 3] [7 0.5 4]))" "  (start [4 0 2] 0 0))"] "t.l")
   mtw {'w 320 'h 160 'paper (cask (320 * 160 * 4))} mt (edit-new mtw mtv "")
   _ (edit-events mt [['down 29] ['down 17] ['text "w"] ['up 17] ['up 29] ['down 17] ['text "w"] ['up 17] ['down 15] ['up 15]])
   _ (pin (mt 'plan) 'k 8.0)
   _ (edit-events mt [['press 1 120 88] ['move 136 88] ['release 1 136 88]])
   mtl (mtv 'lines 2) mtb (mt 'st 'lvl 'brushes 2)
   _ (edit-events mt [['down 29] ['down 44] ['up 44] ['up 29]]) mtu (mtv 'lines 2) mtub (mt 'st 'lvl 'brushes 2 'shape 'box)
   _ (edit-events mt [['down 29] ['down 19] ['up 19] ['up 29]]) mtr (mtv 'lines 2)
   _ (edit-events mt [['press 1 120 56] ['release 1 120 56]]) mts (mt 'sel)
   _ (edit-paint mt) (mtp x y) (peep (mtw 'paper) (4 * (y * 320 + x)) 0)
   _ (edit-events mt [['down 16] ['up 16]]) mtq (mt 'quit)
   _ (pin mt 'qq (clock 0 - 1500)) _ (edit-events mt [['down 16] ['up 16]]) mtq2 (mt 'quit)
   _ (edit-events mt [['down 16] ['up 16]])
 (test (mtl = "  (mirror-x 4 [(solid (box [0 0 1] [1 3 2]))])") (mtb 'shape 'box = [[7.0 0.0 1.0] [8.0 3.0 2.0]]) (take 4 (mtb 'xf) = [-1.0 0.0 0.0 1.0])
       (mtu = "  (mirror-x 4 [(solid (box [1 0 1] [2 3 2]))])") (mtub = [[6.0 0.0 1.0] [7.0 3.0 2.0]]) (mtr = mtl)
       (mts = [4]) (mtp 0 5 = 48) (mtp 200 5 != 48) (mtq = 0) (mtq2 = 0) (mt 'quit = 1)))
; a scene made again from the one before keeps what is the same and comes out as one made
; from nothing: after a solid moves, a lamp moves, a solid goes, the room grows, and all
; comes back
(: ksa "(level \"k\" (room [0 0 0] [6 3 6]) (solid (box [1 0 3] [2 1 4])) (sconce [0 1.5 2] [1 0 0] [0 0 1] 1.2 (texture 8 8 1 '((fill (rgb 0.5 0.5 0.5))))) (start [3 0 1] 0 0))"
   ksb "(level \"k\" (room [0 0 0] [6 3 6]) (solid (box [1.5 0 3] [2.5 1 4])) (sconce [0 1.5 2] [1 0 0] [0 0 1] 1.2 (texture 8 8 1 '((fill (rgb 0.5 0.5 0.5))))) (start [3 0 1] 0 0))"
   ksc "(level \"k\" (room [0 0 0] [6 3 6]) (solid (box [1.5 0 3] [2.5 1 4])) (sconce [0 1.5 3] [1 0 0] [0 0 1] 1.2 (texture 8 8 1 '((fill (rgb 0.5 0.5 0.5))))) (start [3 0 1] 0 0))"
   (ksl t) (world-read t) (ksd sc) (show [(map (c \ [(c 'pk) (c 'lit)]) (sc 'chunks)) (sc 'texs)])
   ksd0 "(level \"k\" (room [0 0 0] [6 3 6]) (sconce [0 1.5 3] [1 0 0] [0 0 1] 1.2 (texture 8 8 1 '((fill (rgb 0.5 0.5 0.5))))) (start [3 0 1] 0 0))"
   kse "(level \"k\" (room [0 0 0] [7 3 6]) (sconce [0 1.5 3] [1 0 0] [0 0 1] 1.2 (texture 8 8 1 '((fill (rgb 0.5 0.5 0.5))))) (start [3 0 1] 0 0))"
   ks0 (world-scene (ksl ksa) "" ()) ks1 (world-scene (ksl ksb) "" ks0) ks2 (world-scene (ksl ksc) "" ks1)
   ks3 (world-scene (ksl ksd0) "" ks2) ks4 (world-scene (ksl kse) "" ks3) ks5 (world-scene (ksl ksa) "" ks4)
 (test (ksd ks1 = ksd (world-scene (ksl ksb) "" ())) (ksd ks2 = ksd (world-scene (ksl ksc) "" ()))
       (ksd ks3 = ksd (world-scene (ksl ksd0) "" ())) (ksd ks4 = ksd (world-scene (ksl kse) "" ())) (ksd ks5 = ksd ks0)
       (ksd ks1 != ksd ks0) (0 < #(keys (ks2 'memo 'v)))))
; a grav shaft: walked into, it carries up to its head, eased in, and out north is street level;
; its twin carries down; motes stream through each the way it goes
(: gl (lv "(room [0 0 0] [8 3 4]) (start [2 0 2] 0 0)
          (grav [1 0 4.3] [3 6 6.3] 'up) (air (box [1.2 0 3.9] [2.8 2.5 4.4]))
          (grav [5 0 4.3] [7 6 6.3] 'down) (air (box [5.2 0 3.9] [6.8 2.5 4.4]))
          (room [0 6 6.6] [8 9 9]) (air (box [1.2 6 6.2] [2.8 8.5 6.7])) (air (box [5.2 6 6.2] [6.8 8.5 6.7]))")
   (feet st) (st 'py - eye-h) (moves st n) (each ^n (_ \ world-move st), st)
   g0 (world-new 40 24 gl "") fu (feet (moves (steps g0 107 32) 40)) ft (feet (moves g0 160))
   fo (feet (steps g0 107 25)) oz (g0 'pz)
   dn (moves (pins (world-new 40 24 gl "") 'px 6.0 'pz 5.3 'py (6.0 + eye-h)) 200)
   ms (g0 'sc 'motes) m0 (motes-at (ms 0) 0.0) m1 (motes-at (ms 0) 0.2) m2 (motes-at (ms 1) 0.2)
   (ys m) (peep (m 0) (iota grav-n * 8 + 1) 0.0)
 (test (#(gl 'gravs) = 2) (gl 'gravs 0 'dir = 'up) (has? (lv "(room [0 0 0] [1 1 1]) (grav [0 0 0] [1 1 1] 'sideways)") "(grav [x y z] [x y z] DIR)")
       (0.5 < fu < 6.0) (mag (ft - 6.0) < 1e-6) (fo = ft) (oz > 6.6)
       (mag (feet dn) < 1e-6) (#ms = 2)
       (#(m0 0) = 8 * 12 * grav-n) (#(m0 1) = 4 * 4 * 3 * grav-n) (peep (m0 1) 3 0 = -2)
       (net (ys m1 > ys m0) > grav-n // 2) (net (ys m2 < ys (motes-at (ms 1) 0.0)) > grav-n // 2)))
;; a street: no face over it, the sky drawn there and none under a ceiling; its walls lit by
; the sun on the side it shines on; the sky's hour and cover, a wrong cover refused
(: sl (lv "(sky 17 'clear) (room [0 0 0] [4 3 4]) (street [0 0 4.3] [10 12 14]) (air (box [1 0 3.9] [3 2.5 4.4])) (start [2 0 2] 0 0)")
   ss (world-new 40 24 sl "")
   (blue f) (net ((f & 255) > 120))
   (red f) (net (f >> 16 & 255))
   sky-up (blue (world-pens (pins ss 'px 5.0 'pz 9.0 'ph 1.4)))
   roof-up (blue (world-pens (pins ss 'px 2.0 'pz 2.0 'ph 1.4)))
   east (red (world-pens (pins ss 'px 5.0 'pz 9.0 'th (pi / 2.0) 'ph 0.0)))
   west (red (world-pens (pins ss 'px 5.0 'pz 9.0 'th (0.0 - pi / 2.0) 'ph 0.0)))
   fs (brush-faces (ss 'sc 'brushes))
   (lids y) (#(filter (f \ f 1 1 < -0.5 && mag (f 0 0 1 - y) < 0.01) fs))
 (test (sl 'sky 'hour = 17.0) (sl 'sky 'cover = 'clear) (has? (lv "(room [0 0 0] [1 1 1]) (sky 17 'stormy)") "(sky hour COVER)")
       (lids 12.0 = 0) (lids 3.0 > 0) (sky-up > 200) (roof-up = 0) (east > west)))
; a car: its door opens at the start and stays open while any of the player is in; walls and the shut
; door stop a walk; out, it shuts, reopening for a step back; then it leaves, and the edge stops
; a walk; each change cried, the car drawn only while it stands, its sounds in range
(: cl "(room [-30 0 -3.2] [30 3 6]) (start [0 0 -1.5] 0 0) (strip-light [0 3 3])
       (train [-5 0 -2.8] [5 2.3 -0.2] (door [0 0 -0.2] 1.2 2) -40)"
   L (lv cl) c (L 'cars 0)
   (car-st _) (world-new 40 24 (lv cl) "")
   (moves st n) (each ^n (_ \ world-move st), st)
   (ph st) (st 'cars 0 'ph)
   shut (steps (car-st ()) 107 20)
   west (steps (pins (moves (car-st ()) 40) 'th (0.0 - pi / 2.0)) 107 120)
   opened (moves (car-st ()) 40)
   inside (ph opened)
   out (steps (moves (car-st ()) 40) 107 20)
   closing (ph out)
   back (world-move (pins (moves (steps (moves (car-st ()) 40) 107 20) 3) 'pz -0.15))
   gone (moves (steps (moves (car-st ()) 40) 107 20) 300)
   half (ph (moves (pins (moves (car-st ()) 40) 'pz -0.02) 200))
   freed (steps (pins (moves (car-st ()) 40) 'pz -0.02) 107 10)
   edge (steps (pins gone 'th pi) 107 80)
   cries (map (q \ q 0) (peep gone 'sfx ()))
   (seen st) (world-pens (pins st 'px 0.0 'pz 3.0 'th pi 'ph 0.0))
   snd (map world-sound ["chime" "hiss" "thud" "motor"])
 (test (#(L 'cars) = 1) (c 'ax = 'z) (c 'side = -0.2) (c 'out = 1.0) (c 'leave = -40.0)
       (has? (lv "(room [-30 0 -3.2] [30 3 6]) (train [-5 0 -2.8] [5 2.3 -0.2] (door [0 0 -1.5] 1.2 2) 40)") "a car's door")
       (has? (lv "(room [0 0 0] [1 1 1]) (train [0 0 0] [4 2 2] 3 10)") "(train [x y z]")
       (ph (car-st ()) = 'wait) (inside = 'open) (opened 'cars 0 'door = 1.0)
       (shut 'pz < -0.2 - body-r + 0.01) (west 'px > -5.0 + body-r - 0.01) (west 'px < -4.5)
       (out 'pz > 0.2) (closing = 'shut)
       (ph back = 'open) (half = 'open) (freed 'pz > 0.3)
       (ph gone = 'gone) (gone 'cars 0 'o = -40.0)
       (edge 'pz >= -0.12 + body-r - 0.01) (edge 'pz < 0.3)
       (elem "chime" cries) (elem "hiss" cries) (elem "thud" cries) (elem "motor" cries)
       (seen opened != seen gone)
       (all (s \ two? s && #(s 0) > 1000 && amax (s 0) <= 1.0 && amin (s 0) >= -1.0) snd) (atom? (world-sound "none"))))
; the walk: w a s d step and sidestep, two ways at once no faster than one
(: L (lv "(room [-5 0 -5] [5 3 15]) (start [0 0 0] 0 0)")
   (st _) (world-new 40 24 L "src/apps/lore/levels/")
   (at2 s) [(s 'px) (s 'pz)]
   w (at2 (steps (st ()) 119 10)) k (at2 (steps (st ()) 107 10)) s (at2 (steps (st ()) 115 10))
   d (at2 (steps (st ()) 100 10)) a (at2 (steps (st ()) 97 10))
   wd (at2 (: q (st ()) _ (each ^10 (_ \ (world-step q 'forward, world-step q 'strafe-right, world-move q))) q))
 (test (w = k) (w 1 > 1.0) (mag (w 0) < 1e-9) (s 1 < -1.0) (d 0 > 1.0) (a 0 < -1.0) (mag (d 1) < 1e-9)
       (mag (sqrt (sq (wd 0) + sq (wd 1)) - w 1) < 1e-6) (wd 0 > 0.5)))
; steps: climbed one at a time, and come down again
(: L (lv "(room [-5 0 -5] [5 3 15]) (start [0 0 0] 0 0) (repeat 4 [0 0.15 0.5] [(solid (box [-2 0 2] [2 0.15 15]))])")
   (st _) (world-new 40 24 L "src/apps/lore/levels/")
   (feet q) (q 'py - eye-h) (moves q n) (each ^n (_ \ world-move q), q)
   up (moves (steps (st ()) 107 40) 10) down (moves (steps (moves (steps (st ()) 107 40) 10) 106 40) 30)
   edge (moves (pins (st ()) 'pz 5.0 'py (0.6 + eye-h) 'th (0.5 * pi)) 0)
   off (moves (steps (moves (pins (st ()) 'pz 5.0 'py (0.6 + eye-h) 'th (0.5 * pi)) 2) 107 25) 30)
 (test (mag (feet up - 0.6) < 0.01) (up 'pz > 4.0) (mag (feet down) < 0.01) (down 'pz < 1.5)
       (mag (feet edge - 0.6) < 0.01) (off 'px > 2.5) (mag (feet off) < 0.01)))
; a jump: up near a metre and down again, onto a ledge too high to step, and none in the air
(: L (lv "(room [-5 0 -5] [5 3 15]) (start [0 0 0] 0 0) (solid (box [-2 0 1] [2 1.1 15]))")
   (st _) (world-new 40 24 L "src/apps/lore/levels/")
   (feet q) (q 'py - eye-h) (moves q n) (each ^n (_ \ world-move q), q)
   up (moves (world-step (st ()) 'jump) 13) twice (world-step (moves (world-step (st ()) 'jump) 20) 'jump)
   down (moves (world-step (st ()) 'jump) 40)
   on (steps (world-step (st ()) 'jump) 107 30) off (steps (st ()) 107 30)
 (test (0.85 < feet up) (feet up < 1.05) (twice 'fv < 0.0) (mag (feet down) < 0.01)
       (mag (feet on - 1.1) < 0.01) (on 'pz > 1.5) (mag (feet off) < 0.01) (off 'pz < 1.0)))
; a wall near eye high: jumped at, pulled up onto; walked into, not
(: L (lv "(room [-5 0 -5] [5 4 15]) (start [0 0 0] 0 0) (solid (box [-2 0 1] [2 1.4 15]))")
   (st _) (world-new 40 24 L "src/apps/lore/levels/")
   (feet q) (q 'py - eye-h)
   on (steps (world-step (st ()) 'jump) 107 30) off (steps (st ()) 107 30)
   ; ..the eye carried up over a few frames, never a leap
   ys (: q (world-step (st ()) 'jump) (map (_ \ (: _ (world-step q (world-kb 107)) _ (world-move q) (q 'py))) ^30))
   rise (foldl max2 0.0 (map (i \ ys (i + 1) - ys i) ^29))
 (test (mag (feet on - 1.4) < 0.01) (on 'pz > 1.5) (mag (feet off) < 0.01) (off 'pz < 1.0) (rise < 0.16)))
; the ball: still until walked into, then away, off the far wall, and still again on the floor
(: L (lv "(room [-5 0 -5] [5 3 15]) (start [0 0 0] 0 0) (ball [0 0 2])")
   (st _) (world-new 40 24 L "src/apps/lore/levels/")
   (moves q n) (each ^n (_ \ world-move q), q)
   b0 (moves (st ()) 30) r0 (b0 'balls 0)
   kicked (steps (st ()) 107 20) r1 (kicked 'balls 0)
   later (moves (steps (st ()) 107 20) 400) r2 (later 'balls 0)
   pk (b0 'sc 'ball) c (pk 'cols) T (pk 'tris) nt (#T // 4)
   (P i k) (peep (c k) (peep T i 0) 0.0)
   (out? t) (: a (map (k \ P (4 * t) k) ^3) b (map (k \ P (4 * t + 1) k) ^3) e (map (k \ P (4 * t + 2) k) ^3)
     n (cross (map (k \ e k - a k) ^3) (map (k \ b k - a k) ^3))
     (dot n (map (k \ a k + b k + e k) ^3) >= -1e-9))
   (seen q) (world-pens (pins q 'px 0.0 'pz 0.0 'th 0.0 'ph -0.3))
   gone (: q (st ()) _ (pin (q 'balls 0) 'p [4.0 0.12 -4.0]) _ (pin (q 'balls 0) 'pk ()) q)
 (test (L 'balls = [[0.0 0.0 2.0]]) (has? (lv "(room [0 0 0] [4 4 4]) (ball 1)") "(ball [x y z])")
       (r0 'rest = 1) (r0 'p = [0.0 0.12 2.0])
       (r1 'rest = 0) (r1 'v 2 > 2.0) (elem "bounce" (map (q \ q 0) (peep kicked 'sfx ())))
       (r2 'rest = 1) (r2 'p 2 > 4.0) (r2 'p 2 <= 15.0 - 0.12 + 1e-6) (mag (r2 'p 1 - 0.12) < 0.05)
       (mag (r2 'p 0) < 0.5) (all out? ^nt) (seen (st ()) != seen gone)
       (two? (world-sound "bounce"))))
; the sign: its strokes, a space between words, its width by its letters
(: hi (neon-strokes "HI") sp (neon-strokes "H I") s (neon-sign "OK" [0.0 0.0 0.0] [1.0 0.0 0.0] [0.0 1.0 0.0] [0.0 0.0 -1.0] 0.3 [1.0 0.2 0.6])
 (test (#(hi 0) = 6) (#(sp 0) = 6) (hi 1 < sp 1) (0 < s 'tube 'n) (0 < s 'halo 'n) (two? (s 'lamp 'at))
       (all (p \ p 2 < 0.0) (s 'lamp 'at)) (s 'w = 0.3 * hi 1)))
;; the street's words: a sign facing its own way, a lit board, the spinning square; hanzi
;; a glyph and a half wider than latin's
(: sl (world-read "(: t (texture 8 8 1 '((fill (rgb 1 0 0))))) (level \"t\" (room [0 0 0] [10 4 10]) (start [5 0 5] 0 0) (neon [5 2 9] [0 0 -1] 0.5 \"中\" (rgb 1 0 0)) (ad [0.01 2 5] [1 0 0] [0 1 0] 3 2 t) (spinner [5 3 5] 1 1 t t) (breathe (flames (rgb 1 0.6 0.2) [[1 0 1] [2 0 1]])) (blink (bulb [1 3 1] (rgb 1 0 0))) (whole (solid (box [1 0 1] [2 1 2]))))")
   wh (neon-strokes "中心") wl (neon-strokes "HI")
 (test (tablet? sl) (#(sl 'signs) = 1) (sl 'signs 0 'n = [0.0 0.0 -1.0]) (#(sl 'ads) = 1) (sl 'ads 0 'w = 3)
       (#(sl 'spins) = 1) (sl 'spins 0 't1 = sl 'spins 0 't2) (#(sl 'flames 0 'pts) = 2) (sl 'flames 0 'how = ['breathe]) (sl 'bulbs 0 'how = ['blink]) (any (b \ b 'whole = 1) (sl 'brushes)) (wl 1 < wh 1) (0 < #(wh 0))
       (has? (world-read "(level \"t\" (room [0 0 0] [1 2 1]) (flames (rgb 1 0 0) 3))") "(flames (rgb r g b) [[x y z] ..])") (has? (world-read "(level \"t\" (room [0 0 0] [1 2 1]) (whole 3))") "(whole BRUSH)")
       (has? (world-read "(level \"t\" (room [0 0 0] [1 2 1]) (spinner [0 0 0] 1 1 3 3))") "(spinner [x y z] width height TEXTURE TEXTURE)")))
;; a drape: its rows, a gap (), mirrored front up with the rest; in the scene two
;; triangles to each four corners there, a vertex to each corner
(: dl "(: t (texture 8 8 1 '((fill (rgb 1 0 0))))) (level \"t\" (room [0 0 0] [4 3 4]) (start [2 0 1] 0 0) "
   dr " (drape t [[() [2 0.1 1] [3 0.1 1]] [[1 0.2 2] [2 0.3 2] [3 0.2 2]] [[1 0.1 3] [2 0.2 3] [3 0.1 3]]])"
   d0 (world-read (dl + ")")) d1 (world-read (dl + dr + ")")) dm (world-read (dl + "(mirror-x 2 [" + dr + "]))"))
   (verts l) (: st (world-new 8 8 l "") (net (map (c \ c 'pk 'n) (st 'sc 'chunks))))
 (test (#(d1 'drapes) = 1) (d1 'drapes 0 'rows 0 0 = ()) (d1 'drapes 0 'rows 1 0 = [1.0 0.2 2.0])
       (#(dm 'drapes) = 2) (dm 'drapes 1 'rows 0 0 = [1.0 0.1 1.0]) (dm 'drapes 1 'rows 0 2 = ())
       (verts d1 - verts d0 = 8) (verts dm - verts d0 = 16)
       (has? (world-read "(level \"t\" (room [0 0 0] [1 2 1]) (drape 3 [[[0 0 0]]]))") "(drape TEXTURE [[[x y z] ..] ..])")))
;; ..beyond or hither, or flowing: a sheet apart from the chunks, its class over its texture's
;; index, its flow in texels a second
(: sl "(: t (texture 8 8 1 '((fill (rgb 1 0 0))))) (level \"t\" (room [0 0 0] [4 3 4]) (start [2 0 1] 0 0) "
   sd " (drape t [[[1 0.1 1] [2 0.1 1]] [[1 0.1 2] [2 0.1 2]]])"
   s0 (world-read (sl + ")")) s1 (world-read (sl + sd + ")"))
   db (world-read (sl + "(beyond (flow [0.5 0] " + sd + ")))")) dh (world-read (sl + "(hither " + sd + "))"))
   (verts l) (: st (world-new 8 8 l "") (net (map (c \ c 'pk 'n) (st 'sc 'chunks))))
   sb (world-new 8 8 db "" 'sc) (tx sc) (peep (sc 'sheets 0 'pk 'tris) 3 0)
 (test (db 'drapes 0 'seen = 1) (db 'drapes 0 'flow = [0.5 0.0]) (dh 'drapes 0 'seen = 2) (s1 'drapes 0 'seen = 0)
       (verts db = verts s0) (verts s1 > verts s0) (#(sb 'sheets) = 1) (sb 'sheets 0 'flow = [4.0 0.0])
       (tx sb >= 16777216) (tx sb < 2 * 16777216) (tx (world-new 8 8 dh "" 'sc) >= 2 * 16777216)
       (has? (world-read "(level \"t\" (room [0 0 0] [1 2 1]) (beyond 3))") "(beyond DRAPE)")
       (has? (world-read (sl + "(flow 1 " + sd + "))")) "(flow [du dv] DRAPE)")))
;; a brittle pane: a tap with it before the eye rings it as steel, a second breaks it, leaving
;; its shards; one not brittle stays
(: bw "(: t (texture 8 8 1 '((fill (rgb 1 1 1))))) (level \"t\" (room [0 0 0] [4 3 4]) (start [2 0 1] 180 0) "
   bp (world-read (bw + "(brittle (window [1 0.5 -0.2] [3 2.5 0] t)))")) bq (world-read (bw + "(window [1 0.5 -0.2] [3 2.5 0] t))"))
   (tap l) (world-step (world-step (world-new 8 8 l "") 'tap) 'tap) (tapped l) (keys (peep (tap l) 'broke {}))
   once (world-step (world-new 8 8 bp "") 'tap)
 (test (bp 'panes 0 'brittle = 1) (bq 'panes 0 'brittle = 0) (tapped bp = [0]) (tapped bq = ()) (#(peep (tap bp) 'shards ()) = 1) (#(peep (tap bq) 'shards ()) = 0)
       (keys (peep once 'broke {}) = ()) (keys (peep once 'knocked {}) = [0]) (elem "land metal 1" (map (q \ q 0) (peep once 'sfx ())))
       (has? (world-read (bw + "(brittle 3))")) "(brittle (window ..))")))
;; ..a lens: on the face toward its point its glass less 2^24, the only glass a beyond drape is
;; seen through, the other face plain; its shards plain
(: lw "(: t (texture 8 8 1 '((fill (rgb 1 1 1))))) (level \"t\" (room [0 0 0] [4 3 4]) (start [2 0 1] 180 0) "
   bl (world-read (lw + "(brittle (lens [2 1 2] (window [1 0.5 -0.2] [3 2.5 0] t))))")) bn (world-read (lw + "(brittle (window [1 0.5 -0.2] [3 2.5 0] t)))"))
   gl (world-new 8 8 bl "") (ts s) (s 'sc 'panes 0 'pk 'tris) (gt s) (amin (peep (ts s) (iota (#(ts s) // 4) * 4 + 3) 0))
   (gm s) (amax (peep (ts s) (iota (#(ts s) // 4) * 4 + 3) 0))
 (test (bl 'panes 0 'lens = [2.0 1.0 2.0]) (bn 'panes 0 'lens = ()) (gt gl < -3 - 16777216 + 1) (gm gl > -16777216) (gt (world-new 8 8 bn "") > -16777216)
       (peep (<(peep (world-step (world-step gl 'tap) 'tap) 'shards ()) 'pk 'tris) 3 0 > -16777216)
       (has? (world-read (lw + "(lens [0 0 0] 3))")) "(lens [x y z] (window ..))")))
;; ..a land: solid under its sheet and open over it, stood on where its rows put it, drawn
;; as a drape
(: ld "(: t (texture 8 8 1 '((fill (rgb 1 1 1))))) (level \"t\" (void [-10 -2 -10] [10 10 10]) (start [0 3 0] 180 0) "
   lv (world-read (ld + "(land t [[[-5 0 -5] [5 0 -5]] [[-5 2 5] [5 2 5]]]))")) st (world-new 8 8 lv "")
   _ (each ^60 (_ \ world-move st)) (md p) (brush-medium (st 'sc 'brushes) p)
 (test (md [0 0.5 0] = 0) (md [0 1.5 0] = 1) (md [0 -0.5 4.9] = 0) (abs (st 'py - 2.6) < 0.01) (#(lv 'drapes) = 1)
       (has? (world-read (ld + "(land t 3))")) "(land TEXTURE [[[x y z] ..] ..])")))
;; ..a room carved under it lit by the room's light alone, the same at noon as at midnight
(: (ldr h) (: ul ("(: t (texture 8 8 1 '((fill (rgb 1 1 1))))) (level \"t\" (void [-10 -2 -10] [10 10 10]) (start [0 3 0] 180 0) (sky " + show h + " 'clear) (ambient (rgb 0.5 0.4 0.3)) (land t [[[-5 2 -5] [5 2 -5]] [[-5 2 5] [5 2 5]]]) (room [-3 0 -3] [3 1.5 3]))")
   (map (c \ c 'lit 'base) (filter (c \ c 'hi 1 < 1.6) (world-new 8 8 (world-read ul) "" 'sc 'chunks))))
   ldn (ldr 12)
 (test (0 < #ldn) (ldn = ldr 0)))
; an unlit strip: its fitting drawn with the room, and no light of its own
(: ulr (lv "(room [0 0 0] [4 3 4]) (unlit (strip-light [2 3 2]))") ulw (world-new 8 8 ulr "")
   (ult w) (net (map (c \ #(c 'pk 'tris)) (w 'sc 'chunks)))
 (test (ulr 'strips 0 'unlit = 1) (#(ulw 'sc 'lights) = 0) (#(world-new 8 8 (lv "(room [0 0 0] [4 3 4]) (strip-light [2 3 2])") "" 'sc 'lights) = 1)
       (ult (world-new 8 8 (lv "(room [0 0 0] [4 3 4])") "") < ult ulw)))
; shots: in order, each for its seconds, the world still meanwhile; a sky shot is the sky alone,
; blue at noon; a key skips the rest; a waiting car opens on the cut
(: sl (lv "(room [0 0 0] [4 3 4]) (start [2 0 2] 0 0) (shot 0.2 (sky 13 'partly) 0 60) (shot 0.2 [1 0 1] 90 0) (train [0.5 0 0.5] [3.5 2 3] (door [2 0 3] 1 1.8) 5)")
   st (pin (world-new 16 8 sl "") 'cut (sl 'shots))
   f (world-pens st) (blue? c) ((c & 255) > (c >> 16 & 255) + 40)
   _ (each ^3 (_ \ world-move st)) mid [(#(st 'cut)) (st 'mt) (st 'cars 0 'ph)]
   _ (each ^4 (_ \ world-move st)) left #(st 'cut)
   _ (each ^7 (_ \ world-move st)) cut (st 'cars 0 'ph)
   sk (pin (world-new 16 8 sl "") 'cut (sl 'shots)) _ (world-step sk (world-kb 119)) _ (world-move sk)
 (test (#(sl 'shots) = 2) (sl 'shots 0 'sky 'cover = 'partly) (sl 'shots 1 'at = [1.0 0.0 1.0])
       (any blue? (map (i \ peep f i 0) ^128)) (mid = [2 0.0 'wait]) (left = 1) (cut = 'open) (sk 'cut = ()) (sk 'cars 0 'ph = 'open)
       (has? (lv "(room [0 0 0] [4 3 4]) (shot 0 [1 0 1] 0 0)") "(shot seconds")
       (has? (lv "(room [0 0 0] [4 3 4]) (shot 1 3 0 0)") "(shot seconds")))
; a slab between the knees and the head stops a walk, however thin: the body's whole height
; is air or it does not go
(: sb (lv "(room [0 0 0] [6 3 2]) (start [1 0 1] 90 0) (solid (box [3 0.8 0] [3.2 1.0 2]))")
   st (world-new 8 8 sb "") _ (steps st 119 60)
 (test (st 'px < 2.8) (st 'px > 2.5) (world-free? st 2.5 1.0) (!(world-free? st 3.1 1.0))))
; props: a mattress, a telescope, a book and a pencil read as solid brushes, a bad colour
; said back; a car
; carries the brushes wholly inside it, meshed and moving with it, standing in a walk's way
(: pl (lv "(room [0 0 0] [6 3 4]) (start [1 0 1] 0 0) (mattress [3 0 1] 0) (telescope [5 0 3] 90 20 (rgb 0.2 0.3 0.8)) (book [1 0 3] 30) (pencil [1.3 0 3] 120 (rgb 1 0.8 0.1))")
   cl (lv "(room [-4 0 -2] [4 3 2]) (start [-3 0 0] 90 0) (train [-3.5 0 -1.2] [3.5 2.2 1] (door [0 0 1] 1.2 1.9) 20) (mattress [0.5 0 -0.5] 90) (solid (box [-4 0 1.5] [-3.8 1 2]))")
   cs (world-new 8 8 cl "") pr (cs 'sc 'cars 0 'props)
 (test (tablet? pl) (#(pl 'brushes) > 10) (has? (lv "(room [0 0 0] [6 3 4]) (telescope [5 0 3] 90 20 3)") "(telescope [x y z] bearing pitch (rgb r g b))")
       (has? (lv "(room [0 0 0] [6 3 4]) (pencil [1 0 1] 0 'red)") "(pencil [x y z] bearing (rgb r g b))")
       (#(cl 'cars 0 'props) = 1) (#(cl 'brushes) = 2) (tablet? pr) (0 < #(pr 'pk 'tris))
       (world-free? cs -1.0 0.0) (!(world-free? cs 1.4 -0.5))))
; an orb: read with its texture, meshed round its middle facing out, and its turning only its texels
; sliding, turns a second round; a radius not above 0 said back; drawn coarse or not
(: ol (world-read "(: t (texture 8 8 1 '((fill (rgb 1 0 0))))) (level \"t\" (room [0 0 0] [6 4 6]) (start [3 0 1] 0 0) (bulb [3 3.9 3] (rgb 1 1 1)) (orb [3 2 4] 0.5 t 2))")
   osc (world-scene ol "" ()) opk (osc 'orbs 0 'pk) cs (opk 'cols)
   out (amin ((cs 0 - 3.0) * cs 5 + (cs 1 - 2.0) * cs 6 + (cs 2 - 4.0) * cs 7))
   far (amax (abs (((cs 0 - 3.0) * (cs 0 - 3.0)) + ((cs 1 - 2.0) * (cs 1 - 2.0)) + ((cs 2 - 4.0) * (cs 2 - 4.0)) - 0.25)))
 (test (#(ol 'orbs) = 1) (ol 'orbs 0 'turns = 2) (#(osc 'orbs) = 1) (far < 1e-6) (out > 0.0) (osc 'orbs 0 'round = 16.0)
       (has? (world-read "(level \"t\" (room [0 0 0] [1 2 1]) (orb [0 0 0] 0 (texture 8 8 1 '((fill 1))) 1))") "(orb [x y z] radius TEXTURE turns)")
       ; ..coarse, drawn twice as coarse; a k not 2 4 or 8 said back
       (ol 'orbs 0 'coarse = 1)
       ((world-read "(level \"t\" (room [0 0 0] [6 4 6]) (coarse 2 (orb [3 2 4] 0.5 (texture 8 8 1 '((fill 1))) 1)))") 'orbs 0 'coarse = 2)
       (has? (world-read "(level \"t\" (room [0 0 0] [6 4 6]) (coarse 3 (orb [3 2 4] 0.5 (texture 8 8 1 '((fill 1))) 1)))") "(coarse k ORB)")))

; a surface: a level laid round a ring's tube, its meshes as far off the tube's core as they
; stand off the void's floor, a walk round the tube coming back round past the end, a step along the
; ring's outside as much shorter as its middle is than its outside, a place in the world
; charted back where it was laid; laid flat, only wrapping
(: sfl (lv "(surface 'torus 40 20) (void [-2 -2 -2] [42 4 22]) (solid (box [0 -1 0] [40 0 20])) (start [5 0 10] 0 0)")
   sfs (world-new 8 8 sfl "") sR (40.0 / (2.0 * pi)) sr (20.0 / (2.0 * pi))
   (off c) (: q (sqrt (c 0 * c 0 + c 2 * c 2)) (sqrt ((q - sR) * (q - sR) + c 1 * c 1)))
   ds (map (c \ off (c 'pk 'cols)) (sfs 'sc 'chunks)) dlo (foldl (\ a d (min2 a (amin d))) 99.0 ds) dhi (foldl (\ a d (max2 a (amax d))) 0.0 ds)
   _ (steps sfs 119 200) round [(sfs 'px) (sfs 'pz)]
   ring (pins (world-new 8 8 sfl "") 'th (pi / 2.0)) _ (steps ring 119 10)
   pl (world-new 8 8 (lv "(surface 'plane 10 10) (void [-2 -1 -2] [12 3 12]) (solid (box [0 -1 0] [10 0 10])) (start [9 0 5] 90 0)")) _ (steps pl 119 30)
   ssf (sfs 'sc 'surf) back (map (q \ (: c (ssf 'chart (ssf 'at (q 0) (q 1) (q 2))) (net (map (i \ abs (c i - q i)) ^3)))) [[7.0 0.5 3.0] [33.0 -1.0 17.0]])
 (test (sfl 'surface 'shape = 'torus) (all (d \ d < 1e-9) back) (sfl 'surface 'lx = 40.0) (sr - 2.0 - 1e-6 < dlo) (dhi < sr + 1e-6)
       (mag (round 0 - 5.0) < 1e-9) (mag (round 1 - (10.0 + 200.0 * 3.4 / 30.0 - 20.0)) < 0.05)
       (mag (ring 'px - 5.0 - 10.0 * 3.4 / 30.0 * sR / (sR + sr)) < 0.01)
       (mag (pl 'px - 2.4) < 0.05) (has? (lv "(surface 'cone 1 1)") "(surface 'torus lx lz)")))
; ..its sun fixed in the world: noon over the start on the tube's outside, night opposite on
; its inside, the ground there dimmer however far the eye opens to the dark
(: snl (lv "(surface 'torus 120 60) (sky 12 'clear) (void [-2 -2 -2] [122 4 62]) (solid (box [0 -1 0] [120 0 60])) (start [5 0 30] 0 -57)")
   (glow z) (: st (pins (world-new 40 25 snl "") 'pz z) f (world-pens st) (foldl (\ a i (a + lum (peep f i 0))) 0 ^(40 * 24)))
   noon (glow 30.0) night (glow 0.5)
 (test (night * 3 < noon)))


(test_fin ())
(puts "world: ok\n")
