; test/host/world.l -- a world level and its file, headless: reading, drawing, light,
; doors, walls, reload on change, the car, the sign, the shots.
; not in the corpus: a crew module. run: cat test/00-init.l test/host/world.l | out/love

(borrow '(world mesh neon posix bough gesture sky))
; a nest that is not there, so no scene is kept in the user's or read from it
(setenv "LOVE_NEST" (cwd 0 + "/out/.world-nest-" + show (getpid 0)))
(borrow 'view)     ; pi
(borrow 'brush)
(borrow 'vec)      ; mag
(borrow 'decay)
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
       ; ..finer: as many metres, four times the texels
       (: (tf w) (world-read (tx + "(level \"t\" (start [0 0 0] 0 180) (textures {'floor " + w + "}) (room [0 0 0] [2 2 2]))") 'textures 0)
          a (tf "rust") b (tf "(fine 4 (feel 'metal rust))")
          ((b 'w) = 128 && b 'h = 128 && b 'm = a 'm && b 'feel = 'metal && b 'layers 1 = '(noise 12 0.2)))
       (has? (lv "(skin {'walls (fine 9 rust)} (room [0 0 0] [2 2 2]))") "(fine k TEXTURE)")
       (has? (lv "(skin {'walls (fine 2 (texture 8 8 1 '((art drip 1))))} (room [0 0 0] [2 2 2]))") "no art in it")
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
   ks (map (t \ world-ks sc (t / 10.0) [0.0] 0.0 {}) ^600)
   bad (map (k \ k 2) ks)
   open (world-ks sc 0.0 [1.0] 0.0 {})
   east (world-pens (pins (at 80 48) 'th (pi / 2.0) 'pz 7.0 'px -0.6))
   (pink? c) ((c >> 16 & 255) > (c >> 8 & 255) + 40 && (c & 255) > (c >> 8 & 255))
   n #(sc 'lights)
 (test (n = 10) (40 < lum (px f st 40 44)) (700 < foldl max 0 (map (i \ lum (peep up i 0)) ^(80 * 48)))
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
; ..a file written again while it is being read is read at the next watch: this one writes itself
(: p ("/tmp/worldtest-w-" + show (getpid 0) + ".l")
   room "(room [0 0 0] [4 3 4]) (strip-light [2 3 2]))"
   _ (put p ("(level \"a\" " + room))
   st (world-watch (pins (world-new 40 24 (world-load p) "/tmp/") 'path p))
   _ (put p ("(: q (open " + show p + " \"w\") (say q " + show ("(level \"later\" " + room) + ", close q)) (level \"b\" " + room))
   b (world-watch st) nb (b 'lvl 'name)
   c (world-watch b)
   _ (unlink p)
 (test (nb = "b") (c 'lvl 'name = "later")))
; a jump's height by the frame's length: the same arc at any, to the few millimetres a step can miss its top by
(: lv0 (lv "(room [0 0 0] [8 6 8]) (strip-light [4 6 4])")
   (arc dt) (: st (pins (world-new 40 24 lv0 "/tmp/") 'px 4.0 'pz 4.0)
               _ (each ^20 (_ \ (pin st 'dt dt, world-move st)))
               y0 (st 'py) _ (world-step st 'jump)
               (go n top) (: _ (pin st 'dt dt) _ (world-move st)
                             (? (n > 400) -1.0 (n > 1 && peep st 'fv 0.0 = 0.0) (top - y0) (go (n + 1) (max top (st 'py)))))
               (go 0 y0))
 (test (all (dt \ mag (arc dt - 0.916) < 0.005) [0.0166 0.025 0.0333 0.034 0.04 0.041 0.05])))
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
       (has? pos "(start [0.0 0.0 1.0] 0.0 0.0)") (tablet? (world-load "src/apps/lore/levels/earth.l"))))
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
   edf (ed 'lay 'ps 'focus)
   _ (edit-events ed [['press 1 80 80] ['release 1 80 80]])
   _ (edit-paint ed) edp (edw 'paper)
   (lit? x0 x1 y0 y1) (any (y \ any (x \ peep edp (4 * (y * 320 + x) + 1) 0 != 0) (drop x0 ^x1)) (drop y0 ^y1))
 (test (edf = 'scene) (edv 'row = 1) (edv 'col = 2) (lit? 0 160 0 160) (lit? 160 320 0 16)))
;; ..a frame vi was typed to paints no scene, so the keys show at once; + on the scene makes
;; its pixels finer, the scene sized again for them
(: tyv ((cite 'vi) 'vi-open "")
   _ ((cite 'vi) 'vload tyv ["(level \"t\"" "  (room [0 0 0] [4 3 4])" "  (start [2 0 2] 0 0))"] "t.l")
   tyw {'w 320 'h 160 'paper (cask (320 * 160 * 4))} ty (edit-new tyw tyv "")
   _ (edit-events ty [['down 36] ['text "j"] ['up 36]]) tyt (ty 'typed)
   _ (edit-paint ty) typ (tyw 'paper) tyt2 (ty 'typed)
   (lit? x0 x1 y0 y1) (any (y \ any (x \ peep typ (4 * (y * 320 + x) + 1) 0 != 0) (drop x0 ^x1)) (drop y0 ^y1))
   tye (ty 'lay 'es)
   _ (edit-events ty [['down 29] ['down 17] ['text "w"] ['up 17] ['up 29] ['down 17] ['text "w"] ['up 17] ['down 13] ['text "+"] ['up 13]])
 (test (tyt = 1) (tyt2 = 0) !(lit? 0 150 0 150) (tyv 'row = 1) (tye = 2) (ty 'lay 'es = 1)
       (ty 'lay 'pw = 152) (ty 'st 'w = 152)))
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
; a tap, with no button to it: nothing in reach, nothing; a ball in reach taken; tapped again
; let fall; a door by hand opens and the thing stays in hand; in a dialogue it moves nothing
(: (tw d x) (: st (world-new 160 100 (world-read ("(level \"t\" (room [0 0 0] [10 5 14]) (ball [5 0 3]) " + x + " (start [5 0 " + d + "] 0 0))")) "")
              _ (pin st 'dt 0.05) _ (world-move st) (pin st 'ph (-44.6 * pi / 180.0)))
   (go st n) (each ^n (_ \ (pin st 'dt 0.05, world-move st)))
   far (tw "0.4" "") _ (world-step far 'tap) fb (far 'balls 0)
   a (tw "1.5" "") b (a 'balls 0) w0 (world-winds? a) _ (world-step a 'tap) h1 (b 'held) w1 (world-winds? a) wd (a 'wind) _ (go a 2) p1 (b 'p)
   _ (pin a 'dlg 0) w2 (world-winds? a) _ (pin a 'dlg ()) _ (world-step a 'tap) h2 (b 'held) _ (go a 60) p2 (b 'p)
   d (tw "1.5" "") db (d 'balls 0) _ (world-step d 'tap) _ (pin d 'lvl (pin (foldl (\ u k (pin u k (d 'lvl k))) {} (keys (d 'lvl))) 'decks [[[4.0 0.0 1.8] [6.0 4.0 2.2]]]))
   _ (pin d 'ph 0.0) _ (world-step d 'tap) dm (d 'music)
 (test (peep fb 'held 0 = 0) (w0 = 0) (h1 = 1) (w1 = 1) (wd = ()) (w2 = 0) (h2 = 0)
       (mag (p2 0 - p1 0) < 0.05) (mag (p2 2 - p1 2) < 0.05) (mag (p2 1 - 0.12) < 0.02) (db 'held = 1) (tablet? dm)))
; the brushes by the plan's cells: what is over and under a place, and near it, as the whole list
; filtered says, in its order, at the cells' edges too; and another list begins again
(: gs (world-new 160 100 (world-read ("(level \"t\" (room [-40 0 -40] [40 9 40]) (void [-12 -4 -9] [3 2 5]) (solid (box [1.9 0 -3] [4.1 2 3.3])) (solid (box [-4 0 -4] [-2 1 -2])) "
            + "(solid (box [6 0 6] [6.05 3 20])) (air (box [-30 2 -30] [30 3 -29])) (start [5 0 5] 0 0))")) "")
   bs (gs 'sc 'brushes) (lin l x z) (filter (b \ b 'lo 0 <= x && x <= b 'hi 0 && b 'lo 2 <= z && z <= b 'hi 2) l)
   (box l x z r) (filter (b \ b 'lo 0 - r <= x && x <= b 'hi 0 + r && b 'lo 2 - r <= z && z <= b 'hi 2 + r) l)
   xs [-41.0 -40.0 -30.0 -12.0 -9.001 -4.0 -2.0 -0.001 0.0 1.9 2.0 3.0 4.0 4.1 5.5 6.0 6.05 8.0 8.5 9.0 30.0 40.0 47.0] (eqs a b) (#a = #b && all (i \ a i == b i) ^#a)
   same (all (x \ all (z \ eqs (column-at gs x z) (lin bs x z) && eqs (box (near-bs gs x z) x z 1.0) (box bs x z 1.0)) xs) xs)
   n0 #(column-at gs 2.5 0.0) _ (pin (gs 'sc) 'brushes (take 1 bs)) n1 #(column-at gs 2.5 0.0)
 (test same (n0 > 1) (n1 <= 1)))
; the stick: at a full lean the key's walk to the digit, past the rim the sprint's, half way less, in
; its dead middle nothing
(: (wk n f) (: st (world-new 160 100 (world-read "(level \"t\" (room [0 0 0] [40 5 40]) (start [5 0 5] 0 0))") "")
      _ (each ^n (_ \ (f st, pin st 'dt 0.05, world-move st))) [(st 'px) (st 'pz) (peep st 'vx 0.0) (peep st 'vz 0.0)])
   (ln dx dy) (: v (view-lean dx dy 720) (\ st (v 0 != 0.0 || v 1 != 0.0 ? (world-lean st (v 0) (v 1) (v 2)) st)))
   key (a \ st \ world-step st a) still (wk 1 (key 'none)) full (wk 20 (ln 0 -120)) run (wk 20 (ln 0 -200)) half (wk 20 (ln 0 -58)) slow (wk 20 (ln 0 -16)) creep (wk 20 (ln 10 -8))
 (test (full = wk 20 (key 'forward)) (run = wk 20 (key 'sprint)) (wk 20 (ln 120 0) = wk 20 (key 'strafe-right)) (wk 20 (ln 0 200) = wk 20 (key 'sprint-back))
       (creep 0 = still 0) (creep 1 = still 1) (still 1 < slow 1) (slow 1 < half 1) (half 1 < full 1) (full 1 < run 1)
       (mag (half 3 - 0.5 * full 3) < 0.05 * full 3)))
; a plush lies where it is put facing its bearing, a turn swinging that on, its model made
; by name and set on the floor, the ball it is taken for half its height; one whose file
; will not read is a ball. a click takes it like a ball, held it looks back at the player,
; and thrown it lands upright and stops
(: (pud t) (world-read ("(level \"t\" (room [0 0 0] [10 5 14]) " + t + " (start [5 0 1.5] 0 0))"))
   pua (pud "(plush [5 0 3] 180 'mouse)") pub (pud "(turn 90 [5 3] (plush [5 0 3] 180 'mouse))")
   pus (world-new 80 50 pua "src/apps/lore/levels/") pm (pus 'sc 'plushes 0) pk (pm 'pk) pt (pk 'tris) pb (pus 'balls 0) py0 (pb 'p 1)
   pno (world-new 80 50 (pud "(plush [5 0 3] 0 \"none.glb\")") "test/lore/")
   plo (map (k \ amin (pk 'cols k)) ^3) phi (map (k \ amax (pk 'cols k)) ^3) r (pm 'r)
   (pgo k) (each ^k (_ \ (pin pus 'dt 0.05, world-move pus)))
   _ (pgo 2) _ (pin pus 'ph (-38.0 * pi / 180.0)) _ (world-mouse pus 'press 1) _ (world-mouse pus 'release 1)
   _ (pgo 2) ph1 (pb 'held) phq (pb 'q) _ (pin pus 'ph 0.4) _ (world-mouse pus 'press 1) _ (pgo 4) _ (world-mouse pus 'release 1)
   _ (pgo 80) pq (pb 'q) pp (pb 'p)
 (test (pua 'plushes 0 'at = [5.0 0.0 3.0]) (pua 'plushes 0 'deg = 180.0) (pub 'plushes 0 'deg = 270.0) (pua 'plushes 0 'toy = 'mouse)
       (pb 'kind = 'plush) (0.05 < r) (r < 0.3) (py0 = r) (pb 'r = r) (1000 < pk 'n) (amax pt = pk 'n - 1) (amin pt = -1)
       (mag (plo 1 + r) < 1e-6) (mag (phi 1 - r) < 1e-6) (foldl max 0.0 (map abs [(plo 0) (phi 0) (plo 2) (phi 2)]) = pm 'w)
       (pno 'balls 0 'r = 0.12) (pno 'sc 'plushes 0 'r = 0.12)
       (ph1 = 1) (mag (phq 0 - cos (0.5 * pi)) < 1e-9) (pb 'held = 0) (pb 'rest = 1)
       (pq 1 = 0.0) (pq 3 = 0.0) (pp 2 > 5.0) (mag (pp 1 - r) < 0.03)))
; a void is open air with no walls, gravity weakens up it by the table, and walking out
; against its edge rings, not again for a moment, and stops there; in the air the edge throws
; the body back and up off it; a room's wall never rings
(: vlv (world-read "(level \"t\" (void [0 0 0] [10 40 10]) (solid (box [3 19.8 3] [7 20 7])) (gravity [[2 9.8] [18 2.0]]) (start [5 0 5] 90 0))")
   vst (world-new 80 50 vlv "test/lore/")
   (vgo k) (each ^k (_ \ (pin vst 'dt (1.0 / 30.0), world-move vst)))
   (vtop k) (: y0 (vst 'py) _ (world-step vst 'jump) (go i m) (i = k ? m (: _ (vgo 1) (go (i + 1) (max m (vst 'py - y0))))) (go 0 0.0))
   vlo (vtop 40) _ (pins vst 'px 5.0 'pz 5.0 'py (20.0 + eye-h) 'fv 0.0) _ (vgo 2) vhi (vtop 150)
   _ (pins vst 'px 9.0 'pz 5.0 'py eye-h 'fv 0.0 'th (0.5 * pi))
   (vwalk k) (each ^k (_ \ (world-step vst 'forward, pin vst 'dt (1.0 / 30.0), world-move vst)))
   _ (vwalk 6) vw0 (peep vst 'ward-at ()) _ (vwalk 6) vw1 (vst 'ward-at) _ (vwalk 12) vbx (vst 'px) _ (vwalk 60) vw2 (vst 'ward-at)
   _ (pins vst 'px 9.0 'py (30.0 + eye-h) 'fv -0.1) _ (vwalk 6) vay (vst 'py) _ (vwalk 24) vax (vst 'px) vay1 (vst 'py)
   rst (world-new 80 50 (world-read "(level \"t\" (room [0 0 0] [10 5 10]) (start [9 0 5] 90 0))") "test/lore/")
   _ (each ^30 (_ \ (world-step rst 'forward, pin rst 'dt (1.0 / 30.0), world-move rst)))
 (test (vlv 'voids = [[[0.0 0.0 0.0] [10.0 40.0 10.0]]]) (vlv 'gravity = [[2.0 9.8] [18.0 2.0]])
       (string? (world-read "(level \"t\" (void [0 0 0] [1 1 1]) (gravity [[1]]))"))
       ((world-read "(level \"t\" (void [0 0 0] [1 1 1]) (skylight (rgb 0.3 0.3 0.4)))") 'skylight = [0.3 0.3 0.4])
       (string? (world-read "(level \"t\" (void [0 0 0] [1 1 1]) (skylight 3))"))
       (mag (vlo - 4.237 * 4.237 / 19.6) < 0.02) (mag (vhi - 4.237 * 4.237 / 4.0) < 0.06)
       (vw0 = ()) (vw1 != ()) (vbx > 9.6) (vax < 8.5) (vay1 > vay) (vw2 > vw1) (vw2 - vw1 > 0.7) (peep rst 'ward-at () = ())))
; a stair shallower than a body is walked at a walk, floating steps too, at a slow frame's
; strides too, and one too tall is not
(: (sgo t) (sgo-at t (1.0 / 30.0) 45)
   (sgo-at t dt n) (: sl (world-read ("(level \"t\" (room [0 0 0] [4 6 12]) " + t + " (start [2 0 1] 0 0))"))
     ss (world-new 80 50 sl "test/lore/")
     _ (each ^n (_ \ (world-step ss 'forward, pin ss 'dt dt, world-move ss))) [(ss 'pz) (ss 'py - eye-h)])
   (steps h y) (foldl (\ a i (a + " (solid (box [0 " + show y + " " + show (3.0 + 0.25 * i) + "] [4 " + show (y + h * (i + 1)) + " 12]))")) "" ^10)
   sa (sgo (steps 0.18 0)) sb (sgo ("(air (box [0 -2 3] [4 0 12]))" + steps 0.18 0)) sc (sgo (steps 0.32 0)) sd (sgo-at (steps 0.18 0) 0.2 8)
 (test (sa 0 > 5.5) (sa 1 > 1.7) (sb 1 > 1.7) (sc 0 < 3.0) (sc 1 = 0.0) (sd 0 > 5.5) (sd 1 > 1.7)))
; walking's feel: at once with accel 0; by default drawn up over accel and down over stop, no faster at
; the end, and in the air let go, down over air-stop, so a far jump drifts no further
(: lv (world-load "test/lore/hall.l") sp (st \ sqrt (st 'vx * st 'vx + st 'vz * st 'vz))
   (mk f) (pins (world-new 64 40 lv "test/lore") 'tread f 'dt 0.01 'cut ())
   (go st n f) (each ^n (_ \ (pin st 'mf f, world-move st)))
   a (mk {'accel 0.0}) _ (go a 1 1) va (sp a) _ (go a 1 0) va0 (sp a)
   b (mk {}) _ (go b 3 1) v3 (sp b) _ (go b 30 1) vb (sp b) _ (go b 3 0) vs (sp b) _ (go b 20 0) v0 (sp b)
   (far s) (: c (mk {'accel 0.1 'air-stop s}) _ (go c 30 1) _ (pin c 'fv 3.0) z0 (c 'pz) _ (go c 50 0) (abs (c 'pz - z0)))
 (test (abs (va - 3.4) < 1e-9) (va0 = 0.0) (v3 < 0.9) (abs (vb - 3.4) < 1e-9) (0.0 < vs && vs < vb) (v0 = 0.0)
       (0.3 < far 0.4) (far 0.4 < 0.8) (far 0.2 < far 0.4)))
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
 (test (lc0 = ["land hard 0"]) (ld0 > 0.02) (lc1 = ["land soft 1"]) (string? (world-read "(level \"t\" (feel 'squish (texture 8 8 1 '((fill 0.5)))))"))
       (lk1 = 4.237) (lk6 < 0.0) (lq > 0.0) (lqy > 0.0) (lh < 30) (lhy > 0.2) (lh2 = 0.0)))
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
   _ (edit-events pl [['down 42] ['press 1 92 96] ['move 140 64] ['release 1 140 64] ['up 42]])
   pl1 (plv 'lines 3) ps (pl 'sel)
   _ (edit-events pl [['press 1 140 80] ['move 148 80] ['release 1 148 80]])
   pl2 (plv 'lines 3)
   _ (edit-events pl [['press 1 116 80] ['move 132 80] ['release 1 132 80]])
   pl3 (plv 'lines 3)
   _ (edit-events pl [['press 1 108 80] ['move 116 80] ['release 1 116 80]])
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
       (#(m0 0) = 8 * 4 * grav-n) (#(m0 1) = 4 * 2 * grav-n) (all (t \ peep (m0 1) (4 * t + 3) 0 = 4194364) ^(2 * grav-n))
       ; ..each a square round its middle, as wide as the round glow it is
       (: (g k) (peep (m0 0) (iota (4 * grav-n) * 8 + k) 0.0) (all (k \ amax (g k) = 0.06 && amin (g k) = -0.06 && net (g k > 0.0) = 2 * grav-n) [3 4]))
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
       (lids 12.0 = 0) (lids 3.0 > 0) (sky-up > 200) (roof-up = 0) (east > west)
       ; ..the air's stir under its stars: earth's unless said, 0 an airless sky's
       (sl 'sky 'twinkle = 1.0) (lv "(room [0 0 0] [1 1 1]) (sky 2 'clear) (twinkle 0)" 'sky 'twinkle = 0.0)
       (has? (lv "(room [0 0 0] [1 1 1]) (twinkle -1)") "(twinkle k)")
       ; ..rested at the start unless the level says winded
       (sl 'winded = 0) (lv "(room [0 0 0] [1 1 1]) winded" 'winded = 1)))
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
   (st _) (pins (world-new 40 24 L "src/apps/lore/levels/") 'tread {'accel 0.0})
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
   rise (foldl max 0.0 (map (i \ ys (i + 1) - ys i) ^29))
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
       (all (p \ p 2 < 0.0) (s 'lamp 'at)) (s 'w = 0.3 * hi 1)
       ; ..its halo level with the tubes, off the wall
       (aall (abs (s 'halo 'cols 2 + 0.0505) < 1e-9))))
; a halo: a disc a point, its vertices all there and their u v the offsets the eye turns them by,
; its colour whole in the middle and none at the rim
(: h (mesh-halo [[1.0 2.0 3.0] [0.0 0.0 0.0]] 0.5 [1.0 0.0 0.0]) vs (h 0) n (#vs // 2) (r v) (sqrt (v 3 * v 3 + v 4 * v 4))
 (test (all (v \ take 3 v = [1.0 2.0 3.0]) (take n vs)) (all (v \ take 3 v = [0.0 0.0 0.0]) (drop n vs))
       (abs (vs 0 8 - 1.0) < 1e-9) (abs (foldl max 0.0 (map r vs) - 0.5) < 1e-9) (all (v \ r v < 0.49 || abs (v 8) < 1e-9) vs)
       (all (t \ (t 0 < n) = (t 1 < n)) (h 1))))
; a bulb's light cut to eighths of a metre on a ceiling where it hangs close, as its light bows
; across a cell, and not where it hangs far
(: (eighths b) (: ks (map (c \ c 'pk 'cols) (world-new 8 8 (lv ("(room [0 0 0] [4 3 4]) (bulb [2 " + b + " 2] (rgb 1 1 1))")) "" 'sc 'chunks))
                 (odd? x) (abs (x * 8.0 - 2.0 * floor (x * 4.0) - 1.0) < 1e-6)
                 #(filter (k \ any (i \ k 1 i > 2.9 && odd? (k 0 i)) ^#(k 1)) ks))
 (test (eighths "1.5" = 0) (0 < eighths "2.85")))
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
;; ..with shift, back and to either side a sprint too, and a turn or a look the same as without
(: gs (world-read "(: t (feel 'wood (texture 8 8 1 '((fill (rgb 1 1 1)))))) (level \"t\" (textures {'wall t 'floor t 'ceiling t 'door t}) (room [0 0 0] [6 3 400]) (start [3 0 200] 0 0))")
   (went a) (: st (world-new 8 8 gs "") x0 (st 'px) z0 (st 'pz)
     _ (each ^10 (_ \ (world-step st a, pin st 'dt (1.0 / 30.0), world-move st))) (sqrt (2 (st 'px - x0) + 2 (st 'pz - z0))))
 (test (world-kb 65 = 'sprint-left) (world-kb 68 = 'sprint-right) (world-kb 83 = 'sprint-back) (world-kb 74 = 'sprint-back)
       (world-kb 72 = world-kb 104) (world-kb 76 = world-kb 108) (world-kb 85 = world-kb 117) (world-kb 78 = world-kb 110)
       (1.5 * went 'back < went 'sprint-back) (1.5 * went 'strafe-left < went 'sprint-left) (1.5 * went 'strafe-right < went 'sprint-right)))
;; the sun's disc seen through glass whole, as bare it is: every pixel of it the one tinted
;; colour, drawn here and on a gpu where there is one
(: sg "(: t (texture 8 8 1 '((fill (grey 0.5))))) (level \"t\" (sky 12 'clear) (street [-60 0 -60] [60 40 60]) (start [0 0 0] 0 0) "
   (sun-at x) (: st (world-new 320 200 (world-read (sg + x + ")")) "") s (st 'sc 'sky 'lt 'sun)
     (pins st 'th (atan2 (s 0) (s 2)) 'ph (asin (s 1)), world-pens st))
   ; ..bare, then behind a pane 3 m out toward -z, where the noon sun lies
   (spread _) (: sb (sun-at "") sp (sun-at "(window [-6 0 -3] [6 30 -2.96] t)")
                 dk (iota ((sb >> 16 & 255 >= 250) * (sb >> 8 & 255 >= 250))) gd (sp dk >> 8 & 255)
                 [#dk (amax gd - amin gd) (amax gd)])
   g0 (getenv "LORE_GPU") cp (: _ (setenv "LORE_GPU" "0") (spread ())) gp (: _ (setenv "LORE_GPU" "1") (spread ()))
   _ (setenv "LORE_GPU" g0)
 (test (20 < cp 0) (cp 1 <= 2) (cp 2 < 200) (20 < gp 0) (gp 1 <= 2) (gp 2 < 200)))
;; ..laid along: u how far down its rows from s, v across a row from its middle, in texels
(: sl "(: t (texture 8 8 1 '((fill (rgb 1 0 0))))) (level \"t\" (room [0 0 0] [4 3 4]) (start [2 0 1] 0 0) "
   sd " (drape t [[[1 0.1 1] [2 0.1 1]] [[1 0.1 2] [2 0.1 2]]])"
   sa (world-new 8 8 (world-read (sl + "(flow [0.5 0] (along 2 " + sd + ")))")) "" 'sc) ca (sa 'sheets 0 'pk 'cols)
 (test (amin (ca 3) = 16.0) (amax (ca 3) = 24.0) (amin (ca 4) = -4.0) (amax (ca 4) = 4.0)
       (has? (world-read (sl + "(along 'a " + sd + "))")) "(along s DRAPE)")))
;; on foot: a walk's steps sound as the floor does, a jump is silent and its landing heard, a
;; sprint goes further and winds the body, unheard, and standing it eases
(: gw "(: t (feel 'wood (texture 8 8 1 '((fill (rgb 1 1 1)))))) (level \"t\" (textures {'wall t 'floor t 'ceiling t 'door t}) (room [0 0 0] [6 3 400]) (start [3 0 1] 0 0))"
   (go st a n) (each ^n (_ \ ((a ? (world-step st a) st), pin st 'dt (1.0 / 30.0), world-move st)))
   (cries st) (map cap (peep st 'sfx ()))
   wk (world-new 8 8 (world-read gw) "") _ (go wk 'forward 60) wz (wk 'pz) wc (cries wk) wbob (peep wk 'wa 0.0) wsteps (filter (s \ snip s 0 5 = "step ") wc)
   (firsts-of l) (rev >(rev l))
   rn (world-new 8 8 (world-read gw) "") _ (go rn 'sprint 60) rz (rn 'pz) rpf (rn 'puff) _ (go rn 'sprint 300) rpf2 (rn 'puff)
   rrate (rn 'bp) _ (go rn () 300) rest (rn 'puff) rb (rn 'wa)
   jp (world-new 8 8 (world-read gw) "") _ (world-step jp 'jump) jc (cries jp)
 (test (all (s \ snip s 0 10 = "step wood " && 48 <= s 10 < 54) wsteps) (2 < #(uniq (sort wsteps))) (all (p \ <p != >p) (zip >wsteps (firsts-of wsteps))) (0.0 < wbob)
       (1.5 * (wz - 1.0) < rz - 1.0) (0.1 < rpf) (rpf < rpf2) (0.8 < rpf2)
       (atom? (world-sound "gasp o2"))
       (rest < 0.7 * rpf2) (rb < 0.001) (jc = ()) (1000 < #(world-sound "step wood 0" 0))
       (1000 < #(world-sound "land grass 0" 0))))
;; --sway swells from nothing as speed changes, and settles; a window's coarsest pixels take
;; a body's sway as a slide of the picture, where its server can
(: lq (\ n v (: st {'sway 1} _ (each ^n (i \ gesture-gait st (1.0 / 60.0) (i = 0 ? 0.0 v) 0)) (st 'lean)))
   wb [0.01 0.02 0.03 0.04] sl {'scale 8 'win {'how 'x 'rd {}}} eb (mesh-sway sl wb 1.5 240) nb (mesh-sway {'scale 4 'win {'how 'x 'rd {}}} wb 1.5 240)
 (test (lq 2 3.0 < 0.008) (0.012 < lq 10 3.0) (lq 90 3.0 < 0.001)
       (eb = [0.0 0.0 0.0 0.0]) (5 < sl 'slide 0 < 15) (-40 < sl 'slide 1 < -30) (nb = wb)
       (mesh-sway {'scale 8 'win 0} wb 1.5 240 = wb)))
;; a foot makes no sound carried in a grav shaft, and does on its floor
(: gs "(level \"t\" (room [0 0 0] [8 3 8]) (start [2 0 2] 0 0) (grav [1 0 3] [3 3 5] 'down))"
   (stepping y) (: st (pins (world-new 8 8 (world-read gs) "") 'pz 3.5 'py (y + eye-h) 'sw 3.1)
     _ (each ^4 (_ \ (world-step st 'forward, pin st 'dt (1.0 / 30.0), world-move st)))
     (any (q \ snip (q 0) 0 5 = "step ") (peep st 'sfx ())))
 (test (stepping 0.0) !(stepping 2.0)))
;; a headstone stands, and is no grave
(: hs (world-read "(: t (texture 8 8 1 '((fill (rgb 1 1 1))))) (level \"t\" (room [0 0 0] [4 3 4]) (start [2 0 1] 0 0) (headstone [2 0 3] 45 t))")
 (test (#(hs 'brushes) > 1) (peep hs 'graves () = ())))
;; a mirage: a pane still there to see, and a body walks through it; plain glass stops it
(: mw "(: t (texture 8 8 1 '((fill (rgb 1 1 1))))) (level \"t\" (room [0 0 0] [4 3 4]) (start [2 0 1] 0 0) "
   (past w) (: st (world-new 8 8 (world-read (mw + w + ")")) "") (each ^90 (_ \ (world-step st 'forward, pin st 'dt (1.0 / 30.0), world-move st)), st 'pz))
   ml (world-read (mw + "(mirage (window [1 0 1.9] [3 2.5 2] t)))"))
 (test (ml 'panes 0 'mirage = 1) (#(ml 'panes) = 1)
       (past "(mirage (window [1 0 1.9] [3 2.5 2] t))" > 2.2) (past "(window [1 0 1.9] [3 2.5 2] t)" < 1.9)
       (has? (world-read (mw + "(mirage 3))")) "(mirage (window ..))")))
;; ..a lens: on the face toward its point its glass less 2^24, the only glass a beyond drape is
;; seen through, the other face plain
(: lw "(: t (texture 8 8 1 '((fill (rgb 1 1 1))))) (level \"t\" (room [0 0 0] [4 3 4]) (start [2 0 1] 180 0) "
   bl (world-read (lw + "(lens [2 1 2] (window [1 0.5 -0.2] [3 2.5 0] t)))")) bn (world-read (lw + "(window [1 0.5 -0.2] [3 2.5 0] t))"))
   gl (world-new 8 8 bl "") (ts s) (s 'sc 'panes 0 'pk 'tris) (gt s) (amin (peep (ts s) (iota (#(ts s) // 4) * 4 + 3) 0))
   (gm s) (amax (peep (ts s) (iota (#(ts s) // 4) * 4 + 3) 0))
 (test (bl 'panes 0 'lens = [2.0 1.0 2.0]) (bn 'panes 0 'lens = ()) (gt gl < -3 - 16777216 + 1) (gm gl > -16777216) (gt (world-new 8 8 bn "") > -16777216)
       (has? (world-read (lw + "(lens [0 0 0] 3))")) "(lens [x y z] (window ..))")))
;; ..a glazed door's glass the same, its other face plain; a door with no glass no lens
(: dw "(: t (texture 8 8 1 '((fill (rgb 1 1 1))))) (level \"t\" (room [0 0 0] [4 3 4]) (room [0 0 4] [4 3 8]) (start [2 0 1] 180 0) "
   dd "(glazed t (door [2 0 4] 1.8 2.2))" dl (world-read (dw + "(lens [2 1 2] " + dd + "))")) dn (world-read (dw + dd + ")"))
   df (world-read (dw + "(lens [2 1 6] " + dd + "))"))
   (tx lv) (: pk ((world-new 8 8 lv "") 'sc 'doors 0) t (pk 'tris) I (iota (#t // 4) * 4) v (pk 'cols)
              cs (map (i \ [(t (i + 3)) (v 7 (t i))]) (map (j \ I j) ^#I)) (filter (q \ q 0 <= -3) cs))
   (lensed q) (q 0 <= -3 - 16777216) (near s l) (all (q \ lensed q = (s * q 1 > 0.5)) l)
   a (tx dl) b (tx df) c (tx dn)
   ; ..a sliding glass door's track: a thin band on each inner face of its opening, across the wall's
   ; middle, within it and no deeper than the leaf, its middle clear
   ps (world-new 8 8 dl "" 'sc 'fences) pt (ps 0 'pk 'cols) lo (map (amin * pt) ^3) hi (map (amax * pt) ^3)
   mid (any (i \ 1.2 < pt 0 i && pt 0 i < 2.8 && 0.1 < pt 1 i && pt 1 i < 2.1) ^#(pt 0))
   nd (world-new 8 8 (world-read (dw + "(door [2 0 4] 1.8 2.2))")) "" 'sc 'fences)
 (test (#ps = 1) (nd = ()) (mag (lo 0 - 1.1) < 0.001) (mag (hi 0 - 2.9) < 0.001) (mag (hi 1 - 2.2) < 0.001) (mag (lo 1) < 0.001) (hi 2 - lo 2 < 0.1) (mag (0.5 * (hi 2 + lo 2) - 4.0) < 0.001) !mid (two? a && two? b && two? c) (near -1.0 a) (near 1.0 b) (!(any lensed c)) (any lensed a && any (! * lensed) a)
       (has? (world-read (dw + "(lens [2 1 2] (door [2 0 4] 1.8 2.2)))")) "(lens [x y z] (window ..))")))
;; ..an opening with no skin takes the skin of what it cuts, so shows no plain texture; seams
;; finds one with nothing to take
(borrow "src/apps/lore/seams.l")
(: ow "(: t (texture 8 8 1 '((fill (rgb 1 1 1))))) (level \"t\" (start [2 0 1] 0 0) "
   (op w) (: st (world-new 8 8 (world-read (ow + w + ")")) "") [st (filter (b \ peep b 'opening 0 = 1) (st 'sc 'brushes))])
   a (op "(skin {'all t} (room [0 0 0] [4 3 4])) (window [1 0 1.9] [3 2.5 2] t)")
   b (op "(room [0 0 0] [4 3 4]) (window [1 0 1.9] [3 2.5 2] t)")
 (test (#(a 1) = 1) (two? (a 1 0 'skin)) (seams (a 0) = ())
       (#(b 1) = 1) (b 1 0 'skin = ()) (#(seams (b 0)) = 1) (seams (b 0) 0 'classes = ['floor])))
;; ..a land: solid under its sheet and open over it, stood on where its rows put it, drawn
;; as a drape
(: ld "(: t (texture 8 8 1 '((fill (rgb 1 1 1))))) (level \"t\" (void [-10 -2 -10] [10 10 10]) (start [0 3 0] 180 0) "
   lv (world-read (ld + "(land t [[[-5 0 -5] [5 0 -5]] [[-5 2 5] [5 2 5]]]))")) st (world-new 8 8 lv "")
   _ (each ^60 (_ \ world-move st)) (md p) (brush-medium (st 'sc 'brushes) p)
 (test (md [0 0.5 0] = 0) (md [0 1.5 0] = 1) (md [0 -0.5 4.9] = 0) (abs (st 'py - 2.6) < 0.01) (#(lv 'drapes) = 1)
       (has? (world-read (ld + "(land t 3))")) "(land TEXTURE [[[x y z] ..] ..])")))
;; ..a shaft up through it from a room under it, walled to its lip past the sheet
(: sh (world-new 8 8 (world-read "(: t (texture 8 8 1 '((fill (rgb 1 1 1))))) (level \"t\" (void [-10 -2 -10] [10 10 10]) (start [0 3 0] 180 0) (land t [[[-5 2 -5] [5 2 -5]] [[-5 2 5] [5 2 5]]]) (room [-3 0 -3] [3 1.5 3]) (street [-0.5 1.45 -0.5] [0.5 2.05 0.5]))") "")
   sbs (sh 'sc 'brushes) si <(filter (i \ sbs i 'lo 1 = 1.45) ^#sbs)
 (test (#(filter (f \ f 2 = si && mag (f 1 1) < 0.5) (brush-faces sbs)) = 4)))
;; ..and round a ring's tube with posts standing in it, one by the tube's seam: its sheet cut
;; round their feet meets itself edge to edge, no corner of one piece mid-edge of the next, so
;; bent round the tube no crack opens. an edge one triangle alone has, by place, is such a crack
(: (bk l) (atom? l ? (show l) ("[" + join " " (map bk l) + "]"))
   tst (world-new 8 8 (world-read ("(: t (texture 8 8 1 '((fill (rgb 1 1 1))))) (level \"t\" (surface 'torus 40 20) (void [-2 -2 -2] [42 4 22]) (start [5 1 10] 0 0) (land t "
                                   + bk (map (z \ map (x \ [x (0.1 * sin (pi * x / 10.0 + pi * z / 5.0)) z]) (map (i \ 2 * i) ^21)) (map (i \ 2 * i) ^11)) + ")"
                                   + " (solid (box [9.8 -0.5 9.8] [10.2 1.8 10.2])) (solid (box [19.8 -0.5 0.2] [20.2 1.8 0.6])))")) "")
   tsf (tst 'sc 'surf) (q x) (int (floor (x * 1000.0 + 0.5)))
   (lone c) (: C (c 'pk 'cols) T (c 'pk 'tris) (key i) [(q (C 0 i)) (q (C 1 i)) (q (C 2 i))]
              (ek a b) (: ka (key a) kb (key b) (show ka < show kb ? [ka kb] [kb ka]))
              es (foldl (\ t j (foldl (\ t e (pin t e (peep t e 0 + 1))) t [(ek (T (4 * j)) (T (4 * j + 1))) (ek (T (4 * j + 1)) (T (4 * j + 2))) (ek (T (4 * j + 2)) (T (4 * j)))])) {} ^(#T // 4))
              (crack? e) (: A (e 0) B (e 1) m (tsf 'chart (map (i \ (A i + B i) / 2000.0) ^3))
                           (es e = 1 && mag (m 1) < 0.2 && 5 < net (map (i \ abs (A i - B i)) ^3)))
              (filter crack? (keys es)))
 (test (catmap lone (tst 'sc 'chunks) = ())))
;; ..a seat smaller than a body come down on by its edge, the middle just past it: stood on,
;; and one clear of it fallen past to the floor
(: sd "(: t (texture 8 8 1 '((fill (rgb 1 1 1))))) (level \"t\" (void [-10 -2 -10] [10 10 10]) (start [0 3 0] 180 0) (solid (box [-5 -1 -5] [5 0 5])) (solid (box [-0.2 1 -0.2] [0.2 1.1 0.2])))"
   (seat x) (: st (world-new 8 8 (world-read sd) "") _ (pins st 'px x 'pz 0.0 'py (2.0 + eye-h) 'fv 0.0) _ (each ^60 (_ \ world-move st)) (st 'py - eye-h))
 (test (abs (seat 0.0 - 1.1) < 0.01) (abs (seat 0.28 - 1.1) < 0.01) (abs (seat 0.4) < 0.01)))
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
; ..a troffer: the strip laid in the ceiling, its frame drawn with the room as well, lit or not
(: tfr (lv "(room [0 0 0] [4 3 4]) (unlit (troffer (strip-light [2.1 3 2.4])))")
   tfl (lv "(room [0 0 0] [4 3 4]) (troffer (strip-light [2.1 3 2.4]))")
   (tft l) (net (map (c \ #(c 'pk 'tris)) (world-new 8 8 l "" 'sc 'chunks)))
 (test (tfr 'strips 0 'troffer = 1) (tft (lv "(room [0 0 0] [4 3 4]) (unlit (strip-light [2.1 3 2.4]))") < tft tfr)
       (#(world-new 8 8 tfl "" 'sc 'lights) = 1) (tft (lv "(room [0 0 0] [4 3 4])") < tft tfl)
       (has? (world-read "(level \"t\" (troffer (bulb [0 0 0] (rgb 1 1 1))))") "(troffer (strip-light ..))")))
; a hum: heard in its box, fading past it, gone a little further, and none without one;
; a strip near makes the buzz louder
(: hml (lv "(room [0 0 0] [8 3 8]) (strip-light [2 3 2]) (hum 'fluorescent [0 0 0] [8 3 8])")
   hst (world-new 8 8 hml "")
   (hb x y z) (: _ (pins hst 'px x 'py y 'pz z) _ (hum-bus hst 480) b (hum-bus hst 480) (atom? b ? 0.0 (amax <b)))
   near (hb 2 1.6 2) far (hb 7 1.6 7) edge (hb 7 3.9 7)
 (test (0.0 < far) (far < near) (0.0 < edge) (edge < far) (hb 7 4.6 7 = 0.0)
       (hum-bus (world-new 8 8 (lv "(room [0 0 0] [8 3 8])") "") 480 = ())
       (has? (world-read "(level \"t\" (hum 'bees [0 0 0] [1 1 1]))") "(hum SOUND [x y z] [x y z])")))
; a level's clouds move by the frame in single precision too: from any time of theirs a frame on
; they go a thirtieth of what a second does, and their clock comes round with no step
(: sk (world-new 8 8 (lv "(void [-20 -2 -20] [40 20 40]) (sky 12 'partly)") "" 'sc 'sky) wx (sk 'wx) sim (sk 'sim)
   ux (iota 2000 * 0.0137 - 13.0) uz (iota 2000 * 0.0071 + 3.0) uy (ux * 0.0 + 0.6)
   (of w t) (sky-cloud w ux uy uz 0.0 0.0 t) (cl t) (of wx t)
   next (pin (foldl (\ t k (pin t k (wx k))) {} (keys wx)) 'base (wx 'base - sky-round)) (gone a b) (net (max (a - b) (b - a)))
   dm (map (t \ [(gone (cl t) (cl (t + 1.0 / 30.0))) (gone (cl t) (cl (t + 1.0)))]) [sim 100.0 (sky-round - 30.0)])
 (test (0.0 <= sim < sky-round) (sky-rest 20716 43200.0 = 81600.0) (sky-rest 40 0.0 = 0.0) (sky-rest 41 0.0 = 86400.0)
       (all (d \ 0.0 < d 0 && d 0 < 0.08 * d 1 && 0.015 * d 1 < d 0) dm)
       (gone (cl 10.0) (of next (10.0 + sky-round)) < 0.5) (gone (cl 10.0) (of next (10.0 + sky-round + 400.0)) > 5.0)))
; the desert's wind under a roof: whole out on it, dulled at once, but along a lull dying away
; evenly from its first x to its second, and dulled past it
(: src "(void [-20 -2 -20] [40 20 40]) (sky 12 'clear) (room [0 0 0] [8 3 8]) (hum 'wind [-20 -2 -20] [40 20 40]) "
   (at l x) (: st (world-new 8 8 l "") _ (pins st 'px x 'py 1.6 'pz 4.0) _ (hum-bus st 480) (amax (abs <(hum-bus st 480))))
   lu (lv (src + "(lull [8 -1 0] [0 4 8])")) no (lv src) o (at no 20.0)
   near? (a \ b \ a - b < 0.01 * o && b - a < 0.01 * o)
   rs (map (x \ at lu x / o) [7.9 6.0 4.0 2.0 0.1])
 (test (0.0 < o) (near? (at lu 20.0) o) (near? (at no 4.0) (0.15 * o)) (near? (at lu 4.0) (0.575 * o))
       (rs 0 > rs 1 > rs 2 > rs 3 > rs 4) (near? (at lu 7.9) (0.99 * o)) (near? (at lu 0.1) (0.16 * o))
       (has? (world-read "(level \"t\" (lull [1 0 0] [1 4 8]))") "(lull [x y z] [x y z])")))
; the street's traffic and a music box: each heard, under the clip, keeping its memory from
; one chunk to the next; the box's reverb left from right
(: (sw nm) (: st (world-new 8 8 (lv ("(room [0 0 0] [8 3 8]) (hum '" + nm + " [0 0 0] [8 3 8])")) "") _ (pins st 'px 4 'py 1.6 'pz 4)
              bs (map (_ \ hum-bus st 1600) ^900) (pk f) (foldl (\ a b (max a (f b))) 0.0 bs)
              (top x) (max (amax x) -(amin x))
              [(pk (b \ top <b)) (pk (b \ top (<b - >b))) (keys (st 'hum 'mem))])
   tr (sw "traffic") mb (sw "musicbox")
 (test (0.05 < tr 0) (tr 0 < 1.0) (tr 2 = ['traffic]) (0.05 < mb 0) (mb 0 < 1.0) (0.0 < mb 1) (mb 2 = ['musicbox])))
; deep chunks: a room under the land far from its one opening is left out from above the
; ground, one near the opening is not, and nothing is from in the opening or under the ground
(: (dpb l) (atom? l ? (show l) ("[" + join " " (map dpb l) + "]"))
   dpl (lv ("(void [-2 -2 -2] [62 10 10]) (land (texture 8 8 1 '((fill (rgb 1 1 1)))) "
            + dpb (map (z \ map (x \ [x 3 z]) (map (i \ 2 * i) ^31)) [0 4 8]) + ")"
            + " (room [1 0 1] [7 2 7]) (room [50 0 1] [58 2 7]) (street [2 0 2] [5 3.2 5])"))
   dsc (world-new 8 8 dpl "" 'sc) (dch x) <(filter (c \ c 'lo 0 <= x && x <= c 'hi 0 && c 'lo 1 < 2.5) (dsc 'chunks))
 (test ((dch 54) 'deep = 1) ((dch 4) 'deep = 0) (#(dsc 'ports) = 1)
       (deep-hid? dsc [30 4.6 4]) (!(deep-hid? dsc [3.5 2.5 3.5])) (!(deep-hid? dsc [54 1.6 4]))))
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
   sfs (pins (world-new 8 8 sfl "") 'tread {'accel 0.0}) sR (40.0 / (2.0 * pi)) sr (20.0 / (2.0 * pi))
   (off c) (: q (sqrt (c 0 * c 0 + c 2 * c 2)) (sqrt ((q - sR) * (q - sR) + c 1 * c 1)))
   ds (map (c \ off (c 'pk 'cols)) (sfs 'sc 'chunks)) dlo (foldl (\ a d (min a (amin d))) 99.0 ds) dhi (foldl (\ a d (max a (amax d))) 0.0 ds)
   _ (steps sfs 119 200) round [(sfs 'px) (sfs 'pz)]
   ring (pins (world-new 8 8 sfl "") 'tread {'accel 0.0} 'th (pi / 2.0)) _ (steps ring 119 10)
   seam (pins (world-new 8 8 sfl "") 'tread {'accel 0.1}) _ (steps seam 119 200)
   pl (world-new 8 8 (lv "(surface 'plane 10 10) (void [-2 -1 -2] [12 3 12]) (solid (box [0 -1 0] [10 0 10])) (start [9 0 5] 90 0)")) _ (steps pl 119 30)
   ssf (sfs 'sc 'surf) back (map (q \ (: c (ssf 'chart (ssf 'at (q 0) (q 1) (q 2))) (net (map (i \ abs (c i - q i)) ^3)))) [[7.0 0.5 3.0] [33.0 -1.0 17.0]])
 (test (sfl 'surface 'shape = 'torus) (all (d \ d < 1e-9) back) (sfl 'surface 'lx = 40.0) (sr - 2.0 - 1e-6 < dlo) (dhi < sr + 1e-6)
       (mag (round 0 - 5.0) < 1e-9) (mag (round 1 - (10.0 + 200.0 * 3.4 / 30.0 - 20.0)) < 0.05)
       (mag (seam 'pz - round 1) < 0.2) (mag (seam 'hv 1) > 3.3)
       (mag (ring 'px - 5.0 - 10.0 * 3.4 / 30.0 * sR / (sR + sr)) < 0.01)
       (mag (pl 'px - 2.4) < 0.05) (has? (lv "(surface 'cone 1 1)") "(surface 'torus lx lz)")))
; ..its sun fixed in the world: noon over the start on the tube's outside, night opposite on
; its inside, the ground there dimmer however far the eye opens to the dark
(: snl (lv "(surface 'torus 120 60) (sky 12 'clear) (void [-2 -2 -2] [122 4 62]) (solid (box [0 -1 0] [120 0 60])) (start [5 0 30] 0 -57)")
   (glow z) (: st (pins (world-new 40 25 snl "") 'pz z) f (world-pens st) (foldl (\ a i (a + lum (peep f i 0))) 0 ^(40 * 24)))
   noon (glow 30.0) night (glow 0.5)
 (test (night * 3 < noon)))

; the cells: two rooms a doorway joins meet through it and one walled off meets none, its
; chunk never drawn from them and a frame drawn the same as one drawn whole; from no cell,
; nothing cut; round a ring, two rooms meeting where it wraps
(: cel (lv "(room [0 0 0] [4 3 4]) (room [4.2 0 0] [8 3 4]) (air (box [3.9 0 1.5] [4.3 2 2.5])) (room [0 0 20] [4 3 24]) (start [1 0 2] 0 0)")
   cst (world-new 40 24 cel "") csc (cst 'sc) cc (csc 'cells 'cells) (to i) (sort (map (w \ w 0) (cc i 'ways)))
   far (filter (k \ csc 'chunks k 'lo 2 > 10.0) ^#(csc 'chunks)) ce [1.0 1.6 2.0]
   (cut th) (sort (keys (cells-seen csc (mesh-eye 40 24 ce th 0.0 0.0 1.5 0.05 60.0) ce)))
   (same th) (: _ (pins cst 'px 1.0 'pz 2.0 'th th 'sky-memo ()) a (world-pens cst) c (csc 'cells)
               _ (pin csc 'cells ()) b (world-pens cst) _ (pin csc 'cells c) (aall (a = b)))
   cwr (world-new 8 8 (lv "(surface 'torus 40 20) (room [0 0 2] [3 3 6]) (room [37 0 2] [40 3 6]) (start [1 0 4] 90 0)") "")
 (test (#cc = 4) (to 0 = [2]) (to 1 = [2]) (to 2 = [0 1]) (to 3 = ()) (two? far)
       (all (th \ two? (cut th) && !(any (k \ elem k far) (cut th))) [0.0 1.6 3.2 4.7]) (all same [0.0 1.6 3.2 4.7])
       (cells-seen csc (mesh-eye 40 24 [1.0 1.6 10.0] 0.0 0.0 0.0 1.5 0.05 60.0) [1.0 1.6 10.0] = ())
       (map (c \ map (w \ w 0) (c 'ways)) (cwr 'sc 'cells 'cells) = [[1] [0]])))
; a door opened by hand: shut however near one stands, open once tapped looking at it, shut
; again at the next; one into a dark room swung out of it whoever opens it, and shut by a tap
; on its leaf where it stands; a dark room lit by its lamps alone, none of the ambient
(: hdl (lv "(room [0 0 0] [2 2 2]) (room [0 0 2.2] [2 2 4]) (by-hand (door [1 0 2.1] 0.9 2)) (start [1 0 1.4] 0 0)")
   hds (world-new 8 8 hdl "") (idle st n) (each ^n (_ \ world-move st))
   _ (idle hds 30) d0 (hds 'doors 0) _ (steps hds 101 1) _ (idle hds 30) d1 (hds 'doors 0) _ (pin hds 'th -0.435) _ (steps hds 101 1) _ (idle hds 30) d2 (hds 'doors 0)
   hdk (lv "(room [0 0 0] [2 2 2]) (dark (room [0 0 2.2] [2 2 4])) (by-hand (door [1 0 2.1] 0.9 2)) (start [1 0 1.4] 0 0)")
   hks (world-new 8 8 hdk "") _ (steps hks 101 1) _ (idle hks 30) k1 (hks 'doors 0) kw (peep (hks 'swing) 0 ())
   _ (pins hks 'px 1.4 'pz 1.66 'th (1.5 * pi) 'ph -0.3) _ (steps hks 101 1) _ (idle hks 30) k2 (hks 'doors 0)
   dkl (lv "(ambient (rgb 1 1 1)) (dark (room [0 0 0] [2 2 2])) (room [10 0 0] [12 2 2]) (start [1 0 1] 0 0)")
   (glow x) (: st (pins (world-new 16 10 dkl "") 'px x 'pz 1.0) f (world-pens st) (foldl (\ a i (a + lum (peep f i 0))) 0 ^(16 * 10)))
 (test (hdl 'doors 0 'hand = 1) (d0 = 0.0) (d1 = 1.0) (d2 = 0.0) (hdk 'doors 0 'out = -1.0) (k1 = 1.0) (kw = -1.0) (k2 = 0.0) (dkl 'darks = [[[0.0 0.0 0.0] [2.0 2.0 2.0]]])
       (glow 1.0 * 4 < glow 11.0) (has? (lv "(dark (street [0 0 0] [2 2 2]))") "(dark (room ..))")))

; a tree climbed out of a well as a ladder: forward facing its trunk climbs it, held there
; with no key, back comes down, and a walk away from it at the top steps off onto the ground
(: twl (lv "(room [-9 0 -9] [9 4 9]) (street [-12 4.5 -12] [12 12 12]) (street [-1 3.95 -1] [1 4.55 1]) (solid (box [-0.9 0 -0.9] [0.9 0.6 0.9])) (tree [0 0 0] 7 (texture 8 8 1 '((fill (grey 0.4))))) (start [6 0 0] 0 0)")
   tst (pins (world-new 8 8 twl "") 'tread {'accel 0.0}) (tgo a n) (each ^n (_ \ (? (a != ()) (world-step tst a), pin tst 'dt (1.0 / 30.0), world-move tst)))
   (tfl _) (tst 'py - eye-h)
   _ (pins tst 'px 0.8 'pz 0.0 'py (0.6 + eye-h) 'th (1.5 * pi)) _ (tgo () 5) t0 (tfl 0)
   _ (tgo 'forward 90) t1 (tfl 0) _ (tgo () 30) t2 (tfl 0) _ (tgo 'back 15) t3 (tfl 0) _ (tgo 'forward 30) t4 (tfl 0)
   _ (pin tst 'th (0.5 * pi)) _ (tgo 'forward 30) t5 (tfl 0))
 (test (#(twl 'trees) = 1) (0.59 < t0 < 0.61) (t1 > 4.6) (t2 = t1) (t3 < t2 - 0.5) (t4 > 4.6) (4.45 < t5 < 4.55) (tst 'px > 1.0)
       (has? (lv "(tree [0 0 0] 'x (texture 8 8 1 '((fill (grey 0.4)))))") "(tree [x y z] seed TEXTURE)"))
; a feed: its ad its placeholder till a frame is seen, then that frame, the placeholder's green
; in it, and the overlay's own colour where it is not a hole; a stamp's time hh:mm:ss
(: fq "(: m (texture 8 4 1 '((fill (rgb 0 1 0))))) (: o (texture 8 4 1 '((fill hole) (rect 0 0 4 4 (rgb 1 0 0))))) "
   fl (world-read (fq + "(level \"t\" (room [0 0 0] [4 3 4]) (feed [o] (ad [2 1.6 3.99] [0 0 -1] [0 1 0] 3.6 1.8 m)) (start [2 0 1] 0 0))"))
   (lq s) (world-read (fq + "(level \"t\" " + s + ")"))
   fst (world-new 16 16 fl "") f1 (world-pens fst) f2 (world-pens fst)
   sl (lq "(room [0 0 0] [4 3 4]) (stamp [0 0] 1 {48 \"111101101101111\"} (rgb 1 1 1) (feed [o] (ad [2 1.6 3.99] [0 0 -1] [0 1 0] 3.6 1.8 m))) (start [2 0 1] 0 0)")
   sst (world-new 16 16 sl "") _ (world-pens sst) _ (world-pens sst) ss (sst 'sc 'feeds 0 'st)
   (ch c k) (c >> k & 255)
   row (map (x \ peep f2 (8 * 16 + x) 0) ^16)
 (test (#(fst 'sc 'feeds) = 1) (ch (peep f1 (8 * 16 + 8) 0) 8 > ch (peep f1 (8 * 16 + 8) 0) 16)
       (any (c \ ch c 8 > ch c 16 + 40) row) (any (c \ ch c 16 > ch c 8 + 40) row)
       (#ss = 8 && ss 2 = 58 && ss 5 = 58 && all (c \ 48 <= c && c <= 57) (map ss [0 1 3 4 6 7]))
       (has? (lq "(room [0 0 0] [1 1 1]) (stamp [0 0] 1 {} (rgb 1 1 1) (ad [0 1 0] [0 0 1] [0 1 0] 1 1 m))") "(stamp [x y] size FONT (rgb r g b) FEED)")
       (has? (lq "(room [0 0 0] [1 1 1]) (feed [] (ad [0 1 0] [0 0 1] [0 1 0] 1 1 m))") "(feed [TEXTURE ..] AD)")
       (has? (lq "(room [0 0 0] [1 1 1]) (feed [m] (room [0 0 0] [1 1 1]))") "(feed [TEXTURE ..] AD)")))
; a vined tree: not climbed till the loop first plays, a tap on the deck, and then not till
; its vines have grown to the fork, drawn as they go
(: vwl (lv "(room [-9 0 -9] [9 4 9]) (street [-12 4.5 -12] [12 12 12]) (street [-1 3.95 -1] [1 4.55 1]) (solid (box [-0.9 0 -0.9] [0.9 0.6 0.9])) (vined (tree [0 0 0] 7 (texture 8 8 1 '((fill (grey 0.4)))))) (deck [5 0 -1] [6 1 1]) (start [6 0 0] 0 0)")
   vst (world-new 8 8 vwl "") (vgo a n) (each ^n (_ \ (? (a != ()) (world-step vst a), pin vst 'dt (1.0 / 30.0), world-move vst)))
   (vfl _) (vst 'py - eye-h) (vup _) (: _ (pins vst 'px 0.8 'pz 0.0 'py (0.6 + eye-h) 'th (1.5 * pi) 'ph 0.0) _ (vgo () 5) _ (vgo 'forward 60) (vfl 0))
   v0 (vup 0) n0 (peep vst 'vined ())
   _ (pins vst 'px 3.8 'pz 0.0 'py eye-h 'th (0.5 * pi) 'ph -0.5) _ (vgo () 5) _ (world-step vst 'tap) n1 (peep vst 'vined ())
   v1 (vup 0) p1 (world-pens vst) _ (pin vst 'vined (vst 'mt - 60.0)) v2 (vup 0) p2 (world-pens vst))
 (test (#(vwl 'trees) = 1) (vwl 'trees 0 'vine = 1) (n0 = ()) (tablet? (vst 'music)) (charm? n1 || gem? n1) (v0 < 0.61) (v1 < 0.61) (v2 > 3.0)
       (#(vst 'sc 'vines) = 1) (has? (lv "(vined (room [0 0 0] [1 1 1]))") "(vined (tree ..))"))
; a lift on a surface: stepped onto through its open side at its foot it carries the body
; into the pocket, and stands there till the switch on its middle post is tapped; then up to
; its head, its gates holding the body on as it goes, off onto the floor there, and back down and out again
(: pfl (lv "(surface 'plane 40 40) (void [-4 -3 -4] [44 20 44]) (solid (box [-4 -3 -4] [44 0 44])) (pocket [20 20] [(void [12 -0.5 12] [28 30 28]) (lift [18 0 20] 1.6 10 (texture 8 8 1 '((fill 0.5)))) (solid (box [19 9 18] [24 10 22]))]) (start [21 0 20] 270 0)")
   pst (world-new 8 8 pfl "") (pgo a n) (each ^n (_ \ (? (a != ()) (world-step pst a), pin pst 'dt (1.0 / 30.0), world-move pst)))
   (pat _) [(pst 'px) (pst 'py - eye-h) (pst 'lifts 0 'ph)]
   ; ..the switch looked at from where the body stands, and tapped
   (ptap _) (: c (pst 'lvl 'lifts 0) dx (pst 'px - c 'at 0 - 0.11) dy (c 'at 1 + pst 'lifts 0 'o + 1.02 - pst 'py)
     _ (pins pst 'th (1.5 * pi) 'ph (atan (dy / dx))) _ (pgo 'tap 1) (pin pst 'ph 0.0))
   _ (pgo 'forward 30) _ (pgo () 90) p0 (pat 0) _ (ptap ()) _ (pgo () 75)
   _ (pin pst 'th (0.5 * pi)) _ (pgo 'forward 30) pg (pat 0) _ (pgo () 300) p1 (pat 0)
   _ (pin pst 'th (0.5 * pi)) _ (pgo 'forward 30) _ (pgo () 60) p2 (pat 0)
   _ (pin pst 'th (1.5 * pi)) _ (pgo 'forward 32) _ (ptap ()) _ (pgo () 300) p3 (pat 0)
   _ (pin pst 'th (0.5 * pi)) _ (pgo 'forward 30) p4 (pat 0))
 (test (p0 1 < -999.9) (p0 2 = 'foot) (pg 2 = 'up) (pg 0 < 18.8) (pg 1 > -999.9) (mag (p1 1 + 990.0) < 0.01) (p1 2 = 'head) (p2 0 > 19.5) (mag (p2 1 + 990.0) < 0.01) (p2 2 = 'head)
       (mag (p3 1 + 1000.0) < 0.01) (p3 2 = 'foot) (p4 0 > 19.5) (mag (p4 1) < 0.01)
       (has? (lv "(lift [0 0 0] 0.5 3 (texture 8 8 1 '((fill 0.5))))") "(lift [x y z] width rise TEXTURE)"))
; a deck tapped within reach starts the loop and tapped again stops it; looked away from, not
(: dkl (lv "(room [0 0 0] [10 4 10]) (deck [4 0 6] [6 1 6.5]) (speaker [8 1 8]) (start [5 0 5.3] 0 -30)")
   dks (world-new 8 8 dkl "") _ (world-step dks 'tap) d0 (peep dks 'music ())
   _ (world-step dks 'tap) d1 (peep dks 'music ()) _ (pin dks 'th pi) _ (world-step dks 'tap) d2 (peep dks 'music ()))
 (test (tablet? d0) (d1 = ()) (d2 = ()) (#(dkl 'speakers) = 1))
; a light given the loop gone: lit with the deck still and as the loop plays, out once it has
; all worn away, lit again begun afresh; one given the loop playing is dimmed then
(: owl (lv "(room [0 0 0] [10 4 10]) (given 'loop-gone (dim 0) (strip-light [5 4 5])) (given 'loop (dim 0.5) (bulb [2 2 2] (rgb 1 1 1))) (deck [4 0 6] [6 1 6.5]) (start [5 0 5.3] 0 -30)")
   ows (world-new 8 8 owl "") (lit _) (world-ks (ows 'sc) 0.0 [] (world-loop ows) {}) go (_ \ world-step ows 'tap)
   o0 (lit ()) _ (go ()) o1 (lit ()) m (ows 'music) _ (pin m 'n (int (1e6 * m 'd 'gone))) o2 (lit ()) _ (go ()) _ (go ()) o3 (lit ()))
 (test ([o0 o1 o2 o3] = [[1.0 1.0] [1.0 0.5] [0.0 0.5] [1.0 0.5]]) (has? (lv "(given 'dusk (dim 0) (strip-light [5 4 5]))") "(given WHEN change LIGHT)"))
; the console: a line of love on the walk's state, its answer short, a fault said
(: cst (world-new 8 8 (lv "(room [0 0 0] [10 4 10]) (deck [4 0 6] [6 1 6.5]) (start [5 0 5.3] 0 -30)") "") c (world-console cst))
 (test (c "st 'px" = "5.0") (has? (c "tp 2 0 3") "[2.0 0.0 3.0]") (cst 'px = 2.0) (has? (c "(1 +") "unfinished") (has? (c "nosuch 3") ";; missing nosuch")
       (c "{'b 2 'a [1 (2 . 3) {}]}" = "{a (1 (2 . 3) {}) b 2}") (#(c "st") < 4100) (c "iota 100" = show (iota 100)) (has? (c "iota 100000") " ..") (c "loop-end ()" = "2.0") (tablet? (cst 'music)) (has? (c "help") "loop-end")
       (has? (world-console (world-new 8 8 (lv "(room [0 0 0] [10 4 10]) (start [5 0 5.3] 0 0)") "") "loop-end ()") ";; missing loop-end"))
; a speaker's reach: the loop gone fifteen metres off a plain one, still heard there off one
; reaching twenty
(: (rch sp x) (: l (lv ("(room [0 0 0] [40 4 4]) (deck [1 0 1] [2 1 2]) " + sp + " (start [1.5 0 2.5] 180 -30)"))
                 st (world-new 8 8 l "") _ (world-step st 'tap) _ (pins st 'px x 'py 0.0 'pz 2.0)
                 _ (each ^4 (_ \ hum-bus st 480)) b (hum-bus st 480) (atom? b ? 0.0 (max (amax <b) -(amin <b))))
   far0 (rch "(speaker [2 1 2])" 17.0) far1 (rch "(reach 20 (speaker [2 1 2]))" 17.0)
 (test (far0 = 0.0) (0.0 < far1)
       (has? (lv "(reach 0 (speaker [0 0 0]))") "(reach metres PARTS)")))
; a resonance: a wisp let fall over a brazier kept in its bowl; the string whole at every
; prime of its steps with 6 and 7 rung, not with 6 and a torn 4, and with 14 across the tube
; and 6; a sealed lift's gates shut till then, and open once it is
(: rsl (lv ("(surface 'torus 42 20) (void [-1 -1 -1] [43 6 21]) (solid (box [-1 -1 -1] [43 0 21])) (resonance [0 3 0] 42) "
            + "(brazier [6 0 2] (texture 8 8 1 '((fill 0.5)))) (brazier [7 0 2] (texture 8 8 1 '((fill 0.5)))) (brazier [4 0 2] (texture 8 8 1 '((fill 0.5)))) "
            + "(brazier [14 0 10] (texture 8 8 1 '((fill 0.5)))) (wisp [20 0 3]) (wisp [21 0 3]) "
            + "(sealed (lift [30 0.16 4] 1.6 3 (texture 8 8 1 '((fill 0.5))))) (start [25 0 4] 0 0)"))
   rst (world-new 8 8 rsl "") ws (filter (b \ b 'kind = 'wisp) (rst 'balls)) bs (rsl 'braziers)
   (rgo n) (each ^n (_ \ (pin rst 'dt (1.0 / 30.0), world-move rst)))
   (rset is) (: _ (each ws (b \ pins b 'in () 'p [(b 'p 0) 0.13 (b 'p 2 + 5.0)])) _ (each ^#is (k \ (: c (bs (is k)) (pins (ws k) 'in (is k) 'p [(c 0) (c 1 + 1.13) (c 2)]))))
                (rgo 60, [(world-whole? rst) (rst 'lifts 0 'g)]))
   _ (pins <ws 'p [7.0 2.0 2.0] 'v [0.0 0.0 0.0] 'rest 0) _ (rgo 30) kept (peep <ws 'in ())
   ; ..one taken and set in brazier 1 by taps alone
   tst (world-new 8 8 rsl "") tw0 (<(filter (b \ b 'kind = 'wisp) (tst 'balls))) _ (pins tst 'cut () 'px 20.0 'pz 2.0 'py 1.6 'th 0.0 'ph (atan -1.47))
   _ (world-step tst 'tap) th1 (peep tw0 'held 0) _ (pins tst 'px 7.0 'pz 0.5 'th 0.0 'ph (atan (-0.5 / 1.5))) _ (world-step tst 'tap) th2 [(peep tw0 'held 0) (peep tw0 'in ())]
   r0 (rset []) r67 (rset [0 1]) r64 (rset [0 2]) r146 (rset [3 0])
 (test (th1 = 1) (th2 = [0 1]) (kept = 1) (r0 0 = 0) (r0 1 > 0.5) (r67 0 = 1) (r67 1 < 0.5) (r64 0 = 0) (r146 0 = 1)
       (has? (lv "(resonance [0 0 0] 1)") "(resonance [x y z] steps)")
       (has? (lv "(sealed (ball [0 0 0]))") "(sealed LIFT)")))
; a camera's feed: shot from where the camera stands while its monitor is in view; with
; cards, now and then snow, a card held, snow, and the camera again
(: cl (lv ("(void [-1 -1 -1] [11 5 11]) (solid (box [-1 -1 -1] [11 0 11])) (cards [(texture 8 8 1 '((fill 0.3)))] 2 1 (camera [5 1 1] 0 0 "
           + "(feed [(texture 8 8 1 '((fill hole)))] (ad [5 1.5 9] [0 0 -1] [0 1 0] 2 1 (texture 16 8 1 '((fill 0.5))))))) (start [5 0 3] 0 0)"))
   cs (world-new 32 20 cl "") cq (cs 'sc 'feeds 0) _ (world-pens cs) c0 (peep cq 'shot-t ())
   phs (map (_ \ (pin cs 'mt (cs 'mt + 0.1), world-pens cs, cq 'ph)) ^50)
 (test (cl 'ads 0 'cam 1 = 0.0) (#(cl 'ads 0 'cards 0) = 1) (c0 != ()) (elem 'in phs) (elem 'card phs) (elem 'out phs) (phs 49 = 'cam)
       (has? (lv "(camera [0 0 0] 0 0 (ball [0 0 0]))") "(camera [x y z] bearing pitch FEED)")
       (has? (lv "(cards [] 1 1 (ball [0 0 0]))") "(cards [TEXTURE ..] every hold FEED)")
       (has? (lv "(watch [0 0 0] 1 [3 2] 30 (ball [0 0 0]))") "(watch [x y z] radius [near far] cone FEED)")))
; ..and one that moves while a plush lies down a hole, not held over it nor on the ground by it
(: ml (lv ("(void [-1 -1 -1] [11 5 11]) (solid (box [-1 -1 -1] [11 0 11])) (plush [2 0 3] 90 'mouse) (missing [8 2 4] 90 -20 (camera [5 1 1] 0 0 "
           + "(feed [(texture 8 8 1 '((fill hole)))] (ad [5 1.5 9] [0 0 -1] [0 1 0] 2 1 (texture 16 8 1 '((fill 0.5))))))) (start [5 0 3] 0 0)"))
   ms (world-new 32 20 ml "") mb (ms 'balls 0) mq (ms 'sc 'feeds 0) _ (pin (ms 'lvl) 'pits [[[1.0 -50.0 2.0] [3.0 0.0 4.0]]])
   (seen p held) (pins mb 'p p 'held held, pin ms 'mt (ms 'mt + 1.0), world-pens ms, mq 'cam 0 0)
 (test (seen [2.0 0.1 3.0] 0 = 5.0) (seen [2.0 -20.0 3.0] 0 = 8.0) (seen [2.0 -20.0 3.0] 1 = 5.0) (seen [6.0 -20.0 3.0] 0 = 5.0)
       (has? (lv "(missing [0 0 0] 0 0 (ball [0 0 0]))") "(missing [x y z] bearing pitch FEED)")))
; an iron gate: shut, in a body's way, and the fence beside it too; tapped, it swings open
; and lets the body by. a headstone tapped kneels the body before it, its name and
; the choices shown; weeping keeps it down, its tears falling, and brings them back, leaving
; stands it again
(: yi "(texture 8 8 1 '((fill 0.1)))"
   yl (lv ("(void [0 -1 0] [10 4 10]) (solid (box [0 -1 0] [10 0 10])) (fence [[5 0 6] [5 0 9.5]] 1 " + yi + ") (fence [[5 0 0.5] [5 0 4]] 1 " + yi
           + ") (gate [5 0 6] [5 0 4] 1 90 " + yi + ") (grave [2 0 5] 90 \"Yuki\" " + yi + ") (start [7 0 5] 270 0)"))
   ys (world-new 80 48 yl "") (ygo a n) (each ^n (_ \ (? (a != ()) (world-step ys a), pin ys 'dt (1.0 / 30.0), world-move ys)))
   _ (ygo 'forward 60) y0 (ys 'px) _ (pin ys 'pz 8.0) _ (ygo 'forward 30) y1 (ys 'px) _ (pins ys 'px 7.0 'pz 5.0)
   _ (ygo 'forward 60) _ (pin ys 'ph -1.0) _ (world-step ys 'tap) _ (pin ys 'ph 0.0)
   _ (ygo () 60) yg (ys 'gates 0 'g) _ (ygo 'forward 60) y2 (ys 'px)
   _ (pin ys 'ph -1.2) _ (world-step ys 'tap) k0 (peep ys 'eye ()) _ (ygo () 150)
   k1 [(ys 'eye) (peep ys 'dlg ()) (ys 'py)] fr (world-frame ys)
   _ (world-step ys 'weep) _ (ygo () 30) k2 [(ys 'eye) (peep ys 'dlg ())] _ (ygo () 45) kt (#(peep ys 'drops ()) + #(peep ys 'splats ())) _ (ygo () 285) k3 (peep ys 'dlg ())
   _ (world-step ys 'leave) _ (ygo () 75) k4 [(ys 'eye) (ys 'py) (ys 'px)] _ (ygo 'back 20) k5 (ys 'px)
 (test (y0 > 5.3) (y1 > 5.3) (yg = 1.0) (y2 < 4.0)
       (k0 = 'move) (k1 0 = 'kneel) (k1 1 = 0) (mag (k1 2 - 1.12) < 0.05) (has? fr "Yuki") (has? fr "1  weep") (has? fr "2  leave")
       (k2 0 = 'move) (k2 1 = ()) (kt > 0) (k3 = 0) (k4 0 = 'walk) (mag (k4 1 - eye-h) < 0.05) (k5 > k4 2 + 0.3)
       (has? (lv ("(grave [0 0 0] 0 'x " + yi + ")")) "(grave [x y z] bearing NAME TEXTURE)")))
; a ball thrown at the fence comes back off it, and off the gate while it is shut
(: yi "(texture 8 8 1 '((fill 0.1)))"
   (yb z) (: l (lv ("(void [0 -1 0] [10 4 10]) (solid (box [0 -1 0] [10 0 10])) (fence [[5 0 6] [5 0 9.5]] 1 " + yi + ") (fence [[5 0 0.5] [5 0 4]] 1 " + yi
                    + ") (gate [5 0 6] [5 0 4] 1 90 " + yi + ") (ball [7 0 " + z + "]) (start [8 0 1] 270 0)"))
            s (world-new 40 24 l "") b (s 'balls 0) _ (pins b 'p [6.0 0.4 (b 'p 2)] 'v [-5.0 0.5 0.0] 'rest 0)
            _ (each ^30 (_ \ (pin s 'dt (1.0 / 30.0), world-move s))) (b 'p 0))
   yf (yb "8") yh (yb "5")
 (test (yf > 5.0) (yh > 5.0)))
; a ball thrown at a tree comes back off its trunk, and one let fall on a lift stops on its
; platform, not the floor under it
(: tl (lv "(room [-9 0 -9] [9 4 9]) (tree [0 0 0] 7 (texture 8 8 1 '((fill (grey 0.4))))) (lift [5 0.3 5] 1.6 3 (texture 8 8 1 '((fill 0.5)))) (ball [3 0 0]) (ball [5 0 5]) (start [-6 0 -6] 0 0)")
   ts (world-new 40 24 tl "") tb (ts 'balls 0) lb (ts 'balls 1)
   _ (pins tb 'p [3.0 0.6 0.0] 'v [-5.0 0.5 0.0] 'rest 0) _ (pins lb 'p [5.3 1.5 5.3] 'v [0.0 0.0 0.0] 'rest 0)
   _ (each ^120 (_ \ (pin ts 'dt (1.0 / 30.0), world-move ts)))
 (test (tb 'p 0 > 1.0) (lb 'rest = 1) (mag (lb 'p 1 - 0.3 - lb 'r) < 0.02)))
; one at rest on a lift is woken as the lift moves, carried up on its platform and let down
; with it, at rest again each time
(: ll (lv "(room [-9 0 -9] [9 6 9]) (lift [5 0.3 5] 1.6 3 (texture 8 8 1 '((fill 0.5)))) (ball [5 0 5]) (start [-6 0 -6] 0 0)")
   ls (world-new 40 24 ll "") lc (ls 'balls 0) _ (pins lc 'p [5.3 1.5 5.3] 'v [0.0 0.0 0.0] 'rest 0)
   (lgo n) (each ^n (_ \ (pin ls 'dt (1.0 / 30.0), world-move ls)))
   _ (lgo 120) l0 [(lc 'p 1) (lc 'rest)]
   _ (each ^30 (k \ (pin (ls 'lifts 0) 'o (k / 30.0), lgo 1))) _ (lgo 30) l1 [(lc 'p 1 - ls 'lifts 0 'o) (lc 'rest)]
   _ (each ^30 (k \ (pin (ls 'lifts 0) 'o (1.0 - k / 60.0), lgo 1))) _ (lgo 60) l2 [(lc 'p 1 - ls 'lifts 0 'o) (lc 'rest)]
 (test (l0 1 = 1) (mag (l0 0 - 0.3 - lc 'r) < 0.02) (l1 1 = 1) (mag (l1 0 - 0.3 - lc 'r) < 0.02) (l2 1 = 1) (mag (l2 0 - 0.3 - lc 'r) < 0.02)))
; a ball thrown at a door comes back off its leaf while it is shut, and goes through once it
; is open: slid into its wall as the body comes near, or one opened by hand swung on its hinge
(: (dshot d at op) (: l (lv ("(room [0 0 0] [6 2 2]) (room [0 0 2.2] [6 2 4]) " + d + " (ball [1 0 1.2]) (start " + at + " 0 0)"))
      s (world-new 40 24 l "") _ (op ? (pins s 'opened {0 1} 'swing {0 1.0}) 0) (go n) (each ^n (_ \ (pin s 'dt (1.0 / 30.0), world-move s)))
      _ (go 40) b (s 'balls 0) _ (pins b 'p [1.0 0.5 1.2] 'v [0.0 1.0 4.0] 'rest 0) _ (go 30) (b 'p 2))
   dr "(door [1 0 2.1] 0.9 2)" dh "(by-hand (door [1 0 2.1] 0.9 2))"
 (test (dshot dr "[5.5 0 0.5]" 0 < 2.0) (dshot dr "[1.5 0 1.0]" 0 > 2.3) (dshot dh "[5.5 0 0.5]" 0 < 2.0) (dshot dh "[5.5 0 0.5]" 1 > 2.3)))
; a ball let fall in a car lands on its floor, not the track's bed under it, comes back off its
; end, and rides out on its floor as the car leaves, held in it, not thrown about
(: cr (lv "(room [-30 -1 -3.2] [30 3 6]) (solid (box [-30 -1 -0.2] [30 0 6])) (start [0 0 3] 0 0) (train [-5 0 -2.8] [5 2.3 -0.2] (door [0 0 -0.2] 1.2 2) -40) (ball [2 0 -1.5])")
   cs (world-new 40 24 cr "") cb (cs 'balls 0) _ (pins cb 'p [2.0 1.0 -1.5] 'v [3.0 0.0 0.0] 'rest 0)
   (cgo n) (each ^n (_ \ (pin cs 'dt (1.0 / 30.0), world-move cs)))
   _ (cgo 100) c0 [(cb 'p 0) (cb 'p 1) (cs 'cars 0 'ph)]
   hs (map (_ \ (cgo 3, [(cb 'p 0 - cs 'cars 0 'o) (cb 'p 1)])) ^30) c1 [(cs 'cars 0 'ph) (cs 'cars 0 'o)]
 (test (c0 2 = 'hold) (c0 0 < 5.0) (mag (c0 1 - 0.16) < 0.02) (c1 0 = 'go) (c1 1 < -2.0)
       (all (h \ mag (h 1 - 0.16) < 0.03 && h 0 < 5.0 && h 0 > -5.0) hs)))
; the loop: the same from the same seed, loud at first and worn nearly away a hundred and
; fifty times round
(: dc0 (decay-new 0.25) dcl (dc0 'len) dct (iota 4000 * (dcl / 4000.0))
   (dce k) (: y (decay-at dc0 (dct + k * dcl)) (sqrt (net (y * y) / 4000.0))))
 (test (dcl > 5.0) (decay-at (decay-new 0.25) (dct + 0.0) = decay-at dc0 dct) (dce 0 > 0.05) (dce 150 < 0.3 * dce 0)
       (dce (int (dc0 'gone / dcl + 0.5) + 1) = 0.0) (0.0 < dce (int (dc0 'gone / dcl + 0.5) - 2)) (0.0 < dc0 'gone <= 902 * dcl))
; the way between levels: a herald within its reach makes for the eye and meeting it leaves
; for its file, by the level's own folder; a bed tapped is lain on, then left for its entry;
; and one come to by a bed's entry wakes on it and stands beside it, on its left
(: wtx "(: face (texture 4 4 1 '((fill (rgb 1 1 0)))))"
   way (world-read (wtx + "(level \"w\" (room [-6 0 -6] [6 4 6]) (start [0 0 -5] 0 0)
                          (herald [0 2 3] 1 2.5 face \"next.l\" 'in) (sleep-bed [3 0 -3] 0 \"back.l\" ())
                          (wake-bed 'up [-3 0 -3] 0) (entry 'door [0 0 5] 180 0))"))
   (frames st n) (? (n < 1 || st 'done) st (: _ (pin st 'dt 0.05) _ (world-move st) (frames st (n - 1))))
   far (frames (world-new 16 8 way "lv/") 20)
   near (frames (pins (world-new 16 8 way "lv/") 'pz 1.0) 40)
   bed (world-new 16 8 way "lv/") _ (pins bed 'px 2.0 'pz -2.0 'py 1.6 'th (pi / 2.0) 'ph -1.0)
   lie (frames (world-step bed 'tap) 200) at (world-at 16 8 way "lv/" 'door) up (world-at 16 8 way "lv/" 'up) ue (up 'eye) uy (up 'py) woke (frames up 100)
 (test (!(far 'done)) (peep far 'goto () = ()) (near 'done) (near 'goto = ["lv/next.l" 'in])
       (lie 'eye = 'lie) (lie 'goto = ["lv/back.l" ()]) (lie 'py < 0.6)
       (at 'pz = 5.0) (abs (at 'th - pi) < 1e-9) (ue = 'move) (uy < 0.6)
       (woke 'eye = 'walk) (abs (woke 'py - 1.6) < 0.01) (woke 'px < -3.9) (!(woke 'done))))
; ..and come by an entry, a level's cars have already left, so none cries out of earshot of it
(: gl (lv "(room [-30 0 -3.2] [30 3 6]) (start [0 0 -1.5] 0 0) (strip-light [0 3 3]) (entry 'far [20 0 4] 0 0)
           (train [-5 0 -2.8] [5 2.3 -0.2] (door [0 0 -0.2] 1.2 2) -40)")
   gs (world-at 40 24 gl "" 'far) _ (each ^40 (_ \ (pin gs 'dt 0.05, world-move gs)))
 (test ((world-at 40 24 gl "" ()) 'cars 0 'ph = 'wait) (gs 'cars 0 'ph = 'gone) (gs 'cars 0 'o = -40.0)))
; the prop kit: dice the same each read and their own per name, ranges thrown inside them,
; the rounded min and max; a lathe and a sweep solid where they turn and run, air past them;
; a scatter kept inside, apart and on its ground; a line-up as many as fit, facing across
(: S (k \ cite 'scenery k) dice (S 'dice) pick (S 'pick) smin (S 'smin) smax (S 'smax)
   scatter (S 'scatter) line-up (S 'line-up)
   (rd x) (int (x * 1e6 + 0.5))
   (lq s) (world-read ("(: m (texture 8 8 1 '((fill 0.5)))) (level \"t\" " + s + ")"))
   lt (lq "(room [0 0 0] [4 3 4]) (lathe [1 0 1] [[0.3 0] [0.3 1]] 8 m) (lathe [3 0 3] [[0.4 0] [0.4 0] [0 1]] 8 m)")
   lb (world-new 8 8 lt "" 'sc 'brushes) (lm x y z) (brush-medium lb [x y z])
   sw (lq "(room [0 0 0] [4 3 4]) (sweep [[0.5 0.5 0.5] [2 0.5 0.5] [2 0.5 0.5] [2 0.5 3]] 0.1 6 m)")
   sb (world-new 8 8 sw "" 'sc 'brushes) (sm x y z) (brush-medium sb [x y z])
   all20 (scatter 5 [[0 0] [4 4]] 20 (\ at d s [at d]) {})
   apart (scatter 5 [[0 0] [4 4]] 40 (\ at d s at) {'gap 1.5 'ground (\ x z (x + z))})
   tri (scatter 9 [[0 0] [4 0] [0 4]] 40 (\ at d s at) {'bearing 30})
   ln (line-up 1 [0 0 0] [3 0 0] (\ a d s w [a d w]) {'w 1 'gap 0.1})
   sc (lv "(room [0 0 0] [4 3 4]) (scatter 3 [[0.5 0.5] [3.5 3.5]] 6 (\\ at d s (bulb at (rgb 1 1 1))) {'ground 2})")
 (test (dice 7 'size = dice 7 'size) (dice 7 'size != dice 7 'girth) (dice 7 'size != dice 8 'size)
       (0.0 <= dice 7 'size < 1.0) (pick 7 'w 2 = 2.0) (2.0 <= pick 7 'w [2 3] <= 3.0)
       (pick 7 'w [2 3] = pick 7 'w [2 3])
       (smin 1.0 5.0 2.0 = 1.0) (smin 1.0 1.0 2.0 = 0.5) (smax 1.0 1.0 2.0 = 1.5) (S 'ease 5.0 0.0 10.0 = 0.5)
       (#(lt 'brushes) = 3) (lm 1.0 0.5 1.0 = 0) (lm 1.25 0.5 1.0 = 0) (lm 1.4 0.5 1.0 = 1) (lm 1.0 1.2 1.0 = 1)
       (lm 3.0 0.1 3.3 = 0) (lm 3.0 0.9 3.3 = 1)
       (has? (lq "(room [0 0 0] [4 3 4]) (lathe [1 0 1] [[0.3 0] [0.3 1]] 2 m)") "(lathe [x y z] [[r y] ..] sides SKIN)")
       (#(sw 'brushes) = 3) (sm 1.2 0.5 0.5 = 0) (sm 2.0 0.5 0.5 = 0) (sm 2.0 0.5 2.0 = 0) (sm 1.2 0.8 0.5 = 1) (sm 1.0 0.5 2.0 = 1)
       (#all20 = 20) (all20 = scatter 5 [[0 0] [4 4]] 20 (\ at d s [at d]) {})
       (all (q \ 0.0 <= q 0 0 <= 4.0 && 0.0 <= q 0 2 <= 4.0 && q 0 1 = 0.0 && 0.0 <= q 1 <= 360.0) all20)
       (1 < #apart < 40) (all (p \ p 1 = p 0 + p 2) apart)
       (all (p \ all (q \ p = q || 2.25 <= (p 0 - q 0) * (p 0 - q 0) + (p 2 - q 2) * (p 2 - q 2)) apart) apart)
       (0 < #tri < 40) (all (p \ p 0 + p 2 <= 4.0) tri)
       (#ln = 2) (map (q \ rd (q 0 0)) ln = [500000 1600000]) (rd (ln 0 1) = 180000000) (ln 1 2 = 1.0)
       (#(sc 'bulbs) = 6) (all (b \ b 'at 1 = 2.0) (sc 'bulbs))))
; materials: every kind skins a brush; tile's as station's tiles texel for texel under seed 0;
; the same seed the same picture and another not; a range thrown inside it; felt as its kind;
; a kind or a parameter not known said back with what is
(: M (cite 'scenery 'material) sw (cite 'swatch 'swatch) T (cite 'scenery 'texture)
   kinds ['wood 'plank 'stone 'sandstone 'brick 'tile 'cobble 'mud 'concrete 'metal 'cloth 'carpet 'gravel 'sand 'soil 'grass]
   (in k) (lv ("(room [0 0 0] [4 3 4]) (skin {'all (material '" + show k + " 3 {})} (solid (box [1 0 1] [2 1 2])))"))
   (pic t) (show (sw (t 'w) (t 'h) (t 'layers)))
   st (T 32 32 0.6 [['fill '(rgb 0.8 0.8 0.78)] ['checker 16 16 '(rgb 0.7 0.7 0.68)] ['noise 5 0.1] ['grid 16 16 1 '(rgb 0.4 0.4 0.4)]])
   mt (M 'tile 0 {'a [0.8 0.8 0.78] 'b [0.7 0.7 0.68] 'grout [0.4 0.4 0.4]})
 (test (all (k \ tablet? (in k)) kinds) (pic mt = pic st) (mt 'm = 0.6)
       (pic (M 'stone 1 {}) = pic (M 'stone 1 {})) (pic (M 'stone 1 {}) != pic (M 'stone 2 {}))
       (tablet? (M 'wood 4 {'rings [5 9]})) (M 'wood 4 {} 'feel = 'wood) (M 'grass 4 {} 'feel = 'soft)
       (has? (lv "(room [0 0 0] [4 3 4]) (skin {'all (material 'tofu 3 {})} (solid (box [1 0 1] [2 1 2])))") "a KIND of")
       (has? (lv "(room [0 0 0] [4 3 4]) (skin {'all (material 'wood 3 {'hue 1})} (solid (box [1 0 1] [2 1 2])))") "wood takes")
       (has? (lv "(room [0 0 0] [4 3 4]) (skin {'all (material 'wood 1.5 {})} (solid (box [1 0 1] [2 1 2])))") "(material KIND seed")))
; rocks: one cut brush, solid at its middle and air past it; a seed the same rock and another
; not; every shape reads; an outcrop several, a cairn stacked up; a shape or a key not known
; said back. grounds: hills within their height, ridges over it, a mound's top and foot, a
; terrace flat then rising, a channel's bed; a land laid over a ground
(: S (k \ cite 'scenery k) R (S 'rock)
   (rk s) (lv ("(room [-4 0 -4] [4 3 4]) " + s))
   (y0 b) (peep (b 'shape) 'prism () @ () (b 'shape 'box 0 1) p (p 0))
   bo (rk "(rock [0 0 0] 5 'boulder)") bb (world-new 8 8 bo "" 'sc 'brushes) (bm x y z) (brush-medium bb [x y z])
   shapes ['boulder 'pebble 'scree 'slab 'standing 'altar 'outcrop 'cairn]
   oc (rk "(rock [0 0 0] 5 'outcrop)") ca (rk "(rock [0 0 0] 5 'cairn)") (rocks l) (filter (b \ b 'air = 0) (l 'brushes)) cb (rocks ca)
   hl (S 'hills 3 {'height 2}) rg (S 'ridges 3 {'height 2})
   pts (map (i \ [(1.7 * i) (2.9 * (i % 7))]) ^60)
   md (S 'mound [1 1] 3 1 2.0) tr (S 'terrace (\ x z x) 1.0) ch (S 'channel [[0 0] [10 0]] 1.0 0.5)
   gl (rk "(ground-of 'grass [[-2 -1] [2 1]] 1 (hills 3 {}))")
 (test (#(bo 'brushes) = 2) (bm 0.0 0.3 0.0 = 0) (bm 3.0 0.3 3.0 = 1) (bm 0.0 2.0 0.0 = 1)
       (show (bo 'brushes) = show (rk "(rock [0 0 0] 5 'boulder)" 'brushes))
       (show (bo 'brushes) != show (rk "(rock [0 0 0] 6 'boulder)" 'brushes))
       (all (k \ tablet? (rk ("(rock [0 0 0] 2 '" + show k + ")"))) shapes)
       (tablet? (rk "(rock [0 0 0] 2 {'like 'slab 'size [3 0.2 2] 'skin 'sandstone})"))
       (3 <= #(rocks oc) <= 5) (4 <= #cb <= 7) (all (i \ y0 (cb i) < y0 (cb (i + 1))) ^(#cb - 1))
       (has? (rk "(rock [0 0 0] 2 'pudding)") "a SHAPE") (has? (rk "(rock [0 0 0] 2 {'like 'slab 'hue 1})") "a rock takes")
       (all (q \ abs (hl (q 0) (q 1)) <= 2.0) pts) (hl 4.2 1.1 = hl 4.2 1.1) (any (q \ abs (hl (q 0) (q 1)) > 0.2) pts)
       (all (q \ 0.0 <= rg (q 0) (q 1) <= 2.0) pts)
       (md 1.0 1.0 = 2.0) (md 1.5 1.0 = 2.0) (md 5.0 1.0 = 0.0) (0.0 < md 3.0 1.0 < 2.0)
       (tr 0.5 0.0 = 0.0) (tr 1.5 0.0 = 1.0) (0.0 < tr 0.9 0.0 < 1.0)
       (ch 5.0 0.0 = -0.5) (ch 5.0 0.9 = -0.5) (ch 5.0 3.0 = 0.0) (-0.5 < ch 5.0 1.5 < 0.0)
       (S 'rise md md 1.0 1.0 = 4.0) (S 'blend md (\ x z 0.0) 0.1 5.0 5.0 > 0.0) (S 'carve md (\ x z 0.0) 0.1 5.0 5.0 < 0.0)
       (#(gl 'drapes) = 1) (gl 'drapes 0 'land = 1) (#(gl 'drapes 0 'rows) = 3) (#(gl 'drapes 0 'rows 0) = 5)))
(: (near1 a b) (abs (a 0 - b 0) < 1e-9 && abs (a 1 - b 1) < 1e-9))
; furniture: station's desk from the desk's own sizes, its top over the floor; a quarter turn
; swaps its spans; every kind reads; drawers and doors counted; a seed a size thrown again and
; another not; a role's skin changed; books on the shelves; a kind or a key not known said back
(: S (k \ cite 'scenery k)
   (fu s) (lv ("(room [-4 0 -4] [4 3 4]) " + s))
   (solids l) (filter (b \ b 'air = 0) (l 'brushes)) (bxs s) (map (b \ b 'shape 'box) (solids (fu s)))
   (near a b) (all (i \ all (j \ abs (a i j - b i j) < 1e-9) ^3) ^2)
   dk (fu "(furnish 'desk [0 0 0] 0 {})") db (bxs "(furnish 'desk [0 0 0] 0 {})") (bm x y z) (brush-medium (world-new 8 8 dk "" 'sc 'brushes) [x y z])
   kinds ['table 'desk 'chair 'stool 'bench 'bed 'shelf 'cabinet 'counter 'crate 'carton 'stand 'sofa]
   (n s) #(solids (fu s))
 (test (near (db 0) [[-0.8 0.71 -0.4] [0.8 0.75 0.4]]) (near (db 1) [[-0.78 0.0 -0.38] [-0.74 0.71 0.38]])
       (near (db 2) [[0.74 0.0 -0.38] [0.78 0.71 0.38]]) (near (db 3) [[-0.74 0.15 0.3] [0.74 0.65 0.33]]) (#db = 4)
       (bm 0.0 0.73 0.0 = 0) (bm 0.0 0.5 0.0 = 1) (bm 0.76 0.3 0.0 = 0)
       (near (bxs "(furnish 'desk [0 0 0] 90 {})" 0) [[-0.4 0.71 -0.8] [0.4 0.75 0.8]])
       (all (k \ n ("(furnish '" + show k + " [0 0 0] 30 {})") > 0) kinds)
       (n "(furnish 'cabinet [0 0 0] 0 {})" = 9) (n "(furnish 'cabinet [0 0 0] 0 {'drawers 0 'doors 2})" = 5)
       (n "(furnish 'counter [0 0 0] 0 {})" = 6) (n "(furnish 'crate [0 0 0] 0 {'slats 3})" = 13)
       (show (fu "(furnish 'table [0 0 0] 0 {'w [1 2] 'seed 4})") = show (fu "(furnish 'table [0 0 0] 0 {'w [1 2] 'seed 4})"))
       (show (fu "(furnish 'table [0 0 0] 0 {'w [1 2] 'seed 4})") != show (fu "(furnish 'table [0 0 0] 0 {'w [1 2] 'seed 5})"))
       (show (fu "(furnish 'desk [0 0 0] 0 {'skin {'top 'stone}})") != show dk)
       (n "(furnish 'shelf [0 0 0] 0 {'fill 'books})" > n "(furnish 'shelf [0 0 0] 0 {})" + 20)
       (has? (fu "(furnish 'throne [0 0 0] 0 {})") "a KIND") (has? (fu "(furnish 'desk [0 0 0] 0 {'hue 1})") "furniture takes")
       (has? (fu "(furnish 'desk [0 0 0] 0 'oak)") "(furnish KIND")))
; plants: every species reads as a tree, a 'like changing one; a plain tree carries none; grown,
; a seed the same plant and another not, an oak's trunk its height, grass blades and no wood,
; the dead leafless; a species, a key, a level's key or a leaf's kind not known said back
(: (pl s) (lv ("(street [-9 0 -9] [9 9 9]) " + s))
   (sp s) (pl s 'trees 0 'species)
   kinds ['ailanthus 'oak 'birch 'pine 'willow 'shrub 'grass 'reed 'fern 'dead]
   (gr k sd) (bough-grow [sd 1.0 1.0 (sp ("(plant [0 0 0] 1 '" + show k + ")"))])
   (leaves g) (net (g 'kind = 2.0))
   ok (gr 'oak 4) gs (gr 'grass 4)
 (test (all (k \ tablet? (sp ("(plant [0 0 0] 3 '" + show k + ")"))) kinds)
       (sp "(plant [0 0 0] 3 {'like 'birch 'height 20})" 'height = 20) (sp "(plant [0 0 0] 3 {'like 'birch 'height 20})" 'crown = 2.5)
       (sp "(plant [0 0 0] 3 {'height 2 'leaf {'kind 'needle}})" 'leaf 'kind = 'needle)
       (!(elem 'species (keys (pl "(tree [0 0 0] 7 (texture 8 8 1 '((fill (grey 0.4)))))" 'trees 0))))
       (show (ok 'segs) = show (gr 'oak 4 'segs)) (show (ok 'segs) != show (gr 'oak 5 'segs))
       (ok 'tn = 5) (2.6 <= ok 'fork 1 <= 3.4) (#(bough-solid ok) = 5) (leaves ok > 1000)
       (#(gs 'segs) = 0) (#(bough-solid gs) = 0) (leaves gs > 100) (leaves (gr 'dead 4) = 0) (leaves (gr 'pine 4) > 1000)
       (has? (pl "(plant [0 0 0] 3 'kudzu)") "a SPECIES") (has? (pl "(plant [0 0 0] 3 {'like 'oak 'hue 1})") "a plant takes")
       (has? (pl "(plant [0 0 0] 3 {'levels [{'n 2 'hue 1}]})") "a level takes")
       (has? (pl "(plant [0 0 0] 3 {'leaf {'kind 'scale}})") "a leaf's 'kind") (has? (pl "(plant [0 0 0] 'x 'oak)") "(plant [x y z]")))
;; a tree cut through its trunk and its crotch: each cut's face, charred at its middle, wound
;; as the wood round it is, so it closes the cut seen from outside
(: bt (bough-grow [7 1.0 1.0]) m (bough-burnt bt 0 1.0 [[0.0 1.0 0.0] 4.2]) v (m 0)
   (way t) (: p (i \ take 3 (v (t i))) N (drop 5 (take 8 (v (t 0)))) (dot (cross (c- (p 1) (p 0)) (c- (p 2) (p 0))) N > 0.0 ? 1 -1))
   (cap? t) (drop 8 (v (t 0)) = [0.05 0.035 0.03])
   cs (filter cap? (m 1)) ws (filter (t \ !(cap? t)) (m 1))
 (test (#cs > 0) (all (t \ way t = -1) cs) (2 * #(filter (t \ way t = -1) ws) > #ws)))
; produce: every kind a closed thing, its rows its profile's, each row's last point its first,
; resting where it was put; a seed the same one and another not; a 'like changing one; a pile a
; painted sheet and whole ones gapped apart, thrown by its seed; the sheet and things swung by a
; bearing; drawn; a stand's slope and lip where they stand; a kind or a key not known said back
(: (pr s) (lv ("(room [-9 0 -9] [9 9 9]) " + s))
   (one k) (pr ("(produce [1 2 3] 5 '" + show k + ")") 'drapes 0)
   (low d) (foldl (\ m r (foldl (\ m q (min m (q 1))) m r)) 1e9 (d 'rows))
   kinds ['apple 'potato 'onion 'carrot 'radish 'cabbage]
   pd (pr "(pile 'apple [0 0 0] 0 3 {'w 1.2 'd 0.9 'dense 12})" 'drapes) sh (pd 0) th (pd 1) m (th 'wrap) C #<(th 'rows)
   tn (pr "(pile 'carrot [0 0 0] 90 3 {'w 2 'd 0.6})" 'drapes 0)
   (span d k) (: qs (catmap (filter two?) (d 'rows)) vs (map (q \ q k) qs) [(foldl min 1e9 vs) (foldl max -1e9 vs)])
   st (lv "(room [-4 0 -4] [4 3 4]) (furnish 'stand [0 0 0] 0 {'w 1.2 'd 0.8 'low 0.7 'h 1 'lip 0.05})")
   bm (brush-medium (world-new 8 8 st "" 'sc 'brushes))
   ap (lv "(room [-4 0 -4] [4 3 4]) (ambient (rgb 1 1 1)) (start [0 0.2 -1] 0 -40) (produce [0 0.8 0] 1 'cabbage)")
   no (lv "(room [-4 0 -4] [4 3 4]) (ambient (rgb 1 1 1)) (start [0 0.2 -1] 0 -40)")
   (pens l) (show (world-pens (world-new 64 40 l "")))
 (test (all (k \ (: d (one k) (d 'wrap = #(d 'rows) && all (r \ r 0 = r (#r - 1)) (d 'rows)))) kinds)
       (all (k \ abs (low (one k) - 2.0) < 1e-9) kinds)
       (show (one 'onion) = show (one 'onion)) (show (one 'onion 'rows) != show (pr "(produce [1 2 3] 6 'onion)" 'drapes 0 'rows))
       (#<(pr "(produce [0 0 0] 1 {'like 'apple 'sides 9})" 'drapes 0 'rows) = 10)
       (#pd = 2) (sh 'wrap = 0) (m = 7) (C = 8) (#(th 'rows) % (m + 1) = m)
       (all (i \ th 'rows (m + (m + 1) * i) = map (_ \ ()) ^C) ^(#(th 'rows) // (m + 1)))
       (show pd = show (pr "(pile 'apple [0 0 0] 0 3 {'w 1.2 'd 0.9 'dense 12})" 'drapes))
       (show (th 'rows) != show (pr "(pile 'apple [0 0 0] 0 4 {'w 1.2 'd 0.9 'dense 12})" 'drapes 1 'rows))
       (near1 (span sh 0) [-0.6 0.6]) (near1 (span sh 2) [-0.45 0.45]) (near1 (span tn 0) [-0.3 0.3]) (near1 (span tn 2) [-1.0 1.0])
       (sh 'rows 0 0 1 < sh 'rows (#(sh 'rows) - 1) 0 1)
       (bm [0.0 0.84 0.0] = 0) (bm [0.0 0.9 0.0] = 1) (bm [0.0 0.8 0.385] = 0) (bm [0.0 1.03 0.399] = 0) (bm [0.0 1.03 0.3] = 1)
       (pens ap != pens no)
       (has? (pr "(produce [0 0 0] 1 'kale)") "a KIND") (has? (pr "(produce [0 0 0] 1 {'like 'apple 'hue 1})") "produce takes")
       (has? (pr "(produce [0 0 0] 'x 'apple)") "(produce [x y z]") (has? (pr "(pile 'apple [0 0 0] 0 3 'big)") "(pile KIND")
       (has? (pr "(wrapped 1 (produce [0 0 0] 1 'apple))") "(wrapped rows")))
; ..a desk in moves and a turn stepped comes out of them as a book does, its bearing turned
(: fkv ((cite 'vi) 'vi-open "")
   fkf "(move [0.15 0 -0.15] (turn 90 [-27.35 7.4] (move [0.8 0 0.25] (furnish 'desk [-28.15 0 7.15] 160 {}))))"
   _ ((cite 'vi) 'vload fkv ["(level \"t\"" "  (room [-30 0 4] [-24 3 10])" ("  " + fkf) "  (start [-27 0 5] 0 0))"] "t.l")
   fkw {'w 320 'h 160 'paper (cask (320 * 160 * 4))} fk (edit-new fkw fkv "")
   _ (edit-events fk [['down 29] ['down 17] ['text "w"] ['up 17] ['up 29] ['down 17] ['text "w"] ['up 17]])
   _ (pin fk 'sel [3]) _ (edit-events fk [['down 52] ['text "."] ['up 52]])
   fl (fkv 'lines 2)
 (test (snip fl 0 18 = "  (furnish 'desk [") (snip fl (#fl - 7) #fl = "-95 {})") (fk 'sel = [3])))
(test_fin ())
; a level's reading told to the loading screen, a form at a time
(: n {'n 0} l (world-reading "(: a 1) (level \"t\" (room [0 0 0] [2 2 2]))" (_ \ _ \ pin n 'n (n 'n + 1)))
   (test (tablet? l) (n 'n = 2)))

; a scene kept: where a nest is, the first scene is stowed in its cache and the next read back
; from there, the same but for its memo, spent
(: kd (cwd 0 + "/out/.world-kept-" + show (getpid 0)) n0 (getenv "LOVE_NEST")
   _ (hark ["rm" "-rf" kd], mkdir kd 448, setenv "LOVE_NEST" kd)
   ; ..each read afresh, as a run reads its file: a scene pins what it grows into its level
   (klv _) (world-read "(level \"t\" (room [0 0 0] [6 3 6]) (start [3 0 1] 0 0))")
   ka (world-new 40 25 (klv ()) "test/lore/" 'sc)
   kf (filter (f \ #f > 6 && snip f (#f - 6) #f = ".scene") (readdir (kd + "/cache/lore/")))
   kb (world-new 40 25 (klv ()) "test/lore/" 'sc)
   ; ..the cache kept under its bytes: of six old ones of 300 MB, holes, the newest three stay
   ; beside seven small ones; with 2.3 GB free, one; past one of 2 GB, none
   kc (kd + "/cache/lore/") (hole n mb) (: q (open (kc + n) "w") _ (close q) w (openfd (kc + n) 1) _ (truncate w (mb * 1048576) 0) (close w))
   _ (each ^6 (i \ (hole "o\(i).scene" 300, utime "\(kc)o\(i).scene" (1000000 * (i + 1)))))
   _ (each ^7 (i \ (hole "s\(i).scene" 0, utime "\(kc)s\(i).scene" 100000000)))
   (held fr) (: _ (scene-sweep kc fr) (sort (filter (f \ #f = 8) (readdir kc)))) (os l) (filter (f \ f 0 = 111) l)
   h1 (held ()) h2 (held 2300000000) _ (hole "z0.scene" 2000) _ (utime "\(kc)z0.scene" (clock () + 5000)) h3 (held ())
   _ (setenv "LOVE_NEST" n0, hark ["rm" "-rf" kd])
   (canon x) (kind x @ 'tablet ['T (map (k \ [k (canon (x k))]) (sort (keys x)))] 'chain (map canon x) x)
   ks (filter (k \ k != 'memo) (sort (keys ka)))
   ; ..and a tree's trunk grown into its level on a hit as on a miss
   (tlv _) (world-read "(level \"t\" (room [-9 0 -9] [9 4 9]) (tree [0 0 0] 7 (texture 8 8 1 '((fill (grey 0.4))))) (start [6 0 0] 0 0))")
   _ (mkdir kd 448, setenv "LOVE_NEST" kd) ta (world-new 40 25 (tlv ()) "test/lore/") tb (world-new 40 25 (tlv ()) "test/lore/")
   _ (setenv "LOVE_NEST" n0, hark ["rm" "-rf" kd])
   (trunk st) (<(st 'lvl 'trees) 'trunk)
 (test (#kf = 1) (os h1 = ["o3.scene" "o4.scene" "o5.scene"]) (#h1 = 10) (os h2 = ["o5.scene"]) (h3 = ["z0.scene"]) (scene-bound () 5 = 1073741824) (scene-bound 5000000000 1000 = 500000100) (scene-bound 50000000000 0 = 1073741824) (scene-bound 0 0 = 0) (tablet? (ka 'memo 'v)) (kb 'memo 'v = ()) (sort (keys kb) = sort (keys ka))
       (all (k \ show (canon (ka k)) = show (canon (kb k))) ks)
       (two? (trunk ta)) (show (trunk tb) = show (trunk ta)) (#(tb 'lvl 'brushes) = #(ta 'lvl 'brushes))))
; a phone's tap acts wherever it is, its corners and its bottom too
(: t (world-tap {'win {'w 900 'h 400}})
 (test (all (q \ t (q 0) (q 1) = [101]) [[450 390] [10 10] [890 10] [450 200]])))
; a jump by a touch: what it could be as the touch came down holds though a ledge was run off since, but
; not once jumped since, and one come down in the air is kept for the landing
(: (lvl _) (: s (world-new 160 100 (world-read "(level \"t\" (room [0 0 0] [10 9 14]) (start [5 0 1.5] 0 0))") "") _ (each ^3 (_ \ (pin s 'dt 0.05, world-move s))) s)
   a (lvl 0) p (world-poised a) _ (world-hop a p) v (a 'fv)
   b (lvl 0) p2 (world-poised b) _ (pins b 'mt (b 'mt + 1.0) 'fv -1.0) q (world-poised b) _ (world-hop b p2) v2 (b 'fv)
   c (lvl 0) p3 (world-poised c) _ (world-hop c p3) _ (pin c 'fv 1.0) _ (world-hop c p3) v3 (c 'fv)
   d (lvl 0) _ (pins d 'mt (d 'mt + 1.0) 'fv -1.0) _ (world-hop d 0) v4 (d 'fv)
 (test p p2 p3 (v > 4.0) !q (v2 > 4.0) (v3 = 1.0) (v4 = -1.0) (d 'jq = d 'mt)))
; a scene's key: the same for the same level whatever the order its tablets keep or where it is
; come to, but on a surface; another level's, another file's and another maker's are others
(: kd (cwd 0 + "/out/.world-key-" + show (getpid 0) + "/") _ (mkdir kd 448)
   (kl r t) (world-read "(level \"t\" (room [0 0 0] [6 3 \(r)]) (poster [1 1 0] 0.6 0.9 \"pp.ppm\") (start [\(t) 0 1] 0 0))")
   (sf t) (world-read "(level \"t\" (surface 'plane 10 10) (void [-2 -1 -2] [12 3 12]) (solid (box [0 -1 0] [10 0 10])) (start [\(t) 0 5] 90 0))")
   (put t) (: p (open (kd + "pp.ppm") "w") (say p t, close p, 0))
   _ (put "P6\n1 1\n255\nabc") ka (scene-key kd (kl 6 1) kd) kb (scene-key kd (kl 6 2) kd) kc (scene-key kd (kl 7 1) kd)
   _ (put "P6\n1 1\n255\nabd") kx (scene-key kd (kl 6 1) kd) s1 (scene-key kd (sf 3) kd) s2 (scene-key kd (sf 4) kd)
   rl (kl 6 1) rk (foldl (\ t k (pin t k (rl k))) {} (rev (keys rl)))
   _ (put "P6\n1 1\n255\nabc") kr (scene-key kd rk kd) _ (hark ["rm" "-rf" kd])
   (src f) (uread f)
   m0 (scene-made src) m1 (scene-made (f \ f = "src/apps/lore/brush.l" ? [0 "x"] (src f))) m2 (scene-made (_ \ ()))
   ; ..and no level's maker borrows a library of lore's that is neither listed nor known not to make
   exempt ['lore 'rove 'console 'gpu 'walk 'mixer 'gesture 'decay 'flicker 'tumble]
   (names l) (: (go i w a) ((i = #l || l i = 41) ? (w = "" ? a (w . a)) (: c (l i) ((96 < c && c < 123) || c = 45 ? (go (i + 1) (w + snip l i (i + 1)) a) (go (i + 1) "" (w = "" ? a (w . a)))))) (go 0 "" ()))
   (bors f) (catmap (l \ (#l > 9 && snip l 0 8 = "(borrow " ? (names (snip l 8 #l)) ())) (lines <>(src f)))
   bad (catmap (f \ filter (n \ two? (src "src/apps/lore/\(n).l") && !(elem n (map string exempt)) && !(elem "src/apps/lore/\(n).l" scene-by)) (bors f)) (filter (f \ snip f 0 13 = "src/apps/lore") scene-by))
 (test (elem "neon" (bors "src/apps/lore/world.l")) (string? ka) (ka = kb) (ka != kc) (ka != kx) (kr = ka) (s1 != s2) (string? m0) (m0 != m1) (m2 = 0 || m2 = ())
       (bad = ())))
(test_fin ())
(puts "world: ok\n")
