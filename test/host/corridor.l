; test/host/corridor.l -- the indoor level and its file, headless: the test corridor read
; and drawn in both palettes and as kitty's pixels; the lamps, what shines, the failing
; strip; the door shut until the player is near and open after; the walls and the shut
; doorway stopping a walk; levels that will not read, and why; a level read again when
; its file changes, the player kept where they stand; and the sign's letters.
; not in the corpus: a crew module. run: cat test/00-init.l test/host/corridor.l | out/love

(borrow 'corridor)
(borrow 'mesh)
(borrow 'neon)
(borrow 'posix)
(borrow 'view)     ; pi

(: (rows s) (: (go i k) (i + 2 <= #s ? (go (i + 1) (k + ("\r\n" = snip s i (i + 2)))) k) (1 + go 0 0))
   hall (corridor-load "src/apps/lore/levels/hall.l")
   (at w h) (corridor-new w h hall "src/apps/lore/levels/")
   (px f st x y) (peep f (y * st 'w + x) 0)
   (lum c) ((c >> 16 & 255) + (c >> 8 & 255) + (c & 255))
   (steps st k n) (each ^n (_ \ (corridor-step st k, corridor-move st)), st)
   (lv s) (corridor-read ("(level \"t\" " + s + ")"))
   (put p s) (: q (open p "w") (say q s, close q)))

; --- the corridor's level: its rooms, the door between them found in their shared wall,
; --- the lights, the poster and the sign
(test (tablet? hall) (hall 'name = "the test corridor") (#(hall 'rooms) = 2) (#(hall 'strips) = 4)
      (hall 'doors 0 'ax = 'z) (hall 'doors 0 'a = 12.4) (hall 'doors 0 'b = 12.6)
      (hall 'start 'at = [0.0 1.0]) (#(hall 'posters) = 1) (hall 'signs 0 'text = "LOUNGE"))
; --- levels that will not read, and why
(test (string? (corridor-read "(room 0 0 1 1 2)")) (string? (lv "")) (has? (lv "") "needs a room")
      (has? (lv "(room 0 0 1 1)") "not understood") (has? (lv "(room 0 0 1 1 2) (lamp 0 0)") "(lamp 0 0)")
      (has? (lv "(room 0 0 2 2 2) (door 5 5 1 2)") "between two rooms")
      (tablet? (lv "(room 0 0 2 2 2) (room 0 2.2 2 4 2) (door 1 2.1 1 2)"))
      (lv "(room 0 0 2 2 2) (room 2.2 0 4 2 2) (door 2.1 1 1 2)" 'doors 0 'ax = 'x)
      (string? (corridor-load "/nonexistent/level.l")))
; --- the frame: half the pixel rows in cells, the same state the same frame, in the 256
; --- palette and in 24 bits; kitty's pixels a picture and its own id
(: st (at 80 48) f (corridor-frame st) f2 (corridor-frame st)
   deep (corridor-frame (pin (at 80 48) 'deep 1))
   kit (corridor-frame (corridor-size (pin (at 80 48) 'kitty 1) 80 24))
 (test (rows f = 24) (f = f2) (rows deep = 24) (f != deep)
       (has? f "38;5;") (has? deep "38;2;") (has? kit "_Ga=T") (has? kit "i=7,")))
; --- the light: the floor ahead lit; a strip bright overhead; the failing one mostly on and
; --- now and then stammering; the door's lamps red while it is shut, green once open; the
; --- sign pink
(: st (at 80 48) f (corridor-pens st) sc (st 'sc)
   up (corridor-pens (pins (at 80 48) 'ph 1.2 'pz 5.0))
   ks (map (t \ corridor-ks sc (t / 10.0) [0.0]) ^600)
   bad (map (k \ k 2) ks)
   open (corridor-ks sc 0.0 [1.0])
   east (corridor-pens (pins (at 80 48) 'th (pi / 2.0) 'pz 7.0 'px -0.6))
   (pink? c) ((c >> 16 & 255) > (c >> 8 & 255) + 40 && (c & 255) > (c >> 8 & 255))
   n #(sc 'lights)
 (test (n = 10) (40 < lum (px f st 40 44)) (700 < foldl max2 0 (map (i \ lum (peep up i 0)) ^(80 * 48)))
       (any (k \ k < 0.5) bad) (all (k \ 0.0 <= k <= 1.0) bad) (300 < #(filter (k \ k = 1.0) bad))
       (all (k \ k 0 = 1.0 && k (n - 4) = 1.0 && k (n - 3) = 0.0) ks)
       (open (n - 4) = 0.0) (open (n - 3) = 1.0)
       (any pink? (map (i \ peep east i 0) ^(80 * 48)))))
; --- the door: shut far off, opening as the player comes near, the doorway stopping a walk
; --- until it is open; the walls stopping one always
(: far (at 80 48) _ (each ^20 (_ \ corridor-move far))
   near (pins (at 80 48) 'pz 10.5) _ (each ^5 (_ \ corridor-move near))
   opened (pins (at 80 48) 'pz 10.5) _ (each ^40 (_ \ corridor-move opened))
   shut (pins (at 80 48) 'pz 12.0)
   walk (pins (at 80 48) 'pz 11.0)
   _ (steps walk 107 80)
   wall (steps (pins (at 80 48) 'th (pi / 2.0)) 107 40)
   back (steps (at 80 48) 106 40)
 (test (far 'doors = [0.0]) (0.0 < near 'doors 0 < 1.0) (opened 'doors = [1.0])
       !(corridor-free? shut 0.0 12.5) (corridor-free? opened 0.0 12.5) !(corridor-free? opened 0.8 12.5)
       (13.5 < walk 'pz) (walk 'pz < 16.5)
       (wall 'px < 1.2) (0.85 < wall 'px) (body-r <= back 'pz)))
; --- read again: the first look takes the file's stamp; nothing while it stands; a change
; --- rebuilds the scene with the player where they stand; a broken save keeps the last
; --- level and says why, on the bottom row
(: p ("/tmp/corridortest-" + show (getpid 0) + ".l")
   _ (put p "(level \"a\" (room 0 0 4 4 3) (strip 2 2))")
   st (corridor-watch (pins (corridor-new 40 24 (corridor-load p) "/tmp/") 'path p 'px 2.5 'pz 1.5))
   a (corridor-watch st 'lvl 'name)
   _ (put p "(level \"b\" (room 0 0 4 4 3) (strip 1 1) (strip 3 3))")
   b (corridor-watch st) got (b 'lvl 'name) nl #(b 'sc 'lights) where [(b 'px) (b 'pz)] said (b 'msg) e0 (b 'err)
   _ (put p "(level \"c\" (room 0 0")
   c (corridor-watch b)
   _ (unlink p)
 (test (a = "a") (got = "b") (nl = 2) (where = [2.5 1.5]) (has? said "again") (e0 = 0)
       (c 'lvl 'name = "b") (c 'err = 1) (string? (c 'msg)) (has? (corridor-frame c) "not a level")))
; --- the sign: its letters' strokes, a space between words, its width by its letters
(: hi (neon-strokes "HI") sp (neon-strokes "H I") s (neon-sign "OK" [0.0 0.0 0.0] [1.0 0.0 0.0] [0.0 1.0 0.0] [0.0 0.0 -1.0] 0.3 [1.0 0.2 0.6])
 (test (#(hi 0) = 6) (#(sp 0) = 6) (hi 1 < sp 1) (0 < s 'tube 'n) (0 < s 'halo 'n) (two? (s 'lamp 'at))
       (all (p \ p 2 < 0.0) (s 'lamp 'at)) (s 'w = 0.3 * hi 1)))
(test_fin ())
(puts "corridor: ok\n")
