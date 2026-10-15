; test/host/wad.l -- lore's wad: a wad laid here, a room 256 square under the sky with a barrel
; in it, read, walked, drawn and heard. run: cat test/00-init.l test/host/wad.l | out/love
(borrow 'wad)
(borrow 'mixer)
(borrow 'bytes)
(: (wad-t-w16 v) (wrle (v < 0 ? (v + 65536) v) 2)
   (wad-t-name s) (s + zbytes (8 - #s))
   (wad-t-cat l) (foldl (\ a s (a + s)) "" l)
   ; ..a patch w by h of one colour, each column a single post
   (wad-t-patch w h c lo to) (: col (wad-t-cat [(string 0) (string h) (string 0) (wad-t-cat (map (_ \ string c) ^h)) (string 0) (string 255)])
     (wad-t-cat [(wad-t-w16 w) (wad-t-w16 h) (wad-t-w16 lo) (wad-t-w16 to)
                 (wad-t-cat (map (k \ wrle (8 + 4 * w + k * #col) 4) ^w)) (wad-t-cat (map (_ \ col) ^w))]))
   (wad-t-tex nm w h) (wad-t-cat [(wad-t-name nm) (wrle 0 4) (wad-t-w16 w) (wad-t-w16 h) (wrle 0 4) (wad-t-w16 1)
                                  (wad-t-w16 0) (wad-t-w16 0) (wad-t-w16 (nm = "WALL" ? 0 1)) (wad-t-w16 1) (wad-t-w16 0)])
   ; ..gray but four: 10 red, 20 blue, 30 green, 40 yellow
   wad-t-pal (wad-t-cat (map (i \ (i @ 10 "\xc8\x1e\x1e" 20 "\x1e\x1e\xc8" 30 "\x1e\xc8\x1e" 40 "\xdc\xdc\x28"
                                     _ (wad-t-cat [(string i) (string i) (string i)])))
                             ^256))
   wad-t-t1 (: a (wad-t-tex "WALL" 64 64) b (wad-t-tex "SKY1" 256 128)
              (wad-t-cat [(wrle 2 4) (wrle 12 4) (wrle (12 + #a) 4) a b]))
   ; ..the room: four walls, each its right side in, one sector, one subsector, no nodes
   vs [[0 0] [0 256] [256 256] [256 0]]
   wad-t-map [["THINGS" (wad-t-cat (map (t \ wad-t-cat (map wad-t-w16 t)) [[128 64 90 1 7] [128 192 0 2035 7]]))]
              ["LINEDEFS" (wad-t-cat (map (i \ wad-t-cat (map wad-t-w16 [i ((i + 1) % 4) 1 0 0 i 65535])) ^4))]
              ["SIDEDEFS" (wad-t-cat (map (_ \ wad-t-cat [(wad-t-w16 0) (wad-t-w16 0) (wad-t-name "-") (wad-t-name "-") (wad-t-name "WALL") (wad-t-w16 0)]) ^4))]
              ["VERTEXES" (wad-t-cat (map (v \ wad-t-w16 (v 0) + wad-t-w16 (v 1)) vs))]
              ["SEGS" (wad-t-cat (map (i \ wad-t-cat (map wad-t-w16 [i ((i + 1) % 4) 0 i 0 0])) ^4))]
              ["SSECTORS" (wad-t-w16 4 + wad-t-w16 0)]
              ["NODES" ""]
              ["SECTORS" (wad-t-cat [(wad-t-w16 0) (wad-t-w16 128) (wad-t-name "FLR") (wad-t-name "F_SKY1") (wad-t-w16 255) (wad-t-w16 0) (wad-t-w16 0)])]
              ["REJECT" ""] ["BLOCKMAP" ""]]
   ; ..and a second: the room, and north of it a door shut (a sector floor and ceiling 0) whose
   ;   line is a door's (special 1), a zombieman past it, a health bonus on the way; one node
   ;   between them
   (wad-t-side up mid s) (wad-t-cat [(wad-t-w16 0) (wad-t-w16 0) (wad-t-name up) (wad-t-name "-") (wad-t-name mid) (wad-t-w16 s)])
   (wad-t-recs rs) (wad-t-cat (map (r \ wad-t-cat (map wad-t-w16 r)) rs))
   wad-t-map2 [["THINGS" (wad-t-recs [[128 64 90 1 7] [128 384 270 3004 7] [128 128 0 2014 7]])]
               ["LINEDEFS" (wad-t-recs [[0 1 1 0 0 0 65535] [1 2 4 1 0 1 2] [2 3 1 0 0 3 65535] [3 0 1 0 0 4 65535]
                                        [1 4 1 0 0 5 65535] [4 5 1 0 0 6 65535] [5 2 1 0 0 7 65535]])]
               ["SIDEDEFS" (wad-t-cat [(wad-t-side "-" "WALL" 0) (wad-t-side "WALL" "-" 0) (wad-t-side "-" "-" 1) (wad-t-side "-" "WALL" 0)
                                       (wad-t-side "-" "WALL" 0) (wad-t-side "-" "WALL" 1) (wad-t-side "-" "WALL" 1) (wad-t-side "-" "WALL" 1)])]
               ["VERTEXES" (wad-t-recs [[0 0] [0 256] [256 256] [256 0] [0 512] [256 512]])]
               ["SEGS" (wad-t-recs [[0 1 0 0 0 0] [1 2 0 1 0 0] [2 3 0 2 0 0] [3 0 0 3 0 0] [2 1 0 1 1 0] [1 4 0 4 0 0] [4 5 0 5 0 0] [5 2 0 6 0 0]])]
               ["SSECTORS" (wad-t-recs [[4 0] [4 4]])]
               ["NODES" (wad-t-recs [[0 256 256 0 256 0 0 256 512 256 0 256 32768 32769]])]
               ["SECTORS" (wad-t-cat [(wad-t-cat [(wad-t-w16 0) (wad-t-w16 128) (wad-t-name "FLR") (wad-t-name "F_SKY1") (wad-t-w16 255) (wad-t-w16 0) (wad-t-w16 0)])
                                      (wad-t-cat [(wad-t-w16 0) (wad-t-w16 0) (wad-t-name "FLR") (wad-t-name "FLR") (wad-t-w16 160) (wad-t-w16 0) (wad-t-w16 0)])])]
               ["REJECT" ""] ["BLOCKMAP" ""]]
   ; ..a shot's sound: format 3, 11025 a second, a tenth of a second of square wave padded 16 either end
   wad-t-snd (: pd (wad-t-cat (map (_ \ string 128) ^16))
               (wad-t-cat [(wad-t-w16 3) (wad-t-w16 11025) (wrle 1135 4) pd (wad-t-cat (map (i \ string (i // 25 % 2 ? 64 192)) ^1103)) pd]))
   lumps ([["PLAYPAL" wad-t-pal] ["DSPISTOL" wad-t-snd] ["PNAMES" (wrle 2 4 + wad-t-name "WALLP" + wad-t-name "SKYP")] ["TEXTURE1" wad-t-t1]
           ["WALLP" (wad-t-patch 64 64 10 0 0)] ["SKYP" (wad-t-patch 256 128 20 0 0)]
           ["F_START" ""] ["FLR" (wad-t-cat (map (_ \ string 30) ^4096))] ["F_END" ""]
           ["S_START" ""] ["BAR1A0" (wad-t-patch 16 32 40 8 32)] ["S_END" ""] ["E1M1" ""]] + wad-t-map + [["E1M2" ""]] + wad-t-map2)
   ; ..laid: the header, the lumps, then the directory
   offs (rev (foldl (\ a l ((<a + #(l 1)) . a)) [12] lumps))
   body (wad-t-cat (map (l \ l 1) lumps))
   dir (wad-t-cat (map (i \ wrle (offs i) 4 + wrle #(lumps i 1) 4 + wad-t-name (lumps i 0)) ^#lumps))
   path ("out/.wad-room-" + show (getpid 0) + ".wad")
   _ (open path "w" @ p (say p ("PWAD" + wrle #lumps 4 + wrle (12 + #body) 4 + body + dir), close p))

   ; read: the lumps and the map
   wd (wad-read path)
   _ (test (#(wd 'ls) = #lumps) (wad-read "out/.no-such.wad" = ()))
   M (wad-map wd "E1M1")
   _ (test (#(M 'vs) = 4) (#(M 'lines) = 4) (#(M 'secs) = 1) (#(M 'things) = 2) (wad-map wd "E9M9" = ()))
   _ (test (wad-sector M 128.0 128.0 = 0))
   ; ..a node that names itself, as a damaged wad may: an answer, not a loop
   _ (test (wad-sector (pins (wad-map wd "E1M1") 'nodes [[0.0 0.0 1.0 0.0 0 0]]) 9.0 9.0 = 0))

   ; the start: the player's thing, the eye 41 over the floor, facing north (lore's z)
   st (pins (wad-new 64 40 wd M) 'w 64 'h 40 'kp 1)
   _ (test (st 'px = 128.0) (st 'pz = 64.0) (st 'py = 41.0) (st 'th = 0.0))

   ; drawn: the barrel ahead in the middle, the red wall beside it, the sky above, the floor below
   f (wad-pens st)
   (px x y) (peep f (y * 64 + x) -1)
   (rgb c) [((c >> 16) & 255) ((c >> 8) & 255) (c & 255)]
   (most c k) (: v (rgb c) (all (j \ j = k || v j < v k) ^3))
   _ (test (#f = 64 * 40) (aall (f != -1)))
   _ (test (: v (rgb (px 32 26)) (v 0 > 100 && v 1 > 100 && v 2 < 100)))   ; the barrel, yellow
   _ (test (most (px 8 20) 0))                                    ; the wall, red
   _ (test (px 32 0 = 1973960))                                   ; the sky's own blue, 0x1e1ec8, unlit
   _ (test (most (px 32 39) 1))                                   ; the floor, green

   ; walked: free in the room, not at the wall; north stops short of the barrel, and beside it
   ;   short of the wall
   _ (test (wad-free? st 128.0 128.0) !(wad-free? st 128.0 250.0) !(wad-free? st 4.0 128.0))
   s (foldl (\ s _ (wad-tics (wad-step s 'forward) 1)) (pin st 'dt 0.25) ^40)
   _ (test (s 'pz > 150.0) (s 'pz < 167.0) (s 'px = 128.0))
   s (foldl (\ s _ (wad-tics (wad-step s 'forward) 1)) (pins (wad-new 64 40 wd M) 'dt 0.25 'px 40.0) ^40)
   _ (test (s 'pz > 200.0) (s 'pz < 241.0))

   ; the door: the bonus taken on the way to it, the door shut, the zombieman behind it asleep
   _ (rng-set (wheel 3))
   M2 (wad-map wd "E1M2")
   d (pins (wad-new 64 40 wd M2) 'w 64 'h 40 'kp 1 'dt 0.25)
   (zom s) <(filter (o \ o 't = 3004) (s 'objs))
   _ (test (#(d 'objs) = 2) (zom d 'st = 'idle) (d 'hp = 100) (d 'bul = 50))
   d (wad-tics (foldl (\ s _ (wad-tics (wad-step s 'forward) 1)) d ^40) 35)
   _ (test (d 'hp = 101) (d 'pz > 200.0) (d 'pz < 241.0) (zom d 'st = 'idle))
   ; ..used, it opens to its neighbour's ceiling less 4, and the zombieman wakes to the player
   d (wad-tics (wad-step d 'use) 70)
   (heard s) (map (f \ f 0) (s 'sfx))
   _ (test (d 'M 'secs 1 1 = 124) (wad-free? d 128.0 300.0) (elem "DOROPN" (heard d)) (elem "ITEMUP" (heard d)))
   d (wad-tics d 24)
   _ (test (zom d 'st != 'idle) (any (n \ elem n ["POSIT1" "POSIT2" "POSIT3"]) (heard d)))
   ; ..heard: the mixer takes what was asked and writes 16-bit pairs, the shot's square wave in them
   snd ("out/.wad-snd-" + show (getpid 0) + ".raw")
   _ (open snd "w" @ p (: fd (wad-mixer p wd) _ (fd d) _ (test (d 'sfx = ()))
                          d1 (wad-step d 'fire) _ (test (elem "PISTOL" (heard d1)))
                          (fd d1, fd d1, close p)))
   pcm (uread snd @ r (two? r ? (r 1) ""))
   _ (test (#pcm > 0) (#pcm % 4 = 0) (any (i \ pcm i != 0) ^#pcm))
   ; ..the mixer alone, in metres: a tone east of a listener facing north sounds in the right ear
   ;   more, and one past far not at all
   (wad-t-mix at) (: q ("out/.wad-mix-" + show (getpid 0) + ".raw")
     _ (open q "w" @ p (: fd (mix-new p (_ \ [(iota 400 % 2 * 1.0 - 0.5) 8000]) (_ \ [0.0 0.0 0.0]) {'near 1.0 'far 20.0})
                          (fd (mix-cry {} "tone" at), close p)))
     b (uread q @ r (two? r ? (r 1) ""))
     _ (unlink q)
     (side k) (net (map (i \ (: v (rdle b (4 * i + 2 * k) 2) (v < 32768 ? v (65536 - v)))) ^(#b // 4)))
     [(side 0) (side 1)])
   e (wad-t-mix [5.0 0.0])
   _ (test (e 1 > 2 * e 0) (e 0 > 0) (wad-t-mix [30.0 0.0] = [0 0]) (: c (wad-t-mix ()) (c 0 = c 1 && c 0 > 0)))
   ; ..and the pistol puts it down, a bullet a shot
   (shoot s k) (k = 0 || zom s 'st = 'die ? s (shoot (wad-tics (wad-step s 'fire) 15) (k - 1)))
   d (shoot d 12)
   _ (test (zom d 'st = 'die) (d 'bul < 50) (d 'hp > 0))

   ; a rocket instead, into the zombieman behind the door: a burst, a rocket the fewer
   r (wad-tics (wad-step (pins (wad-new 64 40 wd (wad-map wd "E1M2")) 'px 128.0 'pz 230.0) 'use) 70)
   r (wad-tics (wad-step (pins r 'has [0 1 4] 'rkt 2 'gun 4) 'fire) 20)
   _ (test (zom r 'st = 'die) (r 'rkt = 1) (any (o \ o 'proj = 1 && o 'boom > 0) (r 'objs)))
   _ (test (elem "RLAUNC" (heard r)) (elem "BAREXP" (heard r)) (any (n \ elem n ["PODTH1" "PODTH2" "PODTH3"]) (heard r)))

   ; the body: a push glides on and slows; a strafe goes sideways; a gun changed comes down, then up
   ; (the state is one tablet, ticked in place: what to compare is read off first)
   g (wad-tics (wad-step (wad-new 64 40 wd M) 'forward) 1) z1 (g 'pz) v1 (g 'vz)
   g (wad-tics g 10)
   _ (test (z1 > 64.0) (g 'pz - z1 > 8.0) (g 'vz < v1))
   g (wad-tics (wad-step (wad-new 64 40 wd M) 'strafe-right) 4)
   _ (test (g 'px > 140.0) (g 'pz = 64.0))
   g (wad-tics (wad-step (wad-new 64 40 wd M) 'gun1) 8)
   _ (test (g 'gun = 1) (g 'gy > 0))
   g (wad-tics g 40)
   _ (test (g 'gun = 0) (g 'gy = 0))

   ; the floor and the light, by the sector's type: 7 hurts 5 each 32 tics, 9 is a secret, 3 a slow strobe
   (typed k) (: m (wad-map wd "E1M1") (pins m 'secs [[0 128 "FLR" "F_SKY1" 255 k 0]]))
   f (wad-tics (wad-new 64 40 wd (typed 7)) 70)
   _ (test (f 'hp = 90))
   f (wad-tics (wad-new 64 40 wd (typed 9)) 1)
   _ (test (f 'secrets = 1) (f 'msg = "a secret") (f 'M 'secs 0 5 = 0))
   f (wad-new 64 40 wd (typed 3))
   seen (keys (foldl (\ t v (pin t v 1)) {} (map (_ \ (: _ (wad-tics f 1) (peep (wad-pens f) (20 * 64 + 8) -1))) ^40)))
   ((test (#(f 'lights) = 1) (#seen >= 2)),
    unlink path, unlink snd,
    test_fin (),
    puts "wad: ok\n"))
